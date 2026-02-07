import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDB {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'parenting_helper.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE children (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            stars INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            childId INTEGER,
            title TEXT,
            completed INTEGER,
            date TEXT
          )
        ''');
      },
    );
  }
}
