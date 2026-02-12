import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    CREATE TABLE task_templates(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      childId INTEGER,
      title TEXT
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

    await db.execute('''
    CREATE TABLE rewards(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      childId INTEGER,
      title TEXT,
      cost INTEGER
    )
  ''');

    await db.execute('''
    CREATE TABLE reward_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      childId INTEGER,
      rewardId INTEGER,
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

  Future<Map<String, dynamic>> getChildById(int id) async {
    final db = await database;

    final result = await db.query('children', where: 'id = ?', whereArgs: [id]);

    return result.first;
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

    // Insert today's task
    int taskId = await db.insert('tasks', {
      'childId': childId,
      'title': title,
      'isCompleted': 0,
      'starAwarded': 0,
      'date': today,
    });

    // Check if template already exists
    final existing = await db.query(
      'task_templates',
      where: 'childId = ? AND title = ?',
      whereArgs: [childId, title],
    );

    if (existing.isEmpty) {
      await db.insert('task_templates', {'childId': childId, 'title': title});
    }

    return taskId;
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

  Future<void> dailyResetIfNeeded() async {
    final db = await database;

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastReset = prefs.getString('last_reset_date');

    if (lastReset != today) {
      await db.delete('tasks');
      await prefs.setString('last_reset_date', today);
    }
  }

  Future<void> clearDatabase() async {
    final db = await database;

    await db.delete('tasks');
    await db.delete('children');
    await db.delete('rewards');
    await db.delete('reward_history');
  }

  Future<void> checkAndResetDaily() async {
    final prefs = await SharedPreferences.getInstance();

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastReset = prefs.getString('lastResetDate');

    if (lastReset != today) {
      final db = await database;

      // Delete old tasks
      await db.delete('tasks', where: 'date != ?', whereArgs: [today]);

      // Save today's date
      await prefs.setString('lastResetDate', today);
    }
  }

  Future<void> generateDailyTasksIfNeeded(int childId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final key = 'lastGenerated_$childId';
    final lastGenerated = prefs.getString(key);

    if (lastGenerated == today) return;

    final db = await database;

    // Get templates
    final templates = await db.query(
      'task_templates',
      where: 'childId = ?',
      whereArgs: [childId],
    );

    for (var template in templates) {
      await db.insert('tasks', {
        'childId': childId,
        'title': template['title'],
        'isCompleted': 0,
        'starAwarded': 0,
        'date': today,
      });
    }

    await prefs.setString(key, today);
  }

  Future<List<String>> getTaskTemplatesForChild(int childId) async {
    final db = await database;

    final results = await db.query(
      'task_templates',
      where: 'childId = ?',
      whereArgs: [childId],
    );

    return results.map((e) => e['title'] as String).toList();
  }

  Future<List<String>> getTaskSuggestions(int childId) async {
    final db = await database;

    final result = await db.query(
      'task_templates',
      where: 'childId = ?',
      whereArgs: [childId],
    );

    return result.map((e) => e['title'] as String).toList();
  }

  // =========================
  // REWARDS METHODS
  // =========================

  Future<void> insertReward(int childId, String title, int cost) async {
    final db = await database;

    await db.insert('rewards', {
      'childId': childId,
      'title': title,
      'cost': cost,
    });
  }

  Future<List<Map<String, dynamic>>> getRewardsForChild(int childId) async {
    final db = await database;

    return await db.query(
      'rewards',
      where: 'childId = ?',
      whereArgs: [childId],
    );
  }

  Future<bool> redeemReward(int childId, int rewardId, int cost) async {
    final db = await database;

    final child = await db.query(
      'children',
      where: 'id = ?',
      whereArgs: [childId],
    );

    if (child.isEmpty) return false;

    int currentStars = child.first['stars'] as int;

    if (currentStars < cost) {
      return false; // Not enough stars
    }

    // Deduct stars
    await db.rawUpdate('UPDATE children SET stars = stars - ? WHERE id = ?', [
      cost,
      childId,
    ]);

    // Log redemption
    await db.insert('reward_history', {
      'childId': childId,
      'rewardId': rewardId,
      'date': DateTime.now().toIso8601String(),
    });

    return true;
  }

  Future<List<Map<String, dynamic>>> getRewardHistory(int childId) async {
    final db = await database;

    return await db.rawQuery(
      '''
    SELECT rh.id, rh.date, r.title, r.cost
    FROM reward_history rh
    JOIN rewards r ON rh.rewardId = r.id
    WHERE rh.childId = ?
    ORDER BY rh.date DESC
  ''',
      [childId],
    );
  }

  Future<void> deleteHistoryEntry(int historyId) async {
    final db = await database;
    await db.delete('reward_history', where: 'id = ?', whereArgs: [historyId]);
  }
}
