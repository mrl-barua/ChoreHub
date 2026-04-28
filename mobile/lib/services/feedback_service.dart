import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

// Minimal TickerProvider for AnimationController outside a State.
class _SingleTickerProvider implements TickerProvider {
  const _SingleTickerProvider();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// Returned by [AppFeedback.loading] — call [success], [error], or [dismiss]
/// to remove the loading overlay and optionally show a result toast.
class LoadingToastController {
  LoadingToastController._(this._context, this._entry);

  final BuildContext _context;
  OverlayEntry _entry;
  bool _dismissed = false;

  void success(String msg) {
    _removeEntry();
    AppFeedback.success(_context, msg);
  }

  void error(String msg) {
    _removeEntry();
    AppFeedback.error(_context, msg);
  }

  void dismiss() => _removeEntry();

  void _removeEntry() {
    if (_dismissed) return;
    _dismissed = true;
    _entry.remove();
  }
}

class AppFeedback {
  // Duplicate-suppression state
  static String? _lastMsgHash;
  static DateTime? _lastShownAt;

  static void _show(
    BuildContext c, {
    required String msg,
    required Color color,
    required IconData icon,
    SnackBarAction? action,
    Widget? actionIcon,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Suppress duplicate toasts within 1 second
    final hash = '$color:$msg';
    if (_lastMsgHash == hash &&
        _lastShownAt != null &&
        DateTime.now().difference(_lastShownAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastMsgHash = hash;
    _lastShownAt = DateTime.now();

    // Build content row, appending actionIcon when provided
    final contentChildren = <Widget>[
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
      if (actionIcon != null) actionIcon,
    ];

    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          // When actionIcon is provided, inline icon takes precedence over action.
          action: actionIcon == null ? action : null,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          content: Row(children: contentChildren),
        ),
      );
  }

  static void success(
    BuildContext c,
    String msg, {
    SnackBarAction? action,
    Widget? actionIcon,
    Duration? duration,
  }) {
    HapticFeedback.lightImpact();
    _show(
      c,
      msg: msg,
      color: AppTheme.accentGreen,
      icon: Icons.check_circle_rounded,
      action: action,
      actionIcon: actionIcon,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void error(
    BuildContext c,
    String msg, {
    SnackBarAction? action,
    Widget? actionIcon,
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
      actionIcon: actionIcon,
      duration: const Duration(seconds: 4),
    );
  }

  static void info(
    BuildContext c,
    String msg, {
    SnackBarAction? action,
    Widget? actionIcon,
  }) {
    _show(
      c,
      msg: msg,
      color: AppTheme.accentBlue,
      icon: Icons.info_rounded,
      action: action,
      actionIcon: actionIcon,
    );
  }

  static void warning(
    BuildContext c,
    String msg, {
    SnackBarAction? action,
    Widget? actionIcon,
  }) {
    HapticFeedback.mediumImpact();
    _show(
      c,
      msg: msg,
      color: AppTheme.accentOrange,
      icon: Icons.warning_rounded,
      action: action,
      actionIcon: actionIcon,
    );
  }

  /// Shows a persistent loading overlay anchored to the bottom of the screen.
  /// Call [success], [error], or [dismiss] on the returned controller to
  /// remove it.
  static LoadingToastController loading(BuildContext context, String msg) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(msg, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    return LoadingToastController._(context, entry);
  }

  /// Shows a top-anchored notification toast with fade-in/out animation.
  /// Tapping the toast dismisses it early.
  static void topToast(
    BuildContext context,
    String msg, {
    Color? color,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    final effectiveColor = color ?? AppTheme.accentBlue;
    final effectiveIcon = icon ?? Icons.info_rounded;

    final controller = AnimationController(
      vsync: const _SingleTickerProvider(),
      duration: const Duration(milliseconds: 200),
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 12,
        left: 16,
        right: 16,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, child) => Opacity(opacity: controller.value, child: child),
          child: GestureDetector(
            onTap: () {
              controller.reverse().then((_) {
                try {
                  entry.remove();
                } catch (_) {}
                controller.dispose();
              });
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(color: effectiveColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 36,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: effectiveColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Icon(effectiveIcon, color: effectiveColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(msg, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);
    controller.forward();

    Future.delayed(duration, () {
      controller.reverse().then((_) {
        try {
          entry.remove();
        } catch (_) {}
        controller.dispose();
      });
    });
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
