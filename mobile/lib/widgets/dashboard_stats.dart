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

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C24),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total > 0 ? '${(progress * 100).round()}% Done' : 'No chores',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Tag(label: '$done done', color: AppTheme.accentGreen),
                    _Tag(label: '$pending left', color: AppTheme.accentOrange),
                    if (overdue > 0) _Tag(label: '$overdue late', color: AppTheme.accentRed),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AnimatedProgressRing(
            progress: progress,
            size: 72,
            strokeWidth: 6,
            color: AppTheme.accent,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            center: Text('$done', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
