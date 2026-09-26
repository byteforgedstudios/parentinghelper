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
      date TEXT,
      UNIQUE(childId, title, date)
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
    await db.transaction((txn) async {
      await txn.delete('children', where: 'id = ?', whereArgs: [id]);
      await txn.delete('tasks', where: 'childId = ?', whereArgs: [id]);
      await txn.delete('rewards', where: 'childId = ?', whereArgs: [id]);
      await txn.delete('reward_history', where: 'childId = ?', whereArgs: [id]);
    });
  }

  // =========================
  // TASK METHODS
  // =========================

  Future<void> insertTask(int childId, String title) async {
    final db = await database;

    final today = DateTime.now().toIso8601String().split('T').first;

    // 🔍 Check if task already exists for this child today
    final existing = await db.query(
      'tasks',
      where: 'childId = ? AND title = ? AND date = ?',
      whereArgs: [childId, title, today],
    );

    if (existing.isNotEmpty) {
      return; // 🚫 Prevent duplicate
    }

    // ✅ Insert only if not existing
    await db.insert('tasks', {
      'childId': childId,
      'title': title,
      'date': today,
      'isCompleted': 0,
      'starAwarded': 0,
    });
  }

  Future<void> insertTaskWithDate(
    int childId,
    String title,
    String date,
  ) async {
    final db = await database;

    // Prevent duplicate for same child + date
    final existing = await db.query(
      'tasks',
      where: 'childId = ? AND title = ? AND date = ?',
      whereArgs: [childId, title, date],
    );

    if (existing.isNotEmpty) return;

    await db.insert('tasks', {
      'childId': childId,
      'title': title,
      'date': date,
      'isCompleted': 0,
      'starAwarded': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getTasksForChild(
    int childId,
    String date,
  ) async {
    final db = await database;

    return await db.query(
      'tasks',
      where: 'childId = ? AND date = ?',
      whereArgs: [childId, date],
    );
  }

  // Completing a task awards 1 star; un-ticking it takes that star back.
  // starAwarded tracks whether the star is currently granted so toggling
  // can't be used to farm stars.
  Future<void> updateTaskStatus(int taskId, bool completed) async {
    final db = await database;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [taskId],
      );
      if (rows.isEmpty) return;

      final task = rows.first;
      final childId = task['childId'] as int;
      final starAwarded = task['starAwarded'] == 1;

      await txn.update(
        'tasks',
        {'isCompleted': completed ? 1 : 0, 'starAwarded': completed ? 1 : 0},
        where: 'id = ?',
        whereArgs: [taskId],
      );

      if (completed && !starAwarded) {
        await txn.rawUpdate(
          'UPDATE children SET stars = stars + 1 WHERE id = ?',
          [childId],
        );
      } else if (!completed && starAwarded) {
        await txn.rawUpdate(
          'UPDATE children SET stars = MAX(stars - 1, 0) WHERE id = ?',
          [childId],
        );
      }
    });
  }

  Future<int> countTasksForChildOnDate(int childId, String date) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM tasks WHERE childId = ? AND date = ?',
      [childId, date],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countChildren() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM children');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> addStars(int childId, int starsToAdd) async {
    final db = await database;

    await db.rawUpdate('UPDATE children SET stars = stars + ? WHERE id = ?', [
      starsToAdd,
      childId,
    ]);
  }

  // Tasks are stored per date, so each day's checklist starts fresh without
  // deleting anything. This only removes tasks from before today.
  Future<void> clearOldTasks() async {
    final db = await database;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    await db.delete('tasks', where: 'date < ?', whereArgs: [today]);
  }

  Future<void> clearDatabase() async {
    final db = await database;

    await db.delete('tasks');
    await db.delete('children');
    await db.delete('rewards');
    await db.delete('reward_history');
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
      // Ignore if the parent already added the same task today (UNIQUE key).
      await db.insert('tasks', {
        'childId': childId,
        'title': template['title'],
        'isCompleted': 0,
        'starAwarded': 0,
        'date': today,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
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

    return db.transaction((txn) async {
      // Only deducts if the child has enough stars.
      final updated = await txn.rawUpdate(
        'UPDATE children SET stars = stars - ? WHERE id = ? AND stars >= ?',
        [cost, childId, cost],
      );

      if (updated == 0) return false; // Not enough stars (or no such child)

      // Log redemption
      await txn.insert('reward_history', {
        'childId': childId,
        'rewardId': rewardId,
        'date': DateTime.now().toIso8601String(),
      });

      return true;
    });
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

  Future<int> insertTemplate(String title) async {
    final db = await database;

    return await db.insert('task_templates', {'title': title});
  }

  Future<List<Map<String, dynamic>>> getAllTemplates() async {
    final db = await database;
    return await db.query('task_templates');
  }

  Future<void> deleteTemplate(int id) async {
    final db = await database;
    await db.delete('task_templates', where: 'id = ?', whereArgs: [id]);
  }
}
