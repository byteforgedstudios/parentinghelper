import 'package:flutter/material.dart';
import 'package:parentinghelper/screens/add_reward_screen.dart';
import 'package:parentinghelper/screens/rewards_screen.dart';
import 'package:parentinghelper/screens/reward_history_screen.dart';
import 'package:parentinghelper/screens/task_templates_screen.dart';
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
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),

        scaffoldBackgroundColor: const Color(0xFFF6F8FC),

        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),

        cardTheme: CardThemeData(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.deepPurple),
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
        '/taskTemplates': (context) => const TaskTemplatesScreen(),
      },
    );
  }
}
