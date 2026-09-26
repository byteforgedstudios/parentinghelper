import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';

class RewardHistoryScreen extends StatefulWidget {
  const RewardHistoryScreen({super.key});

  @override
  State<RewardHistoryScreen> createState() => _RewardHistoryScreenState();
}

class _RewardHistoryScreenState extends State<RewardHistoryScreen> {
  final DatabaseService _db = DatabaseService();

  late Map<String, dynamic> child;
  List<Map<String, dynamic>> history = [];
  bool _initialized = false;

  String filter = "all";
  int totalSpent = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      child =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      loadHistory();
      _initialized = true;
    }
  }

  Future<void> loadHistory() async {
    final data = await _db.getRewardHistory(child['id']);

    List<Map<String, dynamic>> filtered = data;

    if (filter == "week") {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

      filtered = data.where((item) {
        final date = DateTime.parse(item['date']);
        return date.isAfter(oneWeekAgo);
      }).toList();
    }

    int spent = 0;
    for (var item in filtered) {
      spent += item['cost'] as int;
    }

    if (!mounted) return;
    setState(() {
      history = filtered;
      totalSpent = spent;
    });
  }

  Future<void> deleteEntry(int id) async {
    await _db.deleteHistoryEntry(id);
    await loadHistory();
  }

  String formatDate(String rawDate) {
    final dt = DateTime.parse(rawDate);
    return DateFormat("dd MMM yyyy • HH:mm").format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${child['name']}'s History"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              filter = value;
              loadHistory();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: "all", child: Text("All Time")),
              PopupMenuItem(value: "week", child: Text("This Week")),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  "Total Stars Spent",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  "$totalSpent ⭐",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? const Center(child: Text("No rewards redeemed yet"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];

                      return Card(
                        child: ListTile(
                          title: Text(item['title']),
                          subtitle: Text(
                            "Cost: ${item['cost']} ⭐\n${formatDate(item['date'])}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteEntry(item['id']),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
