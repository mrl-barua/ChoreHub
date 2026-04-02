import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? createdAt;
  final String? updatedAt;
  final String syncStatus;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.createdAt,
    this.updatedAt,
    this.syncStatus = 'synced',
  });

  @override
  List<Object?> get props => [id, username, displayName, email, createdAt, updatedAt, syncStatus];

  User copyWith({
    String? username,
    String? displayName,
    String? email,
    String? syncStatus,
  }) {
    return User(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] ?? json['display_name'] as String,
      email: json['email'] as String?,
      createdAt: json['createdAt'] ?? json['created_at'] as String?,
      updatedAt: json['updatedAt'] ?? json['updated_at'] as String?,
      syncStatus: json['sync_status'] ?? json['syncStatus'] ?? 'synced',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'email': email,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'email': email,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
        'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
        'sync_status': syncStatus,
      };

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String,
      email: map['email'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }
}
