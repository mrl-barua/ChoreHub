class ApiConfig {
  // Override at build time: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
  // Physical phone: use your PC's local IP (both devices must be on same WiFi)
  // Android emulator: use 10.0.2.2
  // iOS simulator: use localhost
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.201.71:3000/api',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration uploadTimeout = Duration(seconds: 60);

  /// Build a full image URL from a relative server path
  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = baseUrl.replaceAll('/api', '');
    return '$base$path';
  }
}
