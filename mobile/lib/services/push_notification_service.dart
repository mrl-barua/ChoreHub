import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app.dart'; // exports rootNavigatorKey
import '../providers/notification_provider.dart';
import 'api_client.dart';

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final _flutterLocalNotifications = FlutterLocalNotificationsPlugin();
  static const _defaultChannelId = 'chorehub_default';
  static const _remindersChannelId = 'chorehub_reminders';

  ProviderContainer? _container;

  Future<void> init(ProviderContainer container) async {
    if (!Platform.isAndroid) return;
    _container = container;

    // Create notification channels
    await _flutterLocalNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    const defaultChannel = AndroidNotificationChannel(
      _defaultChannelId,
      'ChoreHub Notifications',
      importance: Importance.high,
    );
    const remindersChannel = AndroidNotificationChannel(
      _remindersChannelId,
      'Reminders',
      importance: Importance.defaultImportance,
    );
    final androidPlugin = _flutterLocalNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(defaultChannel);
    await androidPlugin?.createNotificationChannel(remindersChannel);

    // Request permissions
    await FirebaseMessaging.instance.requestPermission();

    // Register FCM token
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerToken(token);

    FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // Tap on notification while app is in background (not killed)
    FirebaseMessaging.onMessageOpenedApp.listen((msg) => _handleTap(msg.data));

    // Cold start: app opened via notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleTap(initial.data);
  }

  Future<void> _registerToken(String token) async {
    try {
      await ApiClient().dio.post('/notifications/device-token', data: {
        'token': token,
        'platform': 'android',
      });
    } catch (_) {}
  }

  void _handleForeground(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification != null && android != null) {
      _flutterLocalNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _defaultChannelId,
            'ChoreHub Notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data['type'],
      );
    }
    // Refresh in-app notification list
    try {
      _container?.read(notificationProvider.notifier).loadNotifications();
    } catch (_) {}
  }

  void _handleTap(Map<String, dynamic> data) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final type = data['type'] as String?;
    final choreId = data['choreId'] as String?;
    final messageId = data['messageId'] as String?;
    final familyId = data['familyId'] as String?;

    switch (type) {
      case 'chore_assigned':
      case 'chore_completed':
      case 'chore_due_soon':
        if (choreId != null) context.go('/chores/$choreId');
        break;
      case 'mention':
        final uri = Uri(path: '/chat', queryParameters: {
          if (messageId != null) 'messageId': messageId,
          if (familyId != null) 'familyId': familyId,
        });
        context.go(uri.toString());
        break;
      default:
        context.go('/notifications');
    }
  }

  Future<void> unregisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiClient().dio.delete('/notifications/device-token/$token');
      }
    } catch (_) {}
  }
}
