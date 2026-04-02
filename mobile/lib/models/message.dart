import 'dart:convert';
import 'package:equatable/equatable.dart';

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

class ReplyTo {
  final String id;
  final String text;
  final String userId;
  final String? userName;

  ReplyTo({required this.id, required this.text, required this.userId, this.userName});

  factory ReplyTo.fromJson(Map<String, dynamic> json) {
    return ReplyTo(
      id: json['id'] as String,
      text: json['text'] as String,
      userId: json['userId'] ?? json['user_id'] as String,
      userName: json['userName'] ?? json['user_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'userId': userId,
    'userName': userName,
  };
}

class Message extends Equatable {
  final String id;
  final String familyId;
  final String userId;
  final String text;
  final String createdAt;
  final String syncStatus;
  final String? userName;
  final String? choreId;
  final String? mentions;
  final String? replyToId;
  final String? imageUrl;
  final String? reactions; // JSON: {"emoji": ["userId1","userId2"]}
  final String? deletedAt;
  final ChoreAttachment? chore;
  final ReplyTo? replyTo;
  final List<String> readBy;

  const Message({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.syncStatus = 'synced',
    this.userName,
    this.choreId,
    this.mentions,
    this.replyToId,
    this.imageUrl,
    this.reactions,
    this.deletedAt,
    this.chore,
    this.replyTo,
    this.readBy = const [],
  });

  @override
  List<Object?> get props => [id, familyId, userId, text, createdAt, syncStatus, userName, choreId, mentions, replyToId, imageUrl, reactions, deletedAt, readBy];

  bool get hasChoreAttachment => choreId != null && choreId!.isNotEmpty;
  bool get isDeleted => deletedAt != null;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  List<String> get mentionedUserIds {
    if (mentions == null || mentions!.isEmpty) return [];
    return mentions!.split(',').where((s) => s.isNotEmpty).toList();
  }

  /// Parse reactions JSON into map
  Map<String, List<String>> get reactionMap {
    if (reactions == null || reactions!.isEmpty) return {};
    try {
      final decoded = jsonDecode(reactions!) as Map<String, dynamic>;
      return decoded.map((key, value) =>
          MapEntry(key, (value as List).map((e) => e as String).toList()));
    } catch (_) {
      return {};
    }
  }

  Message copyWith({
    String? text,
    String? reactions,
    String? deletedAt,
    ChoreAttachment? chore,
    ReplyTo? replyTo,
    List<String>? readBy,
    String? imageUrl,
  }) {
    return Message(
      id: id,
      familyId: familyId,
      userId: userId,
      text: text ?? this.text,
      createdAt: createdAt,
      syncStatus: syncStatus,
      userName: userName,
      choreId: choreId,
      mentions: mentions,
      replyToId: replyToId,
      imageUrl: imageUrl ?? this.imageUrl,
      reactions: reactions ?? this.reactions,
      deletedAt: deletedAt ?? this.deletedAt,
      chore: chore ?? this.chore,
      replyTo: replyTo ?? this.replyTo,
      readBy: readBy ?? this.readBy,
    );
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
      replyToId: json['replyToId'] ?? json['reply_to_id'] as String?,
      imageUrl: json['imageUrl'] ?? json['image_url'] as String?,
      reactions: json['reactions'] as String?,
      deletedAt: json['deletedAt']?.toString() ?? json['deleted_at'] as String?,
      chore: json['chore'] != null ? ChoreAttachment.fromJson(json['chore']) : null,
      replyTo: json['replyTo'] != null ? ReplyTo.fromJson(json['replyTo']) : null,
      readBy: json['readBy'] != null
          ? (json['readBy'] as List).map((e) => e as String).toList()
          : const [],
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
    'reply_to_id': replyToId,
    'image_url': imageUrl,
    'reactions': reactions,
    'deleted_at': deletedAt,
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
      replyToId: map['reply_to_id'] as String?,
      imageUrl: map['image_url'] as String?,
      reactions: map['reactions'] as String?,
      deletedAt: map['deleted_at'] as String?,
    );
  }
}
