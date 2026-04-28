import '../models/swap_request.dart';
import 'api_client.dart';

class SwapRequestService {
  final ApiClient _apiClient;
  SwapRequestService(this._apiClient);

  Future<SwapRequest> createSwap({
    required String choreId,
    String? toUserId,
    String? message,
  }) async {
    final response = await _apiClient.dio.post('/swap-requests', data: {
      'choreId': choreId,
      if (toUserId != null) 'toUserId': toUserId,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    return SwapRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SwapRequest>> loadIncoming() async {
    final response = await _apiClient.dio.get('/swap-requests/incoming');
    return (response.data as List)
        .map((s) => SwapRequest.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<List<SwapRequest>> loadOutgoing() async {
    final response = await _apiClient.dio.get('/swap-requests/outgoing');
    return (response.data as List)
        .map((s) => SwapRequest.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<List<SwapRequest>> loadForChore(String choreId) async {
    final response = await _apiClient.dio.get('/swap-requests/by-chore/$choreId');
    return (response.data as List)
        .map((s) => SwapRequest.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<SwapRequest> respond(String id, String status) async {
    final response = await _apiClient.dio.patch(
      '/swap-requests/$id',
      data: {'status': status},
    );
    return SwapRequest.fromJson(response.data as Map<String, dynamic>);
  }
}
