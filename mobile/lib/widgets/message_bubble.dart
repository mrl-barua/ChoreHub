import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/message.dart';
import '../utils/category_helpers.dart';
import 'link_preview.dart';
import 'reaction_picker.dart';
import 'voice_message_player.dart';
import 'reply_preview.dart';

class MessageBubble extends StatelessWidget {
  static final _mentionPattern = RegExp(r'@(\w+)');
  static final _audioExtensions = ['.m4a', '.aac', '.mp3', '.wav', '.ogg'];

  bool _isAudioUrl(String url) => _audioExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  bool _isVoiceMessage() => message.imageUrl != null && _isAudioUrl(message.imageUrl!);

  final Message message;
  final bool isMe;
  final bool showName;
  final Map<String, String> memberNames;
  final String currentUserId;
  final VoidCallback? onChoreTap;
  final Function(Message)? onReply;
  final Function(String emoji)? onReaction;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    this.showName = true,
    this.memberNames = const {},
    this.onChoreTap,
    this.onReply,
    this.onReaction,
    this.onDelete,
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

  void _showLongPressMenu(BuildContext context, TapDownDetails? details) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = details?.globalPosition ?? Offset.zero;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, overlay.size.width - position.dx, 0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem(value: 'reply', child: _MenuItem(icon: Icons.reply_rounded, label: 'Reply')),
        const PopupMenuItem(value: 'copy', child: _MenuItem(icon: Icons.copy_rounded, label: 'Copy')),
        const PopupMenuItem(value: 'react', child: _MenuItem(icon: Icons.emoji_emotions_outlined, label: 'React')),
        if (isMe)
          const PopupMenuItem(value: 'delete', child: _MenuItem(icon: Icons.delete_outline_rounded, label: 'Delete', isDestructive: true)),
      ],
    ).then((value) {
      if (value == 'reply') {
        onReply?.call(message);
      } else if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: message.text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message copied'), duration: Duration(seconds: 1)),
          );
        }
      } else if (value == 'react') {
        if (context.mounted) _showReactionPicker(context);
      } else if (value == 'delete') {
        onDelete?.call();
      }
    });
  }

  void _showReactionPicker(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: ReactionPicker(
            onReactionSelected: (emoji) {
              Navigator.pop(ctx);
              onReaction?.call(emoji);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reactions = message.reactionMap;
    final url = extractUrl(message.text);

    Offset? tapPosition;

    return GestureDetector(
      onTapDown: (details) => tapPosition = details.globalPosition,
      onLongPress: () {
        _showLongPressMenu(
          context,
          tapPosition != null ? TapDownDetails(globalPosition: tapPosition!) : null,
        );
      },
      child: Dismissible(
        key: ValueKey('swipe_${message.id}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          onReply?.call(message);
          return false; // Don't actually dismiss
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: Icon(Icons.reply_rounded, color: Colors.grey.shade400, size: 24),
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
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
                      color: AppTheme.accent.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppTheme.accent
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply quote
                    if (message.replyTo != null)
                      ReplyQuote(replyTo: message.replyTo!, isMe: isMe),

                    // Voice message
                    if (message.imageUrl != null && _isAudioUrl(message.imageUrl!))
                      VoiceMessagePlayer(audioUrl: message.imageUrl!, isMe: isMe)
                    // Image
                    else if (message.hasImage)
                      _buildImage(context),

                    // Message text with mentions highlighted
                    if (message.text.isNotEmpty && !(message.hasImage && message.text == 'Sent a photo') && !_isVoiceMessage())
                      _buildRichText(context),

                    // Link preview
                    if (url != null)
                      LinkPreview(url: url, isMe: isMe),

                    // Chore attachment card
                    if (message.hasChoreAttachment) ...[
                      const SizedBox(height: 8),
                      message.chore != null
                          ? _buildChoreCard(context)
                          : _buildChoreIdFallback(context),
                    ],

                    // Timestamp + read receipts
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.grey.shade500,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildReadReceipt(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Reactions below bubble
              if (reactions.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    left: isMe ? 0 : 12,
                    right: isMe ? 12 : 0,
                  ),
                  child: ReactionDisplay(
                    reactions: reactions,
                    currentUserId: currentUserId,
                    onTap: (emoji) => onReaction?.call(emoji),
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadReceipt() {
    final readBy = message.readBy.where((id) => id != message.userId).toList();
    if (readBy.isEmpty) {
      return Icon(Icons.done_rounded, size: 14, color: Colors.white.withValues(alpha: 0.5));
    }
    // Show small avatars or double-check
    if (readBy.length <= 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: readBy.map((userId) {
          final name = memberNames[userId] ?? '?';
          return Padding(
            padding: const EdgeInsets.only(left: 2),
            child: CircleAvatar(
              radius: 7,
              backgroundColor: const Color(0xFF34C759),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          );
        }).toList(),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.done_all_rounded, size: 14, color: const Color(0xFF34C759)),
        const SizedBox(width: 2),
        Text('${readBy.length}', style: const TextStyle(fontSize: 9, color: Color(0xFF34C759))),
      ],
    );
  }

  Widget _buildImage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250, maxWidth: 250),
          child: Image.network(
            ApiConfig.imageUrl(message.imageUrl),
            fit: BoxFit.cover,
            cacheWidth: 500,
            cacheHeight: 500,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.broken_image_rounded, color: Colors.grey.shade600, size: 32),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRichText(BuildContext context) {
    final text = message.text;
    final mentionIds = message.mentionedUserIds;

    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (mentionIds.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: isMe ? Colors.white : onSurface,
          height: 1.3,
        ),
      );
    }

    final mentionColor = isMe ? Colors.white : AppTheme.accent;
    final textColor = isMe ? Colors.white : onSurface;

    final spans = <InlineSpan>[];
    final pattern = _mentionPattern;
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
          color: (isMe ? Colors.white : AppTheme.accent).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isMe ? Colors.white : AppTheme.accent).withValues(alpha: 0.2),
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
              child: Icon(CategoryHelpers.iconFor(chore.category), size: 18, color: categoryColor),
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
                      color: isMe ? Colors.white : Theme.of(context).colorScheme.onSurface,
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
          color: (isMe ? Colors.white : AppTheme.accent).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isMe ? Colors.white : AppTheme.accent).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_rounded, size: 18, color: isMe ? Colors.white70 : AppTheme.accent),
            const SizedBox(width: 8),
            Text(
              'View chore',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isMe ? Colors.white : AppTheme.accent,
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

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _MenuItem({required this.icon, required this.label, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.accentRed : Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 14)),
      ],
    );
  }
}
