import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/chore_history.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../repositories/chore_repository.dart';
import '../../repositories/history_repository.dart';
import '../../models/chore.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/chore_card.dart';
import '../../widgets/dashboard_stats.dart';
import '../../widgets/activity_feed.dart';
import '../../widgets/empty_state.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<Chore> _myChores = [];
  List<Chore> _pendingAssignments = [];
  List<ChoreHistory> _recentActivity = [];
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final user = ref.read(authProvider).user;
    final family = ref.read(familyProvider).currentFamily;
    if (user == null || family == null) return;

    try {
      final choreRepo = ChoreRepository();
      final historyRepo = HistoryRepository();

      final results = await Future.wait([
        choreRepo.getMyChores(family.id, user.id),
        choreRepo.getMyPendingAssignments(family.id, user.id),
        historyRepo.getRecentHistory(family.id, limit: 10),
        historyRepo.calculateStreak(user.id, family.id),
      ]);

      if (mounted) {
        setState(() {
          _myChores = results[0] as List<Chore>;
          _pendingAssignments = results[1] as List<Chore>;
          _recentActivity = results[2] as List<ChoreHistory>;
          _streak = results[3] as int;
        });
      }
    } catch (_) {
      // Data load failed — dashboard still renders with empty state
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
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

    final overdueCount = chores.stats['overdue'] ?? 0;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(choreProvider.notifier).refresh();
            await _loadDashboardData();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              // Greeting + streak
              AnimatedListItem(
                index: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(), style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(auth.user?.displayName ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    if (_streak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9100).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF9100), size: 18),
                            const SizedBox(width: 4),
                            Text('$_streak day${_streak > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFF9100))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats
              AnimatedListItem(index: 1, child: DashboardStats(stats: chores.stats)),
              const SizedBox(height: 20),

              // Quick actions
              AnimatedListItem(
                index: 2,
                child: Row(
                  children: [
                    Expanded(child: _QuickAction(icon: Icons.add_task_rounded, label: 'New Chore', color: const Color(0xFF6C63FF), onTap: () => context.push('/chores/create'))),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickAction(icon: Icons.analytics_rounded, label: 'Analytics', color: AppTheme.accentBlue, onTap: () => context.push('/analytics'))),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickAction(icon: Icons.person_add_rounded, label: 'Invite', color: AppTheme.accentGreen, onTap: () => context.push('/family/invite'))),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickAction(icon: Icons.people_rounded, label: '${family.members.length}', color: AppTheme.accentOrange, onTap: () => context.go('/family'))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Overdue warning
              if (overdueCount > 0)
                AnimatedListItem(
                  index: 3,
                  child: GestureDetector(
                    onTap: () {
                      context.go('/chores');
                      ref.read(choreProvider.notifier).setFilter('overdue');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_rounded, color: AppTheme.accentRed, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('$overdueCount overdue chore${overdueCount > 1 ? 's' : ''} need attention',
                                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.accentRed)),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppTheme.accentRed),
                        ],
                      ),
                    ),
                  ),
                ),

              // Pending assignments
              if (_pendingAssignments.isNotEmpty) ...[
                AnimatedListItem(
                  index: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pending Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ..._pendingAssignments.map((chore) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.orange.withValues(alpha: 0.06),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: const Icon(Icons.assignment_ind_rounded, color: Colors.orange),
                            title: Text(chore.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.red, size: 22),
                                  onPressed: () async {
                                    await ref.read(choreProvider.notifier).respondToAssignment(chore.id, 'declined');
                                    await _loadDashboardData();
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.check_rounded, color: AppTheme.accentGreen, size: 22),
                                  onPressed: () async {
                                    await ref.read(choreProvider.notifier).respondToAssignment(chore.id, 'accepted');
                                    await _loadDashboardData();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // My tasks
              if (_myChores.isNotEmpty) ...[
                AnimatedListItem(
                  index: 5,
                  child: const Text('My Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                ...(_myChores.take(3).toList().asMap().entries.map((entry) {
                  final chore = entry.value;
                  final assignee = family.members.where((m) => m.userId == chore.assignedTo).firstOrNull;
                  return AnimatedListItem(
                    index: entry.key + 6,
                    child: ChoreCard(
                      chore: chore,
                      assigneeName: assignee?.user?.displayName,
                      onToggle: () async {
                        await ref.read(choreProvider.notifier).toggleStatus(chore.id);
                        await _loadDashboardData();
                      },
                      onTap: () => context.push('/chores/${chore.id}'),
                    ),
                  );
                })),
                const SizedBox(height: 20),
              ],

              // Recent chores
              AnimatedListItem(
                index: 9,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Chores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    if (chores.chores.length > 5)
                      TextButton(onPressed: () => context.go('/chores'), child: const Text('View All')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (chores.chores.isEmpty)
                AnimatedListItem(
                  index: 10,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.task_alt_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No chores yet', style: TextStyle(color: Colors.grey.shade500)),
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
                    index: entry.key + 10,
                    child: ChoreCard(
                      chore: chore,
                      assigneeName: assignee?.user?.displayName,
                      onToggle: () async {
                        await ref.read(choreProvider.notifier).toggleStatus(chore.id);
                        await _loadDashboardData();
                      },
                      onTap: () => context.push('/chores/${chore.id}'),
                    ),
                  );
                }),

              // Activity feed
              if (_recentActivity.isNotEmpty) ...[
                const SizedBox(height: 24),
                AnimatedListItem(
                  index: 15,
                  child: const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                AnimatedListItem(
                  index: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: ActivityFeed(entries: _recentActivity),
                    ),
                  ),
                ),
              ],
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

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
