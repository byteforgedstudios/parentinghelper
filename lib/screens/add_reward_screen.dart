import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/premium_service.dart';
import '../state/premium_content.dart';
import '../widgets/emoji_picker.dart';
import 'paywall_screen.dart';

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
  String? _icon;

  @override
  void dispose() {
    _titleController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _unlockIcon(String icon) async {
    final unlocked = await showPaywall(context, PaywallTrigger.rewardIcons);
    if (unlocked && mounted) setState(() => _icon = icon);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      child =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _initialized = true;
    }
  }

  Future<void> saveReward() async {
    final title = _titleController.text.trim();
    final cost = int.tryParse(_costController.text.trim());

    if (title.isEmpty || cost == null || cost <= 0) return;

    // Reward icons are a Premium feature.
    final icon = PremiumService.instance.isPremium ? _icon : null;
    await _db.insertReward(child['id'], title, cost, icon: icon);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Reward")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
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
            Row(
              children: [
                Text("Icon", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                const Chip(
                  avatar: Icon(Icons.workspace_premium, size: 16),
                  label: Text("Premium"),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: PremiumService.instance,
              builder: (context, _) => EmojiPicker(
                options: kRewardIcons,
                selected: _icon,
                isLocked: (_) => !PremiumService.instance.isPremium,
                onSelected: (i) =>
                    setState(() => _icon = _icon == i ? null : i),
                onLockedTap: _unlockIcon,
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
