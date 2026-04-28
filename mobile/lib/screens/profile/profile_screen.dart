import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/theme_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_client.dart';
import '../../services/feedback_service.dart';
import '../../services/user_service.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/polished_bottom_sheet.dart';
import '../../widgets/skeleton_loader.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final UserService _userService = UserService(ApiClient());

  Map<String, dynamic>? _stats;
  bool _statsLoading = false;
  String? _statsError;
  bool _choreReminders = true;
  bool _chatMentions = true;
  bool _assignmentAlerts = true;
  final _prefStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final r = await _prefStorage.read(key: 'pref_chore_reminders');
    final m = await _prefStorage.read(key: 'pref_chat_mentions');
    final a = await _prefStorage.read(key: 'pref_assignment_alerts');
    if (mounted) {
      setState(() {
        _choreReminders = r != 'false';
        _chatMentions = m != 'false';
        _assignmentAlerts = a != 'false';
      });
    }
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() { _statsLoading = true; _statsError = null; });
    try {
      final stats = await _userService.loadMyStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _statsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load user stats: $e');
      if (mounted) {
        setState(() {
          _statsLoading = false;
          _statsError = e.toString();
        });
      }
    }
  }

  void _showEditProfile() {
    final user = ref.read(authProvider).user;
    final controller = TextEditingController(text: user?.displayName ?? '');

    showPolishedBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Display Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Display name'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;
                  try {
                    await _userService.updateDisplayName(controller.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(authProvider);
                    if (mounted) {
                      AppFeedback.success(context, 'Profile updated');
                    }
                  } catch (e) {
                    debugPrint('Failed to update profile: $e');
                    if (ctx.mounted) {
                      AppFeedback.error(ctx, 'Failed to update');
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePassword() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    bool isChangingPassword = false;

    showPolishedBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(controller: currentController, obscureText: true, decoration: const InputDecoration(hintText: 'Current password')),
                const SizedBox(height: 12),
                TextField(controller: newController, obscureText: true, decoration: const InputDecoration(hintText: 'New password (min 6 chars)')),
                const SizedBox(height: 12),
                TextField(controller: confirmController, obscureText: true, decoration: const InputDecoration(hintText: 'Confirm new password')),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isChangingPassword ? null : () async {
                      if (newController.text != confirmController.text) {
                        AppFeedback.error(ctx, 'Passwords do not match');
                        return;
                      }
                      if (newController.text.length < 6) {
                        AppFeedback.error(ctx, 'Password must be at least 6 characters');
                        return;
                      }
                      setSheetState(() => isChangingPassword = true);
                      try {
                        await _userService.changePassword(
                          currentPassword: currentController.text,
                          newPassword: newController.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          AppFeedback.success(context, 'Password changed successfully');
                        }
                      } catch (e) {
                        debugPrint('Failed to change password: $e');
                        if (ctx.mounted) {
                          setSheetState(() => isChangingPassword = false);
                          AppFeedback.error(ctx, 'Failed — check current password');
                        }
                      }
                    },
                    child: isChangingPassword
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Change Password'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, ) {
    final auth = ref.watch(authProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final themeMode = ref.watch(themeProvider);
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AnimatedListItem(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [AppTheme.surfaceVariant, AppTheme.surfaceLow]
                        : [AppTheme.accent, AppTheme.accentLight],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          (user?.displayName ?? '').isNotEmpty ? user!.displayName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.displayName ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('@${user?.username ?? ''}', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showEditProfile,
                      icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_statsLoading)
              AnimatedListItem(
                index: 1,
                child: const SkeletonStats(),
              )
            else if (_statsError != null)
              AnimatedListItem(
                index: 1,
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.accentOrange, size: 16),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('Failed to load stats', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.fontS))),
                    TextButton(onPressed: _loadStats, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_stats != null)
              AnimatedListItem(
                index: 1,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _StatChip(icon: Icons.check_circle_rounded, label: 'Completed', value: '${_stats!['totalCompleted'] ?? 0}', color: AppTheme.accentGreen),
                          const SizedBox(width: 8),
                          _StatChip(icon: Icons.local_fire_department_rounded, label: 'Streak', value: '${_stats!['currentStreak'] ?? 0}d', color: AppTheme.accentOrange),
                          const SizedBox(width: 8),
                          _StatChip(icon: Icons.assignment_rounded, label: 'Assigned', value: '${_stats!['totalAssigned'] ?? 0}', color: AppTheme.accentBlue),
                        ],
                      ),
                      if (_stats!['topCategory'] != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: AppTheme.accentOrange),
                            const SizedBox(width: 6),
                            Text(
                              'Top category: ${_stats!['topCategory']} (${_stats!['topCategoryCount']})',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            AnimatedListItem(
              index: 2,
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(user?.email ?? ''),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.lock_outline_rounded),
                      title: const Text('Change Password'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _showChangePassword,
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: Icon(isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          color: isOnline ? AppTheme.accentGreen : AppTheme.accentOrange),
                      title: const Text('Status'),
                      subtitle: Text(isOnline ? 'Online' : 'Offline'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            AnimatedListItem(
              index: 3,
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.alarm_rounded),
                      title: const Text('Chore Reminders'),
                      subtitle: const Text('Upcoming and overdue chores'),
                      value: _choreReminders,
                      onChanged: (v) async {
                        setState(() => _choreReminders = v);
                        await _prefStorage.write(key: 'pref_chore_reminders', value: v.toString());
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary: const Icon(Icons.alternate_email_rounded),
                      title: const Text('Chat Mentions'),
                      subtitle: const Text('When someone @mentions you'),
                      value: _chatMentions,
                      onChanged: (v) async {
                        setState(() => _chatMentions = v);
                        await _prefStorage.write(key: 'pref_chat_mentions', value: v.toString());
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary: const Icon(Icons.assignment_ind_rounded),
                      title: const Text('Assignment Alerts'),
                      subtitle: const Text('New chore assignments'),
                      value: _assignmentAlerts,
                      onChanged: (v) async {
                        setState(() => _assignmentAlerts = v);
                        await _prefStorage.write(key: 'pref_assignment_alerts', value: v.toString());
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            AnimatedListItem(
              index: 4,
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                    ),
                    ListTile(
                      leading: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
                      title: const Text('Dark Mode'),
                      trailing: Switch.adaptive(
                        value: themeMode == ThemeMode.dark,
                        onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            AnimatedListItem(
              index: 5,
              child: Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('App Version'),
                      trailing: const Text('1.0.0', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            AnimatedListItem(
              index: 6,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Logout')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRed, side: const BorderSide(color: AppTheme.accentRed)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
