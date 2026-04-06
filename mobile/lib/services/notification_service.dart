import 'api_client.dart';

class NotificationService {
  final ApiClient _apiClient;
  NotificationService(this._apiClient);

  Future<List<dynamic>> loadNotifications({int limit = 50}) async {
    final response = await _apiClient.dio.get(
      '/notifications',
      queryParameters: {'limit': limit},
    );
    return response.data as List;
  }

  Future<int> loadUnreadCount() async {
    final response = await _apiClient.dio.get('/notifications/unread-count');
    return response.data['count'] as int;
  }

  Future<void> markRead(String id) async {
    await _apiClient.dio.patch('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _apiClient.dio.post('/notifications/read-all');
  }
}
