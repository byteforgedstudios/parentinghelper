import 'package:flutter/material.dart';
import '../services/database_service.dart';

class TaskChecklistScreen extends StatefulWidget {
  const TaskChecklistScreen({super.key});

  @override
  State<TaskChecklistScreen> createState() => _TaskChecklistScreenState();
}

class _TaskChecklistScreenState extends State<TaskChecklistScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> tasks = [];
  late Map<String, dynamic> child;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      child =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _initializeTasks();
      _initialized = true;
    }
  }

  Future<void> _initializeTasks() async {
    await _db.generateDailyTasksIfNeeded(child['id']);
    await _loadTasks();
  }

  Future<void> _loadTasks() async {
    final loadedTasks = await _db.getTasksForChild(child['id']);
    setState(() {
      tasks = loadedTasks;
    });
  }

  Future<void> addTask() async {
    TextEditingController controller = TextEditingController();

    final suggestions = await _db.getTaskTemplatesForChild(child['id']);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Task"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "Enter task name"),
              ),
              const SizedBox(height: 16),
              if (suggestions.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Suggested Tasks:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: suggestions.map((title) {
                    return ActionChip(
                      label: Text(title),
                      onPressed: () {
                        controller.text = title;
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;

              await _db.insertTask(child['id'], controller.text.trim());
              if (!mounted) return;

              Navigator.pop(context);
              _loadTasks();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${child['name']}'s Tasks")),
      floatingActionButton: FloatingActionButton(
        onPressed: addTask,
        child: const Icon(Icons.add),
      ),
      body: tasks.isEmpty
          ? const Center(child: Text("No tasks yet"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];

                return CheckboxListTile(
                  title: Text(task['title']),
                  value: task['isCompleted'] == 1,
                  onChanged: (value) async {
                    await _db.updateTaskStatus(task['id'], value ?? false);

                    // If completed and star not awarded
                    if ((value ?? false) && task['starAwarded'] == 0) {
                      await _db.addStars(task['childId'], 1);
                      await _db.database.then((db) async {
                        await db.update(
                          'tasks',
                          {'starAwarded': 1},
                          where: 'id = ?',
                          whereArgs: [task['id']],
                        );
                      });
                    }

                    await _loadTasks(); // 🔥 Always reload from DB
                  },
                );
              },
            ),
    );
  }
}
