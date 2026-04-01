import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invitation.dart';
import '../models/user.dart';
import '../repositories/invitation_repository.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
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
  final InvitationRepository _repo = InvitationRepository();
  final ApiClient _apiClient = ApiClient();
  final SyncService _syncService = SyncService();

  @override
  InvitationState build() {
    loadInvitations();
    return InvitationState();
  }

  Future<void> loadInvitations() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    state = InvitationState(isLoading: true);

    if (ConnectivityService().isOnline) {
      try {
        final response = await _apiClient.dio.get('/invitations/incoming');
        final invitations = (response.data as List)
            .map((i) => Invitation.fromJson(i))
            .toList();
        for (final inv in invitations) {
          await _repo.insertInvitation(inv);
        }
        state = InvitationState(incoming: invitations);
        return;
      } catch (_) {}
    }

    final invitations = await _repo.getIncomingInvitations(user.id);
    state = InvitationState(incoming: invitations);
  }

  Future<void> searchUsers(String query) async {
    if (!ConnectivityService().isOnline) {
      state = InvitationState(
        incoming: state.incoming,
        error: 'You need an internet connection to search for users.',
      );
      return;
    }

    state = InvitationState(incoming: state.incoming, isSearching: true);
    try {
      final response = await _apiClient.dio.get('/users/search', queryParameters: {'q': query});
      final users = (response.data as List).map((u) => User.fromJson(u)).toList();
      state = InvitationState(incoming: state.incoming, searchResults: users);
    } catch (_) {
      state = InvitationState(incoming: state.incoming, error: 'Search failed. Try again.');
    }
  }

  Future<void> sendInvitation(String familyId, String toUserId) async {
    try {
      await _apiClient.dio.post('/invitations', data: {
        'familyId': familyId,
        'toUserId': toUserId,
      });
    } catch (_) {
      state = InvitationState(
        incoming: state.incoming,
        searchResults: state.searchResults,
        error: 'Failed to send invitation.',
      );
    }
  }

  Future<void> respondToInvitation(String id, String status) async {
    await _repo.updateStatus(id, status);
    await _syncService.sync();
    await loadInvitations();
  }

  void clearSearch() {
    state = InvitationState(incoming: state.incoming);
  }
}

final invitationProvider = NotifierProvider<InvitationNotifier, InvitationState>(InvitationNotifier.new);
