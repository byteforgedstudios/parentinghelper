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

    if (!mounted) return;
    setState(() {
      stars = dbChild['stars'] as int;
    });
  }

  Future<void> redeem(int rewardId, int cost) async {
    bool success = await _db.redeemReward(child['id'], rewardId, cost);

    if (!mounted) return;

    if (success) {
      setState(() {
        stars -= cost;
      });

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
    if (!mounted) return;
    setState(() {
      rewards = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${child['name']}'s Rewards"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/rewardHistory', arguments: child);
            },
          ),
        ],
      ),

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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(Icons.star_rounded, size: 50, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text(
                    "Stars Available",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$stars",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
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
    final int cost = reward['cost'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          leading: const CircleAvatar(
            backgroundColor: Colors.amber,
            child: Icon(Icons.card_giftcard, color: Colors.white),
          ),
          title: Text(
            reward['title'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text("$cost ⭐"),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: stars >= cost ? Colors.deepPurple : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Confirm Redemption"),
                  content: Text("Redeem ${reward['title']} for $cost stars?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Redeem"),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                redeem(reward['id'], cost);
              }
            },
            child: const Text("Redeem"),
          ),
        ),
      ),
    );
  }
}
