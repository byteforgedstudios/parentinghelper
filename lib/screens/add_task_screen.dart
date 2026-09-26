import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/limit_service.dart';

class AddTaskScreen extends StatefulWidget {
  final int childId;
  const AddTaskScreen({super.key, required this.childId});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = controller.text.trim();
    if (title.isEmpty) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final limits = LimitService(isPremium: false);
    if (!await limits.canAddTask(widget.childId, today)) {
      // TODO: show PaywallTasksLimit
      return;
    }

    await DatabaseService().insertTask(widget.childId, title);

    if (!mounted) return;
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
