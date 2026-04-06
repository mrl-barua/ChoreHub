import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chore.dart';
import '../services/api_client.dart';
import '../services/chore_service.dart';
import 'family_provider.dart';

enum ChoreSort { newest, dueDate, priority }

class ChoreState {
  final List<Chore> allChores;
  final List<Chore> chores;
  final String filter;
  final ChoreSort sort;
  final String searchQuery;
  final Map<String, int> stats;
  final bool isLoading;
  final String? error;

  ChoreState({
    this.allChores = const [],
    this.chores = const [],
    this.filter = 'all',
    this.sort = ChoreSort.newest,
    this.searchQuery = '',
    this.stats = const {'total': 0, 'done': 0, 'pending': 0, 'overdue': 0},
    this.isLoading = false,
    this.error,
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
  final ChoreService _choreService = ChoreService(ApiClient());

  @override
  ChoreState build() {
    _init();
    return ChoreState(isLoading: true);
  }

  void _init() {
    ref.listen(familyProvider, (prev, next) {
      final prevFamily = prev?.currentFamily?.id;
      final nextFamily = next.currentFamily?.id;
      if (nextFamily != null && nextFamily != prevFamily) {
        loadChores();
      }
    });
    loadChores();
  }

  Future<void> loadChores() async {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;

    try {
      final allChores = await _choreService.loadChores(family.id);

      Map<String, int> stats = {'total': 0, 'done': 0, 'pending': 0, 'overdue': 0};
      try {
        stats = await _choreService.loadStats(family.id);
      } catch (e) {
        debugPrint('[Chores] Stats failed: $e');
      }

      List<Chore> filtered;
      if (state.filter == 'all') {
        filtered = allChores;
      } else if (state.filter == 'overdue') {
        final now = DateTime.now();
        filtered = allChores.where((c) {
          if (c.dueDate == null || c.isDone) return false;
          try { return DateTime.parse(c.dueDate!).isBefore(now); } catch (_) { return false; }
        }).toList();
      } else {
        filtered = allChores.where((c) => c.status == state.filter).toList();
      }

      final sorted = _sortChores(filtered, state.sort);
      state = ChoreState(allChores: allChores, chores: sorted, filter: state.filter, sort: state.sort, searchQuery: state.searchQuery, stats: stats);
    } catch (e) {
      debugPrint('[Chores] Load failed: $e');
      state = ChoreState(error: 'Failed to load chores');
    }
  }

  Future<void> setFilter(String filter) async {
    state = ChoreState(allChores: state.allChores, chores: state.chores, filter: filter, sort: state.sort, searchQuery: state.searchQuery, stats: state.stats, isLoading: true);
    await loadChores();
  }

  void setSort(ChoreSort sort) {
    final sorted = _sortChores(state.chores, sort);
    state = ChoreState(allChores: state.allChores, chores: sorted, filter: state.filter, sort: sort, searchQuery: state.searchQuery, stats: state.stats);
  }

  void setSearchQuery(String query) {
    state = ChoreState(allChores: state.allChores, chores: state.chores, filter: state.filter, sort: state.sort, searchQuery: query, stats: state.stats);
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
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;

    try {
      await _choreService.createChore(
        familyId: family.id,
        title: title,
        category: category,
        timeSlot: timeSlot,
        assignedTo: assignedTo,
        dueDate: dueDate,
        priority: priority,
        description: description,
        recurrence: recurrence,
      );
      await loadChores();
    } catch (e) {
      debugPrint('[Chores] Create failed: $e');
      rethrow;
    }
  }

  Future<void> toggleStatus(String choreId) async {
    final chore = state.chores.where((c) => c.id == choreId).firstOrNull;
    if (chore == null) return;
    try {
      await _choreService.toggleStatus(choreId, chore.isDone);
      await loadChores();
    } catch (e) {
      debugPrint('[Chores] Toggle failed: $e');
      rethrow;
    }
  }

  Future<void> updateChore(Chore chore) async {
    try {
      await _choreService.updateChore(chore);
      await loadChores();
    } catch (e) {
      debugPrint('[Chores] Update failed: $e');
      rethrow;
    }
  }

  Future<void> deleteChore(String id) async {
    try {
      await _choreService.deleteChore(id);
      await loadChores();
    } catch (e) {
      debugPrint('[Chores] Delete failed: $e');
      rethrow;
    }
  }

  Future<bool> respondToAssignment(String choreId, String assignmentStatus) async {
    try {
      await _choreService.respondToAssignment(choreId, assignmentStatus);
      await loadChores();
      return true;
    } catch (e) {
      debugPrint('[Chores] Respond failed: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    await loadChores();
  }
}

final choreProvider = NotifierProvider<ChoreNotifier, ChoreState>(ChoreNotifier.new);
