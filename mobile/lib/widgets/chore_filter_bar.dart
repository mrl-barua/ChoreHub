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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _FilterChip(label: 'All', value: 'all', current: currentFilter, onSelected: onFilterChanged),
          const SizedBox(width: 8),
          _FilterChip(label: 'Pending', value: 'pending', current: currentFilter, onSelected: onFilterChanged),
          const SizedBox(width: 8),
          _FilterChip(label: 'Done', value: 'done', current: currentFilter, onSelected: onFilterChanged),
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

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
    );
  }
}
