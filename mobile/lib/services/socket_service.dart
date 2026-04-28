import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import '../models/message.dart';
import 'logger.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  final _storage = const FlutterSecureStorage();

  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  final StreamController<String> _typingController = StreamController<String>.broadcast();
  final StreamController<String> _stopTypingController = StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _reactionController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _readReceiptController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _deleteController = StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _swapCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _swapUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Message> get onMessage => _messageController.stream;
  Stream<String> get onTyping => _typingController.stream;
  Stream<String> get onStopTyping => _stopTypingController.stream;
  Stream<Map<String, dynamic>> get onReaction => _reactionController.stream;
  Stream<Map<String, dynamic>> get onReadReceipt => _readReceiptController.stream;
  Stream<String> get onDelete => _deleteController.stream;
  Stream<Map<String, dynamic>> get onSwapCreated => _swapCreatedController.stream;
  Stream<Map<String, dynamic>> get onSwapUpdated => _swapUpdatedController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket?.connected == true) return;

    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');

    _socket = io.io(baseUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .enableReconnection()
        .setAuth({'token': token})
        .build());

    _socket!.onConnect((_) {
      AppLogger.info('Socket', 'Connected');
    });

    _socket!.on('new_message', (data) {
      try {
        final message = Message.fromJson(data as Map<String, dynamic>);
        _messageController.add(message);
      } catch (e) { AppLogger.error('Socket', 'Parse new_message: $e'); }
    });

    _socket!.on('user_typing', (data) {
      try { _typingController.add(data['userId'] as String); }
      catch (e) { AppLogger.error('Socket', 'Parse typing: $e'); }
    });

    _socket!.on('user_stop_typing', (data) {
      try { _stopTypingController.add(data['userId'] as String); }
      catch (e) { AppLogger.error('Socket', 'Parse stop_typing: $e'); }
    });

    _socket!.on('reaction_updated', (data) {
      try { _reactionController.add(data as Map<String, dynamic>); }
      catch (e) { AppLogger.error('Socket', 'Parse reaction: $e'); }
    });

    _socket!.on('messages_read', (data) {
      try { _readReceiptController.add(data as Map<String, dynamic>); }
      catch (e) { AppLogger.error('Socket', 'Parse read_receipt: $e'); }
    });

    _socket!.on('message_deleted', (data) {
      try { _deleteController.add(data['messageId'] as String); }
      catch (e) { AppLogger.error('Socket', 'Parse delete: $e'); }
    });

    _socket!.on('swap_request_created', (data) {
      try { _swapCreatedController.add(data as Map<String, dynamic>); }
      catch (e) { AppLogger.error('Socket', 'Parse swap_request_created: $e'); }
    });

    _socket!.on('swap_request_updated', (data) {
      try { _swapUpdatedController.add(data as Map<String, dynamic>); }
      catch (e) { AppLogger.error('Socket', 'Parse swap_request_updated: $e'); }
    });

    _socket!.onDisconnect((_) {
      AppLogger.info('Socket', 'Disconnected');
    });

    _socket!.onConnectError((err) {
      AppLogger.error('Socket', 'Connection error: $err');
    });
  }

  void sendMessage({
    required String id,
    required String familyId,
    required String text,
    String? choreId,
    String? mentions,
    String? replyToId,
    String? imageUrl,
  }) {
    _socket?.emit('send_message', {
      'id': id,
      'familyId': familyId,
      'text': text,
      if (choreId != null) 'choreId': choreId,
      if (mentions != null) 'mentions': mentions,
      if (replyToId != null) 'replyToId': replyToId,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
  }

  void toggleReaction({required String messageId, required String familyId, required String emoji}) {
    _socket?.emit('toggle_reaction', {
      'messageId': messageId,
      'familyId': familyId,
      'emoji': emoji,
    });
  }

  void markRead({required List<String> messageIds, required String familyId}) {
    if (messageIds.isEmpty) return;
    _socket?.emit('mark_read', {
      'messageIds': messageIds,
      'familyId': familyId,
    });
  }

  void deleteMessage({required String messageId, required String familyId}) {
    _socket?.emit('delete_message', {
      'messageId': messageId,
      'familyId': familyId,
    });
  }

  void sendTyping(String familyId) {
    _socket?.emit('typing', {'familyId': familyId});
  }

  void sendStopTyping(String familyId) {
    _socket?.emit('stop_typing', {'familyId': familyId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _stopTypingController.close();
    _reactionController.close();
    _readReceiptController.close();
    _deleteController.close();
    _swapCreatedController.close();
    _swapUpdatedController.close();
  }
}
