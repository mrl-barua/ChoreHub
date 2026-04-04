import 'package:flutter/foundation.dart';

class ApiConfig {
  // Override at build time: flutter run --dart-define=API_BASE_URL=https://your-server.com/api
  // IMPORTANT: Production builds MUST use HTTPS
  // Dev only: use http:// with local IP for testing
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.54:3000/api',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration uploadTimeout = Duration(seconds: 60);

  /// Whether the current URL is secure (HTTPS)
  static bool get isSecure => baseUrl.startsWith('https');

  /// Log a warning in debug mode if using HTTP
  static void checkSecurity() {
    if (kReleaseMode && !isSecure) {
      throw StateError('Production builds must use HTTPS. Set API_BASE_URL with --dart-define.');
    }
    if (!isSecure) {
      debugPrint('[SECURITY WARNING] Using unencrypted HTTP. Only use for local development.');
    }
  }

  /// Build a full image URL from a relative server path
  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = baseUrl.replaceAll('/api', '');
    return '$base$path';
  }
}
