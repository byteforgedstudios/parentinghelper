import 'package:flutter/material.dart';
import '../state/premium_content.dart';

class ChildAvatar extends StatelessWidget {
  final String? avatar;
  final double radius;

  const ChildAvatar({super.key, this.avatar, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        avatar ?? kStandardAvatar,
        style: TextStyle(fontSize: radius),
      ),
    );
  }
}
