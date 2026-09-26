import 'package:flutter/material.dart';

/// A reward's emoji icon, or the default gift icon when it has none.
class RewardIcon extends StatelessWidget {
  final String? icon;
  final double radius;

  const RewardIcon({super.key, this.icon, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.amber,
      child: icon == null
          ? Icon(Icons.card_giftcard, color: Colors.white, size: radius)
          : Text(icon!, style: TextStyle(fontSize: radius)),
    );
  }
}
