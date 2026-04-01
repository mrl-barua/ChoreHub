import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chore.dart';
import '../repositories/chore_repository.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';
import 'family_provider.dart';

class ChoreState {
  final List<Chore> chores;
  final String filter;
  final Map<String, int> stats;
  final bool isLoading;

  ChoreState({
    this.chores = const [],
    this.filter = 'all',
    this.stats = const {'total': 0, 'done': 0, 'pending': 0},
    this.isLoading = false,
  });
}

class ChoreNotifier extends Notifier<ChoreState> {
  final ChoreRepository _repo = ChoreRepository();
  final SyncService _syncService = SyncService();

  @override
  ChoreState build() {
    loadChores();
    return ChoreState(isLoading: true);
  }

  Future<void> loadChores() async {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) {
      state = ChoreState();
      return;
    }

    final filterValue = state.filter == 'all' ? null : state.filter;
    final chores = await _repo.getChoresByFamily(family.id, statusFilter: filterValue);
    final stats = await _repo.getStats(family.id);

    state = ChoreState(chores: chores, filter: state.filter, stats: stats);
  }

  Future<void> setFilter(String filter) async {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;

    final filterValue = filter == 'all' ? null : filter;
    final chores = await _repo.getChoresByFamily(family.id, statusFilter: filterValue);
    final stats = await _repo.getStats(family.id);

    state = ChoreState(chores: chores, filter: filter, stats: stats);
  }

  Future<void> createChore({
    required String title,
    required String category,
    String? timeSlot,
    String? assignedTo,
    String? dueDate,
  }) async {
    final user = ref.read(authProvider).user;
    final family = ref.read(familyProvider).currentFamily;
    if (user == null || family == null) return;

    final chore = Chore(
      id: const Uuid().v4(),
      familyId: family.id,
      title: title,
      category: category,
      timeSlot: timeSlot,
      assignedTo: assignedTo,
      dueDate: dueDate,
      createdBy: user.id,
    );

    await _repo.insertChore(chore);
    await loadChores();
    _syncService.sync();
  }

  Future<void> toggleStatus(String choreId) async {
    final chore = await _repo.getChoreById(choreId);
    if (chore == null) return;

    final updated = chore.copyWith(
      status: chore.isDone ? 'pending' : 'done',
      updatedAt: DateTime.now().toIso8601String(),
      syncStatus: 'pending',
    );
    await _repo.updateChore(updated);
    await loadChores();
    _syncService.sync();
  }

  Future<void> updateChore(Chore chore) async {
    await _repo.updateChore(chore);
    await loadChores();
    _syncService.sync();
  }

  Future<void> deleteChore(String id) async {
    await _repo.deleteChore(id);
    await loadChores();
    _syncService.sync();
  }

  Future<void> refresh() async {
    await _syncService.sync();
    await loadChores();
  }
}

final choreProvider = NotifierProvider<ChoreNotifier, ChoreState>(ChoreNotifier.new);
