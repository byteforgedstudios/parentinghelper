const int FREE_MAX_CHILDREN = 1;
const int FREE_MAX_TASKS_PER_CHILD = 5;
const int FREE_MAX_REWARDS_PER_CHILD = 3;

/// The ids of the first [limit] rows, oldest (lowest id) first. On the free
/// plan these stay usable; anything beyond them is read-only. This is how
/// extras behave after Premium lapses.
Set<int> firstIds(Iterable<Map<String, dynamic>> rows, int limit) {
  final ids = rows.map((r) => r['id'] as int).toList()..sort();
  return ids.take(limit).toSet();
}
