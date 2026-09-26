import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/parental_gate.dart';
import '../state/routine_days.dart';
import '../widgets/task_dialog.dart';

/// A child's recurring routines, e.g. "Brush teeth" every day or "Pack
/// school bag" on weekdays. Their tasks appear automatically each day.
class RoutinesScreen extends StatefulWidget {
  final Map<String, dynamic> child;

  const RoutinesScreen({super.key, required this.child});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> routines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadRoutines();
  }

  Future<void> loadRoutines() async {
    final data = await _db.getRoutinesForChild(widget.child['id']);
    if (!mounted) return;
    setState(() {
      routines = data;
      _loading = false;
    });
  }

  Future<void> _edit([Map<String, dynamic>? routine]) async {
    if (!await ParentalGate.instance.requireParent(
          context,
          reason: 'Enter your PIN to change routines.',
        ) ||
        !mounted) {
      return;
    }

    final result = await showTaskDialog(
      context,
      dialogTitle: routine == null ? "New routine" : "Edit routine",
      initialText: routine?['title'] ?? '',
      initialDays: routine?['days'] ?? kEveryDay,
      confirmLabel: "Save",
    );
    if (result == null) return;
    final (title, days) = result;

    if (routine == null) {
      await _db.insertRoutine(widget.child['id'], title, days);
    } else {
      await _db.updateRoutine(routine['id'], title, days);
    }
    await loadRoutines();
  }

  Future<void> _delete(Map<String, dynamic> routine) async {
    if (!await ParentalGate.instance.requireParent(
          context,
          reason: 'Enter your PIN to delete a routine.',
        ) ||
        !mounted) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Stop \"${routine['title']}\"?"),
        content: const Text(
          "It won't be added to future days. Tasks already done stay in "
          "the history.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _db.deleteRoutine(routine['id']);
    await loadRoutines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.child['name']}'s Routines")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text("New routine"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : routines.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "No routines yet.\nAdd tasks that repeat, like \"Brush "
                  "teeth\" every day or \"Pack school bag\" on weekdays.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: routines.length,
              itemBuilder: (context, index) {
                final routine = routines[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.repeat),
                    title: Text(routine['title']),
                    subtitle: Text(describeDays(routine['days'] as int)),
                    onTap: () => _edit(routine),
                    trailing: IconButton(
                      tooltip: "Delete routine",
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(routine),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
