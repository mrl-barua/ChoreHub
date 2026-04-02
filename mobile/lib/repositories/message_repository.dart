import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/message.dart';

class MessageRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> insertMessage(Message message) async {
    final db = await _db.database;
    await db.insert('messages', message.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getMessages(String familyId, {int limit = 50, String? before}) async {
    final db = await _db.database;
    final args = <dynamic>[familyId];
    if (before != null) args.add(before);
    args.add(limit);

    final maps = await db.rawQuery('''
      SELECT m.*, u.display_name as user_name
      FROM messages m
      LEFT JOIN users u ON m.user_id = u.id
      WHERE m.family_id = ? AND m.deleted_at IS NULL
      ${before != null ? 'AND m.created_at < ?' : ''}
      ORDER BY m.created_at DESC
      LIMIT ?
    ''', args);

    return maps.map((m) => Message.fromMap(m)).toList().reversed.toList();
  }

  Future<List<Message>> searchMessages(String familyId, String query, {int limit = 50}) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT m.*, u.display_name as user_name
      FROM messages m
      LEFT JOIN users u ON m.user_id = u.id
      WHERE m.family_id = ? AND m.deleted_at IS NULL AND m.text LIKE ?
      ORDER BY m.created_at DESC
      LIMIT ?
    ''', [familyId, '%$query%', limit]);

    return maps.map((m) => Message.fromMap(m)).toList().reversed.toList();
  }

  Future<Message?> getMessageById(String id) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT m.*, u.display_name as user_name
      FROM messages m
      LEFT JOIN users u ON m.user_id = u.id
      WHERE m.id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    return Message.fromMap(maps.first);
  }

  Future<void> updateReactions(String messageId, String? reactions) async {
    final db = await _db.database;
    await db.update('messages', {'reactions': reactions}, where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> softDelete(String messageId) async {
    final db = await _db.database;
    await db.update(
      'messages',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> upsertReadReceipt(String messageId, String userId) async {
    final db = await _db.database;
    await db.rawInsert('''
      INSERT OR REPLACE INTO message_read_receipts (id, message_id, user_id, read_at)
      VALUES (?, ?, ?, ?)
    ''', ['${messageId}_$userId', messageId, userId, DateTime.now().toIso8601String()]);
  }

  Future<List<String>> getReadByUsers(String messageId) async {
    final db = await _db.database;
    final maps = await db.query(
      'message_read_receipts',
      columns: ['user_id'],
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    return maps.map((m) => m['user_id'] as String).toList();
  }

  Future<int> getUnreadCount(String familyId, String currentUserId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM messages m
      WHERE m.family_id = ? AND m.deleted_at IS NULL AND m.user_id != ?
      AND m.id NOT IN (
        SELECT message_id FROM message_read_receipts WHERE user_id = ?
      )
    ''', [familyId, currentUserId, currentUserId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Message>> getUnsentMessages(String familyId) async {
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: "family_id = ? AND sync_status = 'pending'",
      whereArgs: [familyId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => Message.fromMap(m)).toList();
  }

  Future<void> markSynced(String id) async {
    final db = await _db.database;
    await db.update('messages', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
  }
}
