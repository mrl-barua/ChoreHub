import 'package:flutter/material.dart';
import '../config/theme.dart';

class FormSection extends StatelessWidget {
  final String label;
  final Widget child;

  const FormSection({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.fontS,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spaceS),
        child,
      ],
    );
  }
}
