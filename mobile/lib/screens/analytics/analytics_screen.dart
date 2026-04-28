import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/analytics_provider.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/charts/weekly_chart.dart';
import '../../widgets/charts/category_pie_chart.dart';
import '../../widgets/charts/member_chart.dart';
import '../../widgets/charts/completion_trend_chart.dart';
import '../../widgets/leaderboard.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_loader.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(analyticsProvider.notifier).loadAnalytics(),
          ),
        ],
      ),
      body: analytics.isLoading
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                children: [
                  SkeletonChartCard(height: 220),
                  SkeletonChartCard(height: 220),
                  SkeletonChartCard(height: 220),
                  SkeletonChartCard(height: 220),
                ],
              ),
            )
          : analytics.totalCompleted == 0 && analytics.weeklyCompletions.every((d) => d.completed == 0)
              ? const EmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'No data yet',
                  subtitle: 'Complete some chores to see analytics',
                )
              : RefreshIndicator(
              onRefresh: () => ref.read(analyticsProvider.notifier).loadAnalytics(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // Summary cards
                  AnimatedListItem(
                    index: 0,
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.check_circle_rounded,
                            label: 'Completed',
                            value: '${analytics.totalCompleted}',
                            color: AppTheme.accentGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Day Streak',
                            value: '${analytics.currentStreak}',
                            color: AppTheme.accentOrange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.warning_rounded,
                            label: 'Overdue',
                            value: '${analytics.overdueCount}',
                            color: AppTheme.accentRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  AnimatedListItem(index: 1, child: WeeklyChart(data: analytics.weeklyCompletions)),
                  const SizedBox(height: 12),

                  AnimatedListItem(index: 2, child: CategoryPieChart(data: analytics.categoryBreakdown)),
                  const SizedBox(height: 12),

                  AnimatedListItem(index: 3, child: CompletionTrendChart(data: analytics.completionTrend)),
                  const SizedBox(height: 12),

                  if (analytics.memberContributions.isNotEmpty) ...[
                    AnimatedListItem(index: 4, child: Leaderboard(data: analytics.memberContributions)),
                    const SizedBox(height: 12),
                  ],

                  AnimatedListItem(index: 5, child: MemberChart(data: analytics.memberContributions)),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
