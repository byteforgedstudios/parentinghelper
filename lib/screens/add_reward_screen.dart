import 'package:flutter/material.dart';
import '../services/database_service.dart';

class AddRewardScreen extends StatefulWidget {
  const AddRewardScreen({super.key});

  @override
  State<AddRewardScreen> createState() => _AddRewardScreenState();
}

class _AddRewardScreenState extends State<AddRewardScreen> {
  final DatabaseService _db = DatabaseService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _costController = TextEditingController();

  late Map<String, dynamic> child;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      child = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _initialized = true;
    }
  }

  Future<void> saveReward() async {
    final title = _titleController.text.trim();
    final cost = int.tryParse(_costController.text.trim());

    if (title.isEmpty || cost == null || cost <= 0) return;

    await _db.insertReward(child['id'], title, cost);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Reward")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Reward Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Cost (Stars)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: saveReward,
              child: const Text("Save Reward"),
            ),
          ],
        ),
      ),
    );
  }
}
