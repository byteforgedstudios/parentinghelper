import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../services/limit_service.dart';

class AddTaskScreen extends StatefulWidget {
  final int childId;
  const AddTaskScreen({super.key, required this.childId});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final controller = TextEditingController();

  Future<void> _save() async {
    final limits = LimitService(isPremium: false);
    if (!await limits.canAddTask(widget.childId)) {
      // TODO: show PaywallTasksLimit
      return;
    }

    final db = await LocalDB.db;
    await db.insert('tasks', {
      'childId': widget.childId,
      'title': controller.text,
      'completed': 0,
      'date': DateTime.now().toIso8601String().substring(0, 10),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Task')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Task name'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
