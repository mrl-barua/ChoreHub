import 'dart:async';
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

  MessageState({
    this.messages = const [],
    this.typingUserIds = const {},
    this.isLoading = false,
    this.hasMore = true,
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
  Timer? _typingTimer;

  @override
  MessageState build() {
    _init();
    ref.onDispose(() {
      _messageSub?.cancel();
      _typingSub?.cancel();
      _stopTypingSub?.cancel();
      _typingTimer?.cancel();
    });
    return MessageState(isLoading: true);
  }

  Future<void> _init() async {
    // Connect socket
    await _socket.connect();

    // Listen for incoming messages
    _messageSub = _socket.onMessage.listen((message) async {
      await _repo.insertMessage(message);
      final enriched = await _enrichMessage(message);
      final current = state.messages;
      if (!current.any((m) => m.id == enriched.id)) {
        state = MessageState(
          messages: [...current, enriched],
          typingUserIds: state.typingUserIds,
          hasMore: state.hasMore,
        );
      }
    });

    // Listen for typing
    _typingSub = _socket.onTyping.listen((userId) {
      final user = ref.read(authProvider).user;
      if (userId == user?.id) return; // Don't show own typing
      state = MessageState(
        messages: state.messages,
        typingUserIds: {...state.typingUserIds, userId},
        hasMore: state.hasMore,
      );
    });

    _stopTypingSub = _socket.onStopTyping.listen((userId) {
      final updated = {...state.typingUserIds}..remove(userId);
      state = MessageState(
        messages: state.messages,
        typingUserIds: updated,
        hasMore: state.hasMore,
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

    // Load from local DB and enrich with chore data
    final messages = await _repo.getMessages(family.id, limit: 50);
    final enriched = await _enrichMessages(messages);
    state = MessageState(messages: enriched, hasMore: messages.length >= 50);
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.messages.isEmpty) return;

    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;

    final oldest = state.messages.first.createdAt;

    // Try server first for older messages
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
      state = MessageState(messages: state.messages, typingUserIds: state.typingUserIds, hasMore: false);
      return;
    }

    state = MessageState(
      messages: [...olderLocal, ...state.messages],
      typingUserIds: state.typingUserIds,
      hasMore: olderLocal.length >= 30,
    );
  }

  Future<void> sendMessage(String text, {String? choreId, List<String>? mentionUserIds}) async {
    final user = ref.read(authProvider).user;
    final family = ref.read(familyProvider).currentFamily;
    if (user == null || family == null || text.trim().isEmpty) return;

    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final mentionsStr = mentionUserIds != null && mentionUserIds.isNotEmpty ? mentionUserIds.join(',') : null;

    final message = Message(
      id: id,
      familyId: family.id,
      userId: user.id,
      text: text.trim(),
      createdAt: now,
      syncStatus: 'pending',
      userName: user.displayName,
      choreId: choreId,
      mentions: mentionsStr,
    );

    await _repo.insertMessage(message);

    state = MessageState(
      messages: [...state.messages, message],
      typingUserIds: state.typingUserIds,
      hasMore: state.hasMore,
    );

    // Send via socket
    _socket.sendMessage(id: id, familyId: family.id, text: text.trim(), choreId: choreId, mentions: mentionsStr);

    // Stop typing indicator
    _socket.sendStopTyping(family.id);
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

  /// Enrich a single message with chore data from local DB
  Future<Message> _enrichMessage(Message msg) async {
    if (msg.choreId == null || msg.choreId!.isEmpty || msg.chore != null) return msg;
    final chore = await _choreRepo.getChoreById(msg.choreId!);
    if (chore == null) return msg;
    return Message(
      id: msg.id,
      familyId: msg.familyId,
      userId: msg.userId,
      text: msg.text,
      createdAt: msg.createdAt,
      syncStatus: msg.syncStatus,
      userName: msg.userName,
      choreId: msg.choreId,
      mentions: msg.mentions,
      chore: ChoreAttachment(
        id: chore.id,
        title: chore.title,
        status: chore.status,
        category: chore.category,
        assignedTo: chore.assignedTo,
      ),
    );
  }

  /// Enrich a list of messages
  Future<List<Message>> _enrichMessages(List<Message> messages) async {
    final result = <Message>[];
    for (final msg in messages) {
      result.add(await _enrichMessage(msg));
    }
    return result;
  }
}

final messageProvider = NotifierProvider<MessageNotifier, MessageState>(MessageNotifier.new);
