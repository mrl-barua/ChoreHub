import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import '../app.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/family_provider.dart';
import '../repositories/chore_repository.dart';

class HomeWidgetService {
  HomeWidgetService._();
  static final instance = HomeWidgetService._();

  Future<void> update(Ref ref) async {
    try {
      final authState = ref.read(authProvider);
      final familyState = ref.read(familyProvider);
      if (!authState.isAuthenticated) return;

      final userId = authState.user?.id;
      final familyId = familyState.currentFamily?.id;
      if (userId == null || familyId == null) return;

      final repo = ChoreRepository();
      final chores = await repo.getTodayChores(familyId, userId);

      // Sort by priority then dueDate, take up to 4
      const priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      final sorted = [...chores]
        ..sort((a, b) {
          final p = (priorityOrder[a.priority] ?? 2)
              .compareTo(priorityOrder[b.priority] ?? 2);
          if (p != 0) return p;
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      final top4 = sorted.take(4).toList();

      // Read streak from analytics provider (cached, no network call)
      int streak = 0;
      try {
        final analytics = ref.read(analyticsProvider);
        streak = analytics.currentStreak;
      } catch (_) {}

      final choreData = top4.map((c) {
        String dueTime = '';
        if (c.dueDate != null) {
          try {
            final dt = DateTime.parse(c.dueDate!);
            dueTime =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } catch (_) {}
        }
        return {
          'id': c.id,
          'title': c.title,
          'priority': c.priority,
          'dueTime': dueTime,
        };
      }).toList();

      await HomeWidget.saveWidgetData<String>('chores_today', jsonEncode(choreData));
      await HomeWidget.saveWidgetData<String>('streak', streak.toString());
      await HomeWidget.saveWidgetData<String>(
          'lastUpdated', DateTime.now().toIso8601String());
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.chorehub.mobile.ChoresWidgetProvider',
      );
    } catch (_) {
      // Widget update failures must never crash the app
    }
  }

  // TODO: provider wiring — call this from ProgressionNotifier after a successful load() to keep the widget in sync.
  Future<void> updateProgressionStreak(int streak) async {
    try {
      await HomeWidget.saveWidgetData<String>(
          'progression_streak', streak.toString());
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.chorehub.mobile.ChoresWidgetProvider',
      );
    } catch (_) {
      // Widget update failures must never crash the app
    }
  }

  void registerCallbacks() {
    HomeWidget.registerInteractivityCallback(_widgetCallback);
  }

  static Future<void> _widgetCallback(Uri? uri) async {
    if (uri == null) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final choreId = uri.queryParameters['choreId'];
    final action = uri.queryParameters['action'];
    final route = uri.queryParameters['route'];
    if (choreId != null) {
      // ignore: use_build_context_synchronously
      context.go('/chores/$choreId');
    } else if (action == 'create') {
      // ignore: use_build_context_synchronously
      context.go('/chores?action=create');
    } else if (route != null) {
      // ignore: use_build_context_synchronously
      context.go(route);
    }
  }
}
