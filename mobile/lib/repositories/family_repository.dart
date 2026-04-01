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
    final maps = await db.query('family_members', where: 'family_id = ?', whereArgs: [familyId]);
    final members = maps.map((m) => FamilyMember.fromMap(m)).toList();

    // Attach user info
    final result = <FamilyMember>[];
    for (final member in members) {
      final userMaps = await db.query('users', where: 'id = ?', whereArgs: [member.userId]);
      User? user;
      if (userMaps.isNotEmpty) {
        user = User.fromMap(userMaps.first);
      }
      result.add(FamilyMember(
        id: member.id,
        familyId: member.familyId,
        userId: member.userId,
        role: member.role,
        joinedAt: member.joinedAt,
        syncStatus: member.syncStatus,
        user: user,
      ));
    }
    return result;
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
