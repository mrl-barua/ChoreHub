import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/family.dart';
import '../models/family_member.dart';
import '../models/user.dart';

class FamilyRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Family>> getFamiliesForUser(String userId) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT f.*, fm.role FROM families f
      INNER JOIN family_members fm ON f.id = fm.family_id
      WHERE fm.user_id = ?
    ''', [userId]);
    return maps.map((m) => Family.fromMap(m)).toList();
  }

  Future<void> insertFamily(Family family) async {
    final db = await _db.database;
    await db.insert('families', family.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FamilyMember>> getMembers(String familyId) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT fm.*, u.username, u.display_name, u.email
      FROM family_members fm
      LEFT JOIN users u ON fm.user_id = u.id
      WHERE fm.family_id = ?
    ''', [familyId]);

    return maps.map((m) {
      User? user;
      if (m['username'] != null) {
        user = User(
          id: m['user_id'] as String,
          username: m['username'] as String,
          displayName: m['display_name'] as String,
          email: m['email'] as String?,
        );
      }
      return FamilyMember(
        id: m['id'] as String,
        familyId: m['family_id'] as String,
        userId: m['user_id'] as String,
        role: m['role'] as String? ?? 'member',
        joinedAt: m['joined_at'] as String?,
        syncStatus: m['sync_status'] as String? ?? 'pending',
        user: user,
      );
    }).toList();
  }

  Future<void> insertMember(FamilyMember member) async {
    final db = await _db.database;
    await db.insert('family_members', member.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Family>> getPendingSync() async {
    final db = await _db.database;
    final maps = await db.query('families', where: 'sync_status = ?', whereArgs: ['pending']);
    return maps.map((m) => Family.fromMap(m)).toList();
  }

  Future<void> markSynced(String id) async {
    final db = await _db.database;
    await db.update('families', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
  }
}
