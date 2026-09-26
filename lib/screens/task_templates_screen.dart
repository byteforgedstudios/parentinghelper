import 'package:flutter/material.dart';
import '../services/database_service.dart';

class TaskTemplatesScreen extends StatefulWidget {
  const TaskTemplatesScreen({super.key});

  @override
  State<TaskTemplatesScreen> createState() => _TaskTemplatesScreenState();
}

class _TaskTemplatesScreenState extends State<TaskTemplatesScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> templates = [];

  @override
  void initState() {
    super.initState();
    loadTemplates();
  }

  Future<void> loadTemplates() async {
    final data = await _db.getAllTemplates();
    if (!mounted) return;
    setState(() {
      templates = data;
    });
  }

  Future<void> addTemplate() async {
    TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Template Task"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter task name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;

              await _db.insertTemplate(controller.text.trim());

              if (!mounted) return;
              Navigator.pop(context);
              loadTemplates();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> deleteTemplate(int id) async {
    await _db.deleteTemplate(id);
    loadTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Task Templates")),
      floatingActionButton: FloatingActionButton(
        onPressed: addTemplate,
        child: const Icon(Icons.add),
      ),
      body: templates.isEmpty
          ? const Center(child: Text("No templates created yet"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];

                return Card(
                  child: ListTile(
                    title: Text(template['title']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => deleteTemplate(template['id']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
