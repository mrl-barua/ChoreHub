class ApiConfig {
  // Physical phone: use your PC's local IP (both devices must be on same WiFi)
  // Android emulator: use 10.0.2.2
  // iOS simulator: use localhost
  static const String baseUrl = 'http://192.168.1.54:3000/api';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
