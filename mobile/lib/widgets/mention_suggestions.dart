import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/family_member.dart';

class MentionSuggestions extends StatelessWidget {
  final List<FamilyMember> suggestions;
  final void Function(FamilyMember member) onSelected;

  const MentionSuggestions({super.key, required this.suggestions, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final member = suggestions[index];
          final name = member.user?.displayName ?? 'Unknown';
          final username = member.user?.username ?? '';

          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
              child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accent)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('@$username', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            onTap: () => onSelected(member),
          );
        },
      ),
    );
  }
}
