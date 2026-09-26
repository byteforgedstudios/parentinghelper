import 'package:flutter/material.dart';
import '../../services/premium_service.dart';
import '../paywall_screen.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final premium = PremiumService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text("Premium")),
      body: ListenableBuilder(
        listenable: premium,
        builder: (context, _) => premium.isPremium
            ? const _PremiumActive()
            : const PaywallContent(trigger: PaywallTrigger.general),
      ),
    );
  }
}

class _PremiumActive extends StatelessWidget {
  const _PremiumActive();

  static const _features = [
    (Icons.family_restroom, "Unlimited children"),
    (Icons.checklist, "Unlimited tasks every day"),
    (Icons.card_giftcard, "Unlimited rewards"),
    (Icons.face, "All avatars"),
    (Icons.emoji_emotions, "Reward icons"),
    (Icons.insights, "Weekly & monthly reports with streaks"),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.workspace_premium, size: 72, color: colors.primary),
        const SizedBox(height: 12),
        Text(
          "You're Premium! 🎉",
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "Thanks for supporting Parenting Helper.",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ..._features.map(
          (f) => ListTile(
            leading: Icon(f.$1, color: colors.primary),
            title: Text(f.$2),
            trailing: const Icon(Icons.check, color: Colors.green),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Manage or cancel your subscription in Google Play > "
          "Payments & subscriptions.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
