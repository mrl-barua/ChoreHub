import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String tag, String message) {
    debugPrint('[$tag] $message');
  }

  static void error(String tag, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('[$tag] ERROR: $error');
    if (stackTrace != null) {
      debugPrint('[$tag] $stackTrace');
    }
  }

  static void warn(String tag, String message) {
    debugPrint('[$tag] WARN: $message');
  }
}
