import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/chore.dart';

class ChoreRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Chore>> getChoresByFamily(String familyId, {String? statusFilter}) async {
    final db = await _db.database;
    String where = 'family_id = ?';
    List<dynamic> args = [familyId];

    if (statusFilter != null && statusFilter != 'all') {
      where += ' AND status = ?';
      args.add(statusFilter);
    }

    final maps = await db.query('chores', where: where, whereArgs: args, orderBy: 'created_at DESC');
    return maps.map((m) => Chore.fromMap(m)).toList();
  }

  Future<Chore?> getChoreById(String id) async {
    final db = await _db.database;
    final maps = await db.query('chores', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Chore.fromMap(maps.first);
  }

  Future<void> insertChore(Chore chore) async {
    final db = await _db.database;
    await db.insert('chores', chore.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateChore(Chore chore) async {
    final db = await _db.database;
    final map = chore.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    map['sync_status'] = 'pending';
    await db.update('chores', map, where: 'id = ?', whereArgs: [chore.id]);
  }

  Future<void> deleteChore(String id) async {
    final db = await _db.database;
    await db.delete('chores', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Chore>> getPendingSync() async {
    final db = await _db.database;
    final maps = await db.query('chores', where: 'sync_status = ?', whereArgs: ['pending']);
    return maps.map((m) => Chore.fromMap(m)).toList();
  }

  Future<void> markSynced(String id) async {
    final db = await _db.database;
    await db.update('chores', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getStats(String familyId) async {
    final db = await _db.database;
    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM chores WHERE family_id = ?', [familyId])) ?? 0;
    final done = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM chores WHERE family_id = ? AND status = 'done'", [familyId])) ?? 0;
    return {'total': total, 'done': done, 'pending': total - done};
  }

  Future<List<Chore>> getTodayChores(String familyId, String userId) async {
    final db = await _db.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final maps = await db.query(
      'chores',
      where: 'family_id = ? AND (assigned_to = ? OR assigned_to IS NULL) AND (due_date = ? OR due_date IS NULL)',
      whereArgs: [familyId, userId, today],
      orderBy: 'status ASC, created_at DESC',
    );
    return maps.map((m) => Chore.fromMap(m)).toList();
  }
}
