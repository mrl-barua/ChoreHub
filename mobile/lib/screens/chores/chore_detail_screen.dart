import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../constants/swap_request_constants.dart';
import '../../models/chore_comment.dart';
import '../../models/chore_history.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/progression_provider.dart';
import '../../providers/swap_request_provider.dart';
import '../../services/api_client.dart';
import '../../services/chore_service.dart';
import '../../services/feedback_service.dart';
import '../../utils/category_helpers.dart';
import '../../utils/date_helpers.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/polished_bottom_sheet.dart';
import '../../widgets/skeleton_loader.dart';

class ChoreDetailScreen extends ConsumerStatefulWidget {
  final String choreId;
  const ChoreDetailScreen({super.key, required this.choreId});

  @override
  ConsumerState<ChoreDetailScreen> createState() => _ChoreDetailScreenState();
}

class _ChoreDetailScreenState extends ConsumerState<ChoreDetailScreen> {
  final ChoreService _choreService = ChoreService(ApiClient());

  List<ChoreHistory> _history = [];
  List<ChoreComment> _comments = [];
  final _commentController = TextEditingController();
  bool _showConfetti = false;
  bool _isSwapLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadComments();
    Future.microtask(() => ref.read(swapRequestProvider.notifier).loadForChore(widget.choreId));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _choreService.loadComments(widget.choreId);
      if (mounted) setState(() => _comments = comments);
    } catch (e) {
      debugPrint('Failed to load comments: $e');
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    try {
      final comment = await _choreService.postComment(widget.choreId, text);
      if (mounted) {
        setState(() => _comments = [..._comments, comment]);
        AppFeedback.success(context, 'Comment added');
      }
    } catch (e) {
      debugPrint('Failed to post comment: $e');
      if (mounted) {
        AppFeedback.error(context, 'Failed to post comment');
      }
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _choreService.loadHistory(widget.choreId);
      if (mounted) setState(() => _history = history);
    } catch (e) {
      debugPrint('Failed to load history: $e');
    }
  }

  void _showCompletionDialog() {
    final noteController = TextEditingController();

    showPolishedBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.celebration_rounded, color: AppTheme.accentOrange, size: 24),
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
                    final result = await _choreService.completeChore(
                      widget.choreId,
                      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                    );
                    await ref.read(choreProvider.notifier).loadChores();
                    await _loadHistory();
                    // Refresh progression so XP / level / streak surfaces
                    // reflect the new state on dashboard + profile.
                    await ref.read(progressionProvider.notifier).load();
                    if (mounted) {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _showConfetti = true;
                      });
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) {
                          setState(() {
                            _showConfetti = false;
                          });
                        }
                      });
                    }
                    // If the server reports a level-up, fire the global
                    // takeover via the progression provider. The
                    // LevelUpListener mounted in the shell handles it.
                    final award = result.progression;
                    if (award != null && award.leveledUp && award.newLevel != null) {
                      ref.read(progressionProvider.notifier).triggerLevelUp(
                            LevelUpEvent(
                              newLevel: award.newLevel!,
                              unlocksGained: award.unlocksGained,
                              xpAwarded: award.xpAwarded,
                            ),
                          );
                    }
                  } catch (e) {
                    if (mounted) {
                      AppFeedback.error(context, 'Failed to complete');
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

  void _showSwapRequestSheet(String choreId) {
    final members = ref.read(familyProvider).members;
    final currentUser = ref.read(authProvider).user;
    String? selectedUserId; // null = open request
    final noteController = TextEditingController();

    showPolishedBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: AppTheme.accentBlue, size: 24),
                  SizedBox(width: 10),
                  Text('Request Swap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: selectedUserId,
                decoration: const InputDecoration(labelText: 'Swap with'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Anyone — open request')),
                  ...members
                      .where((m) => m.userId != currentUser?.id)
                      .map((m) => DropdownMenuItem(
                            value: m.userId,
                            child: Text(m.user?.displayName ?? m.userId),
                          )),
                ],
                onChanged: (val) => setSheetState(() => selectedUserId = val),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(hintText: 'Add a note (optional)'),
                maxLength: 200,
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: LoadingButton(
                  label: 'Send Request',
                  isLoading: _isSwapLoading,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (mounted) {
                      setState(() {
                        _isSwapLoading = true;
                      });
                    }
                    try {
                      await ref.read(swapRequestProvider.notifier).createSwap(
                            choreId: choreId,
                            toUserId: selectedUserId,
                            message: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                          );
                      if (mounted) AppFeedback.success(context, 'Swap request sent');
                    } catch (e) {
                      if (mounted) AppFeedback.error(context, 'Failed to send swap request');
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isSwapLoading = false;
                        });
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReassignDialog() {
    final members = ref.read(familyProvider).members;

    showPolishedBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                trailing: ref.read(choreProvider).allChores.where((c) => c.id == widget.choreId).firstOrNull?.assignedTo == m.userId
                    ? const Icon(Icons.check_rounded, color: AppTheme.accentGreen) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _choreService.reassignChore(widget.choreId, m.userId);
                    await ref.read(choreProvider.notifier).loadChores();
                    await _loadHistory();
                  } catch (e) {
                    debugPrint('Failed to reassign chore: $e');
                    if (mounted) {
                      AppFeedback.error(context, 'Failed to reassign chore');
                    }
                  }
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  String _assignmentStatusLabel(String status) {
    switch (status) {
      case 'pending_acceptance': return 'Awaiting Acceptance';
      case 'accepted': return 'Accepted';
      case 'declined': return 'Declined';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final currentUser = ref.watch(authProvider).user;
    final choreState = ref.watch(choreProvider);
    final swapState = ref.watch(swapRequestProvider);

    final choreList = choreState.allChores.isNotEmpty ? choreState.allChores : choreState.chores;
    final chore = choreList.where((c) => c.id == widget.choreId).firstOrNull;

    if (choreState.isLoading && chore == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              SkeletonCard(height: 180),
              SkeletonLoader(itemCount: 3),
            ],
          ),
        ),
      );
    }
    if (chore == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Chore not found')));
    }
    final assignee = family.members.where((m) => m.userId == chore.assignedTo).firstOrNull;
    final categoryColor = AppTheme.categoryColors[chore.category] ?? Colors.grey;
    final isAssignee = currentUser != null && chore.assignedTo == currentUser.id;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (currentUser != null && chore.assignedTo == currentUser.id && !chore.isDone)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded, color: AppTheme.accentBlue),
              tooltip: 'Request swap',
              onPressed: () => _showSwapRequestSheet(chore.id),
            ),
          Builder(builder: (ctx) {
            final outgoing = swapState.outgoing
                .where((s) =>
                    s.choreId == chore.id &&
                    s.status == SwapRequestStatus.pending)
                .toList();
            if (outgoing.isEmpty) return const SizedBox.shrink();
            return TextButton.icon(
              icon: const Icon(Icons.pending_rounded, size: 16),
              label: const Text('Swap pending', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentOrange),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Cancel swap request?'),
                    content: const Text('The recipient will be notified.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Keep'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: Text('Cancel request', style: TextStyle(color: AppTheme.accentRed)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await ref.read(swapRequestProvider.notifier).cancel(outgoing.first.id);
                    if (ctx.mounted) AppFeedback.success(ctx, 'Swap request cancelled');
                  } catch (e) {
                    if (ctx.mounted) AppFeedback.error(ctx, 'Failed to cancel');
                  }
                }
              },
            );
          }),
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
                ref.read(choreProvider.notifier).softDelete(chore.id);
                AppFeedback.success(
                  context,
                  'Chore deleted',
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => ref.read(choreProvider.notifier).cancelSoftDelete(chore.id),
                  ),
                  duration: const Duration(seconds: 4),
                );
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(color: categoryColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(CategoryHelpers.iconFor(chore.category), color: categoryColor, size: 26),
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
                          _Badge(label: '${chore.priority[0].toUpperCase()}${chore.priority.substring(1)}', color: CategoryHelpers.priorityColor(chore.priority)),
                          if (chore.assignedTo != null && chore.assignmentStatus != 'unassigned')
                            _Badge(label: _assignmentStatusLabel(chore.assignmentStatus), color: CategoryHelpers.assignmentStatusColor(chore.assignmentStatus)),
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
                        const Icon(Icons.notes_rounded, size: 20, color: AppTheme.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(chore.description!, style: const TextStyle(fontSize: 15, height: 1.5))),
                      ],
                    ),
                  ),
                ),
              ],

              if (isAssignee && chore.isPendingAcceptance) ...[
                const SizedBox(height: 20),
                Card(
                  color: AppTheme.accentOrange.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(children: [
                          const Icon(Icons.assignment_ind_rounded, color: AppTheme.accentOrange, size: 22),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('You have been assigned this chore', style: TextStyle(fontWeight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(child: OutlinedButton(
                            onPressed: () async { await ref.read(choreProvider.notifier).respondToAssignment(chore.id, 'declined'); _loadHistory(); },
                            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRed),
                            child: const Text('Decline'),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: FilledButton(
                            onPressed: () async { await ref.read(choreProvider.notifier).respondToAssignment(chore.id, 'accepted'); _loadHistory(); },
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentGreen),
                            child: const Text('Accept'),
                          )),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],

              Builder(builder: (ctx) {
                final incoming = swapState.byChoreId[chore.id] ?? [];
                final myIncoming = incoming
                    .where((s) =>
                        s.status == SwapRequestStatus.pending &&
                        (s.toUserId == currentUser?.id || s.toUserId == null) &&
                        s.fromUserId != currentUser?.id)
                    .toList();
                if (myIncoming.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: myIncoming.map((swap) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Card(
                        color: AppTheme.accentBlue.withValues(alpha: 0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.swap_horiz_rounded, color: AppTheme.accentBlue, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${swap.fromUser?.displayName ?? 'Someone'} wants to swap this chore with you',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ]),
                              if (swap.message != null && swap.message!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('"${swap.message}"',
                                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
                              ],
                              const SizedBox(height: 14),
                              Row(children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      try {
                                        await ref.read(swapRequestProvider.notifier).respond(
                                              swap.id, SwapRequestStatus.declined);
                                        if (context.mounted) AppFeedback.success(context, 'Swap declined');
                                      } catch (e) {
                                        if (context.mounted) AppFeedback.error(context, 'Failed to decline');
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRed),
                                    child: const Text('Decline'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () async {
                                      try {
                                        await ref.read(swapRequestProvider.notifier).respond(
                                              swap.id, SwapRequestStatus.accepted);
                                        if (context.mounted) AppFeedback.success(context, 'Swap accepted!');
                                      } catch (e) {
                                        if (context.mounted) AppFeedback.error(context, 'Failed to accept');
                                      }
                                    },
                                    style: FilledButton.styleFrom(backgroundColor: AppTheme.accentBlue),
                                    child: const Text('Accept'),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),

              const SizedBox(height: 20),

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

              if (_history.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...List.generate(_history.length, (i) {
                  final h = _history[i];
                  final color = CategoryHelpers.historyActionColor(h.action);
                  final isLast = i == _history.length - 1;
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
                                child: Icon(CategoryHelpers.historyActionIcon(h.action), size: 14, color: color),
                              ),
                              if (!isLast) Expanded(child: Container(width: 2, color: Theme.of(context).dividerColor)),
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
                                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                  children: [
                                    TextSpan(text: h.userName ?? 'Someone', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    TextSpan(text: ' $actionLabel'),
                                  ],
                                )),
                                if (note != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('"$note"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
                                  ),
                                const SizedBox(height: 2),
                                Text(DateHelpers.timeAgo(h.createdAt), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
                    await ref.read(choreProvider.notifier).loadChores();
                    await _loadHistory();
                  },
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Mark as Pending'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.accentOrange),
                ),

              const SizedBox(height: 32),
              const Text('Comments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (_comments.isEmpty)
                const Text('No comments yet', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ..._comments.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
                      child: Text((c.userName ?? '?')[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(c.userName ?? 'Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(DateHelpers.timeAgo(c.createdAt), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        ]),
                        const SizedBox(height: 2),
                        Text(c.text, style: const TextStyle(fontSize: 13)),
                      ],
                    )),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _postComment,
                  icon: const Icon(Icons.send_rounded, color: AppTheme.accent, size: 20),
                ),
              ]),
            ],
          ),

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
                        child: const Icon(Icons.celebration_rounded, size: 120, color: AppTheme.accentOrange),
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
      leading: Icon(icon, size: 20, color: iconColor ?? AppTheme.textSecondary),
      title: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}
