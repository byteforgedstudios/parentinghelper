import 'package:flutter/material.dart';
import 'package:parentinghelper/screens/add_reward_screen.dart';
import 'package:parentinghelper/screens/rewards_screen.dart';
import 'package:parentinghelper/screens/reward_history_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/add_child_screen.dart';
import 'screens/task_checklist_screen.dart';

class ParentingHelperApp extends StatelessWidget {
  const ParentingHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 24,
            ),
          ),
        ),
        
      ),
      home: const SplashScreen(),
      routes: {
        '/addChild': (context) => const AddChildScreen(),
        '/tasks': (context) => const TaskChecklistScreen(),
        '/rewards': (context) => const RewardsScreen(),
        '/addReward': (context) => const AddRewardScreen(),
        '/rewardHistory': (context) => const RewardHistoryScreen(),
      },
    );
  }
}
