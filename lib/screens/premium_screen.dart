import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Upgrade to Premium",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text("• Unlimited children"),
          Text("• Advanced reward analytics"),
          Text("• Custom themes"),
          Text("• Cloud backup"),
        ],
      ),
    );
  }
}
