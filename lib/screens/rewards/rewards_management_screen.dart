import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/limit_service.dart';
import '../../state/app_limits.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/reward_icon.dart';

class RewardsManagementScreen extends StatefulWidget {
  const RewardsManagementScreen({super.key});

  @override
  State<RewardsManagementScreen> createState() =>
      _RewardsManagementScreenState();
}

class _RewardsManagementScreenState extends State<RewardsManagementScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> children = [];
  Map<int, List<Map<String, dynamic>>> rewardsByChild = {};
  // Rewards that can be redeemed on the current plan (all, with Premium).
  Set<int> redeemableIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final kids = await _db.getChildren();

    final limits = LimitService();
    final activeChildIds = limits.isPremium
        ? kids.map((c) => c['id'] as int).toSet()
        : firstIds(kids, FREE_MAX_CHILDREN);

    final rewards = <int, List<Map<String, dynamic>>>{};
    final redeemable = <int>{};
    for (final child in kids) {
      final list = await _db.getRewardsForChild(child['id']);
      if (activeChildIds.contains(child['id'])) {
        redeemable.addAll(limits.redeemableRewardIds(list));
      }
      rewards[child['id']] = [...list]
        ..sort((a, b) => (a['cost'] as int).compareTo(b['cost'] as int));
    }

    if (!mounted) return;
    setState(() {
      children = kids;
      rewardsByChild = rewards;
      redeemableIds = redeemable;
      _loading = false;
    });
  }

  Future<void> _open(String route, Map<String, dynamic> child) async {
    await Navigator.pushNamed(context, route, arguments: child);
    await loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rewards")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : children.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "Add a child in the Kids tab to start giving rewards.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: children.length,
                itemBuilder: (context, index) =>
                    _buildChildRewards(children[index]),
              ),
            ),
    );
  }

  Widget _buildChildRewards(Map<String, dynamic> child) {
    final int stars = child['stars'] ?? 0;
    final rewards = rewardsByChild[child['id']] ?? [];
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChildAvatar(avatar: child['avatar']),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    child['name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "⭐ $stars",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (rewards.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text("No rewards yet. Add one to motivate them!"),
              )
            else
              ...rewards.map((reward) {
                final int cost = reward['cost'];
                final locked = !redeemableIds.contains(reward['id']);
                final affordable = !locked && stars >= cost;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: RewardIcon(icon: reward['icon'], radius: 18),
                  title: Text(reward['title']),
                  subtitle: Text(
                    locked
                        ? "🔒 Premium"
                        : affordable
                        ? "Ready to redeem!"
                        : "${cost - stars} more ⭐ needed",
                    style: TextStyle(
                      color: affordable ? Colors.green.shade700 : null,
                    ),
                  ),
                  trailing: Text(
                    "$cost ⭐",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _open('/rewards', child),
                    icon: const Icon(Icons.card_giftcard),
                    label: const Text("Manage & redeem"),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: "Reward history",
                  color: colors.primary,
                  onPressed: () => _open('/rewardHistory', child),
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
