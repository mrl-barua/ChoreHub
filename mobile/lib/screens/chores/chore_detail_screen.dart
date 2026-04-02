import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/chore.dart';
import '../../models/chore_history.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../services/api_client.dart';

class ChoreDetailScreen extends ConsumerStatefulWidget {
  final String choreId;
  const ChoreDetailScreen({super.key, required this.choreId});

  @override
  ConsumerState<ChoreDetailScreen> createState() => _ChoreDetailScreenState();
}

class _ChoreDetailScreenState extends ConsumerState<ChoreDetailScreen> {
  Chore? _chore;
  List<ChoreHistory> _history = [];
  bool _isLoading = true;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _loadChore();
    _loadHistory();
  }

  Future<void> _loadChore() async {
    final chores = ref.read(choreProvider).chores;
    final chore = chores.where((c) => c.id == widget.choreId).firstOrNull;
    if (mounted) setState(() { _chore = chore; _isLoading = false; });
  }

  Future<void> _loadHistory() async {
    try {
      final response = await ApiClient().dio.get('/chores/${widget.choreId}/history');
      final history = (response.data as List).map((h) => ChoreHistory.fromJson(h)).toList();
      if (mounted) setState(() => _history = history);
    } catch (_) {}
  }

  void _showCompletionDialog() {
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.celebration_rounded, color: Color(0xFFFF9100), size: 24),
                SizedBox(width: 10),
                Text('Complete Chore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(hintText: 'Add a note (optional)'),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await ApiClient().dio.post('/chores/${widget.choreId}/complete', data: {
                      'note': noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                    });
                    await ref.read(choreProvider.notifier).loadChores();
                    await _loadChore();
                    await _loadHistory();
                    if (mounted) {
                      setState(() => _showConfetti = true);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _showConfetti = false);
                      });
                    }
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to complete')));
                    }
                  }
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Mark as Done'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.accentGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReassignDialog() {
    final members = ref.read(familyProvider).members;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reassign Chore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...members.map((m) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
                  child: Text(
                    (m.user?.displayName ?? '?')[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                title: Text(m.user?.displayName ?? 'Unknown'),
                subtitle: Text('@${m.user?.username ?? ''}'),
                trailing: _chore?.assignedTo == m.userId ? const Icon(Icons.check_rounded, color: AppTheme.accentGreen) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ApiClient().dio.patch('/chores/${widget.choreId}', data: {'assignedTo': m.userId});
                    await ref.read(choreProvider.notifier).loadChores();
                    await _loadChore();
                    await _loadHistory();
                  } catch (_) {}
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Color get _priorityColor {
    switch (_chore?.priority) {
      case 'high': return AppTheme.priorityHigh;
      case 'low': return AppTheme.priorityLow;
      default: return AppTheme.priorityMedium;
    }
  }

  Color _assignmentStatusColor(String status) {
    switch (status) {
      case 'pending_acceptance': return Colors.orange;
      case 'accepted': return AppTheme.accentGreen;
      case 'declined': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _assignmentStatusLabel(String status) {
    switch (status) {
      case 'pending_acceptance': return 'Awaiting Acceptance';
      case 'accepted': return 'Accepted';
      case 'declined': return 'Declined';
      default: return '';
    }
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

  IconData _historyIcon(String action) {
    if (action.startsWith('completed')) return Icons.check_circle_rounded;
    switch (action) {
      case 'created': return Icons.add_circle_outline_rounded;
      case 'assigned': return Icons.person_add_rounded;
      case 'accepted': return Icons.thumb_up_rounded;
      case 'declined': return Icons.thumb_down_rounded;
      case 'reopened': return Icons.replay_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  Color _historyColor(String action) {
    if (action.startsWith('completed')) return AppTheme.accentGreen;
    switch (action) {
      case 'created': return AppTheme.accentBlue;
      case 'assigned': return AppTheme.accent;
      case 'accepted': return AppTheme.accentGreen;
      case 'declined': return AppTheme.accentRed;
      case 'reopened': return AppTheme.accentOrange;
      default: return Colors.grey;
    }
  }

  String _timeAgo(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.month}/${date.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final currentUser = ref.watch(authProvider).user;

    if (_isLoading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (_chore == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Chore not found')));

    final chore = _chore!;
    final assignee = family.members.where((m) => m.userId == chore.assignedTo).firstOrNull;
    final categoryColor = AppTheme.categoryColors[chore.category] ?? Colors.grey;
    final isAssignee = currentUser != null && chore.assignedTo == currentUser.id;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Reassign',
            onPressed: _showReassignDialog,
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              await context.push('/chores/${chore.id}/edit');
              await ref.read(choreProvider.notifier).loadChores();
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
                    TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('Delete', style: TextStyle(color: AppTheme.accentRed))),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await ref.read(choreProvider.notifier).deleteChore(chore.id);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(color: categoryColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(_categoryIcon(chore.category), color: categoryColor, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(chore.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          _Badge(label: chore.isDone ? 'Done' : 'Pending', color: chore.isDone ? AppTheme.accentGreen : AppTheme.accentOrange),
                          _Badge(label: '${chore.priority[0].toUpperCase()}${chore.priority.substring(1)}', color: _priorityColor),
                          if (chore.assignedTo != null && chore.assignmentStatus != 'unassigned')
                            _Badge(label: _assignmentStatusLabel(chore.assignmentStatus), color: _assignmentStatusColor(chore.assignmentStatus)),
                          if (chore.recurrence != null)
                            _Badge(label: '${chore.recurrence![0].toUpperCase()}${chore.recurrence!.substring(1)}', color: AppTheme.accentBlue, icon: Icons.repeat_rounded),
                        ]),
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

              // Assignment accept/decline
              if (isAssignee && chore.isPendingAcceptance) ...[
                const SizedBox(height: 20),
                Card(
                  color: Colors.orange.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(children: [
                          const Icon(Icons.assignment_ind_rounded, color: Colors.orange, size: 22),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('You have been assigned this chore', style: TextStyle(fontWeight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(child: OutlinedButton(
                            onPressed: () async { await ref.read(choreProvider.notifier).respondToAssignment(chore.id, 'declined'); _loadChore(); _loadHistory(); },
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Decline'),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: FilledButton(
                            onPressed: () async { await ref.read(choreProvider.notifier).respondToAssignment(chore.id, 'accepted'); _loadChore(); _loadHistory(); },
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentGreen),
                            child: const Text('Accept'),
                          )),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Details
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(children: [
                    _DetailTile(icon: Icons.category_rounded, label: 'Category', value: chore.category[0].toUpperCase() + chore.category.substring(1), iconColor: categoryColor),
                    if (chore.timeSlot != null) _DetailTile(icon: Icons.schedule_rounded, label: 'Time Slot', value: chore.timeSlot![0].toUpperCase() + chore.timeSlot!.substring(1)),
                    _DetailTile(icon: Icons.person_outline_rounded, label: 'Assigned To', value: assignee?.user?.displayName ?? 'Unassigned'),
                    if (chore.dueDate != null) _DetailTile(icon: Icons.calendar_today_rounded, label: 'Due Date', value: chore.dueDate!),
                    if (chore.recurrence != null) _DetailTile(icon: Icons.repeat_rounded, label: 'Repeats', value: chore.recurrence![0].toUpperCase() + chore.recurrence!.substring(1)),
                  ]),
                ),
              ),

              // History timeline
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...List.generate(_history.length, (i) {
                  final h = _history[i];
                  final color = _historyColor(h.action);
                  final isLast = i == _history.length - 1;
                  // Parse note from "completed: note text"
                  String actionLabel = h.actionLabel;
                  String? note;
                  if (h.action.startsWith('completed: ')) {
                    actionLabel = 'completed';
                    note = h.action.substring(11);
                  }

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 32,
                          child: Column(
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                                child: Icon(_historyIcon(h.action), size: 14, color: color),
                              ),
                              if (!isLast) Expanded(child: Container(width: 2, color: Colors.grey.shade800)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(text: TextSpan(
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                                  children: [
                                    TextSpan(text: h.userName ?? 'Someone', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    TextSpan(text: ' $actionLabel'),
                                  ],
                                )),
                                if (note != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('"$note"', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade500)),
                                  ),
                                const SizedBox(height: 2),
                                Text(_timeAgo(h.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 32),
              if (!chore.isDone)
                FilledButton.icon(
                  onPressed: _showCompletionDialog,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Complete Chore'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.accentGreen),
                )
              else
                FilledButton.icon(
                  onPressed: () async {
                    await ref.read(choreProvider.notifier).toggleStatus(chore.id);
                    await _loadChore();
                    await _loadHistory();
                  },
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Mark as Pending'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.accentOrange),
                ),
            ],
          ),

          // Confetti overlay
          if (_showConfetti)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) => Opacity(
                      opacity: value > 0.7 ? (1 - value) * 3.33 : 1,
                      child: Transform.scale(
                        scale: 0.5 + value * 0.5,
                        child: const Icon(Icons.celebration_rounded, size: 120, color: Color(0xFFFF9100)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
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
