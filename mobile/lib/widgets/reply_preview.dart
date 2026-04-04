import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/message.dart';

/// Shows above the input bar when replying to a message
class ReplyPreviewBar extends StatelessWidget {
  final Message replyingTo;
  final VoidCallback onCancel;

  const ReplyPreviewBar({super.key, required this.replyingTo, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replyingTo.userName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyingTo.hasImage ? '📷 Photo' : replyingTo.text,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// Shows inside a message bubble as quoted text
class ReplyQuote extends StatelessWidget {
  final ReplyTo replyTo;
  final bool isMe;

  const ReplyQuote({super.key, required this.replyTo, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (isMe ? Colors.white : AppTheme.accent).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white.withValues(alpha: 0.5) : AppTheme.accent,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyTo.userName ?? 'Unknown',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isMe ? Colors.white.withValues(alpha: 0.8) : AppTheme.accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyTo.text,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white.withValues(alpha: 0.6) : Colors.grey.shade400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
