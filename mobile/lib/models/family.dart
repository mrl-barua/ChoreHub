import 'package:equatable/equatable.dart';

class Family extends Equatable {
  final String id;
  final String name;
  final String createdBy;
  final String? createdAt;
  final String? updatedAt;
  final String syncStatus;
  final String? role;

  const Family({
    required this.id,
    required this.name,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.syncStatus = 'pending',
    this.role,
  });

  @override
  List<Object?> get props => [id, name, createdBy, createdAt, updatedAt, syncStatus, role];

  Family copyWith({String? name, String? syncStatus, String? role}) {
    return Family(
      id: id, name: name ?? this.name, createdBy: createdBy,
      createdAt: createdAt, updatedAt: updatedAt,
      syncStatus: syncStatus ?? this.syncStatus, role: role ?? this.role,
    );
  }

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'] as String,
      name: json['name'] as String,
      createdBy: json['createdBy'] ?? json['created_by'] as String,
      createdAt: json['createdAt']?.toString() ?? json['created_at'] as String?,
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at'] as String?,
      syncStatus: json['sync_status'] ?? 'synced',
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_by': createdBy,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
        'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
        'sync_status': syncStatus,
      };

  factory Family.fromMap(Map<String, dynamic> map) {
    return Family(
      id: map['id'] as String,
      name: map['name'] as String,
      createdBy: map['created_by'] as String,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }
}
