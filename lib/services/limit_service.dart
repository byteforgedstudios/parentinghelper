import 'database_service.dart';
import '../state/app_limits.dart';

class LimitService {
  final bool isPremium;
  final DatabaseService _db = DatabaseService();

  LimitService({required this.isPremium});

  Future<bool> canAddChild() async {
    if (isPremium) return true;

    return await _db.countChildren() < FREE_MAX_CHILDREN;
  }

  // Free plan: up to FREE_MAX_TASKS_PER_CHILD tasks per child per day.
  Future<bool> canAddTask(int childId, String date) async {
    if (isPremium) return true;

    return await _db.countTasksForChildOnDate(childId, date) <
        FREE_MAX_TASKS_PER_CHILD;
  }
}
