import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/limit_service.dart';
import '../services/parental_gate.dart';
import '../widgets/read_only_banner.dart';
import '../widgets/reward_icon.dart';
import 'paywall_screen.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final DatabaseService _db = DatabaseService();
  final LimitService _limits = LimitService();
  final ParentalGate _gate = ParentalGate.instance;

  late Map<String, dynamic> child;
  int stars = 0;
  List<Map<String, dynamic>> rewards = [];
  bool _initialized = false;

  // Without Premium: extra children are read-only, and only the first 3
  // rewards of each child can be redeemed.
  bool _readOnly = false;
  Set<int> _redeemableIds = {};

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

  Future<void> deleteReward(Map<String, dynamic> reward) async {
    if (!await _gate.requireParent(
          context,
          reason: 'Enter your PIN to delete a reward.',
        ) ||
        !mounted) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete ${reward['title']}?"),
        content: const Text("Past redemptions stay in the history."),
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

    await _db.deleteReward(reward['id']);
    await loadRewards();
  }

  Future<void> loadRewards() async {
    final data = await _db.getRewardsForChild(child['id']);
    final readOnly = await _limits.isChildReadOnly(child['id']);
    if (!mounted) return;
    setState(() {
      rewards = data;
      _readOnly = readOnly;
      _redeemableIds = readOnly ? {} : _limits.redeemableRewardIds(data);
    });
  }

  Future<void> _addReward() async {
    if (!await _gate.requireParent(
          context,
          reason: 'Enter your PIN to add a reward.',
        ) ||
        !mounted) {
      return;
    }
    // Free plan: 3 rewards per child.
    if (!await _limits.canAddReward(child['id'])) {
      if (!mounted) return;
      if (!await showPaywall(context, PaywallTrigger.addReward)) return;
    }
    if (!mounted) return;
    await Navigator.pushNamed(context, '/addReward', arguments: child);
    await loadRewards();
  }

  Future<void> _upgrade() async {
    await showPaywall(context, PaywallTrigger.readOnly);
    await loadRewards();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${child['name']}'s Rewards"),
        actions: [
          IconButton(
            tooltip: "Reward history",
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/rewardHistory', arguments: child);
            },
          ),
        ],
      ),

      floatingActionButton: _readOnly
          ? null
          : FloatingActionButton(
              tooltip: "Add reward",
              onPressed: _addReward,
              child: const Icon(Icons.add),
            ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_readOnly) ...[
              ReadOnlyBanner(
                message:
                    "${child['name']} is read-only because Premium has ended.",
                onUpgrade: _upgrade,
              ),
              const SizedBox(height: 12),
            ],
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
    final redeemable = _redeemableIds.contains(reward['id']);
    final lockedByPlan = !_readOnly && !redeemable;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          leading: RewardIcon(icon: reward['icon']),
          onLongPress: _readOnly ? null : () => deleteReward(reward),
          title: Text(
            reward['title'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            lockedByPlan
                ? "$cost ⭐  •  Premium: free plan has 3 rewards"
                : "$cost ⭐  •  hold to delete",
          ),
          trailing: lockedByPlan
              ? IconButton(
                  tooltip: "Unlock with Premium",
                  icon: const Icon(Icons.lock_outline),
                  onPressed: _upgrade,
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: stars >= cost
                        ? Colors.deepPurple
                        : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _readOnly
                      ? null
                      : () async {
                          // The PIN prompt doubles as the redemption confirmation.
                          if (await _gate.requireParent(
                            context,
                            reason:
                                "Redeem ${reward['title']} for $cost stars? "
                                "Enter your PIN to confirm.",
                          )) {
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
