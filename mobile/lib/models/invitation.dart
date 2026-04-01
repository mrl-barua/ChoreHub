import 'user.dart';

class Invitation {
  final String id;
  final String familyId;
  final String fromUserId;
  final String toUserId;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final String syncStatus;
  final String? familyName;
  final User? fromUser;

  Invitation({
    required this.id,
    required this.familyId,
    required this.fromUserId,
    required this.toUserId,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
    this.syncStatus = 'pending',
    this.familyName,
    this.fromUser,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'] as String,
      familyId: json['familyId'] ?? json['family_id'] as String,
      fromUserId: json['fromUserId'] ?? json['from_user_id'] as String,
      toUserId: json['toUserId'] ?? json['to_user_id'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt']?.toString() ?? json['created_at'] as String?,
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at'] as String?,
      syncStatus: json['sync_status'] ?? 'synced',
      familyName: json['family']?['name'] as String?,
      fromUser: json['fromUser'] != null ? User.fromJson(json['fromUser']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'family_id': familyId,
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'status': status,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
        'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
        'sync_status': syncStatus,
      };

  factory Invitation.fromMap(Map<String, dynamic> map) {
    return Invitation(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      fromUserId: map['from_user_id'] as String,
      toUserId: map['to_user_id'] as String,
      status: map['status'] as String? ?? 'pending',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }
}
