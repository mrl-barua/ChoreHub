import 'package:flutter/material.dart';
import '../config/theme.dart';

class ChoreFilterBar extends StatelessWidget {
  final String currentFilter;
  final ValueChanged<String> onFilterChanged;

  const ChoreFilterBar({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(label: 'All', value: 'all', current: currentFilter, onSelected: onFilterChanged, icon: Icons.check_rounded),
          const SizedBox(width: 10),
          _FilterChip(label: 'Pending', value: 'pending', current: currentFilter, onSelected: onFilterChanged, icon: Icons.schedule_rounded),
          const SizedBox(width: 10),
          _FilterChip(label: 'Done', value: 'done', current: currentFilter, onSelected: onFilterChanged, icon: Icons.check_circle_rounded),
          const SizedBox(width: 10),
          _FilterChip(label: 'Overdue', value: 'overdue', current: currentFilter, onSelected: onFilterChanged, icon: Icons.warning_rounded),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onSelected;
  final IconData icon;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;

    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppTheme.accent : Theme.of(context).dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.accent : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
