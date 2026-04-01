import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import '../db/database_helper.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final DatabaseHelper _db = DatabaseHelper();

  Future<User> register({
    required String username,
    required String displayName,
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.dio.post('/auth/register', data: {
      'username': username,
      'displayName': displayName,
      'email': email,
      'password': password,
    });

    final data = response.data;
    await _apiClient.setTokens(data['accessToken'], data['refreshToken']);

    final user = User.fromJson(data['user']);
    await _saveCurrentUser(user);
    return user;
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final data = response.data;
    await _apiClient.setTokens(data['accessToken'], data['refreshToken']);

    final user = User.fromJson(data['user']);
    await _saveCurrentUser(user);
    return user;
  }

  Future<void> logout() async {
    await _apiClient.clearTokens();
    final db = await _db.database;
    await db.delete('sync_meta', where: 'key = ?', whereArgs: ['current_user_id']);
  }

  Future<User?> getCurrentUser() async {
    final db = await _db.database;
    final meta = await db.query('sync_meta', where: 'key = ?', whereArgs: ['current_user_id']);
    if (meta.isEmpty) return null;

    final userId = meta.first['value'] as String;
    final users = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (users.isEmpty) return null;

    return User.fromMap(users.first);
  }

  Future<void> _saveCurrentUser(User user) async {
    final db = await _db.database;
    await db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert(
      'sync_meta',
      {'key': 'current_user_id', 'value': user.id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
