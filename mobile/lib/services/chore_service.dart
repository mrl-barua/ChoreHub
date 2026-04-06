import '../models/chore.dart';
import '../models/chore_comment.dart';
import '../models/chore_history.dart';
import 'api_client.dart';

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

  Future<void> toggleStatus(String choreId, bool isDone) async {
    final newStatus = isDone ? 'pending' : 'done';
    await _apiClient.dio.patch(
      '/chores/$choreId',
      data: {'status': newStatus},
    );
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

  Future<void> completeChore(String choreId, {String? note}) async {
    await _apiClient.dio.post(
      '/chores/$choreId/complete',
      data: {'note': note},
    );
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
