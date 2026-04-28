import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/notification_preferences_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  Future<void> _updatePref(String key, dynamic value) async {
    await ref.read(notificationPrefsProvider.notifier).update({key: value});
  }

  Future<void> _pickTime(String key, String? currentValue) async {
    final parts = (currentValue ?? '08:00').split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await _updatePref(key, formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationPrefsProvider);
    final prefs = state.prefs;

    bool getPref(String key, {bool defaultValue = true}) {
      final val = prefs[key];
      if (val is bool) return val;
      return defaultValue;
    }

    String? getStringPref(String key) {
      final val = prefs[key];
      if (val is String) return val;
      return null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (state.error != null)
                  Container(
                    margin: const EdgeInsets.all(AppTheme.spaceM),
                    padding: const EdgeInsets.all(AppTheme.spaceS),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.accentRed, size: AppTheme.iconSizeM),
                        const SizedBox(width: AppTheme.spaceS),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: const TextStyle(color: AppTheme.accentRed, fontSize: AppTheme.fontS),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Push Notifications',
                    style: TextStyle(
                      fontSize: AppTheme.fontS,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Enable Push Notifications'),
                  subtitle: const Text('Master toggle for all push notifications'),
                  value: getPref('pushEnabled'),
                  onChanged: (v) => _updatePref('pushEnabled', v),
                ),
                const Divider(height: 1, indent: 56),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Notification Types',
                    style: TextStyle(
                      fontSize: AppTheme.fontS,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.assignment_ind_rounded),
                  title: const Text('Chore Assigned'),
                  subtitle: const Text('When a chore is assigned to you'),
                  value: getPref('choreAssigned'),
                  onChanged: (v) => _updatePref('choreAssigned', v),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.check_circle_outline_rounded),
                  title: const Text('Chore Completed'),
                  subtitle: const Text('When someone completes your chore'),
                  value: getPref('choreCompleted'),
                  onChanged: (v) => _updatePref('choreCompleted', v),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.alarm_rounded),
                  title: const Text('Due Soon Reminders'),
                  subtitle: const Text('Reminders for chores due within an hour'),
                  value: getPref('choreDueSoon'),
                  onChanged: (v) => _updatePref('choreDueSoon', v),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.alternate_email_rounded),
                  title: const Text('Mentions'),
                  subtitle: const Text('When someone @mentions you in chat'),
                  value: getPref('mention'),
                  onChanged: (v) => _updatePref('mention', v),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.swap_horiz_rounded),
                  title: const Text('Swap Requests'),
                  subtitle: const Text('Chore swap requests and responses'),
                  value: getPref('swap'),
                  onChanged: (v) => _updatePref('swap', v),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.today_rounded),
                  title: const Text('Daily Summary'),
                  subtitle: const Text('Morning summary of today\'s chores'),
                  value: getPref('dailySummary'),
                  onChanged: (v) => _updatePref('dailySummary', v),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Quiet Hours',
                    style: TextStyle(
                      fontSize: AppTheme.fontS,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.bedtime_rounded),
                  title: const Text('Quiet Hours Start'),
                  subtitle: Text(getStringPref('quietHoursStart') ?? '22:00'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickTime('quietHoursStart', getStringPref('quietHoursStart')),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Quiet Hours End'),
                  subtitle: Text(getStringPref('quietHoursEnd') ?? '07:00'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickTime('quietHoursEnd', getStringPref('quietHoursEnd')),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
