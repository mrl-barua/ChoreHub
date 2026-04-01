import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chore')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_chore == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chore')),
        body: const Center(child: Text('Chore not found')),
      );
    }

    final chore = _chore!;
    final assignedMember = family.members.where((m) => m.userId == chore.assignedTo).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chore Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outlined),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Chore'),
                  content: const Text('Are you sure you want to delete this chore?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
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
        padding: const EdgeInsets.all(24),
        children: [
          Text(chore.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          _DetailRow(label: 'Category', value: chore.category[0].toUpperCase() + chore.category.substring(1)),
          if (chore.timeSlot != null)
            _DetailRow(label: 'Time Slot', value: chore.timeSlot![0].toUpperCase() + chore.timeSlot!.substring(1)),
          _DetailRow(label: 'Status', value: chore.isDone ? 'Done' : 'Pending'),
          _DetailRow(label: 'Assigned To', value: assignedMember?.user?.displayName ?? 'Unassigned'),
          if (chore.dueDate != null) _DetailRow(label: 'Due Date', value: chore.dueDate!),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(choreProvider.notifier).toggleStatus(chore.id);
              await _loadChore();
            },
            icon: Icon(chore.isDone ? Icons.undo : Icons.check),
            label: Text(chore.isDone ? 'Mark as Pending' : 'Mark as Done'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
