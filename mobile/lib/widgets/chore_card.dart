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

class _ChoreCardState extends State<ChoreCard> with SingleTickerProviderStateMixin {
  late final AnimationController _checkController;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkScale = Tween(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  Color get _categoryColor =>
      AppTheme.categoryColors[widget.chore.category] ?? AppTheme.categoryColors['other']!;

  Color get _priorityColor {
    switch (widget.chore.priority) {
      case 'high':
        return AppTheme.priorityHigh;
      case 'low':
        return AppTheme.priorityLow;
      default:
        return AppTheme.priorityMedium;
    }
  }

  IconData _categoryIcon() {
    switch (widget.chore.category) {
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'cooking':
        return Icons.restaurant_rounded;
      case 'dishwashing':
        return Icons.local_laundry_service_rounded;
      case 'laundry':
        return Icons.dry_cleaning_rounded;
      case 'gardening':
        return Icons.grass_rounded;
      case 'shopping':
        return Icons.shopping_cart_rounded;
      default:
        return Icons.task_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chore = widget.chore;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Status toggle with animation
              ScaleTransition(
                scale: _checkScale,
                child: GestureDetector(
                  onTap: () async {
                    await _checkController.forward();
                    widget.onToggle();
                    await _checkController.reverse();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: chore.isDone ? AppTheme.accentGreen : Colors.transparent,
                      border: Border.all(
                        color: chore.isDone ? AppTheme.accentGreen : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: chore.isDone
                        ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Category icon with colored background
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_categoryIcon(), size: 20, color: _categoryColor),
              ),
              const SizedBox(width: 14),
              // Title + metadata
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
                        color: chore.isDone
                            ? Colors.grey
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (widget.assigneeName != null) ...[
                          Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            widget.assigneeName!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (chore.timeSlot != null) ...[
                          Icon(Icons.schedule_rounded, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            chore.timeSlot![0].toUpperCase() + chore.timeSlot!.substring(1),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (chore.recurrence != null) ...[
                          Icon(Icons.repeat_rounded, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            chore.recurrence![0].toUpperCase() + chore.recurrence!.substring(1),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (chore.isPendingAcceptance)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Awaiting', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange)),
                          )
                        else if (chore.isAssignmentDeclined)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Declined', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Priority dot + due date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _priorityColor,
                    ),
                  ),
                  if (chore.dueDate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(chore.dueDate!),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ],
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
          decoration: BoxDecoration(
            color: AppTheme.accentRed,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        child: card,
      );
    }

    return card;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      if (diff == -1) return 'Yesterday';
      return '${date.month}/${date.day}';
    } catch (_) {
      return dateStr;
    }
  }
}
