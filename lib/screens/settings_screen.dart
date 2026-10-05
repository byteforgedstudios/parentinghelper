import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/consent_service.dart';
import '../services/database_service.dart';
import '../services/parental_gate.dart';
import '../services/premium_service.dart';
import '../state/app_info.dart';
import 'intro_screen.dart';
import 'premium/premium_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final premium = PremiumService.instance;
    final gate = ParentalGate.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([premium, gate]),
        builder: (context, _) => ListView(
          children: [
            const _Header('Premium'),
            ListTile(
              leading: Icon(
                Icons.workspace_premium,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(premium.isPremium ? 'Premium active' : 'Go Premium'),
              subtitle: Text(
                premium.hasSubscription
                    ? 'Unlimited children, tasks, rewards and reports'
                    : premium.accessCodeActive
                    ? 'Access code active until '
                          '${_formatDate(premium.accessCodeUntil!)}'
                    : 'Unlimited children, tasks & rewards, reports and more',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore purchases'),
              onTap: () async {
                await premium.restore();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      premium.lastError ??
                          (premium.isPremium
                              ? 'Premium restored.'
                              : 'No active subscription found.'),
                    ),
                  ),
                );
              },
            ),
            if (!premium.hasSubscription)
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Have an access code?'),
                onTap: () => _enterAccessCode(context),
              ),
            if (premium.hasSubscription)
              ListTile(
                leading: const Icon(Icons.subscriptions_outlined),
                title: const Text('Manage subscription'),
                subtitle: const Text('Change plan or cancel in Google Play'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(Uri.parse(kManageSubscriptionsUrl)),
              ),

            const _Header('Parental controls'),
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Change parent PIN'),
              onTap: () async {
                if (await gate.requireParent(context) && context.mounted) {
                  final changed = await gate.createPin(context, isChange: true);
                  if (changed && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Parent PIN changed.')),
                    );
                  }
                }
              },
            ),
            if (gate.isUnlocked)
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Lock parent mode now'),
                subtitle: const Text(
                  'Parent mode stays unlocked for 2 minutes after the PIN.',
                ),
                onTap: gate.lock,
              ),

            const _Header('Privacy'),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy policy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Delete all data'),
              subtitle: const Text(
                'Children, tasks, routines, stars, rewards and history',
              ),
              onTap: () => _deleteAllData(context),
            ),

            const _Header('Help'),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Contact support'),
              subtitle: const Text(kSupportEmail),
              onTap: () => _open(
                Uri(
                  scheme: 'mailto',
                  path: kSupportEmail,
                  query: 'subject=$kAppName support',
                ),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(kAppName),
              subtitle: Text('by $kStudioName'),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _enterAccessCode(BuildContext context) async {
    if (!await ParentalGate.instance.requireParent(
          context,
          reason: 'Enter your PIN to use an access code.',
        ) ||
        !context.mounted) {
      return;
    }

    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _AccessCodeDialog(),
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;

    final premium = PremiumService.instance;
    final ok = await premium.redeemAccessCode(code);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Premium unlocked until ${_formatDate(premium.accessCodeUntil!)}.'
              : "That access code isn't valid.",
        ),
      ),
    );
  }

  static Future<void> _open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> _deleteAllData(BuildContext context) async {
    final gate = ParentalGate.instance;
    if (!await gate.requireParent(
          context,
          reason: 'Enter your PIN to delete all data.',
        ) ||
        !context.mounted) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This permanently deletes every child, task, routine, star, reward '
          'and reward history on this device, and your parent PIN. It can\'t '
          'be undone.\n\nYour Premium subscription is not affected; cancel it '
          'in Google Play if you no longer want it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await DatabaseService().clearDatabase();
    await gate.clearPin();
    await ConsentService().clearConsent();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IntroScreen()),
      (_) => false,
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Asks for an access code. Owns its controller so it's disposed only after
/// the dialog has fully closed.
class _AccessCodeDialog extends StatefulWidget {
  const _AccessCodeDialog();

  @override
  State<_AccessCodeDialog> createState() => _AccessCodeDialogState();
}

class _AccessCodeDialogState extends State<_AccessCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Access code'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'PH-XXXX-XXXX-XXXX'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Redeem'),
        ),
      ],
    );
  }
}
