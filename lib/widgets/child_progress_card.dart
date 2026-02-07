import 'package:flutter/material.dart';

class ChildProgressCard extends StatelessWidget {
  final String name;
  final int completed;
  final int total;
  final int stars;
  final VoidCallback? onTap;

  const ChildProgressCard({
    super.key,
    required this.name,
    required this.completed,
    required this.total,
    required this.stars,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    double progress = total == 0 ? 0 : completed / total;

    return InkWell(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text("$completed / $total tasks completed"),
              Text("⭐ Stars: $stars"),
            ],
          ),
        ),
      ),
    );
  }
}
