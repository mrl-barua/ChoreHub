import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/chore_history.dart';

class HistoryRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> recordAction(ChoreHistory entry) async {
    final db = await _db.database;
    await db.insert('chore_history', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ChoreHistory>> getRecentHistory(String familyId, {int limit = 20}) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT h.*, u.display_name as user_name, c.title as chore_title
      FROM chore_history h
      LEFT JOIN users u ON h.user_id = u.id
      LEFT JOIN chores c ON h.chore_id = c.id
      WHERE h.family_id = ?
      ORDER BY h.created_at DESC
      LIMIT ?
    ''', [familyId, limit]);
    return maps.map((m) => ChoreHistory.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getCompletionsByDateRange(
      String familyId, String startDate, String endDate) async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT date(created_at) as day, COUNT(*) as count
      FROM chore_history
      WHERE family_id = ? AND action = 'completed'
        AND created_at >= ? AND created_at <= ?
      GROUP BY date(created_at)
      ORDER BY day ASC
    ''', [familyId, startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getCompletionCountsByUser(
      String familyId, String startDate, String endDate) async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT h.user_id, u.display_name, COUNT(*) as count
      FROM chore_history h
      LEFT JOIN users u ON h.user_id = u.id
      WHERE h.family_id = ? AND h.action = 'completed'
        AND h.created_at >= ? AND h.created_at <= ?
      GROUP BY h.user_id
      ORDER BY count DESC
    ''', [familyId, startDate, endDate]);
  }

  Future<int> calculateStreak(String userId, String familyId) async {
    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT date(created_at) as day
      FROM chore_history
      WHERE user_id = ? AND family_id = ? AND action = 'completed'
      ORDER BY day DESC
    ''', [userId, familyId]);

    if (results.isEmpty) return 0;

    int streak = 0;
    DateTime checkDate = DateTime.now();
    for (final row in results) {
      final day = DateTime.parse(row['day'] as String);
      final diff = DateTime(checkDate.year, checkDate.month, checkDate.day)
          .difference(DateTime(day.year, day.month, day.day))
          .inDays;
      if (diff <= 1) {
        streak++;
        checkDate = day;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<List<ChoreHistory>> getPendingSync() async {
    final db = await _db.database;
    final maps = await db.query('chore_history', where: 'sync_status = ?', whereArgs: ['pending']);
    return maps.map((m) => ChoreHistory.fromMap(m)).toList();
  }

  Future<void> markSynced(String id) async {
    final db = await _db.database;
    await db.update('chore_history', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
  }
}
