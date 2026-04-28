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

  if (Platform.isAndroid) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  }

  final container = ProviderContainer();

  if (Platform.isAndroid) {
    await PushNotificationService.instance.init(container);
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
