import 'package:equatable/equatable.dart';
import 'user.dart';

class FamilyMember extends Equatable {
  final String id;
  final String familyId;
  final String userId;
  final String role;
  final String? joinedAt;
  final String syncStatus;
  final User? user;

  const FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    this.role = 'member',
    this.joinedAt,
    this.syncStatus = 'pending',
    this.user,
  });

  @override
  List<Object?> get props => [id, familyId, userId, role, joinedAt, syncStatus, user];

  FamilyMember copyWith({String? role, String? syncStatus, User? user}) {
    return FamilyMember(
      id: id, familyId: familyId, userId: userId,
      role: role ?? this.role, joinedAt: joinedAt,
      syncStatus: syncStatus ?? this.syncStatus, user: user ?? this.user,
    );
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      familyId: json['familyId'] ?? json['family_id'] as String,
      userId: json['userId'] ?? json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joinedAt']?.toString() ?? json['joined_at'] as String?,
      syncStatus: json['sync_status'] ?? 'synced',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'family_id': familyId,
        'user_id': userId,
        'role': role,
        'joined_at': joinedAt ?? DateTime.now().toIso8601String(),
        'sync_status': syncStatus,
      };

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String? ?? 'member',
      joinedAt: map['joined_at'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }
}
