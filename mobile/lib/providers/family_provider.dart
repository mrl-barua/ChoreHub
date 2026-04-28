import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family.dart';
import '../models/family_member.dart';
import '../services/api_client.dart';
import '../services/chore_service.dart';
import '../services/family_service.dart';
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
  final Set<String> softRemovedIds;

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
    this.softRemovedIds = const {},
  });

  bool get hasLoadError => error != null;

  List<FamilyMember> get visibleMembers =>
      members.where((m) => !softRemovedIds.contains(m.userId)).toList();
}

class FamilyNotifier extends Notifier<FamilyState> {
  final FamilyService _familyService = FamilyService(ApiClient());
  final ChoreService _choreService = ChoreService(ApiClient());
  final Map<String, Timer> _pendingRemovals = {};

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
      final families = await _familyService.loadFamilies();
      final currentFamily = families.isNotEmpty ? families.first : null;

      List<FamilyMember> members = [];
      if (currentFamily != null) {
        members = await _familyService.loadMembers(currentFamily.id);
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

  Future<void> selectFamily(Family family) async {
    final members = await _familyService.loadMembers(family.id);
    state = FamilyState(
      families: state.families,
      currentFamily: family,
      members: members,
    );
  }

  Future<void> createFamily(String name) async {
    try {
      await _familyService.createFamily(name);
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
    final members = await _familyService.loadMembers(state.currentFamily!.id);
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
      final data = await _choreService.loadAnalytics(family.id);
      final stats = data['stats'] as Map<String, dynamic>;

      final contributions = (data['memberContributions'] as List?) ?? [];
      final completedCount = <String, int>{};
      for (final c in contributions) {
        completedCount[c['userId'] as String] = c['count'] as int;
      }

      final chores = await _choreService.loadChores(family.id);
      final choreCount = <String, int>{};
      for (final member in state.members) {
        choreCount[member.userId] = chores.where((c) => c.assignedTo == member.userId).length;
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
      // Preserve previous stats on error
      state = FamilyState(
        families: state.families,
        currentFamily: state.currentFamily,
        members: state.members,
        memberChoreCount: state.memberChoreCount,
        memberCompletedCount: state.memberCompletedCount,
        totalChores: state.totalChores,
        completedChores: state.completedChores,
      );
    }
  }

  void softRemoveMember(String memberId) {
    state = FamilyState(
      families: state.families,
      currentFamily: state.currentFamily,
      members: state.members,
      memberChoreCount: state.memberChoreCount,
      memberCompletedCount: state.memberCompletedCount,
      totalChores: state.totalChores,
      completedChores: state.completedChores,
      softRemovedIds: {...state.softRemovedIds, memberId},
    );

    final familyId = state.currentFamily?.id;
    if (familyId == null) return;

    _pendingRemovals[memberId] = Timer(const Duration(seconds: 4), () async {
      _pendingRemovals.remove(memberId);
      try {
        await _familyService.removeMember(familyId, memberId);
        await loadFamilies();
      } catch (e) {
        debugPrint('[Family] Soft remove failed: $e');
        // Restore on failure
        state = FamilyState(
          families: state.families,
          currentFamily: state.currentFamily,
          members: state.members,
          memberChoreCount: state.memberChoreCount,
          memberCompletedCount: state.memberCompletedCount,
          totalChores: state.totalChores,
          completedChores: state.completedChores,
          softRemovedIds: state.softRemovedIds.difference({memberId}),
        );
      }
    });
  }

  void cancelSoftRemoveMember(String memberId) {
    _pendingRemovals[memberId]?.cancel();
    _pendingRemovals.remove(memberId);
    state = FamilyState(
      families: state.families,
      currentFamily: state.currentFamily,
      members: state.members,
      memberChoreCount: state.memberChoreCount,
      memberCompletedCount: state.memberCompletedCount,
      totalChores: state.totalChores,
      completedChores: state.completedChores,
      softRemovedIds: state.softRemovedIds.difference({memberId}),
    );
  }
}

final familyProvider = NotifierProvider<FamilyNotifier, FamilyState>(FamilyNotifier.new);
