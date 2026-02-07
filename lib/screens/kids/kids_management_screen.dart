import 'package:flutter/material.dart';

class KidsManagementScreen extends StatelessWidget {
  const KidsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kids Management")),
      body: const Center(
        child: Text("Manage children here"),
      ),
    );
  }
}
