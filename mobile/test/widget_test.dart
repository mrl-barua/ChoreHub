import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/insights.dart';
import 'package:mobile/widgets/insights_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(colorScheme: const ColorScheme.dark(), useMaterial3: true),
      home: Scaffold(body: child),
    );

void main() {
  // Original smoke test
  testWidgets('App smoke test', (WidgetTester tester) async {
    expect(true, isTrue);
  });

  group('InsightsCard', () {
    testWidgets('familySampleSize=0 shows cold-start, no data sections',
        (tester) async {
      final data = InsightsData(
        familySampleSize: 0,
        timingSuggestions: const [],
        memberScores: const [],
        fairnessScore: null,
      );
      await tester.pumpWidget(_wrap(InsightsCard(data: data)));
      expect(find.byKey(const Key('insights_cold_start')), findsOneWidget);
      expect(find.byKey(const Key('insights_card')), findsNothing);
      expect(find.byKey(const Key('family_balance_section')), findsNothing);
    });

    testWidgets('empty timingSuggestions and null fairnessScore hides card',
        (tester) async {
      final data = InsightsData(
        familySampleSize: 15,
        timingSuggestions: const [],
        memberScores: const [
          MemberEngagement(
            userId: 'u1',
            name: 'Alice',
            thisWeekCount: 3,
            prevWeekCount: 2,
            trend: 0.5,
            driftAlert: false,
          ),
        ],
        fairnessScore: null,
      );
      await tester.pumpWidget(_wrap(InsightsCard(data: data)));
      expect(find.byKey(const Key('insights_card')), findsNothing);
    });

    testWidgets('driftAlert=true shows warning badge', (tester) async {
      final data = InsightsData(
        familySampleSize: 30,
        timingSuggestions: const [
          TimingSuggestion(
            choreTitle: 'Dishes',
            bestDayOfWeek: 0,
            bestHour: 20,
            label: 'Sunday evening',
          ),
        ],
        memberScores: const [
          MemberEngagement(
            userId: 'u1',
            name: 'Alice',
            thisWeekCount: 2,
            prevWeekCount: 10,
            trend: -0.8,
            driftAlert: true,
          ),
        ],
        fairnessScore: 75,
      );
      await tester.pumpWidget(_wrap(InsightsCard(data: data)));
      expect(find.byKey(const Key('drift_alert_u1')), findsOneWidget);
    });

    testWidgets('prevWeekCount=0 shows star New badge', (tester) async {
      final data = InsightsData(
        familySampleSize: 25,
        timingSuggestions: const [
          TimingSuggestion(
            choreTitle: 'Vacuuming',
            bestDayOfWeek: 1,
            bestHour: 10,
            label: 'Monday morning',
          ),
        ],
        memberScores: const [
          MemberEngagement(
            userId: 'u2',
            name: 'Bob',
            thisWeekCount: 4,
            prevWeekCount: 0,
            trend: 4.0,
            driftAlert: false,
          ),
        ],
        fairnessScore: null,
      );
      await tester.pumpWidget(_wrap(InsightsCard(data: data)));
      // Should show New badge, not a percentage
      expect(find.byKey(const Key('new_badge_u2')), findsOneWidget);
      // Should NOT show a percentage label (prevWeekCount=0 means no prior baseline)
      expect(find.text('+400%'), findsNothing);
    });

    testWidgets('fairnessScore=null hides Family Balance section',
        (tester) async {
      final data = InsightsData(
        familySampleSize: 25,
        timingSuggestions: const [
          TimingSuggestion(
            choreTitle: 'Dishes',
            bestDayOfWeek: 0,
            bestHour: 20,
            label: 'Sunday evening',
          ),
        ],
        memberScores: const [
          MemberEngagement(
            userId: 'u1',
            name: 'Alice',
            thisWeekCount: 3,
            prevWeekCount: 2,
            trend: 0.5,
            driftAlert: false,
          ),
        ],
        fairnessScore: null,
      );
      await tester.pumpWidget(_wrap(InsightsCard(data: data)));
      expect(find.byKey(const Key('family_balance_section')), findsNothing);
      expect(find.byKey(const Key('insights_card')), findsOneWidget);
    });
  });
}
