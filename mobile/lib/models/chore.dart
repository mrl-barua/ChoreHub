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
  final String priority; // 'low', 'medium', 'high'
  final String? description;
  final String? recurrence; // null, 'daily', 'weekly', 'monthly'
  final String assignmentStatus; // 'unassigned', 'pending_acceptance', 'accepted', 'declined'

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
    this.priority = 'medium',
    this.description,
    this.recurrence,
    this.assignmentStatus = 'unassigned',
  });

  bool get isDone => status == 'done';
  bool get isPendingAcceptance => assignmentStatus == 'pending_acceptance';
  bool get isAssignmentAccepted => assignmentStatus == 'accepted';
  bool get isAssignmentDeclined => assignmentStatus == 'declined';

  bool get isOverdue {
    if (dueDate == null || isDone) return false;
    try {
      final due = DateTime.parse(dueDate!);
      return DateTime.now().isAfter(DateTime(due.year, due.month, due.day, 23, 59, 59));
    } catch (_) {
      return false;
    }
  }

  Chore copyWith({
    String? title,
    String? category,
    String? timeSlot,
    String? assignedTo,
    String? status,
    String? dueDate,
    String? syncStatus,
    String? updatedAt,
    String? priority,
    String? description,
    String? recurrence,
    String? assignmentStatus,
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
      priority: priority ?? this.priority,
      description: description ?? this.description,
      recurrence: recurrence ?? this.recurrence,
      assignmentStatus: assignmentStatus ?? this.assignmentStatus,
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
      priority: json['priority'] as String? ?? 'medium',
      description: json['description'] as String?,
      recurrence: json['recurrence'] as String?,
      assignmentStatus: json['assignmentStatus'] ?? json['assignment_status'] as String? ?? 'unassigned',
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
        'priority': priority,
        'description': description,
        'recurrence': recurrence,
        'assignmentStatus': assignmentStatus,
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
        'priority': priority,
        'description': description,
        'recurrence': recurrence,
        'assignment_status': assignmentStatus,
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
      priority: map['priority'] as String? ?? 'medium',
      description: map['description'] as String?,
      recurrence: map['recurrence'] as String?,
      assignmentStatus: map['assignment_status'] as String? ?? 'unassigned',
    );
  }
}
