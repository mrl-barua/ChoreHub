class Family {
  final String id;
  final String name;
  final String createdBy;
  final String? createdAt;
  final String? updatedAt;
  final String syncStatus;
  final String? role;

  Family({
    required this.id,
    required this.name,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.syncStatus = 'pending',
    this.role,
  });

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
