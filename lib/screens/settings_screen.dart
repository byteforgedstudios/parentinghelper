import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.child_care),
            title: Text('Manage Children'),
          ),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('Upgrade to Premium'),
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
