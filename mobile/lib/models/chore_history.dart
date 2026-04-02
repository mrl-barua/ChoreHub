import 'package:equatable/equatable.dart';

class ChoreHistory extends Equatable {
  final String id;
  final String choreId;
  final String familyId;
  final String userId;
  final String action; // 'created', 'completed', 'assigned', 'accepted', 'declined', 'reopened'
  final String createdAt;
  final String syncStatus;

  // Joined fields (not stored in DB)
  final String? userName;
  final String? choreTitle;

  const ChoreHistory({
    required this.id,
    required this.choreId,
    required this.familyId,
    required this.userId,
    required this.action,
    required this.createdAt,
    this.syncStatus = 'pending',
    this.userName,
    this.choreTitle,
  });

  @override
  List<Object?> get props => [id, choreId, familyId, userId, action, createdAt, syncStatus, userName, choreTitle];

  factory ChoreHistory.fromJson(Map<String, dynamic> json) {
    return ChoreHistory(
      id: json['id'] as String,
      choreId: json['choreId'] ?? json['chore_id'] as String,
      familyId: json['familyId'] ?? json['family_id'] as String,
      userId: json['userId'] ?? json['user_id'] as String,
      action: json['action'] as String,
      createdAt: json['createdAt']?.toString() ?? json['created_at'] as String,
      syncStatus: json['sync_status'] ?? 'synced',
      userName: json['userName'] ?? json['user_name'] as String?,
      choreTitle: json['choreTitle'] ?? json['chore_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'choreId': choreId,
        'familyId': familyId,
        'userId': userId,
        'action': action,
        'createdAt': createdAt,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'chore_id': choreId,
        'family_id': familyId,
        'user_id': userId,
        'action': action,
        'created_at': createdAt,
        'sync_status': syncStatus,
      };

  factory ChoreHistory.fromMap(Map<String, dynamic> map) {
    return ChoreHistory(
      id: map['id'] as String,
      choreId: map['chore_id'] as String,
      familyId: map['family_id'] as String,
      userId: map['user_id'] as String,
      action: map['action'] as String,
      createdAt: map['created_at'] as String,
      syncStatus: map['sync_status'] as String? ?? 'pending',
      userName: map['user_name'] as String?,
      choreTitle: map['chore_title'] as String?,
    );
  }

  String get actionLabel {
    switch (action) {
      case 'created':
        return 'created';
      case 'completed':
        return 'completed';
      case 'assigned':
        return 'assigned';
      case 'accepted':
        return 'accepted';
      case 'declined':
        return 'declined';
      case 'reopened':
        return 'reopened';
      default:
        return action;
    }
  }
}
