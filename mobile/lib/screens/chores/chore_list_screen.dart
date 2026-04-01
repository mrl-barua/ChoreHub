import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/chore_card.dart';
import '../../widgets/chore_filter_bar.dart';
import '../../widgets/empty_state.dart';

class ChoreListScreen extends ConsumerStatefulWidget {
  const ChoreListScreen({super.key});

  @override
  ConsumerState<ChoreListScreen> createState() => _ChoreListScreenState();
}

class _ChoreListScreenState extends ConsumerState<ChoreListScreen> {
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final chores = ref.watch(choreProvider);

    if (family.currentFamily == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chores')),
        body: const EmptyState(
          icon: Icons.people_outline_rounded,
          title: 'Join a family first',
          subtitle: 'Create or join a family to start managing chores.',
        ),
      );
    }

    final displayedChores = chores.filteredChores;

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search chores...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (q) => ref.read(choreProvider.notifier).setSearchQuery(q),
              )
            : const Text('Chores'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  ref.read(choreProvider.notifier).setSearchQuery('');
                }
              });
            },
          ),
          PopupMenuButton<ChoreSort>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (sort) => ref.read(choreProvider.notifier).setSort(sort),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: ChoreSort.newest,
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 18, color: chores.sort == ChoreSort.newest ? Theme.of(context).colorScheme.primary : null),
                    const SizedBox(width: 8),
                    const Text('Newest First'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ChoreSort.dueDate,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 18, color: chores.sort == ChoreSort.dueDate ? Theme.of(context).colorScheme.primary : null),
                    const SizedBox(width: 8),
                    const Text('Due Date'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ChoreSort.priority,
                child: Row(
                  children: [
                    Icon(Icons.flag_rounded, size: 18, color: chores.sort == ChoreSort.priority ? Theme.of(context).colorScheme.primary : null),
                    const SizedBox(width: 8),
                    const Text('Priority'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ChoreFilterBar(
            currentFilter: chores.filter,
            onFilterChanged: (filter) => ref.read(choreProvider.notifier).setFilter(filter),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: displayedChores.isEmpty
                ? EmptyState(
                    icon: Icons.checklist_rounded,
                    title: chores.filter == 'all' ? 'No chores yet' : 'No ${chores.filter} chores',
                    subtitle: 'Tap the button below to create one.',
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(choreProvider.notifier).refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: displayedChores.length,
                      itemBuilder: (context, index) {
                        final chore = displayedChores[index];
                        final assignee = family.members.where((m) => m.userId == chore.assignedTo).firstOrNull;
                        return AnimatedListItem(
                          index: index,
                          child: ChoreCard(
                            chore: chore,
                            assigneeName: assignee?.user?.displayName,
                            onToggle: () => ref.read(choreProvider.notifier).toggleStatus(chore.id),
                            onTap: () => context.push('/chores/${chore.id}'),
                            onDismissed: () => ref.read(choreProvider.notifier).deleteChore(chore.id),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chores/create'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Chore'),
      ),
    );
  }
}
