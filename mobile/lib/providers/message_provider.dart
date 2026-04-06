import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../services/api_client.dart';
import '../services/message_service.dart';
import '../services/socket_service.dart';
import 'auth_provider.dart';
import 'family_provider.dart';

class MessageState {
  final List<Message> messages;
  final Set<String> typingUserIds;
  final bool isLoading;
  final bool hasMore;
  final int unreadCount;
  final String? searchQuery;
  final bool isSearching;
  final String? error;

  MessageState({
    this.messages = const [],
    this.typingUserIds = const {},
    this.isLoading = false,
    this.hasMore = true,
    this.unreadCount = 0,
    this.searchQuery,
    this.isSearching = false,
    this.error,
  });
}

class MessageNotifier extends Notifier<MessageState> {
  final SocketService _socket = SocketService();
  final MessageService _messageService = MessageService(ApiClient());
  StreamSubscription<Message>? _messageSub;
  StreamSubscription<String>? _typingSub;
  StreamSubscription<String>? _stopTypingSub;
  StreamSubscription<Map<String, dynamic>>? _reactionSub;
  StreamSubscription<Map<String, dynamic>>? _readReceiptSub;
  StreamSubscription<String>? _deleteSub;
  Timer? _typingTimer;

  @override
  MessageState build() {
    _init();
    ref.onDispose(() {
      _messageSub?.cancel();
      _typingSub?.cancel();
      _stopTypingSub?.cancel();
      _reactionSub?.cancel();
      _readReceiptSub?.cancel();
      _deleteSub?.cancel();
      _typingTimer?.cancel();
    });
    return MessageState(isLoading: true);
  }

  Future<void> _init() async {
    await _socket.connect();

    ref.listen(familyProvider, (prev, next) {
      final prevFamily = prev?.currentFamily?.id;
      final nextFamily = next.currentFamily?.id;
      if (nextFamily != null && nextFamily != prevFamily) {
        loadMessages();
      }
    });

    _messageSub = _socket.onMessage.listen((message) {
      final current = state.messages;
      if (!current.any((m) => m.id == message.id)) {
        final user = ref.read(authProvider).user;
        final newUnread = (message.userId != user?.id) ? state.unreadCount + 1 : state.unreadCount;
        state = MessageState(
          messages: [...current, message],
          typingUserIds: state.typingUserIds,
          hasMore: state.hasMore,
          unreadCount: newUnread,
        );
      }
    });

    _typingSub = _socket.onTyping.listen((userId) {
      final user = ref.read(authProvider).user;
      if (userId == user?.id) return;
      state = MessageState(
        messages: state.messages,
        typingUserIds: {...state.typingUserIds, userId},
        hasMore: state.hasMore,
        unreadCount: state.unreadCount,
      );
    });

    _stopTypingSub = _socket.onStopTyping.listen((userId) {
      final updated = {...state.typingUserIds}..remove(userId);
      state = MessageState(
        messages: state.messages,
        typingUserIds: updated,
        hasMore: state.hasMore,
        unreadCount: state.unreadCount,
      );
    });

    _reactionSub = _socket.onReaction.listen((data) {
      final messageId = data['messageId'] as String;
      final reactions = data['reactions'] as String?;
      final msgs = state.messages.map((m) {
        if (m.id == messageId) return m.copyWith(reactions: reactions);
        return m;
      }).toList();
      state = MessageState(
        messages: msgs,
        typingUserIds: state.typingUserIds,
        hasMore: state.hasMore,
        unreadCount: state.unreadCount,
      );
    });

    _readReceiptSub = _socket.onReadReceipt.listen((data) {
      final userId = data['userId'] as String;
      final messageIds = (data['messageIds'] as List).map((e) => e as String).toList();
      final msgs = state.messages.map((m) {
        if (messageIds.contains(m.id) && !m.readBy.contains(userId)) {
          return m.copyWith(readBy: [...m.readBy, userId]);
        }
        return m;
      }).toList();
      state = MessageState(
        messages: msgs,
        typingUserIds: state.typingUserIds,
        hasMore: state.hasMore,
        unreadCount: state.unreadCount,
      );
    });

    _deleteSub = _socket.onDelete.listen((messageId) {
      final msgs = state.messages.where((m) => m.id != messageId).toList();
      state = MessageState(
        messages: msgs,
        typingUserIds: state.typingUserIds,
        hasMore: state.hasMore,
        unreadCount: state.unreadCount,
      );
    });

    await loadMessages();
  }

  Future<void> loadMessages() async {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) {
      debugPrint('[Messages] family is null, waiting...');
      return;
    }

    debugPrint('[Messages] Loading from server for family: ${family.id}');
    state = MessageState(isLoading: true);

    try {
      final messages = await _messageService.loadMessages(family.id, limit: 50);
      debugPrint('[Messages] Server returned ${messages.length} messages');

      state = MessageState(
        messages: messages,
        hasMore: messages.length >= 50,
      );
    } catch (e) {
      debugPrint('[Messages] Server fetch failed: $e');
      state = MessageState(error: 'Could not load messages. Pull to retry.');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.messages.isEmpty) return;

    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;

    final oldest = state.messages.first.createdAt;

    try {
      final olderMessages = await _messageService.loadMessages(
        family.id,
        limit: 30,
        before: oldest,
      );

      if (olderMessages.isEmpty) {
        state = MessageState(
          messages: state.messages,
          typingUserIds: state.typingUserIds,
          hasMore: false,
          unreadCount: state.unreadCount,
        );
        return;
      }

      state = MessageState(
        messages: [...olderMessages, ...state.messages],
        typingUserIds: state.typingUserIds,
        hasMore: olderMessages.length >= 30,
        unreadCount: state.unreadCount,
      );
    } catch (e) {
      debugPrint('[Messages] Load more failed: $e');
    }
  }

  /// Send message — socket for real-time, REST as backup
  Future<void> sendMessage(String text, {String? choreId, List<String>? mentionUserIds, String? replyToId, String? imageUrl}) async {
    final user = ref.read(authProvider).user;
    final family = ref.read(familyProvider).currentFamily;
    if (user == null || family == null) return;
    if (text.trim().isEmpty && imageUrl == null) return;

    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final mentionsStr = mentionUserIds != null && mentionUserIds.isNotEmpty ? mentionUserIds.join(',') : null;

    ReplyTo? replyTo;
    if (replyToId != null) {
      final original = state.messages.where((m) => m.id == replyToId).firstOrNull;
      if (original != null) {
        replyTo = ReplyTo(id: original.id, text: original.text, userId: original.userId, userName: original.userName);
      }
    }

    final msgText = text.trim().isEmpty ? (imageUrl != null ? 'Sent a photo' : '') : text.trim();

    final message = Message(
      id: id,
      familyId: family.id,
      userId: user.id,
      text: msgText,
      createdAt: now,
      userName: user.displayName,
      choreId: choreId,
      mentions: mentionsStr,
      replyToId: replyToId,
      imageUrl: imageUrl,
      replyTo: replyTo,
    );

    state = MessageState(
      messages: [...state.messages, message],
      typingUserIds: state.typingUserIds,
      hasMore: state.hasMore,
      unreadCount: state.unreadCount,
    );

    _socket.sendMessage(
      id: id,
      familyId: family.id,
      text: msgText,
      choreId: choreId,
      mentions: mentionsStr,
      replyToId: replyToId,
      imageUrl: imageUrl,
    );

    _socket.sendStopTyping(family.id);

    try {
      await _messageService.sendMessageRest(
        id: id,
        familyId: family.id,
        text: msgText,
        choreId: choreId,
        mentions: mentionsStr,
        replyToId: replyToId,
        imageUrl: imageUrl,
        createdAt: now,
      );
    } catch (e) {
      debugPrint('[Messages] REST backup send failed: $e');
    }
  }

  Future<String?> uploadImage(File file) async {
    try {
      return await _messageService.uploadImage(file.path);
    } catch (e) {
      debugPrint('[Messages] Image upload error: $e');
      return null;
    }
  }

  void toggleReaction(String messageId, String emoji) {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;
    _socket.toggleReaction(messageId: messageId, familyId: family.id, emoji: emoji);
  }

  void markMessagesRead(List<String> messageIds) {
    final family = ref.read(familyProvider).currentFamily;
    final user = ref.read(authProvider).user;
    if (family == null || user == null) return;

    final toMark = messageIds.where((id) {
      final msg = state.messages.where((m) => m.id == id).firstOrNull;
      return msg != null && msg.userId != user.id && !msg.readBy.contains(user.id);
    }).toList();

    if (toMark.isEmpty) return;

    _socket.markRead(messageIds: toMark, familyId: family.id);

    final newUnread = (state.unreadCount - toMark.length).clamp(0, state.unreadCount);
    state = MessageState(
      messages: state.messages,
      typingUserIds: state.typingUserIds,
      hasMore: state.hasMore,
      unreadCount: newUnread,
    );
  }

  void deleteMessage(String messageId) {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;
    _socket.deleteMessage(messageId: messageId, familyId: family.id);
  }

  Future<void> searchMessages(String query) async {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;

    if (query.isEmpty) {
      await loadMessages();
      return;
    }

    state = MessageState(isLoading: true, isSearching: true, searchQuery: query);

    try {
      final results = await _messageService.loadMessages(family.id, limit: 50, search: query);
      state = MessageState(messages: results, isSearching: true, searchQuery: query, hasMore: false);
    } catch (e) {
      debugPrint('[Messages] Search failed: $e');
      state = MessageState(isSearching: true, searchQuery: query, error: 'Search failed');
    }
  }

  void clearSearch() {
    loadMessages();
  }

  void onTyping() {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;

    _socket.sendTyping(family.id);

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _socket.sendStopTyping(family.id);
    });
  }
}

final messageProvider = NotifierProvider<MessageNotifier, MessageState>(MessageNotifier.new);
