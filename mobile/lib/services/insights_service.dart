import '../services/api_client.dart';
import '../models/insights.dart';

class InsightsService {
  final ApiClient _apiClient;
  InsightsService(this._apiClient);

  Future<InsightsData> loadInsights(String familyId) async {
    final tzOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final response = await _apiClient.dio.get(
      '/families/$familyId/insights',
      queryParameters: {'tzOffsetMinutes': tzOffsetMinutes},
    );
    return InsightsData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> rescheduleChore(
    String familyId,
    String choreId,
    int dayOfWeek,
    int hour,
  ) async {
    await _apiClient.dio.patch(
      '/families/$familyId/chores/$choreId/reschedule',
      data: {'dayOfWeek': dayOfWeek, 'hour': hour},
    );
  }
}
