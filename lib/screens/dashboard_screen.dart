import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/limit_service.dart';
import '../services/parental_gate.dart';
import '../state/app_limits.dart';
import '../widgets/child_progress_card.dart';
import 'paywall_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> children = [];
  Set<int> activeChildIds = {};
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
      activeChildIds = LimitService().isPremium
          ? kids.map((c) => c['id'] as int).toSet()
          : firstIds(kids, FREE_MAX_CHILDREN);
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
            icon: const Icon(Icons.insights),
            tooltip: "Reports",
            onPressed: () async {
              // Paywall Screen 3: Reports are locked on the free plan.
              if (await showPaywall(context, PaywallTrigger.reports) &&
                  context.mounted) {
                Navigator.pushNamed(context, '/reports');
              }
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "addChild",
            tooltip: "Add child",
            onPressed: () async {
              if (!await ParentalGate.instance.requireParent(
                    context,
                    reason: 'Enter your PIN to add a child.',
                  ) ||
                  !context.mounted) {
                return;
              }
              final canAdd = await LimitService().canAddChild();
              if (!context.mounted) return;

              // Paywall Screen 1: adding a 2nd child on the free plan.
              if (!canAdd &&
                  !await showPaywall(context, PaywallTrigger.addChild)) {
                return;
              }
              if (!context.mounted) return;

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
                  avatar: child['avatar'],
                  readOnly: !activeChildIds.contains(child['id']),
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
