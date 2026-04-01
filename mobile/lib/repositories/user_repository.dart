import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/user.dart';

class UserRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<User?> getUserById(String id) async {
    final db = await _db.database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<void> insertUser(User user) async {
    final db = await _db.database;
    await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertUsers(List<User> users) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final user in users) {
      batch.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
