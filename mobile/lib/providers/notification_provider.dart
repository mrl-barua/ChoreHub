import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

class AppNotification {
  final String id;
  final String userId;
  final String familyId;
  final String type;
  final String title;
  final String body;
  final String? data;
  final bool read;
  final String createdAt;

  AppNotification({
    required this.id, required this.userId, required this.familyId,
    required this.type, required this.title, required this.body,
    this.data, required this.read, required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    userId: json['userId'] ?? json['user_id'] as String,
    familyId: json['familyId'] ?? json['family_id'] as String,
    type: json['type'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    data: json['data'] as String?,
    read: json['read'] as bool? ?? false,
    createdAt: json['createdAt']?.toString() ?? json['created_at'] as String,
  );
}

class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationState({this.notifications = const [], this.unreadCount = 0, this.isLoading = false});
}

class NotificationNotifier extends Notifier<NotificationState> {
  final ApiClient _api = ApiClient();

  @override
  NotificationState build() {
    loadNotifications();
    return NotificationState(isLoading: true);
  }

  Future<void> loadNotifications() async {
    try {
      final response = await _api.dio.get('/notifications');
      final list = (response.data as List).map((n) => AppNotification.fromJson(n)).toList();
      final unread = list.where((n) => !n.read).length;
      state = NotificationState(notifications: list, unreadCount: unread);
    } catch (e) {
      debugPrint('[Notifications] Load failed: $e');
      state = NotificationState();
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      final response = await _api.dio.get('/notifications/unread-count');
      state = NotificationState(notifications: state.notifications, unreadCount: response.data['count'] as int);
    } catch (_) {}
  }

  Future<void> markRead(String id) async {
    try {
      await _api.dio.patch('/notifications/$id/read');
      await loadNotifications();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.dio.post('/notifications/read-all');
      await loadNotifications();
    } catch (_) {}
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, NotificationState>(NotificationNotifier.new);
