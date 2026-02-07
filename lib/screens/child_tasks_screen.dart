import 'package:flutter/material.dart';

class ChildTasksScreen extends StatelessWidget {
  const ChildTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today’s Tasks')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add task (with free limit check)
        },
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          TaskTile(title: 'Brush Teeth'),
          TaskTile(title: 'Pack School Bag'),
        ],
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  final String title;

  const TaskTile({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
