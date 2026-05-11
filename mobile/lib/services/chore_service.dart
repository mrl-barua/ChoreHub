import '../models/chore.dart';
import '../models/chore_comment.dart';
import '../models/chore_history.dart';
import 'api_client.dart';

/// Wraps the chore-completion API response. The server returns a
/// `progression` field on the *first* successful completion; idempotent
/// retries omit it. We surface it here so the caller can decide whether to
/// trigger the level-up takeover.
class ChoreCompletionResult {
  final bool success;
  final ChoreProgressionAward? progression;
  const ChoreCompletionResult({required this.success, this.progression});

  factory ChoreCompletionResult.fromJson(Map<String, dynamic> json) {
    final progressionRaw = json['progression'];
    return ChoreCompletionResult(
      success: json['success'] as bool? ?? true,
      progression: progressionRaw is Map<String, dynamic>
          ? ChoreProgressionAward.fromJson(progressionRaw)
          : (progressionRaw is Map
              ? ChoreProgressionAward.fromJson(
                  Map<String, dynamic>.from(progressionRaw),
                )
              : null),
    );
  }
}

/// Progression award returned by the chore-completion endpoint when XP was
/// actually granted (i.e. the chore transitioned from non-done to done in
/// this request).
class ChoreProgressionAward {
  final int xpAwarded;
  final bool leveledUp;
  final int? newLevel;
  final List<String> unlocksGained;
  final bool streakIncremented;
  final List<String> badgesEarned;

  const ChoreProgressionAward({
    required this.xpAwarded,
    required this.leveledUp,
    required this.newLevel,
    required this.unlocksGained,
    required this.streakIncremented,
    required this.badgesEarned,
  });

  factory ChoreProgressionAward.fromJson(Map<String, dynamic> json) {
    final unlocksRaw = json['unlocksGained'] ?? json['unlocks'];
    final badgesRaw = json['badgesEarned'] ?? json['badges'];
    return ChoreProgressionAward(
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
      leveledUp: json['leveledUp'] as bool? ?? false,
      newLevel: (json['newLevel'] as num?)?.toInt(),
      unlocksGained: unlocksRaw is List
          ? unlocksRaw.map((u) => u.toString()).toList()
          : const <String>[],
      streakIncremented: json['streakIncremented'] as bool? ?? false,
      badgesEarned: badgesRaw is List
          ? badgesRaw.map((b) => b.toString()).toList()
          : const <String>[],
    );
  }
}

class ChoreService {
  final ApiClient _apiClient;
  ChoreService(this._apiClient);

  Future<List<Chore>> loadChores(String familyId) async {
    final response = await _apiClient.dio.get(
      '/chores',
      queryParameters: {'familyId': familyId},
    );
    return (response.data as List)
        .map((c) => Chore.fromJson(c))
        .toList();
  }

  Future<Chore> getChoreById(String choreId) async {
    final response = await _apiClient.dio.get('/chores/$choreId');
    return Chore.fromJson(response.data);
  }

  Future<Map<String, int>> loadStats(String familyId) async {
    final response = await _apiClient.dio.get(
      '/chores/stats',
      queryParameters: {'familyId': familyId},
    );
    return Map<String, int>.from(response.data);
  }

  Future<void> createChore({
    required String familyId,
    required String title,
    required String category,
    String? timeSlot,
    String? assignedTo,
    String? dueDate,
    String priority = 'medium',
    String? description,
    String? recurrence,
  }) async {
    await _apiClient.dio.post('/chores', data: {
      'familyId': familyId,
      'title': title,
      'category': category,
      'timeSlot': timeSlot,
      'assignedTo': assignedTo,
      'dueDate': dueDate,
      'priority': priority,
      'description': description,
      'recurrence': recurrence,
    });
  }

  Future<void> updateChore(Chore chore) async {
    await _apiClient.dio.patch('/chores/${chore.id}', data: {
      'title': chore.title,
      'category': chore.category,
      'timeSlot': chore.timeSlot,
      'assignedTo': chore.assignedTo,
      'status': chore.status,
      'dueDate': chore.dueDate,
      'priority': chore.priority,
      'description': chore.description,
      'recurrence': chore.recurrence,
    });
  }

  /// Toggle a chore's status between done and pending. When transitioning to
  /// done the server may return a `progression` block; we surface it via
  /// [ChoreCompletionResult] for the caller to drive the level-up modal.
  Future<ChoreCompletionResult> toggleStatus(String choreId, bool isDone) async {
    final newStatus = isDone ? 'pending' : 'done';
    final response = await _apiClient.dio.patch(
      '/chores/$choreId',
      data: {'status': newStatus},
    );
    final data = response.data;
    if (data is Map) {
      return ChoreCompletionResult.fromJson(Map<String, dynamic>.from(data));
    }
    return const ChoreCompletionResult(success: true);
  }

  Future<void> deleteChore(String id) async {
    await _apiClient.dio.delete('/chores/$id');
  }

  Future<void> respondToAssignment(
    String choreId,
    String assignmentStatus,
  ) async {
    await _apiClient.dio.patch(
      '/chores/$choreId/assignment',
      data: {'assignmentStatus': assignmentStatus},
    );
  }

  /// Complete a chore. The first successful completion includes a
  /// `progression` award block in the response; idempotent retries return
  /// only `{success: true}`. Both shapes are normalized into
  /// [ChoreCompletionResult].
  Future<ChoreCompletionResult> completeChore(
    String choreId, {
    String? note,
  }) async {
    final response = await _apiClient.dio.post(
      '/chores/$choreId/complete',
      data: {'note': note},
    );
    final data = response.data;
    if (data is Map) {
      return ChoreCompletionResult.fromJson(Map<String, dynamic>.from(data));
    }
    return const ChoreCompletionResult(success: true);
  }

  Future<void> reassignChore(String choreId, String userId) async {
    await _apiClient.dio.patch(
      '/chores/$choreId',
      data: {'assignedTo': userId},
    );
  }

  Future<List<ChoreHistory>> loadHistory(String choreId) async {
    final response = await _apiClient.dio.get('/chores/$choreId/history');
    return (response.data as List)
        .map((h) => ChoreHistory.fromJson(h))
        .toList();
  }

  Future<List<ChoreHistory>> loadFamilyHistory(
    String familyId, {
    int limit = 10,
  }) async {
    final response = await _apiClient.dio.get(
      '/chores/history',
      queryParameters: {'familyId': familyId, 'limit': limit},
    );
    return (response.data as List)
        .map((h) => ChoreHistory.fromJson(h))
        .toList();
  }

  Future<List<ChoreComment>> loadComments(String choreId) async {
    final response = await _apiClient.dio.get('/chores/$choreId/comments');
    return (response.data as List)
        .map((c) => ChoreComment.fromJson(c))
        .toList();
  }

  Future<ChoreComment> postComment(String choreId, String text) async {
    final response = await _apiClient.dio.post(
      '/chores/$choreId/comments',
      data: {'text': text},
    );
    return ChoreComment.fromJson(response.data);
  }

  Future<Map<String, dynamic>> loadAnalytics(String familyId) async {
    final response = await _apiClient.dio.get(
      '/chores/analytics',
      queryParameters: {'familyId': familyId},
    );
    return response.data as Map<String, dynamic>;
  }
}
