class ApiConfig {
  // Change this to your server's IP/URL
  // For Android emulator use 10.0.2.2, for iOS simulator use localhost
  static const String baseUrl = 'http://10.0.2.2:3000/api';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
