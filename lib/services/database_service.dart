import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'parenting_helper.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE children(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        stars INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        childId INTEGER,
        title TEXT,
        isCompleted INTEGER DEFAULT 0,
        starAwarded INTEGER DEFAULT 0,
        date TEXT
      )
    ''');
  }

  // =========================
  // CHILD METHODS
  // =========================

  Future<int> insertChild(String name) async {
    final db = await database;
    return await db.insert('children', {'name': name, 'stars': 0});
  }

  Future<List<Map<String, dynamic>>> getChildren() async {
    final db = await database;
    return await db.query('children');
  }

  Future<void> deleteChild(int id) async {
    final db = await database;
    await db.delete('children', where: 'id = ?', whereArgs: [id]);
    await db.delete('tasks', where: 'childId = ?', whereArgs: [id]);
  }

  // =========================
  // TASK METHODS
  // =========================

  Future<int> insertTask(int childId, String title) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return await db.insert('tasks', {
      'childId': childId,
      'title': title,
      'isCompleted': 0,
      'starAwarded': 0, // <-- REQUIRED
      'date': today,
    });
  }

  Future<List<Map<String, dynamic>>> getTasksForChild(int childId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return await db.query(
      'tasks',
      where: 'childId = ? AND date = ?',
      whereArgs: [childId, today],
    );
  }

  Future<void> updateTaskStatus(int taskId, bool completed) async {
    final db = await database;

    await db.update(
      'tasks',
      {'isCompleted': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> addStars(int childId, int starsToAdd) async {
    final db = await database;

    await db.rawUpdate('UPDATE children SET stars = stars + ? WHERE id = ?', [
      starsToAdd,
      childId,
    ]);
  }

  Future<void> clearOldTasks() async {
    final db = await database;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    await db.delete('tasks', where: 'date != ?', whereArgs: [today]);
  }

  Future<void> clearDatabase() async {
    final db = await database;

    await db.delete('tasks');
    await db.delete('children');
    await db.delete('rewards');
  }
}
