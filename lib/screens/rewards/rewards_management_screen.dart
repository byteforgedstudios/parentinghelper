import 'package:flutter/material.dart';

class RewardsManagementScreen extends StatelessWidget {
  const RewardsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rewards Management")),
      body: const Center(
        child: Text("Manage rewards here"),
      ),
    );
  }
}
