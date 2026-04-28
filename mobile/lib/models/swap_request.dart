import 'package:equatable/equatable.dart';
import 'chore.dart';
import 'user.dart';

class SwapRequest extends Equatable {
  final String id;
  final String choreId;
  final String fromUserId;
  final String? toUserId;
  final String familyId;
  final String status;
  final String? message;
  final String? createdAt;
  final Chore? chore;
  final User? fromUser;
  final User? toUser;

  const SwapRequest({
    required this.id,
    required this.choreId,
    required this.fromUserId,
    this.toUserId,
    required this.familyId,
    required this.status,
    this.message,
    this.createdAt,
    this.chore,
    this.fromUser,
    this.toUser,
  });

  @override
  List<Object?> get props => [id, choreId, fromUserId, toUserId, familyId, status, message, createdAt];

  factory SwapRequest.fromJson(Map<String, dynamic> json) {
    return SwapRequest(
      id: json['id'] as String,
      choreId: json['choreId'] ?? json['chore_id'] as String,
      fromUserId: json['fromUserId'] ?? json['from_user_id'] as String,
      toUserId: json['toUserId'] as String? ?? json['to_user_id'] as String?,
      familyId: json['familyId'] ?? json['family_id'] as String,
      status: json['status'] as String? ?? 'pending',
      message: json['message'] as String?,
      createdAt: json['createdAt']?.toString() ?? json['created_at'] as String?,
      chore: json['chore'] != null ? Chore.fromJson(json['chore'] as Map<String, dynamic>) : null,
      fromUser: json['fromUser'] != null ? User.fromJson(json['fromUser'] as Map<String, dynamic>) : null,
      toUser: json['toUser'] != null ? User.fromJson(json['toUser'] as Map<String, dynamic>) : null,
    );
  }
}
