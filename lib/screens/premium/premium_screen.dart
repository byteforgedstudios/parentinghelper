import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Premium Features")),
      body: const Center(
        child: Text("Upgrade to Premium"),
      ),
    );
  }
}
