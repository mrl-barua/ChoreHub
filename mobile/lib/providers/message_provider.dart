import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../repositories/chore_repository.dart';
import '../repositories/message_repository.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
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

  MessageState({
    this.messages = const [],
    this.typingUserIds = const {},
    this.isLoading = false,
    this.hasMore = true,
    this.unreadCount = 0,
    this.searchQuery,
    this.isSearching = false,
  });
}

class MessageNotifier extends Notifier<MessageState> {
  final MessageRepository _repo = MessageRepository();
  final ChoreRepository _choreRepo = ChoreRepository();
  final SocketService _socket = SocketService();
  final ApiClient _apiClient = ApiClient();
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

    // Listen for incoming messages
    _messageSub = _socket.onMessage.listen((message) async {
      await _repo.insertMessage(message);
      final enriched = await _enrichMessage(message);
      final current = state.messages;
      if (!current.any((m) => m.id == enriched.id)) {
        // Update unread count if message is from someone else
        final user = ref.read(authProvider).user;
        final newUnread = (enriched.userId != user?.id) ? state.unreadCount + 1 : state.unreadCount;
        state = MessageState(
          messages: [...current, enriched],
          typingUserIds: state.typingUserIds,
          hasMore: state.hasMore,
          unreadCount: newUnread,
        );
      }
    });

    // Listen for typing
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

    // Listen for reactions
    _reactionSub = _socket.onReaction.listen((data) async {
      final messageId = data['messageId'] as String;
      final reactions = data['reactions'] as String?;
      await _repo.updateReactions(messageId, reactions);
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

    // Listen for read receipts
    _readReceiptSub = _socket.onReadReceipt.listen((data) async {
      final userId = data['userId'] as String;
      final messageIds = (data['messageIds'] as List).map((e) => e as String).toList();
      for (final msgId in messageIds) {
        await _repo.upsertReadReceipt(msgId, userId);
      }
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

    // Listen for deletes
    _deleteSub = _socket.onDelete.listen((messageId) async {
      await _repo.softDelete(messageId);
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
      state = MessageState();
      return;
    }

    state = MessageState(isLoading: true);

    // Try to fetch from server first
    if (ConnectivityService().isOnline) {
      try {
        final response = await _apiClient.dio.get('/messages', queryParameters: {
          'familyId': family.id,
          'limit': 50,
        });
        final serverMessages = (response.data as List).map((m) => Message.fromJson(m)).toList();
        for (final msg in serverMessages) {
          await _repo.insertMessage(msg);
        }
      } catch (_) {}
    }

    final messages = await _repo.getMessages(family.id, limit: 50);
    final enriched = await _enrichMessages(messages);

    // Load unread count
    final user = ref.read(authProvider).user;
    int unread = 0;
    if (user != null) {
      unread = await _repo.getUnreadCount(family.id, user.id);
    }

    state = MessageState(messages: enriched, hasMore: messages.length >= 50, unreadCount: unread);
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.messages.isEmpty) return;

    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;

    final oldest = state.messages.first.createdAt;

    if (ConnectivityService().isOnline) {
      try {
        final response = await _apiClient.dio.get('/messages', queryParameters: {
          'familyId': family.id,
          'before': oldest,
          'limit': 30,
        });
        final olderMessages = (response.data as List).map((m) => Message.fromJson(m)).toList();
        for (final msg in olderMessages) {
          await _repo.insertMessage(msg);
        }
      } catch (_) {}
    }

    final olderLocal = await _repo.getMessages(family.id, limit: 30, before: oldest);
    if (olderLocal.isEmpty) {
      state = MessageState(
        messages: state.messages,
        typingUserIds: state.typingUserIds,
        hasMore: false,
        unreadCount: state.unreadCount,
      );
      return;
    }

    final enriched = await _enrichMessages(olderLocal);
    state = MessageState(
      messages: [...enriched, ...state.messages],
      typingUserIds: state.typingUserIds,
      hasMore: olderLocal.length >= 30,
      unreadCount: state.unreadCount,
    );
  }

  Future<void> sendMessage(String text, {String? choreId, List<String>? mentionUserIds, String? replyToId, String? imageUrl}) async {
    final user = ref.read(authProvider).user;
    final family = ref.read(familyProvider).currentFamily;
    if (user == null || family == null) return;
    if (text.trim().isEmpty && imageUrl == null) return;

    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final mentionsStr = mentionUserIds != null && mentionUserIds.isNotEmpty ? mentionUserIds.join(',') : null;

    // Build replyTo from existing message
    ReplyTo? replyTo;
    if (replyToId != null) {
      final original = state.messages.where((m) => m.id == replyToId).firstOrNull;
      if (original != null) {
        replyTo = ReplyTo(id: original.id, text: original.text, userId: original.userId, userName: original.userName);
      }
    }

    final message = Message(
      id: id,
      familyId: family.id,
      userId: user.id,
      text: text.trim().isEmpty ? (imageUrl != null ? 'Sent a photo' : '') : text.trim(),
      createdAt: now,
      syncStatus: 'pending',
      userName: user.displayName,
      choreId: choreId,
      mentions: mentionsStr,
      replyToId: replyToId,
      imageUrl: imageUrl,
      replyTo: replyTo,
    );

    await _repo.insertMessage(message);

    state = MessageState(
      messages: [...state.messages, message],
      typingUserIds: state.typingUserIds,
      hasMore: state.hasMore,
      unreadCount: state.unreadCount,
    );

    _socket.sendMessage(
      id: id,
      familyId: family.id,
      text: message.text,
      choreId: choreId,
      mentions: mentionsStr,
      replyToId: replyToId,
      imageUrl: imageUrl,
    );

    _socket.sendStopTyping(family.id);
  }

  Future<String?> uploadImage(File file) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
      });
      final response = await _apiClient.dio.post('/messages/upload', data: formData);
      return response.data['imageUrl'] as String?;
    } catch (e) {
      print('Image upload error: $e');
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

    // Filter to only messages not sent by current user
    final toMark = messageIds.where((id) {
      final msg = state.messages.where((m) => m.id == id).firstOrNull;
      return msg != null && msg.userId != user.id && !msg.readBy.contains(user.id);
    }).toList();

    if (toMark.isEmpty) return;

    _socket.markRead(messageIds: toMark, familyId: family.id);

    // Optimistically update unread count
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

    List<Message> results = [];
    if (ConnectivityService().isOnline) {
      try {
        final response = await _apiClient.dio.get('/messages', queryParameters: {
          'familyId': family.id,
          'search': query,
          'limit': 50,
        });
        results = (response.data as List).map((m) => Message.fromJson(m)).toList();
      } catch (_) {}
    }

    if (results.isEmpty) {
      results = await _repo.searchMessages(family.id, query);
    }

    final enriched = await _enrichMessages(results);
    state = MessageState(messages: enriched, isSearching: true, searchQuery: query, hasMore: false);
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

  Future<Message> _enrichMessage(Message msg) async {
    if (msg.choreId == null || msg.choreId!.isEmpty || msg.chore != null) return msg;
    final chore = await _choreRepo.getChoreById(msg.choreId!);
    if (chore == null) return msg;
    return msg.copyWith(
      chore: ChoreAttachment(
        id: chore.id,
        title: chore.title,
        status: chore.status,
        category: chore.category,
        assignedTo: chore.assignedTo,
      ),
    );
  }

  Future<List<Message>> _enrichMessages(List<Message> messages) async {
    final result = <Message>[];
    for (final msg in messages) {
      result.add(await _enrichMessage(msg));
    }
    return result;
  }
}

final messageProvider = NotifierProvider<MessageNotifier, MessageState>(MessageNotifier.new);
