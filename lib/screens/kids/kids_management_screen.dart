import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/limit_service.dart';
import '../../services/parental_gate.dart';
import '../../state/app_limits.dart';
import '../../widgets/child_avatar.dart';
import '../paywall_screen.dart';
import '../routines_screen.dart';

class KidsManagementScreen extends StatefulWidget {
  const KidsManagementScreen({super.key});

  @override
  State<KidsManagementScreen> createState() => _KidsManagementScreenState();
}

class _KidsManagementScreenState extends State<KidsManagementScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> children = [];
  Map<int, (int completed, int total)> todayProgress = {};
  Set<int> activeChildIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final kids = await _db.getChildren();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final progress = <int, (int, int)>{};
    for (final child in kids) {
      final tasks = await _db.getTasksForChild(child['id'], today);
      final done = tasks.where((t) => t['isCompleted'] == 1).length;
      progress[child['id']] = (done, tasks.length);
    }

    if (!mounted) return;
    setState(() {
      children = kids;
      todayProgress = progress;
      activeChildIds = LimitService().isPremium
          ? kids.map((c) => c['id'] as int).toSet()
          : firstIds(kids, FREE_MAX_CHILDREN);
      _loading = false;
    });
  }

  Future<bool> _parentOk(String reason) =>
      ParentalGate.instance.requireParent(context, reason: reason);

  Future<void> _addChild() async {
    if (!await _parentOk('Enter your PIN to add a child.')) return;
    if (!await LimitService().canAddChild()) {
      if (!mounted) return;
      final unlocked = await showPaywall(context, PaywallTrigger.addChild);
      if (!unlocked || !mounted) return;
    }
    if (!mounted) return;
    await Navigator.pushNamed(context, '/addChild');
    await loadData();
  }

  Future<void> _editChild(Map<String, dynamic> child) async {
    if (!activeChildIds.contains(child['id'])) {
      await showPaywall(context, PaywallTrigger.readOnly);
      await loadData();
      return;
    }
    if (!await _parentOk('Enter your PIN to edit ${child['name']}.')) return;
    if (!mounted) return;
    await Navigator.pushNamed(context, '/addChild', arguments: child);
    await loadData();
  }

  Future<void> _deleteChild(Map<String, dynamic> child) async {
    if (!await _parentOk('Enter your PIN to delete ${child['name']}.')) return;
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete ${child['name']}?"),
        content: const Text(
          "This permanently deletes their tasks, stars, rewards and reward "
          "history. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _db.deleteChild(child['id']);
    await loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kids")),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "kidsAddChild",
        onPressed: _addChild,
        icon: const Icon(Icons.person_add),
        label: const Text("Add child"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : children.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: children.length,
              itemBuilder: (context, index) => _buildChildCard(children[index]),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("👶", style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              "No children yet",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              "Add your first child to start building routines.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final (done, total) = todayProgress[child['id']] ?? (0, 0);
    final readOnly = !activeChildIds.contains(child['id']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ChildAvatar(avatar: child['avatar']),
        title: Text(
          child['name'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          "⭐ ${child['stars'] ?? 0} ${child['stars'] == 1 ? 'star' : 'stars'}"
          "  •  Today: $done / $total tasks"
          "${readOnly ? '\n🔒 Read-only: Premium ended' : ''}",
        ),
        onTap: () async {
          await Navigator.pushNamed(context, '/tasks', arguments: child);
          await loadData();
        },
        trailing: PopupMenuButton<String>(
          tooltip: "Options for ${child['name']}",
          onSelected: (value) {
            if (value == 'edit') _editChild(child);
            if (value == 'routines') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoutinesScreen(child: child)),
              );
            }
            if (value == 'delete') _deleteChild(child);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(leading: Icon(Icons.edit), title: Text("Edit")),
            ),
            if (!readOnly)
              const PopupMenuItem(
                value: 'routines',
                child: ListTile(
                  leading: Icon(Icons.repeat),
                  title: Text("Routines"),
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text("Delete"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
