import '../models/family.dart';
import '../models/family_member.dart';
import '../models/user.dart';
import 'api_client.dart';

class FamilyService {
  final ApiClient _apiClient;
  FamilyService(this._apiClient);

  Future<List<Family>> loadFamilies() async {
    final response = await _apiClient.dio.get('/families');
    return (response.data as List)
        .map((f) => Family.fromJson(f))
        .toList();
  }

  Future<List<FamilyMember>> loadMembers(String familyId) async {
    final response = await _apiClient.dio.get('/families/$familyId/members');
    return (response.data as List).map((m) {
      final member = FamilyMember.fromJson(m);
      User? user;
      if (m['user'] != null) {
        user = User.fromJson(m['user']);
      }
      return FamilyMember(
        id: member.id,
        familyId: member.familyId,
        userId: member.userId,
        role: member.role,
        joinedAt: member.joinedAt,
        user: user,
      );
    }).toList();
  }

  Future<Family> createFamily(String name) async {
    final response = await _apiClient.dio.post(
      '/families',
      data: {'name': name},
    );
    return Family.fromJson(response.data);
  }

  Future<void> updateFamilyName(String familyId, String name) async {
    await _apiClient.dio.patch(
      '/families/$familyId',
      data: {'name': name},
    );
  }

  Future<void> removeMember(String familyId, String userId) async {
    await _apiClient.dio.delete('/families/$familyId/members/$userId');
  }

  Future<void> changeMemberRole(
    String familyId,
    String userId,
    String newRole,
  ) async {
    await _apiClient.dio.patch(
      '/families/$familyId/members/$userId/role',
      data: {'role': newRole},
    );
  }

  Future<Map<String, dynamic>?> loadWeeklySummary(String familyId) async {
    final response = await _apiClient.dio.get(
      '/families/$familyId/weekly-summary',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadChallenges(String familyId) async {
    final response = await _apiClient.dio.get(
      '/families/$familyId/challenges',
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<void> createChallenge(
    String familyId, {
    required String title,
    required int targetCount,
    required String startDate,
    required String endDate,
  }) async {
    await _apiClient.dio.post(
      '/families/$familyId/challenges',
      data: {
        'title': title,
        'targetCount': targetCount,
        'startDate': startDate,
        'endDate': endDate,
      },
    );
  }
}
