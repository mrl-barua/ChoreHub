import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/invitation.dart';

class InvitationRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Invitation>> getIncomingInvitations(String userId) async {
    final db = await _db.database;
    final maps = await db.query(
      'invitations',
      where: 'to_user_id = ? AND status = ?',
      whereArgs: [userId, 'pending'],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Invitation.fromMap(m)).toList();
  }

  Future<void> insertInvitation(Invitation invitation) async {
    final db = await _db.database;
    await db.insert('invitations', invitation.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStatus(String id, String status) async {
    final db = await _db.database;
    await db.update(
      'invitations',
      {'status': status, 'updated_at': DateTime.now().toIso8601String(), 'sync_status': 'pending'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Invitation>> getPendingSync() async {
    final db = await _db.database;
    final maps = await db.query('invitations', where: 'sync_status = ?', whereArgs: ['pending']);
    return maps.map((m) => Invitation.fromMap(m)).toList();
  }

  Future<void> markSynced(String id) async {
    final db = await _db.database;
    await db.update('invitations', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
  }
}
