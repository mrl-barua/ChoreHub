import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'chore_provider.dart';
import 'family_provider.dart';
import 'invitation_provider.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;
}

class AuthNotifier extends Notifier<AuthState> {
  final AuthService _authService = AuthService();

  @override
  AuthState build() {
    _loadCurrentUser();
    return AuthState(isLoading: true);
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        state = AuthState(user: user);
        // Sync to restore data from server (DB was cleared on logout)
        try { await SyncService().sync(); } catch (_) {}
        ref.invalidate(familyProvider);
        ref.invalidate(choreProvider);
        ref.invalidate(invitationProvider);
      } else {
        state = AuthState();
      }
    } catch (_) {
      state = AuthState();
    }
  }

  Future<void> login({required String email, required String password}) async {
    // Clear any previous user first, then show loading
    state = AuthState(isLoading: true);
    try {
      final user = await _authService.login(email: email, password: password);
      state = AuthState(user: user);
      // Sync from server to restore user's data, then rebuild providers
      try { await SyncService().sync(); } catch (_) {}
      ref.invalidate(familyProvider);
      ref.invalidate(choreProvider);
      ref.invalidate(invitationProvider);
    } catch (e) {
      // No user on error — must not keep a stale user in state
      state = AuthState(error: _extractError(e));
    }
  }

  Future<void> register({
    required String username,
    required String displayName,
    required String email,
    required String password,
  }) async {
    state = AuthState(isLoading: true);
    try {
      final user = await _authService.register(
        username: username,
        displayName: displayName,
        email: email,
        password: password,
      );
      state = AuthState(user: user);
      ref.invalidate(familyProvider);
      ref.invalidate(choreProvider);
      ref.invalidate(invitationProvider);
    } catch (e) {
      state = AuthState(error: _extractError(e));
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    // Force other providers to clear stale data
    ref.invalidate(familyProvider);
    ref.invalidate(choreProvider);
    ref.invalidate(invitationProvider);
    // Force a clean unauthenticated state
    state = AuthState();
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Cannot connect to server. Check your internet connection.';
      }
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        return 'Invalid email or password.';
      }
      if (statusCode == 409) {
        return 'Email or username already taken.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
