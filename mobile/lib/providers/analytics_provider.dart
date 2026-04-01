import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/chore_repository.dart';
import '../repositories/history_repository.dart';
import 'auth_provider.dart';
import 'family_provider.dart';

class DayCompletion {
  final String dayName;
  final int completed;
  DayCompletion(this.dayName, this.completed);
}

class MemberContribution {
  final String userId;
  final String displayName;
  final int count;
  MemberContribution(this.userId, this.displayName, this.count);
}

class WeeklyRate {
  final String label;
  final double rate;
  WeeklyRate(this.label, this.rate);
}

class AnalyticsState {
  final List<DayCompletion> weeklyCompletions;
  final Map<String, int> categoryBreakdown;
  final List<MemberContribution> memberContributions;
  final List<WeeklyRate> completionTrend;
  final int overdueCount;
  final int currentStreak;
  final int totalCompleted;
  final bool isLoading;

  AnalyticsState({
    this.weeklyCompletions = const [],
    this.categoryBreakdown = const {},
    this.memberContributions = const [],
    this.completionTrend = const [],
    this.overdueCount = 0,
    this.currentStreak = 0,
    this.totalCompleted = 0,
    this.isLoading = false,
  });
}

class AnalyticsNotifier extends Notifier<AnalyticsState> {
  final ChoreRepository _choreRepo = ChoreRepository();
  final HistoryRepository _historyRepo = HistoryRepository();

  @override
  AnalyticsState build() {
    loadAnalytics();
    return AnalyticsState(isLoading: true);
  }

  Future<void> loadAnalytics() async {
    final user = ref.read(authProvider).user;
    final family = ref.read(familyProvider).currentFamily;
    if (user == null || family == null) {
      state = AnalyticsState();
      return;
    }

    state = AnalyticsState(isLoading: true);

    final results = await Future.wait([
      _loadWeeklyCompletions(family.id),
      _choreRepo.getCategoryBreakdown(family.id),
      _loadMemberContributions(family.id),
      _loadCompletionTrend(family.id),
      _choreRepo.getStats(family.id),
      _historyRepo.calculateStreak(user.id, family.id),
    ]);

    final weekly = results[0] as List<DayCompletion>;
    final categories = results[1] as Map<String, int>;
    final members = results[2] as List<MemberContribution>;
    final trend = results[3] as List<WeeklyRate>;
    final stats = results[4] as Map<String, int>;
    final streak = results[5] as int;

    state = AnalyticsState(
      weeklyCompletions: weekly,
      categoryBreakdown: categories,
      memberContributions: members,
      completionTrend: trend,
      overdueCount: stats['overdue'] ?? 0,
      currentStreak: streak,
      totalCompleted: stats['done'] ?? 0,
    );
  }

  Future<List<DayCompletion>> _loadWeeklyCompletions(String familyId) async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startDate = DateTime(monday.year, monday.month, monday.day).toIso8601String();
    final endDate = now.toIso8601String();

    final completions = await _historyRepo.getCompletionsByDateRange(familyId, startDate, endDate);
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final result = <DayCompletion>[];

    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final dayStr = day.toIso8601String().substring(0, 10);
      final match = completions.where((c) => c['day'] == dayStr);
      final count = match.isNotEmpty ? match.first['count'] as int : 0;
      result.add(DayCompletion(dayNames[i], count));
    }
    return result;
  }

  Future<List<MemberContribution>> _loadMemberContributions(String familyId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    final endDate = now.toIso8601String();

    final counts = await _historyRepo.getCompletionCountsByUser(familyId, startOfMonth, endDate);
    return counts.map((row) => MemberContribution(
          row['user_id'] as String,
          row['display_name'] as String? ?? 'Unknown',
          row['count'] as int,
        )).toList();
  }

  Future<List<WeeklyRate>> _loadCompletionTrend(String familyId) async {
    final result = <WeeklyRate>[];
    final now = DateTime.now();

    for (int w = 3; w >= 0; w--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + (w * 7)));
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
      final startStr = DateTime(weekStart.year, weekStart.month, weekStart.day).toIso8601String();
      final endStr = weekEnd.toIso8601String();

      final completions = await _historyRepo.getCompletionsByDateRange(familyId, startStr, endStr);
      int total = 0;
      for (final c in completions) {
        total += c['count'] as int;
      }

      final label = w == 0 ? 'This Week' : w == 1 ? 'Last Week' : 'Wk -$w';
      result.add(WeeklyRate(label, total.toDouble()));
    }
    return result;
  }
}

final analyticsProvider = NotifierProvider<AnalyticsNotifier, AnalyticsState>(AnalyticsNotifier.new);
