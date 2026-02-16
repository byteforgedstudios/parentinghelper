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
  DateTime selectedDate = DateTime.now();

  String get formattedDate => selectedDate.toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
  }

  bool _initialized = false;

  String get prettyDate {
    return "${_weekday(selectedDate.weekday)}, "
        "${selectedDate.day} "
        "${_month(selectedDate.month)} "
        "${selectedDate.year}";
  }

  String _weekday(int day) {
    const names = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return names[day];
  }

  String _month(int month) {
    const names = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return names[month];
  }

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
    final loadedTasks = await _db.getTasksForChild(child['id'], formattedDate);

    setState(() {
      tasks = loadedTasks;
    });
  }

  Future<void> addTask() async {
    TextEditingController controller = TextEditingController();
    final templates = await _db.getAllTemplates();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Task"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Manual entry
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "Enter task name"),
            ),

            const SizedBox(height: 20),

            // Template dropdown
            if (templates.isNotEmpty)
              DropdownButtonFormField<Map<String, dynamic>>(
                hint: const Text("Or select from templates"),
                items: templates.map((template) {
                  return DropdownMenuItem(
                    value: template,
                    child: Text(template['title']),
                  );
                }).toList(),
                onChanged: (selected) {
                  if (selected != null) {
                    controller.text = selected['title'];
                  }
                },
              ),
          ],
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
      appBar: AppBar(
        title: Text("${child['name']}'s Tasks"),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: copyTasksToSelectedDays,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );

              if (picked != null) {
                setState(() {
                  selectedDate = picked;
                });
                await _loadTasks();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addTask,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prettyDate,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          setState(() {
                            selectedDate = selectedDate.subtract(
                              const Duration(days: 1),
                            );
                          });
                          await _loadTasks();
                        },
                      ),
                      Text(
                        "Swipe days or tap arrows",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          setState(() {
                            selectedDate = selectedDate.add(
                              const Duration(days: 1),
                            );
                          });
                          await _loadTasks();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Task list
            Expanded(
              child: tasks.isEmpty
                  ? const Center(child: Text("No tasks yet"))
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];

                        return CheckboxListTile(
                          title: Text(task['title']),
                          value: task['isCompleted'] == 1,
                          onChanged: (value) async {
                            await _db.updateTaskStatus(
                              task['id'],
                              value ?? false,
                            );

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

                            await _loadTasks();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> copyTasksToSelectedDays() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked == null) return;

    DateTime current = picked.start;

    while (!current.isAfter(picked.end)) {
      final newDate = current.toIso8601String().split('T').first;

      for (var task in tasks) {
        await _db.insertTaskWithDate(child['id'], task['title'], newDate);
      }

      current = current.add(const Duration(days: 1));
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Tasks copied successfully")));
  }
}
