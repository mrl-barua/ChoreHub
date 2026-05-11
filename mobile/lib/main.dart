import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/connectivity_service.dart';
import 'services/home_widget_service.dart';
import 'services/push_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages are handled by flutter_local_notifications on Android
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConnectivityService().initialize();

  // FCM init is best-effort: without google-services.json the native side
  // throws and we want the rest of the app (chores, chat, progression) to
  // still come up. Re-enable strict init once Firebase config is provided.
  bool firebaseReady = false;
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      firebaseReady = true;
    } catch (e) {
      debugPrint('[FCM] Firebase init failed (continuing without push): $e');
    }
  }

  final container = ProviderContainer();

  if (Platform.isAndroid && firebaseReady) {
    try {
      await PushNotificationService.instance.init(container);
    } catch (e) {
      debugPrint('[FCM] Push notification init failed: $e');
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ChoreHubApp(),
    ),
  );

  // Register widget tap callbacks after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (Platform.isAndroid) {
      HomeWidgetService.instance.registerCallbacks();
    }
  });
}
