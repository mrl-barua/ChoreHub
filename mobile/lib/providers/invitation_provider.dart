import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invitation.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

class InvitationState {
  final List<Invitation> incoming;
  final List<User> searchResults;
  final bool isLoading;
  final bool isSearching;
  final String? error;

  InvitationState({
    this.incoming = const [],
    this.searchResults = const [],
    this.isLoading = false,
    this.isSearching = false,
    this.error,
  });
}

class InvitationNotifier extends Notifier<InvitationState> {
  final ApiClient _apiClient = ApiClient();

  @override
  InvitationState build() {
    loadInvitations();
    return InvitationState();
  }

  Future<void> loadInvitations() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    state = InvitationState(isLoading: true);

    try {
      final response = await _apiClient.dio.get('/invitations/incoming');
      final invitations = (response.data as List).map((i) => Invitation.fromJson(i)).toList();
      state = InvitationState(incoming: invitations);
    } catch (e) {
      debugPrint('[Invitations] Load failed: $e');
      state = InvitationState(error: 'Failed to load invitations');
    }
  }

  Future<void> searchUsers(String query) async {
    state = InvitationState(incoming: state.incoming, isSearching: true);
    try {
      final response = await _apiClient.dio.get('/users/search', queryParameters: {'q': query});
      final users = (response.data as List).map((u) => User.fromJson(u)).toList();
      state = InvitationState(incoming: state.incoming, searchResults: users);
    } catch (e) {
      debugPrint('[Invitations] Search failed: $e');
      state = InvitationState(incoming: state.incoming, error: 'Search failed. Try again.');
    }
  }

  Future<void> sendInvitation(String familyId, String toUserId) async {
    try {
      await _apiClient.dio.post('/invitations', data: {
        'familyId': familyId,
        'toUserId': toUserId,
      });
    } catch (e) {
      debugPrint('[Invitations] Send failed: $e');
      state = InvitationState(
        incoming: state.incoming,
        searchResults: state.searchResults,
        error: 'Failed to send invitation.',
      );
    }
  }

  Future<bool> respondToInvitation(String id, String status) async {
    try {
      await _apiClient.dio.patch('/invitations/$id', data: {'status': status});
      await loadInvitations();
      return true;
    } catch (e) {
      debugPrint('[Invitations] Respond failed: $e');
      state = InvitationState(
        incoming: state.incoming,
        error: 'Failed to respond. Please try again.',
      );
      return false;
    }
  }

  void clearSearch() {
    state = InvitationState(incoming: state.incoming);
  }
}

final invitationProvider = NotifierProvider<InvitationNotifier, InvitationState>(InvitationNotifier.new);
