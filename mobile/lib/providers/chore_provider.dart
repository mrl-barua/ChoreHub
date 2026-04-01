import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chore.dart';
import '../repositories/chore_repository.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';
import 'family_provider.dart';

enum ChoreSort { newest, dueDate, priority }

class ChoreState {
  final List<Chore> chores;
  final String filter;
  final ChoreSort sort;
  final String searchQuery;
  final Map<String, int> stats;
  final bool isLoading;

  ChoreState({
    this.chores = const [],
    this.filter = 'all',
    this.sort = ChoreSort.newest,
    this.searchQuery = '',
    this.stats = const {'total': 0, 'done': 0, 'pending': 0},
    this.isLoading = false,
  });

  List<Chore> get filteredChores {
    var list = chores;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((c) => c.title.toLowerCase().contains(q) || c.category.toLowerCase().contains(q)).toList();
    }
    return list;
  }
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

    final sorted = _sortChores(chores, state.sort);

    state = ChoreState(
      chores: sorted,
      filter: state.filter,
      sort: state.sort,
      searchQuery: state.searchQuery,
      stats: stats,
    );
  }

  Future<void> setFilter(String filter) async {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;

    final filterValue = filter == 'all' ? null : filter;
    final chores = await _repo.getChoresByFamily(family.id, statusFilter: filterValue);
    final stats = await _repo.getStats(family.id);
    final sorted = _sortChores(chores, state.sort);

    state = ChoreState(chores: sorted, filter: filter, sort: state.sort, searchQuery: state.searchQuery, stats: stats);
  }

  void setSort(ChoreSort sort) {
    final sorted = _sortChores(state.chores, sort);
    state = ChoreState(chores: sorted, filter: state.filter, sort: sort, searchQuery: state.searchQuery, stats: state.stats);
  }

  void setSearchQuery(String query) {
    state = ChoreState(chores: state.chores, filter: state.filter, sort: state.sort, searchQuery: query, stats: state.stats);
  }

  List<Chore> _sortChores(List<Chore> chores, ChoreSort sort) {
    final list = List<Chore>.from(chores);
    switch (sort) {
      case ChoreSort.newest:
        list.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      case ChoreSort.dueDate:
        list.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      case ChoreSort.priority:
        const order = {'high': 0, 'medium': 1, 'low': 2};
        list.sort((a, b) => (order[a.priority] ?? 1).compareTo(order[b.priority] ?? 1));
    }
    return list;
  }

  Future<void> createChore({
    required String title,
    required String category,
    String? timeSlot,
    String? assignedTo,
    String? dueDate,
    String priority = 'medium',
    String? description,
    String? recurrence,
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
      assignmentStatus: assignedTo != null ? 'pending_acceptance' : 'unassigned',
      dueDate: dueDate,
      createdBy: user.id,
      priority: priority,
      description: description,
      recurrence: recurrence,
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

  Future<bool> respondToAssignment(String choreId, String assignmentStatus) async {
    if (ConnectivityService().isOnline) {
      try {
        final apiClient = ApiClient();
        await apiClient.dio.patch('/chores/$choreId/assignment', data: {
          'assignmentStatus': assignmentStatus,
        });
        final chore = await _repo.getChoreById(choreId);
        if (chore != null) {
          final updated = chore.copyWith(
            assignmentStatus: assignmentStatus,
            updatedAt: DateTime.now().toIso8601String(),
            syncStatus: 'synced',
          );
          await _repo.updateChore(updated);
        }
        await loadChores();
        return true;
      } catch (_) {
        return false;
      }
    } else {
      final chore = await _repo.getChoreById(choreId);
      if (chore != null) {
        final updated = chore.copyWith(
          assignmentStatus: assignmentStatus,
          updatedAt: DateTime.now().toIso8601String(),
          syncStatus: 'pending',
        );
        await _repo.updateChore(updated);
      }
      await loadChores();
      return true;
    }
  }

  Future<void> refresh() async {
    await _syncService.sync();
    await loadChores();
  }
}

final choreProvider = NotifierProvider<ChoreNotifier, ChoreState>(ChoreNotifier.new);
