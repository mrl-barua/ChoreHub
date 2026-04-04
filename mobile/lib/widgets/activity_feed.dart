import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/chore_history.dart';

class ActivityFeed extends StatelessWidget {
  final List<ChoreHistory> entries;
  const ActivityFeed({super.key, required this.entries});

  IconData _actionIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'assigned':
        return Icons.person_add_rounded;
      case 'accepted':
        return Icons.thumb_up_rounded;
      case 'declined':
        return Icons.thumb_down_rounded;
      case 'reopened':
        return Icons.replay_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'created':
        return AppTheme.accentBlue;
      case 'completed':
        return AppTheme.accentGreen;
      case 'assigned':
        return AppTheme.accent;
      case 'accepted':
        return AppTheme.accentGreen;
      case 'declined':
        return AppTheme.accentRed;
      case 'reopened':
        return AppTheme.accentOrange;
      default:
        return Colors.grey;
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
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text('No activity yet', style: TextStyle(color: Colors.grey.shade500))),
      );
    }

    return Column(
      children: entries.map((entry) {
        final color = _actionColor(entry.action);
        final name = entry.userName ?? 'Someone';
        final chore = entry.choreTitle ?? 'a chore';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_actionIcon(entry.action), size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                    children: [
                      TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: ' ${entry.actionLabel} '),
                      TextSpan(text: chore, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(_timeAgo(entry.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
