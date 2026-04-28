import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../services/api_client.dart';
import '../../services/family_service.dart';
import '../../services/feedback_service.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pressable.dart';
import '../../widgets/skeleton_loader.dart';

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final FamilyService _familyService = FamilyService(ApiClient());

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(familyProvider.notifier).refreshWithSync();
      await ref.read(familyProvider.notifier).loadMemberStats();
    });
  }

  Future<void> _leaveFamily() async {
    final family = ref.read(familyProvider).currentFamily;
    final user = ref.read(authProvider).user;
    if (family == null || user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave Family'),
        content: const Text('Are you sure you want to leave this family? Your assigned chores will be unassigned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Leave', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _familyService.removeMember(family.id, user.id);
      ref.invalidate(familyProvider);
      ref.invalidate(choreProvider);
    } catch (e) {
      debugPrint('Failed to leave family: $e');
      if (mounted) {
        AppFeedback.error(context, 'Failed to leave family');
      }
    }
  }

  Future<void> _removeMember(String targetUserId, String displayName) async {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $displayName from the family? Their assigned chores will be unassigned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Remove', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _familyService.removeMember(family.id, targetUserId);
      await ref.read(familyProvider.notifier).refreshWithSync();
      await ref.read(familyProvider.notifier).loadMemberStats();
      if (mounted) {
        AppFeedback.success(context, '$displayName removed');
      }
    } catch (e) {
      debugPrint('Failed to remove member: $e');
      if (mounted) {
        AppFeedback.error(context, 'Failed to remove member');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final currentUser = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserIsAdmin = family.members.any((m) => m.userId == currentUser?.id && m.role == 'admin');
    final totalChores = family.totalChores;
    final completedChores = family.completedChores;
    final memberChoreCount = family.memberChoreCount;
    final memberCompletedCount = family.memberCompletedCount;

    if (family.currentFamily == null && family.hasLoadError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family')),
        body: EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Connection Problem',
          subtitle: 'Could not load your family data. Check your internet connection and try again.',
          action: FilledButton.icon(
            onPressed: () => ref.read(familyProvider.notifier).loadFamilies(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      );
    }

    if (family.currentFamily == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family')),
        body: EmptyState(
          icon: Icons.people_outline_rounded,
          title: 'No family yet',
          subtitle: 'Create a family group or accept an invitation.',
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
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(family.currentFamily!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => context.push('/family/challenges'),
            tooltip: 'Challenges',
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded),
            onPressed: () => context.push('/family/invitations'),
            tooltip: 'Invitations',
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/family/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(familyProvider.notifier).refreshWithSync();
          await ref.read(familyProvider.notifier).loadMemberStats();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            AnimatedListItem(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [AppTheme.surfaceVariant, AppTheme.surfaceLow]
                        : [AppTheme.accent, AppTheme.accentLight],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: isDark ? 0.1 : 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                family.currentFamily!.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              Text(
                                '${family.members.length} member${family.members.length != 1 ? 's' : ''}',
                                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _HeaderStat(icon: Icons.task_rounded, label: 'Total', value: '$totalChores', color: Colors.white),
                        const SizedBox(width: 16),
                        _HeaderStat(icon: Icons.check_circle_rounded, label: 'Done', value: '$completedChores', color: AppTheme.accentGreen),
                        const SizedBox(width: 16),
                        _HeaderStat(icon: Icons.pending_rounded, label: 'Pending', value: '${totalChores - completedChores}', color: AppTheme.accentOrange),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            AnimatedListItem(
              index: 1,
              child: Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.person_add_rounded,
                      label: 'Invite\nMember',
                      color: AppTheme.accent,
                      onTap: () => context.push('/family/invite'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.chat_rounded,
                      label: 'Family\nChat',
                      color: AppTheme.accentBlue,
                      onTap: () => context.go('/chat'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.analytics_rounded,
                      label: 'View\nAnalytics',
                      color: AppTheme.accentGreen,
                      onTap: () => context.push('/analytics'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            AnimatedListItem(
              index: 2,
              child: const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            if (family.isLoading && family.members.isEmpty) ...[
              const SkeletonStats(),
              const SizedBox(height: 12),
              const SkeletonMemberList(count: 3),
            ],
            ...family.members.asMap().entries.map((entry) {
              final member = entry.value;
              final isCurrentUser = member.userId == currentUser?.id;
              final assignedCount = memberChoreCount[member.userId] ?? 0;
              final completedCount = memberCompletedCount[member.userId] ?? 0;
              final colors = [
                AppTheme.accent,
                AppTheme.accentGreen,
                AppTheme.accentOrange,
                AppTheme.accentBlue,
                AppTheme.accentLight,
              ];
              final avatarColor = colors[entry.key % colors.length];

              return AnimatedListItem(
                index: entry.key + 3,
                child: GestureDetector(
                  onTap: () => context.push('/family/member/${member.userId}'),
                  child: Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: avatarColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  (member.user?.displayName ?? '').isNotEmpty
                                      ? member.user!.displayName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: avatarColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          member.user?.displayName ?? 'Unknown',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCurrentUser)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: const Text('(You)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('@${member.user?.username ?? ''}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (member.role == 'admin')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('Admin',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                                  ),
                                if (currentUserIsAdmin && !isCurrentUser) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: AppTheme.textSecondary),
                                    onPressed: () => _removeMember(member.userId, member.user?.displayName ?? 'this member'),
                                    tooltip: 'Remove member',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _MemberStatChip(
                              icon: Icons.assignment_rounded,
                              label: '$assignedCount assigned',
                              color: AppTheme.accentBlue,
                            ),
                            const SizedBox(width: 8),
                            _MemberStatChip(
                              icon: Icons.check_circle_rounded,
                              label: '$completedCount done',
                              color: AppTheme.accentGreen,
                            ),
                            const Spacer(),
                            if (completedCount > 0)
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, size: 16, color: AppTheme.accentOrange),
                                  const SizedBox(width: 2),
                                  Text('$completedCount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentOrange)),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              );
            }),

            const SizedBox(height: 24),
            AnimatedListItem(
              index: family.members.length + 4,
              child: OutlinedButton.icon(
                onPressed: _leaveFamily,
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('Leave Family'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentRed,
                  side: BorderSide(color: AppTheme.accentRed.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/family/invite'),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Invite'),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _HeaderStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MemberStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MemberStatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
