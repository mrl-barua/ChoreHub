import 'package:flutter/material.dart';
import '../config/theme.dart';

class WeeklySummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const WeeklySummaryCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final thisWeek = data['totalCompletedThisWeek'] as int? ?? 0;
    final lastWeek = data['totalCompletedLastWeek'] as int? ?? 0;
    final change = data['changePercent'] as int? ?? 0;
    final topContributor = data['topContributor'] as Map<String, dynamic>?;
    final topCategory = data['topCategory'] as String?;

    final isUp = change >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              const Text('This Week', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (lastWeek > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isUp ? AppTheme.accentGreen : AppTheme.accentRed).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          size: 14, color: isUp ? AppTheme.accentGreen : AppTheme.accentRed),
                      const SizedBox(width: 4),
                      Text('${isUp ? '+' : ''}$change%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isUp ? AppTheme.accentGreen : AppTheme.accentRed)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('$thisWeek', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Text('chore${thisWeek != 1 ? 's' : ''} completed', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
          if (topContributor != null || topCategory != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: [
                if (topContributor != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded, size: 14, color: AppTheme.accentGold),
                      const SizedBox(width: 4),
                      Text(topContributor['displayName'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                if (topCategory != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_rounded, size: 14, color: AppTheme.categoryColors[topCategory] ?? Colors.grey),
                      const SizedBox(width: 4),
                      Text(topCategory, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
