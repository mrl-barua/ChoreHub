import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/family.dart';
import '../models/family_member.dart';
import '../repositories/chore_repository.dart';
import '../repositories/family_repository.dart';
import '../repositories/history_repository.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';

class FamilyState {
  final List<Family> families;
  final Family? currentFamily;
  final List<FamilyMember> members;
  final bool isLoading;
  final Map<String, int> memberChoreCount;
  final Map<String, int> memberCompletedCount;
  final int totalChores;
  final int completedChores;

  FamilyState({
    this.families = const [],
    this.currentFamily,
    this.members = const [],
    this.isLoading = false,
    this.memberChoreCount = const {},
    this.memberCompletedCount = const {},
    this.totalChores = 0,
    this.completedChores = 0,
  });
}

class FamilyNotifier extends Notifier<FamilyState> {
  final FamilyRepository _repo = FamilyRepository();
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

    state = FamilyState(isLoading: true);
    final families = await _repo.getFamiliesForUser(user.id);
    final currentFamily = families.isNotEmpty ? families.first : null;

    List<FamilyMember> members = [];
    if (currentFamily != null) {
      members = await _repo.getMembers(currentFamily.id);
    }

    state = FamilyState(
      families: families,
      currentFamily: currentFamily,
      members: members,
    );
  }

  Future<void> selectFamily(Family family) async {
    final members = await _repo.getMembers(family.id);
    state = FamilyState(
      families: state.families,
      currentFamily: family,
      members: members,
    );
  }

  Future<void> createFamily(String name) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final id = const Uuid().v4();
    final family = Family(id: id, name: name, createdBy: user.id);
    await _repo.insertFamily(family);

    final member = FamilyMember(
      id: const Uuid().v4(),
      familyId: id,
      userId: user.id,
      role: 'admin',
    );
    await _repo.insertMember(member);

    if (ConnectivityService().isOnline) {
      try {
        await _apiClient.dio.post('/families', data: {'id': id, 'name': name});
      } catch (_) {}
    }

    await loadFamilies();
  }

  Future<void> refreshWithSync() async {
    if (ConnectivityService().isOnline) {
      try {
        await SyncService().sync();
      } catch (_) {}
    }
    await loadFamilies();
  }

  Future<void> loadMembers() async {
    if (state.currentFamily == null) return;
    final members = await _repo.getMembers(state.currentFamily!.id);
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
      final choreRepo = ChoreRepository();
      final historyRepo = HistoryRepository();
      final stats = await choreRepo.getStats(family.id);
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
      final completions = await historyRepo.getCompletionCountsByUser(family.id, startOfMonth, now.toIso8601String());

      final choreCount = <String, int>{};
      for (final member in state.members) {
        choreCount[member.userId] = await choreRepo.getAssignedCount(family.id, member.userId);
      }

      final completedCount = <String, int>{};
      for (final row in completions) {
        completedCount[row['user_id'] as String] = row['count'] as int;
      }

      state = FamilyState(
        families: state.families,
        currentFamily: state.currentFamily,
        members: state.members,
        memberChoreCount: choreCount,
        memberCompletedCount: completedCount,
        totalChores: stats['total'] ?? 0,
        completedChores: stats['done'] ?? 0,
      );
    } catch (e) {
      debugPrint('Load member stats error: $e');
    }
  }
}

final familyProvider = NotifierProvider<FamilyNotifier, FamilyState>(FamilyNotifier.new);
