import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/chore.dart';

class ChoreCard extends StatefulWidget {
  final Chore chore;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onDismissed;
  final String? assigneeName;

  const ChoreCard({
    super.key,
    required this.chore,
    required this.onToggle,
    required this.onTap,
    this.onDismissed,
    this.assigneeName,
  });

  @override
  State<ChoreCard> createState() => _ChoreCardState();
}

class _ChoreCardState extends State<ChoreCard> {
  bool _isPressed = false;

  Chore get chore => widget.chore;
  Color get _priorityColor => chore.priority == 'high'
      ? AppTheme.priorityHigh
      : chore.priority == 'low'
          ? AppTheme.priorityLow
          : AppTheme.priorityMedium;
  Color get _categoryColor => AppTheme.categoryColors[chore.category] ?? AppTheme.categoryColors['other']!;

  IconData _categoryIcon() {
    switch (chore.category) {
      case 'cleaning': return Icons.cleaning_services_rounded;
      case 'cooking': return Icons.restaurant_rounded;
      case 'dishwashing': return Icons.local_laundry_service_rounded;
      case 'laundry': return Icons.dry_cleaning_rounded;
      case 'gardening': return Icons.grass_rounded;
      case 'shopping': return Icons.shopping_cart_rounded;
      default: return Icons.task_rounded;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff < 0) return 'Overdue';
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      return '${date.month}/${date.day}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget card = GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: chore.isOverdue
                ? Border.all(color: AppTheme.accentRed.withValues(alpha: 0.4))
                : Border.all(color: Colors.white.withValues(alpha: 0.04)),
            boxShadow: _isPressed
                ? []
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                // Priority color stripe
                Container(width: 4, height: 68, color: _priorityColor),
                // Card content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                    child: Row(
                      children: [
                        // Animated checkbox (no controller needed)
                        GestureDetector(
                          onTap: widget.onToggle,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: chore.isDone ? 1.0 : 0.0, end: chore.isDone ? 1.0 : 0.0),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.elasticOut,
                            builder: (context, value, _) {
                              return Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.accentGreen.withValues(alpha: value),
                                  border: Border.all(
                                    color: value > 0.5 ? AppTheme.accentGreen : Colors.grey.shade600,
                                    width: 2,
                                  ),
                                ),
                                child: value > 0.3
                                    ? Transform.scale(
                                        scale: value,
                                        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                      )
                                    : null,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Category icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _categoryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_categoryIcon(), size: 20, color: _categoryColor),
                        ),
                        const SizedBox(width: 14),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chore.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  decoration: chore.isDone ? TextDecoration.lineThrough : null,
                                  color: chore.isDone ? Colors.grey.shade600 : Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.assigneeName != null || chore.dueDate != null || chore.isPendingAcceptance) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (widget.assigneeName != null) ...[
                                      Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade500),
                                      const SizedBox(width: 3),
                                      Flexible(child: Text(widget.assigneeName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade400), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    ],
                                    if (widget.assigneeName != null && chore.dueDate != null)
                                      Text('  ·  ', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                    if (chore.dueDate != null)
                                      Text(
                                        _formatDate(chore.dueDate!),
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: chore.isOverdue ? AppTheme.accentRed : Colors.grey.shade400),
                                      ),
                                    if (chore.isPendingAcceptance) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppTheme.accentOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                        child: Text('Awaiting', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.accentOrange)),
                                      ),
                                    ] else if (chore.isAssignmentDeclined) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppTheme.accentRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                        child: Text('Declined', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.accentRed)),
                                      ),
                                    ],
                                    if (chore.recurrence != null) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.repeat_rounded, size: 13, color: AppTheme.accentBlue),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.onDismissed != null) {
      return Dismissible(
        key: ValueKey(chore.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => widget.onDismissed!(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: AppTheme.accentRed, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        child: card,
      );
    }

    return card;
  }
}
