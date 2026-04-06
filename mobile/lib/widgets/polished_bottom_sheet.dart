import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Shows a polished bottom sheet with gradient top border and handle
Future<T?> showPolishedBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gradient top accent
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 80),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.0),
                  AppTheme.accent.withValues(alpha: 0.6),
                  AppTheme.accent.withValues(alpha: 0.0),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Content
          Flexible(child: builder(ctx)),
        ],
      ),
    ),
  );
}
