import 'package:flutter/material.dart';
import '../services/database_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final DatabaseService _db = DatabaseService();

  late Map<String, dynamic> child;
  int stars = 0;
  List<Map<String, dynamic>> rewards = [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      child =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

      loadStars();
      loadRewards();

      _initialized = true;
    }
  }

  Future<void> loadStars() async {
    final dbChild = await _db.getChildById(child['id']);

    setState(() {
      stars = dbChild['stars'] as int;
    });
  }

  Future<void> redeem(int rewardId, int cost) async {
    bool success = await _db.redeemReward(child['id'], rewardId, cost);

    if (!mounted) return;

    print("Stars before redeem: $stars");
    if (success) {
      setState(() {
        stars -= cost;
      });
      print("Stars after redeem: $stars");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Reward redeemed! 🎉")));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Not enough stars")));
    }

    await loadStars();
  }

  Future<void> loadRewards() async {
    final data = await _db.getRewardsForChild(child['id']);
    setState(() {
      rewards = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${child['name']}'s Rewards")),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/addReward', arguments: child);

          if (!mounted) return;
          loadRewards(); // refresh after adding
        },
        child: const Icon(Icons.add),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.star, size: 64, color: Colors.amber),
            const SizedBox(height: 12),
            Text(
              'Stars available: $stars',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),

            Expanded(
              child: rewards.isEmpty
                  ? const Center(child: Text("No rewards added yet"))
                  : ListView.builder(
                      itemCount: rewards.length,
                      itemBuilder: (context, index) {
                        final reward = rewards[index];
                        return rewardTile(reward);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget rewardTile(Map<String, dynamic> reward) {
    return Card(
      child: ListTile(
        title: Text(reward['title']),
        subtitle: Text("Cost: ${reward['cost']} ⭐"),
        trailing: ElevatedButton(
          onPressed: () => redeem(
            reward['id'], // rewardId
            reward['cost'], // cost
          ),
          child: const Text("Redeem"),
        ),
      ),
    );
  }
}
