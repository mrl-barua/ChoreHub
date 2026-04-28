import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/clipboard_helpers.dart';

class CopyField extends StatelessWidget {
  final String value;
  final String copyLabel;

  const CopyField({
    super.key,
    required this.value,
    this.copyLabel = 'Copied',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: AppTheme.fontM,
                letterSpacing: 1.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.textSecondary),
            tooltip: 'Copy',
            onPressed: () => copyWithFeedback(context, value, label: copyLabel),
          ),
        ],
      ),
    );
  }
}
