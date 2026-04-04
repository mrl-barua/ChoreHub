import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/chore_history.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../models/chore.dart';
import '../../services/api_client.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/chore_card.dart';
import '../../widgets/dashboard_stats.dart';
import '../../widgets/activity_feed.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/weekly_summary_card.dart';
import '../../widgets/suggestions_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<Chore> _myChores = [];
  List<Chore> _pendingAssignments = [];
  List<ChoreHistory> _recentActivity = [];
  List<Chore> _upcomingDue = [];
  List<Chore> _doneToday = [];
  int _streak = 0;
  Map<String, dynamic>? _weeklySummary;
  List<dynamic> _suggestions = [];

  int _daysUntilDue(String? dueDate) {
    if (dueDate == null) return 999;
    try {
      final due = DateTime.parse(dueDate);
      final now = DateTime.now();
      return DateTime(due.year, due.month, due.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    } catch (_) {
      return 999;
    }
  }

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
      final api = ApiClient();

      // Fetch all dashboard data from server in parallel
      final results = await Future.wait([
        api.dio.get('/chores', queryParameters: {'familyId': family.id}),
        api.dio.get('/chores/history', queryParameters: {'familyId': family.id, 'limit': 10}),
        api.dio.get('/chores/analytics', queryParameters: {'familyId': family.id}),
      ]);

      // Load optional data separately (don't crash if these fail)
      Map<String, dynamic>? weeklySummary;
      List<dynamic> suggestions = [];
      try { weeklySummary = (await api.dio.get('/families/${family.id}/weekly-summary')).data; } catch (_) {}
      try { suggestions = (await api.dio.get('/chores/suggestions', queryParameters: {'familyId': family.id})).data as List; } catch (_) {}

      final allChores = (results[0].data as List).map((c) => Chore.fromJson(c)).toList();
      final history = (results[1].data as List).map((h) => ChoreHistory.fromJson(h)).toList();
      final analytics = results[2].data;

      final myChores = allChores.where((c) => c.assignedTo == user.id && !c.isDone).toList();
      final pending = allChores.where((c) => c.assignedTo == user.id && c.isPendingAcceptance).toList();
      final streak = analytics['currentStreak'] as int? ?? 0;

      // Upcoming due (within 3 days, not done)
      final now = DateTime.now();
      final upcoming = allChores.where((c) {
        if (c.dueDate == null || c.isDone) return false;
        try {
          final due = DateTime.parse(c.dueDate!);
          final days = DateTime(due.year, due.month, due.day).difference(DateTime(now.year, now.month, now.day)).inDays;
          return days >= 0 && days <= 3;
        } catch (_) { return false; }
      }).toList()..sort((a, b) => (a.dueDate ?? '').compareTo(b.dueDate ?? ''));

      // Done today
      final todayStr = now.toIso8601String().substring(0, 10);
      final doneToday = allChores.where((c) => c.isDone && c.updatedAt != null && c.updatedAt!.startsWith(todayStr)).toList();

      if (mounted) {
        setState(() {
          _myChores = myChores;
          _pendingAssignments = pending;
          _recentActivity = history;
          _upcomingDue = upcoming;
          _doneToday = doneToday;
          _streak = streak;
          _weeklySummary = weeklySummary;
          _suggestions = suggestions;
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

    if (family.currentFamily == null && !family.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/welcome');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
              const SizedBox(height: 16),

              // Weekly summary
              if (_weeklySummary != null)
                AnimatedListItem(index: 2, child: WeeklySummaryCard(data: _weeklySummary!)),
              if (_weeklySummary != null) const SizedBox(height: 12),

              // Smart suggestions
              if (_suggestions.isNotEmpty)
                AnimatedListItem(index: 3, child: SuggestionsCard(suggestions: _suggestions)),
              if (_suggestions.isNotEmpty) const SizedBox(height: 12),

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
                  child: _SectionHeader(title: 'My Tasks', color: AppTheme.accent),
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

              // Upcoming due (next 3 days)
              if (_upcomingDue.isNotEmpty) ...[
                AnimatedListItem(
                  index: 8,
                  child: _SectionHeader(title: 'Due Soon', color: AppTheme.accentOrange),
                ),
                const SizedBox(height: 8),
                ...(_upcomingDue.take(3).toList().asMap().entries.map((entry) {
                  final chore = entry.value;
                  final daysLeft = _daysUntilDue(chore.dueDate);
                  return AnimatedListItem(
                    index: entry.key + 8,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C24),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: daysLeft == 0 ? AppTheme.accentRed.withValues(alpha: 0.4) : AppTheme.accentOrange.withValues(alpha: 0.2)),
                      ),
                      child: GestureDetector(
                        onTap: () => context.push('/chores/${chore.id}'),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: daysLeft == 0 ? AppTheme.accentRed.withValues(alpha: 0.15) : AppTheme.accentOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                daysLeft == 0 ? 'Today' : daysLeft == 1 ? 'Tomorrow' : '${daysLeft}d',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: daysLeft == 0 ? AppTheme.accentRed : AppTheme.accentOrange),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(chore.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                  );
                })),
                const SizedBox(height: 16),
              ],

              // Done today celebration
              if (_doneToday.isNotEmpty) ...[
                AnimatedListItem(
                  index: 9,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.celebration_rounded, color: AppTheme.accentGreen, size: 22),
                        const SizedBox(width: 10),
                        Text('${_doneToday.length} chore${_doneToday.length > 1 ? 's' : ''} done today!',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.accentGreen)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Recent chores
              AnimatedListItem(
                index: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionHeader(title: 'Recent Chores', color: AppTheme.accentGreen),
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
                  child: _SectionHeader(title: 'Recent Activity', color: AppTheme.accentBlue),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ],
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
