import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import '../models/message.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  final _storage = const FlutterSecureStorage();

  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  final StreamController<String> _typingController = StreamController<String>.broadcast();
  final StreamController<String> _stopTypingController = StreamController<String>.broadcast();

  Stream<Message> get onMessage => _messageController.stream;
  Stream<String> get onTyping => _typingController.stream;
  Stream<String> get onStopTyping => _stopTypingController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket?.connected == true) return;

    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    // Extract base URL without /api path
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');

    _socket = io.io(baseUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .enableReconnection()
        .setAuth({'token': token})
        .build());

    _socket!.onConnect((_) {
      print('Socket.IO connected');
    });

    _socket!.on('new_message', (data) {
      final message = Message.fromJson(data as Map<String, dynamic>);
      _messageController.add(message);
    });

    _socket!.on('user_typing', (data) {
      _typingController.add(data['userId'] as String);
    });

    _socket!.on('user_stop_typing', (data) {
      _stopTypingController.add(data['userId'] as String);
    });

    _socket!.onDisconnect((_) {
      print('Socket.IO disconnected');
    });

    _socket!.onConnectError((err) {
      print('Socket.IO connection error: $err');
    });
  }

  void sendMessage({required String id, required String familyId, required String text}) {
    _socket?.emit('send_message', {
      'id': id,
      'familyId': familyId,
      'text': text,
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
  }
}
