import 'package:flutter/material.dart';
import 'child_avatar.dart';

class ChildProgressCard extends StatelessWidget {
  final String name;
  final String? avatar;
  final bool readOnly;
  final int completed;
  final int total;
  final int stars;
  final VoidCallback? onTap;
  final VoidCallback onRewardsTap;

  const ChildProgressCard({
    super.key,
    required this.name,
    this.avatar,
    this.readOnly = false,
    required this.completed,
    required this.total,
    required this.stars,
    required this.onTap,
    required this.onRewardsTap,
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
              Row(
                children: [
                  ChildAvatar(avatar: avatar, radius: 20),
                  const SizedBox(width: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (readOnly) ...[
                    const Spacer(),
                    const Chip(
                      avatar: Icon(Icons.lock_outline, size: 16),
                      label: Text("Read-only"),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text("$completed / $total tasks completed"),
              Text("⭐ Stars: $stars"),
              IconButton(
                icon: const Icon(Icons.card_giftcard),
                onPressed: onRewardsTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
