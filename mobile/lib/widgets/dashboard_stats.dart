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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.surface, AppTheme.surfaceLow],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderSubtle(context)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total > 0 ? '${(progress * 100).round()}% Done' : 'No chores',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colorScheme.onSurface, letterSpacing: -0.5),
                ),
                const SizedBox(height: 16),
                _StatRow(icon: Icons.check_circle_rounded, label: '$done done', color: AppTheme.accentGreen),
                const SizedBox(height: 8),
                _StatRow(icon: Icons.pending_rounded, label: '$pending left', color: AppTheme.accentOrange),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: overdue > 0 ? 1.0 : 0.0,
                    child: overdue > 0
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              _StatRow(icon: Icons.warning_rounded, label: '$overdue overdue', color: AppTheme.accentRed),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: AnimatedProgressRing(
              progress: progress,
              size: 78,
              strokeWidth: 7,
              color: AppTheme.accent,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.06),
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$done', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                  Text('of $total', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      ],
    );
  }
}
