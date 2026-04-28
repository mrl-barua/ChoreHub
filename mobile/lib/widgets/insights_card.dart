import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/insights.dart';

class InsightsCard extends StatelessWidget {
  final InsightsData data;
  final void Function(String choreId, int dayOfWeek, int hour)? onReschedule;
  const InsightsCard({super.key, required this.data, this.onReschedule});

  @override
  Widget build(BuildContext context) {
    // Cold-start: not enough data collected yet
    if (data.familySampleSize < 20) {
      return Container(
        key: const Key('insights_cold_start'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: AppTheme.borderSubtle(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.insights_rounded, size: 18, color: AppTheme.accent),
                SizedBox(width: 8),
                Text(
                  'Family Insights',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const LinearProgressIndicator(value: null),
            const SizedBox(height: 12),
            const Text(
              'Collecting data...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Insights appear after 20 chore completions',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    // Hidden: nothing to show
    if (data.timingSuggestions.isEmpty && data.fairnessScore == null) {
      return const SizedBox.shrink();
    }

    // Full card
    return Container(
      key: const Key('insights_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.borderSubtle(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: const [
              Icon(Icons.insights_rounded, size: 18, color: AppTheme.accent),
              SizedBox(width: 8),
              Text(
                'Family Insights',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),

          // Timing Suggestions section
          if (data.timingSuggestions.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Best Times',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...data.timingSuggestions.map((suggestion) {
                  final row = Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          onReschedule != null
                              ? Icons.schedule_rounded
                              : Icons.schedule_rounded,
                          size: 14,
                          color: AppTheme.accentBlue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            suggestion.choreTitle,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          suggestion.label,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        if (onReschedule != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.textMuted),
                        ],
                      ],
                    ),
                  );
                  if (onReschedule == null) return row;
                  return GestureDetector(
                    onTap: () => onReschedule!(suggestion.choreId, suggestion.bestDayOfWeek, suggestion.bestHour),
                    child: row,
                  );
                }),
          ],

          // Member Engagement section
          if (data.memberScores.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Member Engagement',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...data.memberScores.map((member) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${member.thisWeekCount} this week',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (member.driftAlert)
                        Icon(
                          Icons.warning_amber_rounded,
                          key: Key('drift_alert_${member.userId}'),
                          size: 16,
                          color: Colors.amber,
                        )
                      else if (member.prevWeekCount == 0)
                        Text(
                          '★ New',
                          key: Key('new_badge_${member.userId}'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                          ),
                        )
                      else
                        _TrendBadge(trend: member.trend),
                    ],
                  ),
                )),
          ],

          // Family Balance section
          if (data.fairnessScore != null) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('family_balance_section'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Family Balance',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Score: ${data.fairnessScore}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double trend;
  const _TrendBadge({required this.trend});

  @override
  Widget build(BuildContext context) {
    final isPositive = trend >= 0;
    final percent = (trend * 100).round();
    final label = '${isPositive ? '+' : ''}$percent%';
    final color = isPositive ? AppTheme.accentGreen : AppTheme.accentRed;

    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}
