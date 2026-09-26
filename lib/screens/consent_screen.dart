import 'package:flutter/material.dart';
import '../services/consent_service.dart';
import '../services/parental_gate.dart';
import 'app_shell.dart';
import 'privacy_policy_screen.dart';

/// Asks a parent or guardian (18+) to agree to the privacy policy before
/// the app is used (COPPA/GDPR), then to set a parent PIN.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _isParent = false;
  bool _agreesToPolicy = false;

  Future<void> _continue() async {
    await ConsentService().recordConsent();
    if (!mounted) return;

    if (!await ParentalGate.instance.hasPin() && mounted) {
      await ParentalGate.instance.createPin(context);
    }
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.family_restroom,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              "Before you start",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Parenting Helper is for parents and guardians to manage "
              "their children's routines and rewards.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const _Point(
              icon: Icons.phone_android,
              text: "Everything you enter stays on this device.",
            ),
            const _Point(
              icon: Icons.block,
              text: "No account, no ads, no tracking.",
            ),
            const _Point(
              icon: Icons.badge_outlined,
              text: "Only enter your child's first name or a nickname.",
            ),
            const _Point(
              icon: Icons.lock_outline,
              text: "A parent PIN keeps rewards, purchases and settings safe.",
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _isParent,
              onChanged: (v) => setState(() => _isParent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                "I am a parent or legal guardian aged 18 or over.",
              ),
            ),
            CheckboxListTile(
              value: _agreesToPolicy,
              onChanged: (v) => setState(() => _agreesToPolicy = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text("I have read and agree to the Privacy Policy."),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.description_outlined),
                label: const Text("Read the Privacy Policy"),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isParent && _agreesToPolicy ? _continue : null,
              child: const Text("Agree and continue"),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Point({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
