import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/swap_request.dart';
import '../utils/date_helpers.dart';

class SwapRequestCard extends StatelessWidget {
  final SwapRequest swap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;

  const SwapRequestCard({
    super.key,
    required this.swap,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  Color _statusColor() {
    switch (swap.status) {
      case 'pending': return AppTheme.accentOrange;
      case 'accepted': return AppTheme.accentGreen;
      case 'declined': return AppTheme.accentRed;
      case 'cancelled': return AppTheme.textSecondary;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    swap.chore?.title ?? 'Chore',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${swap.status[0].toUpperCase()}${swap.status.substring(1)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (swap.fromUser != null)
              Text(
                'From: ${swap.fromUser!.displayName}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            if (swap.toUser != null)
              Text(
                'To: ${swap.toUser!.displayName}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            if (swap.toUserId == null && swap.toUser == null)
              const Text(
                'Open request (anyone can accept)',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            if (swap.message != null && swap.message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '"${swap.message}"',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
              ),
            ],
            if (swap.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateHelpers.timeAgo(swap.createdAt!),
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
            if (onAccept != null || onDecline != null || onCancel != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onDecline != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDecline,
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRed),
                        child: const Text('Decline'),
                      ),
                    ),
                  if (onDecline != null && onAccept != null)
                    const SizedBox(width: 12),
                  if (onAccept != null)
                    Expanded(
                      child: FilledButton(
                        onPressed: onAccept,
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.accentBlue),
                        child: const Text('Accept'),
                      ),
                    ),
                  if (onCancel != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRed),
                        child: const Text('Cancel Request'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
