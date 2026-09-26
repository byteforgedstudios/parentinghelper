import 'database_service.dart';
import 'premium_service.dart';
import '../state/app_limits.dart';

/// Free plan limits, and what happens to extras when Premium lapses:
/// the oldest child stays active and the others become read-only; per
/// child, the first 5 tasks a day and the first 3 rewards stay usable.
class LimitService {
  final DatabaseService _db = DatabaseService();

  bool get isPremium => PremiumService.instance.isPremium;

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

  // Free plan: up to FREE_MAX_REWARDS_PER_CHILD rewards per child.
  Future<bool> canAddReward(int childId) async {
    if (isPremium) return true;

    final rewards = await _db.getRewardsForChild(childId);
    return rewards.length < FREE_MAX_REWARDS_PER_CHILD;
  }

  /// Children beyond the first are read-only without Premium.
  Future<bool> isChildReadOnly(int childId) async {
    if (isPremium) return false;

    final children = await _db.getChildren();
    return !firstIds(children, FREE_MAX_CHILDREN).contains(childId);
  }

  Set<int> editableTaskIds(List<Map<String, dynamic>> tasksForDay) => isPremium
      ? tasksForDay.map((t) => t['id'] as int).toSet()
      : firstIds(tasksForDay, FREE_MAX_TASKS_PER_CHILD);

  Set<int> redeemableRewardIds(List<Map<String, dynamic>> rewards) => isPremium
      ? rewards.map((r) => r['id'] as int).toSet()
      : firstIds(rewards, FREE_MAX_REWARDS_PER_CHILD);
}
