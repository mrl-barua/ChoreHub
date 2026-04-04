import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/notification_provider.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  IconData _typeIcon(String type) {
    switch (type) {
      case 'chore_assigned': return Icons.assignment_ind_rounded;
      case 'chore_completed': return Icons.check_circle_rounded;
      case 'mention': return Icons.alternate_email_rounded;
      case 'swap_request': return Icons.swap_horiz_rounded;
      case 'challenge_complete': return Icons.emoji_events_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'chore_assigned': return AppTheme.accent;
      case 'chore_completed': return AppTheme.accentGreen;
      case 'mention': return AppTheme.accentBlue;
      case 'swap_request': return AppTheme.accentOrange;
      case 'challenge_complete': return const Color(0xFFFFD700);
      default: return Colors.grey;
    }
  }

  String _timeAgo(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.month}/${date.day}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade700),
                      const SizedBox(height: 12),
                      Text('No notifications', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(notificationProvider.notifier).loadNotifications(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: state.notifications.length,
                    itemBuilder: (context, index) {
                      final n = state.notifications[index];
                      final color = _typeColor(n.type);
                      return GestureDetector(
                        onTap: () {
                          if (!n.read) ref.read(notificationProvider.notifier).markRead(n.id);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: n.read ? AppTheme.surface : AppTheme.surfaceHigh,
                            borderRadius: BorderRadius.circular(14),
                            border: n.read ? null : Border.all(color: color.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                                child: Icon(_typeIcon(n.type), size: 18, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n.title, style: TextStyle(fontSize: 14, fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(n.body, style: TextStyle(fontSize: 12, color: Colors.grey.shade400), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(_timeAgo(n.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              if (!n.read)
                                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
