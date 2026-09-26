import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../state/routine_days.dart';

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

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // v2: child avatars, reward icons, and reward title/cost copied into
  // history so past redemptions survive deleting a reward.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE children ADD COLUMN avatar TEXT');
      await db.execute('ALTER TABLE rewards ADD COLUMN icon TEXT');
      await db.execute('ALTER TABLE reward_history ADD COLUMN title TEXT');
      await db.execute('ALTER TABLE reward_history ADD COLUMN cost INTEGER');
    }
    // v3: per-child recurring routines replace the global task templates.
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN routineId INTEGER');
      await _createRoutineTables(db);
      await db.execute('DROP TABLE IF EXISTS task_templates');
    }
  }

  Future<void> _createRoutineTables(Database db) async {
    // days: bitmask, bit 0 = Monday ... bit 6 = Sunday.
    await db.execute('''
    CREATE TABLE routines(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      childId INTEGER,
      title TEXT,
      days INTEGER
    )
  ''');

    // Which routine tasks have been created, so a task the parent deletes
    // isn't recreated.
    await db.execute('''
    CREATE TABLE routine_generated(
      routineId INTEGER,
      date TEXT,
      PRIMARY KEY(routineId, date)
    )
  ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE children(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      stars INTEGER DEFAULT 0,
      avatar TEXT
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
      routineId INTEGER,
      UNIQUE(childId, title, date)
    )
  ''');

    await _createRoutineTables(db);

    await db.execute('''
    CREATE TABLE rewards(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      childId INTEGER,
      title TEXT,
      cost INTEGER,
      icon TEXT
    )
  ''');

    await db.execute('''
    CREATE TABLE reward_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      childId INTEGER,
      rewardId INTEGER,
      date TEXT,
      title TEXT,
      cost INTEGER
    )
  ''');
  }

  // =========================
  // CHILD METHODS
  // =========================

  Future<int> insertChild(String name, {String? avatar}) async {
    final db = await database;
    return await db.insert('children', {
      'name': name,
      'stars': 0,
      'avatar': avatar,
    });
  }

  Future<void> updateChild(int id, String name, String? avatar) async {
    final db = await database;
    await db.update(
      'children',
      {'name': name, 'avatar': avatar},
      where: 'id = ?',
      whereArgs: [id],
    );
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
      await txn.rawDelete(
        'DELETE FROM routine_generated WHERE routineId IN '
        '(SELECT id FROM routines WHERE childId = ?)',
        [id],
      );
      await txn.delete('routines', where: 'childId = ?', whereArgs: [id]);
    });
  }

  // =========================
  // TASK METHODS
  // =========================

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
      orderBy: 'id',
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

  /// Deletes every child, task, routine, reward and redemption.
  Future<void> clearDatabase() async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('children');
      await txn.delete('rewards');
      await txn.delete('reward_history');
      await txn.delete('routines');
      await txn.delete('routine_generated');
    });
  }

  Future<void> deleteTask(int taskId) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  }

  // =========================
  // ROUTINE METHODS
  // =========================

  Future<List<Map<String, dynamic>>> getRoutinesForChild(int childId) async {
    final db = await database;
    return await db.query(
      'routines',
      where: 'childId = ?',
      whereArgs: [childId],
      orderBy: 'id',
    );
  }

  Future<int> insertRoutine(int childId, String title, int days) async {
    final db = await database;
    return await db.insert('routines', {
      'childId': childId,
      'title': title,
      'days': days,
    });
  }

  /// Changing a routine re-plans its unfinished future tasks; today's and
  /// past tasks are kept.
  Future<void> updateRoutine(int id, String title, int days) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'routines',
        {'title': title, 'days': days},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _removeFutureRoutineTasks(txn, id);
    });
  }

  Future<void> deleteRoutine(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await _removeFutureRoutineTasks(txn, id);
      await txn.delete('routines', where: 'id = ?', whereArgs: [id]);
      await txn.delete(
        'routine_generated',
        where: 'routineId = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> _removeFutureRoutineTasks(Transaction txn, int routineId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await txn.delete(
      'tasks',
      where: 'routineId = ? AND date > ? AND isCompleted = 0',
      whereArgs: [routineId, today],
    );
    await txn.delete(
      'routine_generated',
      where: 'routineId = ? AND date > ?',
      whereArgs: [routineId, today],
    );
  }

  /// Creates the tasks a child's routines schedule on [date]. Only runs for
  /// today and later, so it never rewrites history. [maxTasks] applies the
  /// free plan limit; routines that don't fit are created later if the
  /// limit is lifted.
  Future<void> generateRoutineTasks(
    int childId,
    DateTime date, {
    int? maxTasks,
  }) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (dateStr.compareTo(today) < 0) return;

    final db = await database;
    final routines = await getRoutinesForChild(childId);

    await db.transaction((txn) async {
      for (final routine in routines) {
        if (!includesWeekday(routine['days'] as int, date.weekday)) continue;

        final done = await txn.query(
          'routine_generated',
          where: 'routineId = ? AND date = ?',
          whereArgs: [routine['id'], dateStr],
        );
        if (done.isNotEmpty) continue;

        if (maxTasks != null) {
          final count = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM tasks WHERE childId = ? AND date = ?',
              [childId, dateStr],
            ),
          )!;
          if (count >= maxTasks) continue;
        }

        await txn.insert('tasks', {
          'childId': childId,
          'title': routine['title'],
          'isCompleted': 0,
          'starAwarded': 0,
          'date': dateStr,
          'routineId': routine['id'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.insert('routine_generated', {
          'routineId': routine['id'],
          'date': dateStr,
        });
      }
    });
  }

  // =========================
  // REWARDS METHODS
  // =========================

  Future<void> insertReward(
    int childId,
    String title,
    int cost, {
    String? icon,
  }) async {
    final db = await database;

    await db.insert('rewards', {
      'childId': childId,
      'title': title,
      'cost': cost,
      'icon': icon,
    });
  }

  Future<void> deleteReward(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Redemptions from before v2 have no title/cost of their own; copy
      // them in so the history keeps showing what was redeemed.
      await txn.rawUpdate(
        '''
        UPDATE reward_history
        SET title = (SELECT title FROM rewards WHERE id = ?),
            cost = (SELECT cost FROM rewards WHERE id = ?)
        WHERE rewardId = ? AND title IS NULL
        ''',
        [id, id, id],
      );
      await txn.delete('rewards', where: 'id = ?', whereArgs: [id]);
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
      final reward = await txn.query(
        'rewards',
        where: 'id = ?',
        whereArgs: [rewardId],
      );
      if (reward.isEmpty) return false;

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
        'title': reward.first['title'],
        'cost': cost,
      });

      return true;
    });
  }

  Future<List<Map<String, dynamic>>> getRewardHistory(int childId) async {
    final db = await database;

    return await db.rawQuery(
      '''
    SELECT rh.id, rh.date,
           COALESCE(rh.title, r.title, 'Deleted reward') AS title,
           COALESCE(rh.cost, r.cost, 0) AS cost
    FROM reward_history rh
    LEFT JOIN rewards r ON rh.rewardId = r.id
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

  // =========================
  // REPORT METHODS
  // =========================

  /// Tasks for a child between two yyyy-mm-dd dates, inclusive.
  Future<List<Map<String, dynamic>>> getTasksForChildBetween(
    int childId,
    String fromDate,
    String toDate,
  ) async {
    final db = await database;

    return await db.query(
      'tasks',
      where: 'childId = ? AND date >= ? AND date <= ?',
      whereArgs: [childId, fromDate, toDate],
      orderBy: 'date',
    );
  }
}
