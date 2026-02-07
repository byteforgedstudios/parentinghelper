import 'local_db.dart';

Future<void> resetTasksIfNewDay(String today) async {
  final db = await LocalDB.db;

  await db.update(
    'tasks',
    {'completed': 0},
    where: 'date != ?',
    whereArgs: [today],
  );
}
