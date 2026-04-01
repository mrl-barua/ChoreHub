import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showName;
  final Map<String, String> memberNames; // userId -> displayName
  final VoidCallback? onChoreTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showName = true,
    this.memberNames = const {},
    this.onChoreTap,
  });

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'cleaning': return Icons.cleaning_services_rounded;
      case 'cooking': return Icons.restaurant_rounded;
      case 'dishwashing': return Icons.local_laundry_service_rounded;
      case 'laundry': return Icons.dry_cleaning_rounded;
      case 'gardening': return Icons.grass_rounded;
      case 'shopping': return Icons.shopping_cart_rounded;
      default: return Icons.task_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 64 : 12,
        right: isMe ? 12 : 64,
        top: showName ? 8 : 2,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showName && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                message.userName ?? 'Unknown',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.8),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFF6C63FF)
                  : (isDark ? const Color(0xFF2A2A40) : Colors.white),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message text with mentions highlighted
                _buildRichText(context),

                // Chore attachment card
                if (message.hasChoreAttachment) ...[
                  const SizedBox(height: 8),
                  message.chore != null
                      ? _buildChoreCard(context)
                      : _buildChoreIdFallback(context),
                ],

                // Timestamp
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichText(BuildContext context) {
    final text = message.text;
    final mentionIds = message.mentionedUserIds;

    if (mentionIds.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: isMe ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
          height: 1.3,
        ),
      );
    }

    // Parse @mentions in text and highlight them
    final textColor = isMe ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87);
    final mentionColor = isMe ? Colors.white : const Color(0xFF6C63FF);

    final spans = <InlineSpan>[];
    final pattern = RegExp(r'@(\w+)');
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: TextStyle(fontSize: 15, color: textColor, height: 1.3)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(fontSize: 15, color: mentionColor, fontWeight: FontWeight.w700, height: 1.3),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: TextStyle(fontSize: 15, color: textColor, height: 1.3)));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildChoreCard(BuildContext context) {
    final chore = message.chore!;
    final categoryColor = AppTheme.categoryColors[chore.category] ?? Colors.grey;
    final isDone = chore.status == 'done';

    return GestureDetector(
      onTap: onChoreTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isMe ? Colors.white : const Color(0xFF6C63FF)).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isMe ? Colors.white : const Color(0xFF6C63FF)).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_categoryIcon(chore.category), size: 18, color: categoryColor),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chore.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone ? AppTheme.accentGreen : AppTheme.accentOrange,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isDone ? 'Done' : 'Pending',
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: isMe ? Colors.white.withValues(alpha: 0.5) : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoreIdFallback(BuildContext context) {
    return GestureDetector(
      onTap: onChoreTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isMe ? Colors.white : const Color(0xFF6C63FF)).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isMe ? Colors.white : const Color(0xFF6C63FF)).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_rounded, size: 18, color: isMe ? Colors.white70 : const Color(0xFF6C63FF)),
            const SizedBox(width: 8),
            Text(
              'View chore',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isMe ? Colors.white : const Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 14, color: isMe ? Colors.white54 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
