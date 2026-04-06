import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family.dart';
import '../models/family_member.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

class FamilyState {
  final List<Family> families;
  final Family? currentFamily;
  final List<FamilyMember> members;
  final bool isLoading;
  final String? error;
  final Map<String, int> memberChoreCount;
  final Map<String, int> memberCompletedCount;
  final int totalChores;
  final int completedChores;

  FamilyState({
    this.families = const [],
    this.currentFamily,
    this.members = const [],
    this.isLoading = false,
    this.error,
    this.memberChoreCount = const {},
    this.memberCompletedCount = const {},
    this.totalChores = 0,
    this.completedChores = 0,
  });

  bool get hasLoadError => error != null;
}

class FamilyNotifier extends Notifier<FamilyState> {
  final ApiClient _apiClient = ApiClient();

  @override
  FamilyState build() {
    loadFamilies();
    return FamilyState(isLoading: true);
  }

  Future<void> loadFamilies() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      state = FamilyState();
      return;
    }

    try {
      // Fetch families from server
      final response = await _apiClient.dio.get('/families');
      final families = (response.data as List).map((f) => Family.fromJson(f)).toList();
      final currentFamily = families.isNotEmpty ? families.first : null;

      List<FamilyMember> members = [];
      if (currentFamily != null) {
        members = await _loadMembersFromServer(currentFamily.id);
      }

      state = FamilyState(
        families: families,
        currentFamily: currentFamily,
        members: members,
      );
    } catch (e) {
      debugPrint('[Family] Load failed: $e');
      state = FamilyState(error: 'Failed to load families. Check your connection.');
    }
  }

  Future<List<FamilyMember>> _loadMembersFromServer(String familyId) async {
    try {
      final response = await _apiClient.dio.get('/families/$familyId/members');
      return (response.data as List).map((m) {
        final member = FamilyMember.fromJson(m);
        // Server returns user object nested
        User? user;
        if (m['user'] != null) {
          user = User.fromJson(m['user']);
        }
        return FamilyMember(
          id: member.id,
          familyId: member.familyId,
          userId: member.userId,
          role: member.role,
          joinedAt: member.joinedAt,
          user: user,
        );
      }).toList();
    } catch (e) {
      debugPrint('[Family] Load members failed: $e');
      return [];
    }
  }

  Future<void> selectFamily(Family family) async {
    final members = await _loadMembersFromServer(family.id);
    state = FamilyState(
      families: state.families,
      currentFamily: family,
      members: members,
    );
  }

  Future<void> createFamily(String name) async {
    try {
      await _apiClient.dio.post('/families', data: {'name': name});
      await loadFamilies();
    } catch (e) {
      debugPrint('[Family] Create failed: $e');
      rethrow;
    }
  }

  Future<void> refreshWithSync() async {
    await loadFamilies();
  }

  Future<void> loadMembers() async {
    if (state.currentFamily == null) return;
    final members = await _loadMembersFromServer(state.currentFamily!.id);
    state = FamilyState(
      families: state.families,
      currentFamily: state.currentFamily,
      members: members,
      memberChoreCount: state.memberChoreCount,
      memberCompletedCount: state.memberCompletedCount,
      totalChores: state.totalChores,
      completedChores: state.completedChores,
    );
  }

  Future<void> loadMemberStats() async {
    final family = state.currentFamily;
    if (family == null) return;

    try {
      // Use analytics endpoint to get stats
      final response = await _apiClient.dio.get('/chores/analytics', queryParameters: {'familyId': family.id});
      final data = response.data;
      final stats = data['stats'] as Map<String, dynamic>;

      // Member contributions from analytics
      final contributions = (data['memberContributions'] as List?) ?? [];
      final completedCount = <String, int>{};
      for (final c in contributions) {
        completedCount[c['userId'] as String] = c['count'] as int;
      }

      // Get assigned count per member from chores
      final choresResp = await _apiClient.dio.get('/chores', queryParameters: {'familyId': family.id});
      final chores = choresResp.data as List;
      final choreCount = <String, int>{};
      for (final member in state.members) {
        choreCount[member.userId] = chores.where((c) => c['assignedTo'] == member.userId).length;
      }

      state = FamilyState(
        families: state.families,
        currentFamily: state.currentFamily,
        members: state.members,
        memberChoreCount: choreCount,
        memberCompletedCount: completedCount,
        totalChores: stats['total'] as int? ?? 0,
        completedChores: stats['done'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('[Family] Load member stats failed: $e');
    }
  }
}

final familyProvider = NotifierProvider<FamilyNotifier, FamilyState>(FamilyNotifier.new);
