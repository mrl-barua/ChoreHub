import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/chore_card.dart';
import '../../widgets/dashboard_stats.dart';
import '../../widgets/empty_state.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final family = ref.watch(familyProvider);
    final chores = ref.watch(choreProvider);

    if (family.currentFamily == null) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.family_restroom_rounded,
            title: 'Welcome to ChoreHub!',
            subtitle: 'Create a family group or accept an invitation to get started.',
            action: Column(
              children: [
                FilledButton.icon(
                  onPressed: () => context.push('/family/create'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Family'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/family/invitations'),
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text('View Invitations'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(choreProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              // Greeting header
              AnimatedListItem(
                index: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      auth.user?.displayName ?? '',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats card
              AnimatedListItem(
                index: 1,
                child: DashboardStats(stats: chores.stats),
              ),
              const SizedBox(height: 28),

              // Quick actions
              AnimatedListItem(
                index: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.add_task_rounded,
                        label: 'New Chore',
                        color: const Color(0xFF6C63FF),
                        onTap: () => context.push('/chores/create'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.person_add_rounded,
                        label: 'Invite',
                        color: const Color(0xFF00C853),
                        onTap: () => context.push('/family/invite'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.people_rounded,
                        label: '${family.members.length} Members',
                        color: const Color(0xFFFF9100),
                        onTap: () => context.go('/family'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Recent chores
              AnimatedListItem(
                index: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Chores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    if (chores.chores.length > 5)
                      TextButton(
                        onPressed: () => context.go('/chores'),
                        child: const Text('View All'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (chores.chores.isEmpty)
                AnimatedListItem(
                  index: 4,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.task_alt_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No chores yet', style: TextStyle(color: Colors.grey.shade500)),
                          const SizedBox(height: 8),
                          Text('Tap + to create your first chore',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...chores.chores.take(5).toList().asMap().entries.map((entry) {
                  final chore = entry.value;
                  final assignee = family.members.where((m) => m.userId == chore.assignedTo).firstOrNull;
                  return AnimatedListItem(
                    index: entry.key + 4,
                    child: ChoreCard(
                      chore: chore,
                      assigneeName: assignee?.user?.displayName,
                      onToggle: () => ref.read(choreProvider.notifier).toggleStatus(chore.id),
                      onTap: () => context.push('/chores/${chore.id}'),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      floatingActionButton: family.currentFamily != null
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/chores/create'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Chore'),
            )
          : null,
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
