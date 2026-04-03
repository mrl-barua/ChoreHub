class ChoreComment {
  final String id;
  final String choreId;
  final String userId;
  final String? userName;
  final String text;
  final String createdAt;

  ChoreComment({
    required this.id,
    required this.choreId,
    required this.userId,
    this.userName,
    required this.text,
    required this.createdAt,
  });

  factory ChoreComment.fromJson(Map<String, dynamic> json) {
    return ChoreComment(
      id: json['id'] as String,
      choreId: json['choreId'] ?? json['chore_id'] as String,
      userId: json['userId'] ?? json['user_id'] as String,
      userName: json['userName'] ?? json['user_name'] as String?,
      text: json['text'] as String,
      createdAt: json['createdAt']?.toString() ?? json['created_at'] as String,
    );
  }
}
