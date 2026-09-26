import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/limit_service.dart';
import '../widgets/child_progress_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> children = [];
  Map<int, Map<String, int>> childStats = {};

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final kids = await _db.getChildren();

    Map<int, Map<String, int>> stats = {};

    final today = DateTime.now().toIso8601String().split('T').first;

    for (var child in kids) {
      final tasks = await _db.getTasksForChild(child['id'], today);

      int total = tasks.length;
      int completed = tasks.where((task) => task['isCompleted'] == 1).length;

      stats[child['id']] = {"total": total, "completed": completed};
    }

    if (!mounted) return;
    setState(() {
      children = kids;
      childStats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parent Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: "Task Templates",
            onPressed: () => Navigator.pushNamed(context, '/taskTemplates'),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "addChild",
            onPressed: () async {
              final canAdd = await LimitService(isPremium: false).canAddChild();
              if (!context.mounted) return;

              if (!canAdd) {
                // TODO: show Paywall Screen 1 (Add Another Child)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "The free plan allows 1 child. Upgrade to Premium to add more.",
                    ),
                  ),
                );
                return;
              }

              await Navigator.pushNamed(context, '/addChild');
              await loadData();
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: children.isEmpty
          ? const Center(child: Text("No children added yet"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                final stats =
                    childStats[child['id']] ?? {"total": 0, "completed": 0};

                return ChildProgressCard(
                  name: child['name'],
                  completed: stats["completed"]!,
                  total: stats["total"]!,
                  stars: child['stars'] ?? 0,
                  onTap: () async {
                    await Navigator.pushNamed(
                      context,
                      '/tasks',
                      arguments: child,
                    );

                    loadData(); // refresh dashboard when returning
                  },
                  onRewardsTap: () async {
                    await Navigator.pushNamed(
                      context,
                      '/rewards',
                      arguments: child,
                    );
                    await loadData(); // refresh stars after redeem
                  },
                );
              },
            ),
    );
  }
}
