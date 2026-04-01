import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'animated_progress_ring.dart';

class DashboardStats extends StatelessWidget {
  final Map<String, int> stats;

  const DashboardStats({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats['total'] ?? 0;
    final done = stats['done'] ?? 0;
    final pending = stats['pending'] ?? 0;
    final overdue = stats['overdue'] ?? 0;
    final progress = total > 0 ? done / total : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2A2A40), const Color(0xFF1E1E2A)]
              : [const Color(0xFF6C63FF), const Color(0xFF9B59FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: isDark ? 0.1 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Progress',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total > 0 ? '${(progress * 100).round()}% Done' : 'No chores yet',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _MiniStat(label: 'Done', count: done, color: AppTheme.accentGreen),
                    const SizedBox(width: 16),
                    _MiniStat(label: 'Pending', count: pending, color: AppTheme.accentOrange),
                    if (overdue > 0) ...[
                      const SizedBox(width: 16),
                      _MiniStat(label: 'Overdue', count: overdue, color: AppTheme.accentRed),
                    ],
                  ],
                ),
              ],
            ),
          ),
          AnimatedProgressRing(
            progress: progress,
            size: 90,
            strokeWidth: 8,
            color: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            center: Text(
              '$done/$total',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniStat({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
