class ChoreAttachment {
  final String id;
  final String title;
  final String status;
  final String category;
  final String? assignedTo;

  ChoreAttachment({
    required this.id,
    required this.title,
    required this.status,
    required this.category,
    this.assignedTo,
  });

  factory ChoreAttachment.fromJson(Map<String, dynamic> json) {
    return ChoreAttachment(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String? ?? 'pending',
      category: json['category'] as String? ?? 'other',
      assignedTo: json['assignedTo'] ?? json['assigned_to'] as String?,
    );
  }
}

class Message {
  final String id;
  final String familyId;
  final String userId;
  final String text;
  final String createdAt;
  final String syncStatus;
  final String? userName;
  final String? choreId;
  final String? mentions; // JSON string: ["userId1", "userId2"]
  final ChoreAttachment? chore;

  Message({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.syncStatus = 'synced',
    this.userName,
    this.choreId,
    this.mentions,
    this.chore,
  });

  bool get hasChoreAttachment => choreId != null && choreId!.isNotEmpty;

  List<String> get mentionedUserIds {
    if (mentions == null || mentions!.isEmpty) return [];
    // Simple comma-separated format: "id1,id2"
    return mentions!.split(',').where((s) => s.isNotEmpty).toList();
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      familyId: json['familyId'] ?? json['family_id'] as String,
      userId: json['userId'] ?? json['user_id'] as String,
      text: json['text'] as String,
      createdAt: json['createdAt']?.toString() ?? json['created_at'] as String,
      syncStatus: json['sync_status'] ?? 'synced',
      userName: json['userName'] ?? json['user_name'] as String?,
      choreId: json['choreId'] ?? json['chore_id'] as String?,
      mentions: json['mentions'] as String?,
      chore: json['chore'] != null ? ChoreAttachment.fromJson(json['chore']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'family_id': familyId,
        'user_id': userId,
        'text': text,
        'created_at': createdAt,
        'sync_status': syncStatus,
        'chore_id': choreId,
        'mentions': mentions,
      };

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      userId: map['user_id'] as String,
      text: map['text'] as String,
      createdAt: map['created_at'] as String,
      syncStatus: map['sync_status'] as String? ?? 'synced',
      userName: map['user_name'] as String?,
      choreId: map['chore_id'] as String?,
      mentions: map['mentions'] as String?,
    );
  }
}
