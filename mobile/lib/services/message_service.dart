import 'package:dio/dio.dart';
import '../models/message.dart';
import 'api_client.dart';

class MessageService {
  final ApiClient _apiClient;
  MessageService(this._apiClient);

  Future<List<Message>> loadMessages(
    String familyId, {
    int limit = 50,
    String? before,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'familyId': familyId,
      'limit': limit,
    };
    if (before != null) params['before'] = before;
    if (search != null) params['search'] = search;

    final response = await _apiClient.dio.get(
      '/messages',
      queryParameters: params,
    );
    return (response.data as List)
        .map((m) => Message.fromJson(m))
        .toList();
  }

  Future<void> sendMessageRest({
    required String id,
    required String familyId,
    required String text,
    String? choreId,
    String? mentions,
    String? replyToId,
    String? imageUrl,
    required String createdAt,
  }) async {
    await _apiClient.dio.post('/messages/send', data: {
      'id': id,
      'familyId': familyId,
      'text': text,
      'choreId': choreId,
      'mentions': mentions,
      'replyToId': replyToId,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
    });
  }

  Future<String?> uploadImage(String filePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    final response = await _apiClient.dio.post(
      '/messages/upload',
      data: formData,
    );
    return response.data['imageUrl'] as String?;
  }

  Future<int> loadUnreadCount(String familyId) async {
    final response = await _apiClient.dio.get(
      '/messages/unread',
      queryParameters: {'familyId': familyId},
    );
    return response.data['count'] as int? ?? 0;
  }
}
