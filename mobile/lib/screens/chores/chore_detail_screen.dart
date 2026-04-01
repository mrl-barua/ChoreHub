import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../repositories/chore_repository.dart';
import '../../models/chore.dart';

class ChoreDetailScreen extends ConsumerStatefulWidget {
  final String choreId;
  const ChoreDetailScreen({super.key, required this.choreId});

  @override
  ConsumerState<ChoreDetailScreen> createState() => _ChoreDetailScreenState();
}

class _ChoreDetailScreenState extends ConsumerState<ChoreDetailScreen> {
  Chore? _chore;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChore();
  }

  Future<void> _loadChore() async {
    final chore = await ChoreRepository().getChoreById(widget.choreId);
    setState(() {
      _chore = chore;
      _isLoading = false;
    });
  }

  Color get _priorityColor {
    switch (_chore?.priority) {
      case 'high':
        return AppTheme.priorityHigh;
      case 'low':
        return AppTheme.priorityLow;
      default:
        return AppTheme.priorityMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);

    if (_isLoading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_chore == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Chore not found')));
    }

    final chore = _chore!;
    final assignee = family.members.where((m) => m.userId == chore.assignedTo).firstOrNull;
    final categoryColor = AppTheme.categoryColors[chore.category] ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              await context.push('/chores/${chore.id}/edit');
              _loadChore();
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: AppTheme.accentRed),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Delete Chore'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text('Delete', style: TextStyle(color: AppTheme.accentRed)),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await ref.read(choreProvider.notifier).deleteChore(chore.id);
                if (mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_categoryIcon(chore.category), color: categoryColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chore.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: chore.isDone ? AppTheme.accentGreen.withValues(alpha: 0.12) : AppTheme.accentOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            chore.isDone ? 'Done' : 'Pending',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: chore.isDone ? AppTheme.accentGreen : AppTheme.accentOrange),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _priorityColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${chore.priority[0].toUpperCase()}${chore.priority.substring(1)} Priority',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _priorityColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (chore.description != null && chore.description!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded, size: 20, color: Colors.grey.shade500),
                    const SizedBox(width: 12),
                    Expanded(child: Text(chore.description!, style: const TextStyle(fontSize: 15, height: 1.5))),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Details cards
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _DetailTile(icon: Icons.category_rounded, label: 'Category', value: chore.category[0].toUpperCase() + chore.category.substring(1), iconColor: categoryColor),
                  if (chore.timeSlot != null)
                    _DetailTile(icon: Icons.schedule_rounded, label: 'Time Slot', value: chore.timeSlot![0].toUpperCase() + chore.timeSlot!.substring(1)),
                  _DetailTile(icon: Icons.person_outline_rounded, label: 'Assigned To', value: assignee?.user?.displayName ?? 'Unassigned'),
                  if (chore.dueDate != null)
                    _DetailTile(icon: Icons.calendar_today_rounded, label: 'Due Date', value: chore.dueDate!),
                  if (chore.recurrence != null)
                    _DetailTile(icon: Icons.repeat_rounded, label: 'Repeats', value: chore.recurrence![0].toUpperCase() + chore.recurrence!.substring(1)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(choreProvider.notifier).toggleStatus(chore.id);
              await _loadChore();
            },
            icon: Icon(chore.isDone ? Icons.undo_rounded : Icons.check_rounded),
            label: Text(chore.isDone ? 'Mark as Pending' : 'Mark as Done'),
            style: FilledButton.styleFrom(
              backgroundColor: chore.isDone ? AppTheme.accentOrange : AppTheme.accentGreen,
            ),
          ),
        ],
      ),
    );
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
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const _DetailTile({required this.icon, required this.label, required this.value, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: iconColor ?? Colors.grey.shade500),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      trailing: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}
