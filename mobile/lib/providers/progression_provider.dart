import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../services/api_client.dart';
import '../services/home_widget_service.dart';
import '../services/progression_service.dart';
import 'auth_provider.dart';

/// One-shot signal emitted by the progression provider after a successful
/// chore completion that produced a level-up. The UI consumes
/// `state.pendingLevelUp`, plays the full-screen takeover, then calls
/// `clearPendingLevelUp()` so the same event is not replayed on the next
/// rebuild.
class LevelUpEvent {
  final int newLevel;
  final List<String> unlocksGained;
  final int xpAwarded;
  const LevelUpEvent({
    required this.newLevel,
    required this.unlocksGained,
    required this.xpAwarded,
  });
}

/// Reasons the Mend endpoint can fail. Mapped from the server's
/// `{error, reason}` payload + status code so the UI can show the right
/// toast copy without having to inspect a DioException directly.
enum MendErrorReason { notEligible, insufficientXp, cooldownActive, unknown }

// Sentinel for nullable fields in copyWith — distinguishes "not provided"
// (keep current value) from "explicitly clearing to null". Using a private
// const sentinel object so it cannot collide with any real value.
const Object _unset = Object();

class ProgressionState {
  final bool isLoading;
  final String? error;
  final int xp;
  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int xpRemainingToNextLevel;
  final int currentStreak;
  final int longestStreak;
  final int freezesAvailable;
  final bool mendEligible;
  final int mendCooldownRemainingSec;
  final List<String> badges;
  final String? displayTitle;
  final List<String> unlocks;
  final LevelUpEvent? pendingLevelUp;
  final MendErrorReason? lastMendError;

  /// 7-day strip of "did the user clear their due-quota that day?", indexed
  /// Monday (0) → Sunday (6) for the user's CURRENT local-week. Always
  /// length 7 (defaults to all-false until the first compute completes).
  /// A day with `dueCount == 0` is treated as `true` (no work due == day
  /// satisfied), matching the server-side `streakService.evaluateStreak`
  /// rule. Computed client-side from the local sqflite mirror — no server
  /// payload change is required.
  final List<bool> weekCompletion;

  const ProgressionState({
    this.isLoading = false,
    this.error,
    this.xp = 0,
    this.level = 1,
    this.xpIntoLevel = 0,
    this.xpForNextLevel = 50,
    this.xpRemainingToNextLevel = 50,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.freezesAvailable = 0,
    this.mendEligible = false,
    this.mendCooldownRemainingSec = 0,
    this.badges = const [],
    this.displayTitle,
    this.unlocks = const [],
    this.pendingLevelUp,
    this.lastMendError,
    this.weekCompletion = const [
      false, false, false, false, false, false, false,
    ],
  });

  ProgressionState copyWith({
    bool? isLoading,
    Object? error = _unset,
    int? xp,
    int? level,
    int? xpIntoLevel,
    int? xpForNextLevel,
    int? xpRemainingToNextLevel,
    int? currentStreak,
    int? longestStreak,
    int? freezesAvailable,
    bool? mendEligible,
    int? mendCooldownRemainingSec,
    List<String>? badges,
    Object? displayTitle = _unset,
    List<String>? unlocks,
    Object? pendingLevelUp = _unset,
    Object? lastMendError = _unset,
    List<bool>? weekCompletion,
  }) {
    return ProgressionState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      xpIntoLevel: xpIntoLevel ?? this.xpIntoLevel,
      xpForNextLevel: xpForNextLevel ?? this.xpForNextLevel,
      xpRemainingToNextLevel:
          xpRemainingToNextLevel ?? this.xpRemainingToNextLevel,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      freezesAvailable: freezesAvailable ?? this.freezesAvailable,
      mendEligible: mendEligible ?? this.mendEligible,
      mendCooldownRemainingSec:
          mendCooldownRemainingSec ?? this.mendCooldownRemainingSec,
      badges: badges ?? this.badges,
      displayTitle: identical(displayTitle, _unset)
          ? this.displayTitle
          : displayTitle as String?,
      unlocks: unlocks ?? this.unlocks,
      pendingLevelUp: identical(pendingLevelUp, _unset)
          ? this.pendingLevelUp
          : pendingLevelUp as LevelUpEvent?,
      lastMendError: identical(lastMendError, _unset)
          ? this.lastMendError
          : lastMendError as MendErrorReason?,
      weekCompletion: weekCompletion ?? this.weekCompletion,
    );
  }
}

class ProgressionNotifier extends Notifier<ProgressionState> {
  // Service held as a class field (CLAUDE.md: never instantiate inside a
  // callback). The shared ApiClient singleton is constructor-injected.
  final ProgressionService _service = ProgressionService(ApiClient());

  @override
  ProgressionState build() {
    final auth = ref.watch(authProvider);
    if (auth.user != null) {
      Future.microtask(() => load());
    }
    return const ProgressionState();
  }

  /// Returns the device's current UTC offset in minutes. On platforms where
  /// `DateTime.now().timeZoneOffset` is unavailable or throws (some web /
  /// desktop edge cases), we fall back to 0 (UTC) — the server will still
  /// produce a valid response, just centered on UTC midnight rather than the
  /// kid's local midnight, which is acceptable degradation.
  int _tzOffsetMinutes() {
    try {
      return DateTime.now().timeZoneOffset.inMinutes;
    } catch (e) {
      debugPrint('[Progression] tzOffset unavailable, defaulting to 0: $e');
      return 0;
    }
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final json = await _service.loadProgression(
        tzOffsetMinutes: _tzOffsetMinutes(),
      );
      state = _applyServerJson(json);
      _pushStreakToWidget();
      // Recompute the local 7-day strip whenever the server payload
      // refreshes — chore-history rows may have changed in the same window.
      // Fire-and-forget; the helper updates state itself when done.
      // ignore: unawaited_futures
      _refreshWeekCompletion();
    } catch (e) {
      debugPrint('[Progression] Load failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load progression',
      );
      return;
    }
  }

  Future<void> mend() async {
    try {
      final json = await _service.mend(tzOffsetMinutes: _tzOffsetMinutes());
      state = _applyServerJson(json);
      _pushStreakToWidget();
      // Recompute the local 7-day strip whenever the server payload
      // refreshes — chore-history rows may have changed in the same window.
      // Fire-and-forget; the helper updates state itself when done.
      // ignore: unawaited_futures
      _refreshWeekCompletion();
    } on DioException catch (e) {
      final reason = _mapMendError(e);
      state = state.copyWith(lastMendError: reason);
      return;
    } catch (e) {
      debugPrint('[Progression] Mend failed: $e');
      state = state.copyWith(lastMendError: MendErrorReason.unknown);
      return;
    }
  }

  Future<void> setTitle(String? badgeKey) async {
    try {
      final json = await _service.setTitle(badgeKey);
      state = _applyServerJson(json);
      _pushStreakToWidget();
    } catch (e) {
      debugPrint('[Progression] Set title failed: $e');
      state = state.copyWith(error: 'Failed to update display title');
      return;
    }
  }

  void triggerLevelUp(LevelUpEvent event) {
    state = state.copyWith(pendingLevelUp: event);
  }

  void clearPendingLevelUp() {
    state = state.copyWith(pendingLevelUp: null);
  }

  void clearMendError() {
    state = state.copyWith(lastMendError: null);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Map the server's progression JSON into ProgressionState.
  ///
  /// The server response shape (from `me-progression.ts`
  /// `projectProgressionResponse`) is:
  ///   { xp, level, xpToNextLevel: int, currentStreak, longestStreak,
  ///     freezesAvailable, mendEligible, mendCooldownRemainingSec,
  ///     badges: string[], displayTitle: string|null, unlocks: string[] }
  ///
  /// `xpToNextLevel` is a *flat* int (the `xpRemaining` value) — not the
  /// nested object the PRD originally described. We derive `xpIntoLevel`
  /// and `xpForNextLevel` from the level curve formula
  /// (`xp_required_to_advance = level * 50`, cumulative XP for level N is
  /// `25 * N * (N - 1)`). This keeps the typed state shape rich enough for
  /// the UI XP-bar widget without a server change.
  ///
  /// `pendingLevelUp` is preserved across loads — a level-up event from a
  /// chore completion must survive a refresh until the UI dismisses it.
  ProgressionState _applyServerJson(Map<String, dynamic> json) {
    final xp = (json['xp'] as num?)?.toInt() ?? 0;
    final level = (json['level'] as num?)?.toInt() ?? 1;
    final xpRemaining = (json['xpToNextLevel'] as num?)?.toInt() ?? 0;

    // Level curve: cumulative XP for level N = 25 * N * (N - 1).
    // xpForCurrentLevel = cumulative XP at the start of `level`.
    // xpForNextLevel    = XP required to advance from `level` to `level+1`.
    final xpForCurrentLevel = 25 * level * (level - 1);
    final xpForNextLevel = level * 50;
    final xpIntoLevel = xp - xpForCurrentLevel;

    final badgesRaw = json['badges'] as List?;
    final badges = badgesRaw == null
        ? <String>[]
        : badgesRaw.map((b) => b.toString()).toList();

    final unlocksRaw = json['unlocks'] as List?;
    final unlocks = unlocksRaw == null
        ? <String>[]
        : unlocksRaw.map((u) => u.toString()).toList();

    return ProgressionState(
      isLoading: false,
      error: null,
      xp: xp,
      level: level,
      xpIntoLevel: xpIntoLevel < 0 ? 0 : xpIntoLevel,
      xpForNextLevel: xpForNextLevel,
      xpRemainingToNextLevel: xpRemaining,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      freezesAvailable: (json['freezesAvailable'] as num?)?.toInt() ?? 0,
      mendEligible: json['mendEligible'] as bool? ?? false,
      mendCooldownRemainingSec:
          (json['mendCooldownRemainingSec'] as num?)?.toInt() ?? 0,
      badges: badges,
      displayTitle: json['displayTitle'] as String?,
      unlocks: unlocks,
      // Preserve the ephemeral pending level-up across refreshes.
      pendingLevelUp: state.pendingLevelUp,
      // Clear any stale mend error after a successful server round-trip.
      lastMendError: null,
      // Preserve the locally-computed week strip — it has its own refresh
      // path via _refreshWeekCompletion() and must not be reset to all-false
      // by every server response.
      weekCompletion: state.weekCompletion,
    );
  }

  /// Recompute the Mon→Sun week-completion strip for the current local week
  /// from the local sqflite mirror. Safe to call any time; failures are
  /// swallowed so a missing/empty DB never breaks the provider — the strip
  /// just stays at its last value (or the all-false default).
  ///
  /// Definition of a "satisfied" day (matches the server-side
  /// `streakService.evaluateStreak` rule):
  ///   - dueCount  = chores assigned to the user with due_date == that day
  ///   - doneCount = chore_history rows where action='completed',
  ///                 user_id=current user, date(created_at) == that day
  ///   - satisfied = doneCount >= dueCount  (a day with dueCount==0 is
  ///                 trivially satisfied → true)
  Future<void> _refreshWeekCompletion() async {
    final auth = ref.read(authProvider);
    final userId = auth.user?.id;
    if (userId == null) return;

    try {
      // Local "today" → Monday of this week (ISO: Mon=1 ... Sun=7).
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: today.weekday - 1));

      final days = List<DateTime>.generate(
        7,
        (i) => monday.add(Duration(days: i)),
      );
      final dayKeys = days.map(_isoDate).toList(growable: false);
      final weekStart = dayKeys.first;
      final weekEnd = dayKeys.last;

      final db = await DatabaseHelper().database;

      // Per-day due counts: chores assigned to this user with due_date in week.
      // Per-day completion counts: chore_history completed by this user.
      // `created_at` is an ISO timestamp; date() extracts YYYY-MM-DD in UTC.
      // The server stores timestamps in UTC, so for kids near a tz boundary
      // this can cross-shift by a day. This is the same approximation
      // history_repository.calculateStreak() already uses; staying
      // consistent with it is more important than a perfect local-tz parse.
      final results = await Future.wait([
        db.rawQuery(
          '''
        SELECT due_date AS day, COUNT(*) AS c
        FROM chores
        WHERE assigned_to = ?
          AND due_date IS NOT NULL
          AND due_date >= ?
          AND due_date <= ?
        GROUP BY due_date
        ''',
          [userId, weekStart, weekEnd],
        ),
        db.rawQuery(
          '''
        SELECT date(created_at) AS day, COUNT(*) AS c
        FROM chore_history
        WHERE user_id = ?
          AND action = 'completed'
          AND date(created_at) >= ?
          AND date(created_at) <= ?
        GROUP BY day
        ''',
          [userId, weekStart, weekEnd],
        ),
      ]);
      final dueRows = results[0];
      final doneRows = results[1];
      final dueByDay = <String, int>{};
      for (final row in dueRows) {
        dueByDay[row['day'] as String] = (row['c'] as num).toInt();
      }

      final doneByDay = <String, int>{};
      for (final row in doneRows) {
        doneByDay[row['day'] as String] = (row['c'] as num).toInt();
      }

      final result = List<bool>.generate(7, (i) {
        final key = dayKeys[i];
        final due = dueByDay[key] ?? 0;
        final done = doneByDay[key] ?? 0;
        if (due == 0) return true; // No work due → day satisfied.
        return done >= due;
      });

      state = state.copyWith(weekCompletion: result);
    } catch (e) {
      debugPrint('[Progression] weekCompletion compute failed: $e');
      // Leave the previous strip in place; do not surface as a user error.
      return;
    }
  }

  String _isoDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  // Fire-and-forget widget refresh. Called after every successful server
  // round-trip so the Android home widget stays in sync with the kid's
  // current streak. The home widget service swallows its own errors, so
  // failures here cannot crash the provider.
  void _pushStreakToWidget() {
    HomeWidgetService.instance.updateProgressionStreak(state.currentStreak);
  }

  MendErrorReason _mapMendError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? reason;
    if (data is Map && data['reason'] is String) {
      reason = data['reason'] as String;
    }

    if (reason == 'NOT_ELIGIBLE' || status == 400) {
      return MendErrorReason.notEligible;
    }
    if (reason == 'INSUFFICIENT_XP' || status == 402) {
      return MendErrorReason.insufficientXp;
    }
    if (reason == 'COOLDOWN_ACTIVE' || status == 429) {
      return MendErrorReason.cooldownActive;
    }
    return MendErrorReason.unknown;
  }
}

final progressionProvider =
    NotifierProvider<ProgressionNotifier, ProgressionState>(
  ProgressionNotifier.new,
);
