import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_preferences_service.dart';

class NotificationPrefsState {
  const NotificationPrefsState({
    this.isLoading = false,
    this.prefs = const {},
    this.error,
  });
  final bool isLoading;
  final Map<String, dynamic> prefs;
  final String? error;

  NotificationPrefsState copyWith({bool? isLoading, Map<String, dynamic>? prefs, String? error}) =>
      NotificationPrefsState(
        isLoading: isLoading ?? this.isLoading,
        prefs: prefs ?? this.prefs,
        error: error,
      );
}

class NotificationPrefsNotifier extends Notifier<NotificationPrefsState> {
  final _service = NotificationPreferencesService();

  @override
  NotificationPrefsState build() {
    loadPrefs();
    return const NotificationPrefsState(isLoading: true);
  }

  Future<void> loadPrefs() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await _service.getPreferences();
      state = state.copyWith(isLoading: false, prefs: prefs);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> update(Map<String, dynamic> updates) async {
    try {
      final prefs = await _service.updatePreferences(updates);
      state = state.copyWith(prefs: prefs);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsNotifier, NotificationPrefsState>(
        NotificationPrefsNotifier.new);
