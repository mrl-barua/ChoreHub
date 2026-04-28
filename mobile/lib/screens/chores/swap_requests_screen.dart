import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/swap_request_constants.dart';
import '../../providers/swap_request_provider.dart';
import '../../services/feedback_service.dart';
import '../../widgets/swap_request_card.dart';

class SwapRequestsScreen extends ConsumerWidget {
  const SwapRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swapState = ref.watch(swapRequestProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Swap Requests'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Incoming'),
              Tab(text: 'Outgoing'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Incoming tab
            _SwapList(
              swaps: swapState.incoming,
              isLoading: swapState.isLoading,
              emptyMessage: 'No incoming swap requests',
              onRefresh: () => ref.read(swapRequestProvider.notifier).loadAll(),
              onAccept: (id) async {
                try {
                  await ref.read(swapRequestProvider.notifier).respond(id, SwapRequestStatus.accepted);
                  if (context.mounted) AppFeedback.success(context, 'Swap accepted!');
                } catch (e) {
                  if (context.mounted) AppFeedback.error(context, 'Failed to accept');
                }
              },
              onDecline: (id) async {
                try {
                  await ref.read(swapRequestProvider.notifier).respond(id, SwapRequestStatus.declined);
                  if (context.mounted) AppFeedback.success(context, 'Swap declined');
                } catch (e) {
                  if (context.mounted) AppFeedback.error(context, 'Failed to decline');
                }
              },
            ),
            // Outgoing tab
            _SwapList(
              swaps: swapState.outgoing,
              isLoading: swapState.isLoading,
              emptyMessage: 'No outgoing swap requests',
              onRefresh: () => ref.read(swapRequestProvider.notifier).loadAll(),
              onCancel: (id) async {
                try {
                  await ref.read(swapRequestProvider.notifier).cancel(id);
                  if (context.mounted) AppFeedback.success(context, 'Request cancelled');
                } catch (e) {
                  if (context.mounted) AppFeedback.error(context, 'Failed to cancel');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SwapList extends StatelessWidget {
  final List swaps;
  final bool isLoading;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final void Function(String id)? onAccept;
  final void Function(String id)? onDecline;
  final void Function(String id)? onCancel;

  const _SwapList({
    required this.swaps,
    required this.isLoading,
    required this.emptyMessage,
    required this.onRefresh,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (swaps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(emptyMessage, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: swaps.length,
        itemBuilder: (context, index) {
          final swap = swaps[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SwapRequestCard(
              swap: swap,
              onAccept: onAccept != null ? () => onAccept!(swap.id) : null,
              onDecline: onDecline != null ? () => onDecline!(swap.id) : null,
              onCancel: onCancel != null && swap.status == 'pending' ? () => onCancel!(swap.id) : null,
            ),
          );
        },
      ),
    );
  }
}
