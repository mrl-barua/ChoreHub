import 'api_client.dart';

class NotificationPreferencesService {
  final _client = ApiClient();

  Future<Map<String, dynamic>> getPreferences() async {
    final res = await _client.dio.get('/notifications/preferences');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> updates) async {
    final res = await _client.dio.patch('/notifications/preferences', data: updates);
    return Map<String, dynamic>.from(res.data as Map);
  }
}
