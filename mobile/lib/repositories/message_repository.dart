import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/message.dart';

class MessageRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> insertMessage(Message message) async {
    final db = await _db.database;
    await db.insert('messages', message.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
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
      WHERE m.family_id = ?
      ${before != null ? 'AND m.created_at < ?' : ''}
      ORDER BY m.created_at DESC
      LIMIT ?
    ''', args);

    return maps.map((m) => Message.fromMap(m)).toList().reversed.toList();
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
