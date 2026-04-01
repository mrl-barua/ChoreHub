class Chore {
  final String id;
  final String familyId;
  final String title;
  final String category;
  final String? timeSlot;
  final String? assignedTo;
  final String status;
  final String? dueDate;
  final String createdBy;
  final String? createdAt;
  final String? updatedAt;
  final String syncStatus;

  Chore({
    required this.id,
    required this.familyId,
    required this.title,
    required this.category,
    this.timeSlot,
    this.assignedTo,
    this.status = 'pending',
    this.dueDate,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.syncStatus = 'pending',
  });

  bool get isDone => status == 'done';

  Chore copyWith({
    String? title,
    String? category,
    String? timeSlot,
    String? assignedTo,
    String? status,
    String? dueDate,
    String? syncStatus,
    String? updatedAt,
  }) {
    return Chore(
      id: id,
      familyId: familyId,
      title: title ?? this.title,
      category: category ?? this.category,
      timeSlot: timeSlot ?? this.timeSlot,
      assignedTo: assignedTo ?? this.assignedTo,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory Chore.fromJson(Map<String, dynamic> json) {
    return Chore(
      id: json['id'] as String,
      familyId: json['familyId'] ?? json['family_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      timeSlot: json['timeSlot'] ?? json['time_slot'] as String?,
      assignedTo: json['assignedTo'] ?? json['assigned_to'] as String?,
      status: json['status'] as String? ?? 'pending',
      dueDate: json['dueDate']?.toString() ?? json['due_date'] as String?,
      createdBy: json['createdBy'] ?? json['created_by'] as String,
      createdAt: json['createdAt']?.toString() ?? json['created_at'] as String?,
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at'] as String?,
      syncStatus: json['sync_status'] ?? 'synced',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyId': familyId,
        'title': title,
        'category': category,
        'timeSlot': timeSlot,
        'assignedTo': assignedTo,
        'status': status,
        'dueDate': dueDate,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'family_id': familyId,
        'title': title,
        'category': category,
        'time_slot': timeSlot,
        'assigned_to': assignedTo,
        'status': status,
        'due_date': dueDate,
        'created_by': createdBy,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
        'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
        'sync_status': syncStatus,
      };

  factory Chore.fromMap(Map<String, dynamic> map) {
    return Chore(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      timeSlot: map['time_slot'] as String?,
      assignedTo: map['assigned_to'] as String?,
      status: map['status'] as String? ?? 'pending',
      dueDate: map['due_date'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }
}
