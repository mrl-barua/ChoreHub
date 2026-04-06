import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';

class SuggestionsCard extends StatelessWidget {
  final List<dynamic> suggestions;
  const SuggestionsCard({super.key, required this.suggestions});

  IconData _typeIcon(String type) {
    switch (type) {
      case 'pattern': return Icons.auto_awesome_rounded;
      case 'stale': return Icons.access_time_rounded;
      case 'frequent': return Icons.repeat_rounded;
      default: return Icons.lightbulb_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'pattern': return AppTheme.accent;
      case 'stale': return AppTheme.accentOrange;
      case 'frequent': return AppTheme.accentBlue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFFFD700)),
              SizedBox(width: 8),
              Text('Suggestions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...suggestions.map((s) {
            final type = s['type'] as String? ?? '';
            final message = s['message'] as String? ?? '';
            final category = s['category'] as String? ?? '';
            final title = s['title'] as String?;
            final color = _typeColor(type);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Icon(_typeIcon(type), size: 16, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(message, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final params = <String, String>{'category': category};
                      if (title != null) params['title'] = title;
                      context.push(Uri(path: '/chores/create', queryParameters: params).toString());
                    },
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add_rounded, size: 16, color: AppTheme.accent),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
