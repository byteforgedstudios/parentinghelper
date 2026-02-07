import 'package:flutter/material.dart';
//import 'package:firebase_core/firebase_core.dart';
import 'services/database_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = DatabaseService();
  await db.dailyResetIfNeeded();

  //  await Firebase.initializeApp();
  runApp(const ParentingHelperApp());
}
