class Message {
  final String id;
  final String familyId;
  final String userId;
  final String text;
  final String createdAt;
  final String syncStatus;
  final String? userName;

  Message({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.syncStatus = 'synced',
    this.userName,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      familyId: json['familyId'] ?? json['family_id'] as String,
      userId: json['userId'] ?? json['user_id'] as String,
      text: json['text'] as String,
      createdAt: json['createdAt']?.toString() ?? json['created_at'] as String,
      syncStatus: json['sync_status'] ?? 'synced',
      userName: json['userName'] ?? json['user_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'family_id': familyId,
        'user_id': userId,
        'text': text,
        'created_at': createdAt,
        'sync_status': syncStatus,
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
    );
  }
}
