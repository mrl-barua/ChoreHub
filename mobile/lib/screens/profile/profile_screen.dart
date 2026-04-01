import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/animated_list_item.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final themeMode = ref.watch(themeProvider);
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
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
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Settings section
          AnimatedListItem(
            index: 1,
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(user?.email ?? ''),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Icon(isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: isOnline ? Colors.green : Colors.orange),
                    title: const Text('Sync Status'),
                    subtitle: Text(isOnline ? 'Online' : 'Offline - changes sync later'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Appearance
          AnimatedListItem(
            index: 2,
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Theme'),
                    subtitle: Text(themeMode == ThemeMode.system ? 'System' : themeMode == ThemeMode.dark ? 'Dark' : 'Light'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Choose Theme', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                              ),
                              ...ThemeMode.values.map((mode) => ListTile(
                                    leading: Icon(
                                      mode == ThemeMode.dark ? Icons.dark_mode_rounded : mode == ThemeMode.light ? Icons.light_mode_rounded : Icons.auto_mode_rounded,
                                    ),
                                    title: Text(mode.name[0].toUpperCase() + mode.name.substring(1)),
                                    trailing: themeMode == mode ? const Icon(Icons.check_rounded, color: Color(0xFF6C63FF)) : null,
                                    onTap: () {
                                      ref.read(themeProvider.notifier).setThemeMode(mode);
                                      Navigator.pop(context);
                                    },
                                  )),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Logout
          AnimatedListItem(
            index: 3,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(authProvider.notifier).logout();
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
