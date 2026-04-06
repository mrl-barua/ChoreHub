import 'api_client.dart';

class UserService {
  final ApiClient _apiClient;
  UserService(this._apiClient);

  Future<Map<String, dynamic>> loadMyStats() async {
    final response = await _apiClient.dio.get('/users/me/stats');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> loadUserStats(
    String userId,
    String familyId,
  ) async {
    final response = await _apiClient.dio.get(
      '/users/$userId/stats',
      queryParameters: {'familyId': familyId},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateDisplayName(String displayName) async {
    await _apiClient.dio.patch(
      '/users/me',
      data: {'displayName': displayName},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.dio.post(
      '/users/me/change-password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }
}
