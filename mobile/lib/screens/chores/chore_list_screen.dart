import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../widgets/chore_card.dart';
import '../../widgets/chore_filter_bar.dart';

class ChoreListScreen extends ConsumerWidget {
  const ChoreListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProvider);
    final chores = ref.watch(choreProvider);

    if (family.currentFamily == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chores')),
        body: const Center(child: Text('Join or create a family first.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chores')),
      body: Column(
        children: [
          ChoreFilterBar(
            currentFilter: chores.filter,
            onFilterChanged: (filter) => ref.read(choreProvider.notifier).setFilter(filter),
          ),
          Expanded(
            child: chores.chores.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.checklist, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          chores.filter == 'all' ? 'No chores yet' : 'No ${chores.filter} chores',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(choreProvider.notifier).refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: chores.chores.length,
                      itemBuilder: (context, index) {
                        final chore = chores.chores[index];
                        return ChoreCard(
                          chore: chore,
                          onToggle: () => ref.read(choreProvider.notifier).toggleStatus(chore.id),
                          onTap: () => context.push('/chores/${chore.id}'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chores/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
