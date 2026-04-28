import 'package:equatable/equatable.dart';

class TimingSuggestion extends Equatable {
  final String choreId;
  final String choreTitle;
  final int bestDayOfWeek; // 0=Sunday
  final int bestHour;
  final String label; // e.g. "Sunday evening"
  final int choreSampleSize;

  const TimingSuggestion({
    required this.choreId,
    required this.choreTitle,
    required this.bestDayOfWeek,
    required this.bestHour,
    required this.label,
    required this.choreSampleSize,
  });

  factory TimingSuggestion.fromJson(Map<String, dynamic> json) => TimingSuggestion(
        choreId: json['choreId'] as String,
        choreTitle: json['choreTitle'] as String,
        bestDayOfWeek: json['bestDayOfWeek'] as int,
        bestHour: json['bestHour'] as int,
        label: json['label'] as String,
        choreSampleSize: json['choreSampleSize'] as int,
      );

  @override
  List<Object?> get props => [choreId, choreTitle, bestDayOfWeek, bestHour, label, choreSampleSize];
}

class MemberEngagement extends Equatable {
  final String userId;
  final String name;
  final int thisWeekCount;
  final int prevWeekCount;
  final double trend;
  final bool driftAlert;

  const MemberEngagement({
    required this.userId,
    required this.name,
    required this.thisWeekCount,
    required this.prevWeekCount,
    required this.trend,
    required this.driftAlert,
  });

  factory MemberEngagement.fromJson(Map<String, dynamic> json) => MemberEngagement(
        userId: json['userId'] as String,
        name: json['name'] as String,
        thisWeekCount: json['thisWeekCount'] as int,
        prevWeekCount: json['prevWeekCount'] as int,
        trend: (json['trend'] as num).toDouble(),
        driftAlert: json['driftAlert'] as bool,
      );

  @override
  List<Object?> get props => [userId, name, thisWeekCount, prevWeekCount, trend, driftAlert];
}

class InsightsData extends Equatable {
  final int familySampleSize;
  final List<TimingSuggestion> timingSuggestions;
  final List<MemberEngagement> memberScores;
  final int? fairnessScore;
  final Map<String, int>? fairnessDistribution;

  const InsightsData({
    required this.familySampleSize,
    required this.timingSuggestions,
    required this.memberScores,
    this.fairnessScore,
    this.fairnessDistribution,
  });

  factory InsightsData.fromJson(Map<String, dynamic> json) => InsightsData(
        familySampleSize: json['familySampleSize'] as int,
        timingSuggestions: (json['timingSuggestions'] as List)
            .map((e) => TimingSuggestion.fromJson(e as Map<String, dynamic>))
            .toList(),
        memberScores: (json['memberScores'] as List)
            .map((e) => MemberEngagement.fromJson(e as Map<String, dynamic>))
            .toList(),
        fairnessScore: json['fairnessScore'] != null
            ? (json['fairnessScore'] as num).toInt()
            : null,
        fairnessDistribution: json['fairnessDistribution'] != null
            ? (json['fairnessDistribution'] as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, (v as num).toInt()))
            : null,
      );

  @override
  List<Object?> get props => [familySampleSize, timingSuggestions, memberScores, fairnessScore, fairnessDistribution];
}
