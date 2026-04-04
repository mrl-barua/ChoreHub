import 'package:flutter/material.dart';
import '../config/theme.dart';

class ReactionPicker extends StatelessWidget {
  final Function(String emoji) onReactionSelected;

  const ReactionPicker({super.key, required this.onReactionSelected});

  static const List<String> reactions = ['👍', '❤️', '😂', '😮', '😢', '🎉'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.map((emoji) {
          return GestureDetector(
            onTap: () => onReactionSelected(emoji),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ReactionDisplay extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String currentUserId;
  final Function(String emoji) onTap;

  const ReactionDisplay({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactions.entries.map((entry) {
          final hasReacted = entry.value.contains(currentUserId);
          return GestureDetector(
            onTap: () => onTap(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasReacted
                    ? AppTheme.accent.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: hasReacted
                    ? Border.all(color: AppTheme.accent.withValues(alpha: 0.5))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.key, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 3),
                  Text(
                    '${entry.value.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasReacted ? AppTheme.accent : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
