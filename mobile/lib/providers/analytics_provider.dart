import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
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
  final String? error;

  AnalyticsState({
    this.weeklyCompletions = const [],
    this.categoryBreakdown = const {},
    this.memberContributions = const [],
    this.completionTrend = const [],
    this.overdueCount = 0,
    this.currentStreak = 0,
    this.totalCompleted = 0,
    this.isLoading = false,
    this.error,
  });
}

class AnalyticsNotifier extends Notifier<AnalyticsState> {
  final ApiClient _apiClient = ApiClient();

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

    try {
      final response = await _apiClient.dio.get('/chores/analytics', queryParameters: {
        'familyId': family.id,
      });
      final data = response.data;

      // Parse stats
      final stats = data['stats'] as Map<String, dynamic>;

      // Parse weekly completions
      final weeklyRaw = (data['weeklyCompletions'] as List?) ?? [];
      final weekly = weeklyRaw.map((w) => DayCompletion(
        w['dayName'] as String,
        w['completed'] as int,
      )).toList();

      // Parse category breakdown
      final catRaw = (data['categoryBreakdown'] as Map<String, dynamic>?) ?? {};
      final categories = catRaw.map((k, v) => MapEntry(k, v as int));

      // Parse member contributions
      final membersRaw = (data['memberContributions'] as List?) ?? [];
      final members = membersRaw.map((m) => MemberContribution(
        m['userId'] as String,
        m['displayName'] as String? ?? 'Unknown',
        m['count'] as int,
      )).toList();

      // Parse completion trend
      final trendRaw = (data['completionTrend'] as List?) ?? [];
      final trend = trendRaw.map((t) => WeeklyRate(
        t['label'] as String,
        (t['rate'] as num).toDouble(),
      )).toList();

      state = AnalyticsState(
        weeklyCompletions: weekly,
        categoryBreakdown: categories,
        memberContributions: members,
        completionTrend: trend,
        overdueCount: stats['overdue'] as int? ?? 0,
        currentStreak: data['currentStreak'] as int? ?? 0,
        totalCompleted: stats['done'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('[Analytics] Load failed: $e');
      state = AnalyticsState(error: 'Failed to load analytics');
    }
  }
}

final analyticsProvider = NotifierProvider<AnalyticsNotifier, AnalyticsState>(AnalyticsNotifier.new);
