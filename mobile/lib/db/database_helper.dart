import 'package:sqflite/sqflite.dart';
import 'schema.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/chorehub.db';

    return await openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        for (final sql in allCreateStatements) {
          await db.execute(sql);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final sql in migrationV2) {
            await db.execute(sql);
          }
        }
        if (oldVersion < 3) {
          for (final sql in migrationV3) {
            await db.execute(sql);
          }
        }
        if (oldVersion < 4) {
          for (final sql in migrationV4) {
            await db.execute(sql);
          }
        }
        if (oldVersion < 5) {
          for (final sql in migrationV5) {
            await db.execute(sql);
          }
        }
        if (oldVersion < 6) {
          for (final sql in migrationV6) {
            try { await db.execute(sql); } catch (_) {}
          }
        }
      },
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
