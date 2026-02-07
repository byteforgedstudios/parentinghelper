import 'package:flutter/material.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.star, size: 64, color: Colors.amber),
            SizedBox(height: 12),
            Text('Stars earned today: 3',
                style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
