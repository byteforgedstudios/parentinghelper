import 'package:flutter/material.dart';
import '../services/database_service.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseService _db = DatabaseService();

  void saveChild() async {
    if (_controller.text.trim().isEmpty) return;

    await _db.insertChild(_controller.text.trim());

    Navigator.pop(context); // go back to dashboard
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Child")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Child Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveChild,
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
