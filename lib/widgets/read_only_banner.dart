import 'package:flutter/material.dart';

/// Shown on children and screens that became read-only after Premium ended.
class ReadOnlyBanner extends StatelessWidget {
  final String message;
  final VoidCallback onUpgrade;

  const ReadOnlyBanner({
    super.key,
    required this.message,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: Colors.amber.shade50,
      leading: const Icon(Icons.lock_outline),
      content: Text(message),
      actions: [TextButton(onPressed: onUpgrade, child: const Text("Upgrade"))],
    );
  }
}
