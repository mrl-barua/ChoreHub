import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/swap_request.dart';
import '../services/swap_request_service.dart';
import '../services/api_client.dart';
import '../services/socket_service.dart';
import '../constants/swap_request_constants.dart';
import 'auth_provider.dart';
import 'chore_provider.dart';

class SwapRequestState {
  final List<SwapRequest> incoming;
  final List<SwapRequest> outgoing;
  final Map<String, List<SwapRequest>> byChoreId; // pending only
  final bool isLoading;
  final String? error;

  const SwapRequestState({
    this.incoming = const [],
    this.outgoing = const [],
    this.byChoreId = const {},
    this.isLoading = false,
    this.error,
  });
}

class SwapRequestNotifier extends Notifier<SwapRequestState> {
  final SwapRequestService _service = SwapRequestService(ApiClient());
  StreamSubscription<Map<String, dynamic>>? _createdSub;
  StreamSubscription<Map<String, dynamic>>? _updatedSub;

  @override
  SwapRequestState build() {
    final auth = ref.watch(authProvider);
    if (auth.user != null) {
      Future.microtask(() => loadAll());
      final socketService = SocketService();
      _createdSub?.cancel();
      _updatedSub?.cancel();
      _createdSub = socketService.onSwapCreated.listen(_handleSwapCreated);
      _updatedSub = socketService.onSwapUpdated.listen(_handleSwapUpdated);
      ref.onDispose(() {
        _createdSub?.cancel();
        _updatedSub?.cancel();
      });
    }
    return const SwapRequestState();
  }

  Future<void> loadAll() async {
    state = SwapRequestState(
      incoming: state.incoming,
      outgoing: state.outgoing,
      byChoreId: state.byChoreId,
      isLoading: true,
    );
    try {
      final results = await Future.wait([
        _service.loadIncoming(),
        _service.loadOutgoing(),
      ]);
      final incoming = results[0];
      final outgoing = results[1];
      // Build byChoreId from pending incoming
      final byChoreId = <String, List<SwapRequest>>{};
      for (final s in incoming) {
        if (s.status == SwapRequestStatus.pending) {
          byChoreId.putIfAbsent(s.choreId, () => []).add(s);
        }
      }
      state = SwapRequestState(
        incoming: incoming,
        outgoing: outgoing,
        byChoreId: byChoreId,
        isLoading: false,
      );
    } catch (e) {
      state = SwapRequestState(
        incoming: state.incoming,
        outgoing: state.outgoing,
        byChoreId: state.byChoreId,
        isLoading: false,
        error: 'Failed to load swap requests',
      );
    }
  }

  Future<void> loadForChore(String choreId) async {
    try {
      final swaps = await _service.loadForChore(choreId);
      final pending = swaps.where((s) => s.status == SwapRequestStatus.pending).toList();
      final updated = Map<String, List<SwapRequest>>.from(state.byChoreId);
      updated[choreId] = pending;
      state = SwapRequestState(
        incoming: state.incoming,
        outgoing: state.outgoing,
        byChoreId: updated,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      debugPrint('[SwapReq] loadForChore failed: $e');
    }
  }

  Future<SwapRequest?> createSwap({
    required String choreId,
    String? toUserId,
    String? message,
  }) async {
    try {
      final swap = await _service.createSwap(
        choreId: choreId,
        toUserId: toUserId,
        message: message,
      );
      await loadAll();
      return swap;
    } catch (e) {
      state = SwapRequestState(
        incoming: state.incoming,
        outgoing: state.outgoing,
        byChoreId: state.byChoreId,
        isLoading: false,
        error: 'Failed to create swap request',
      );
      rethrow;
    }
  }

  Future<void> respond(String id, String status) async {
    try {
      await _service.respond(id, status);
      if (status == SwapRequestStatus.accepted) {
        ref.invalidate(choreProvider);
      }
      await loadAll();
    } catch (e) {
      state = SwapRequestState(
        incoming: state.incoming,
        outgoing: state.outgoing,
        byChoreId: state.byChoreId,
        isLoading: false,
        error: 'Failed to respond to swap request',
      );
      rethrow;
    }
  }

  Future<void> cancel(String id) async {
    await respond(id, SwapRequestStatus.cancelled);
  }

  void _handleSwapCreated(Map<String, dynamic> data) {
    loadAll();
  }

  void _handleSwapUpdated(Map<String, dynamic> data) {
    if (data['status'] == SwapRequestStatus.accepted) {
      ref.invalidate(choreProvider);
    }
    loadAll();
  }
}

final swapRequestProvider = NotifierProvider<SwapRequestNotifier, SwapRequestState>(
  SwapRequestNotifier.new,
);
