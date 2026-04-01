import 'package:flutter/material.dart';

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
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(label: 'All', value: 'all', current: currentFilter, onSelected: onFilterChanged),
          const SizedBox(width: 8),
          _FilterChip(label: 'Pending', value: 'pending', current: currentFilter, onSelected: onFilterChanged, icon: Icons.schedule_rounded),
          const SizedBox(width: 8),
          _FilterChip(label: 'Done', value: 'done', current: currentFilter, onSelected: onFilterChanged, icon: Icons.check_circle_outline_rounded),
          const SizedBox(width: 8),
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
  final IconData? icon;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        selectedColor: primaryColor,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
        backgroundColor: Theme.of(context).cardColor,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
