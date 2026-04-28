import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

class AppFeedback {
  static void _show(
    BuildContext c, {
    required String msg,
    required Color color,
    required IconData icon,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          action: action,
          content: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(msg, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      );
  }

  static void success(
    BuildContext c,
    String msg, {
    SnackBarAction? action,
    Duration? duration,
  }) {
    HapticFeedback.lightImpact();
    _show(
      c,
      msg: msg,
      color: AppTheme.accentGreen,
      icon: Icons.check_circle_rounded,
      action: action,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void error(
    BuildContext c,
    String msg, {
    SnackBarAction? action,
    VoidCallback? onRetry,
  }) {
    HapticFeedback.mediumImpact();
    _show(
      c,
      msg: msg,
      color: AppTheme.accentRed,
      icon: Icons.error_rounded,
      action: action ??
          (onRetry != null
              ? SnackBarAction(label: 'Retry', onPressed: onRetry)
              : null),
      duration: const Duration(seconds: 4),
    );
  }

  static void info(BuildContext c, String msg, {SnackBarAction? action}) {
    _show(
      c,
      msg: msg,
      color: AppTheme.accentBlue,
      icon: Icons.info_rounded,
      action: action,
    );
  }

  static void warning(BuildContext c, String msg, {SnackBarAction? action}) {
    HapticFeedback.mediumImpact();
    _show(
      c,
      msg: msg,
      color: AppTheme.accentOrange,
      icon: Icons.warning_rounded,
      action: action,
    );
  }

  static Future<bool> confirm(
    BuildContext c, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppTheme.accentRed)
                : null,
            onPressed: () {
              if (destructive) HapticFeedback.heavyImpact();
              Navigator.pop(ctx, true);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
