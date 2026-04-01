import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../widgets/chore_card.dart';
import '../../widgets/dashboard_stats.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final family = ref.watch(familyProvider);
    final chores = ref.watch(choreProvider);

    if (family.currentFamily == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ChoreHub')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.family_restroom, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text('Welcome, ${auth.user?.displayName ?? ''}!',
                    style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Create or join a family to get started.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/family/create'),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Family'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/family/invitations'),
                  icon: const Icon(Icons.mail_outlined),
                  label: const Text('View Invitations'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(family.currentFamily!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(choreProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(choreProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DashboardStats(stats: chores.stats),
            const SizedBox(height: 24),
            Text('Recent Chores', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (chores.chores.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.task_alt, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text('No chores yet. Create one!', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ...chores.chores.take(5).map((chore) => ChoreCard(
                    chore: chore,
                    onToggle: () => ref.read(choreProvider.notifier).toggleStatus(chore.id),
                    onTap: () => context.push('/chores/${chore.id}'),
                  )),
            if (chores.chores.length > 5) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/chores'),
                child: const Text('View all chores'),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chores/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
