import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_client.dart';
import '../../widgets/animated_list_item.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final response = await ApiClient().dio.get('/users/me/stats');
      if (mounted) setState(() => _stats = response.data);
    } catch (_) {}
  }

  void _showEditProfile() {
    final user = ref.read(authProvider).user;
    final controller = TextEditingController(text: user?.displayName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
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
                    await ApiClient().dio.patch('/users/me', data: {'displayName': controller.text.trim()});
                    if (ctx.mounted) Navigator.pop(ctx);
                    // Refresh auth state
                    ref.invalidate(authProvider);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated')),
                      );
                    }
                  } catch (_) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Failed to update')),
                      );
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
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
                onPressed: () async {
                  if (newController.text != confirmController.text) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                    return;
                  }
                  if (newController.text.length < 6) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                    return;
                  }
                  try {
                    await ApiClient().dio.post('/users/me/change-password', data: {
                      'currentPassword': currentController.text,
                      'newPassword': newController.text,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully')));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Failed — check current password')));
                    }
                  }
                },
                child: const Text('Change Password'),
              ),
            ),
          ],
        ),
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
            // Avatar + name card
            AnimatedListItem(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF2A2A40), const Color(0xFF1E1E2A)]
                        : [const Color(0xFF6C63FF), const Color(0xFF9B59FF)],
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
                          (user?.displayName ?? '?')[0].toUpperCase(),
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

            // Personal stats
            if (_stats != null)
              AnimatedListItem(
                index: 1,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
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
                          _StatChip(icon: Icons.local_fire_department_rounded, label: 'Streak', value: '${_stats!['currentStreak'] ?? 0}d', color: const Color(0xFFFF9100)),
                          const SizedBox(width: 8),
                          _StatChip(icon: Icons.assignment_rounded, label: 'Assigned', value: '${_stats!['totalAssigned'] ?? 0}', color: AppTheme.accentBlue),
                        ],
                      ),
                      if (_stats!['topCategory'] != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, size: 16, color: AppTheme.accentOrange),
                            const SizedBox(width: 6),
                            Text(
                              'Top category: ${_stats!['topCategory']} (${_stats!['topCategoryCount']})',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Account section
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
                          color: isOnline ? Colors.green : Colors.orange),
                      title: const Text('Status'),
                      subtitle: Text(isOnline ? 'Online' : 'Offline'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Appearance
            AnimatedListItem(
              index: 3,
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

            // App info
            AnimatedListItem(
              index: 4,
              child: Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('App Version'),
                      trailing: Text('1.0.0', style: TextStyle(color: Colors.grey.shade500)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Logout
            AnimatedListItem(
              index: 5,
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
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
