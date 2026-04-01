import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConnectivityService().initialize();

  runApp(
    const ProviderScope(
      child: ChoreHubApp(),
    ),
  );
}
