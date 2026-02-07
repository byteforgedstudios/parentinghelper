import '../data/local_db.dart';
import '../state/app_limits.dart';

class LimitService {
  final bool isPremium;

  LimitService({required this.isPremium});

  Future<bool> canAddChild() async {
    if (isPremium) return true;

    final db = await LocalDB.db;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM children');
    return (result.first['count'] as int) < FREE_MAX_CHILDREN;
  }

  Future<bool> canAddTask(int childId) async {
    if (isPremium) return true;

    final db = await LocalDB.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tasks WHERE childId = ?',
      [childId],
    );

    return (result.first['count'] as int) < FREE_MAX_TASKS_PER_CHILD;
  }
}
