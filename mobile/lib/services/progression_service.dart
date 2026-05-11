import 'api_client.dart';

/// API client for the Kid Motivation Loop progression endpoints.
///
/// All three endpoints return the same JSON shape on success (defined by
/// `server/src/routes/me-progression.ts` via `projectProgressionResponse`).
/// We return the raw `Map<String, dynamic>` here; mapping into a typed
/// `ProgressionState` is the provider's job. DioExceptions are intentionally
/// not caught — the provider needs the status code + `reason` field on the
/// error body to distinguish the Mend failure modes (NOT_ELIGIBLE,
/// INSUFFICIENT_XP, COOLDOWN_ACTIVE).
class ProgressionService {
  final ApiClient _apiClient;
  ProgressionService(this._apiClient);

  Future<Map<String, dynamic>> loadProgression({int tzOffsetMinutes = 0}) async {
    final response = await _apiClient.dio.get(
      '/me/progression',
      queryParameters: {'tzOffsetMinutes': tzOffsetMinutes},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> mend({int tzOffsetMinutes = 0}) async {
    final response = await _apiClient.dio.post(
      '/me/progression/mend',
      data: {'tzOffsetMinutes': tzOffsetMinutes},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> setTitle(String? badgeKey) async {
    final response = await _apiClient.dio.post(
      '/me/progression/title',
      data: {'badgeKey': badgeKey},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
