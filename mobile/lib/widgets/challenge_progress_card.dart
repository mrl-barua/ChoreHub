import 'package:flutter/material.dart';
import '../config/theme.dart';

class ChallengeProgressCard extends StatelessWidget {
  final String title;
  final int currentCount;
  final int targetCount;
  final String endDate;

  const ChallengeProgressCard({
    super.key,
    required this.title,
    required this.currentCount,
    required this.targetCount,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final progress = targetCount > 0 ? (currentCount / targetCount).clamp(0.0, 1.0) : 0.0;
    final isComplete = currentCount >= targetCount;
    final daysLeft = _daysLeft();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isComplete
              ? [AppTheme.accentGreen.withValues(alpha: 0.15), AppTheme.accentGreen.withValues(alpha: 0.05)]
              : [AppTheme.accent.withValues(alpha: 0.15), AppTheme.accent.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (isComplete ? AppTheme.accentGreen : AppTheme.accent).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.emoji_events_rounded : Icons.flag_rounded,
                color: isComplete ? AppTheme.accentGreen : AppTheme.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              if (!isComplete && daysLeft != null)
                Text('${daysLeft}d left', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              if (isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Complete!', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(isComplete ? AppTheme.accentGreen : AppTheme.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text('$currentCount / $targetCount chores', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  int? _daysLeft() {
    try {
      final end = DateTime.parse(endDate);
      final diff = end.difference(DateTime.now()).inDays;
      return diff >= 0 ? diff : null;
    } catch (_) { return null; }
  }
}
