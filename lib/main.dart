import 'package:flutter/material.dart';
//rimport 'package:firebase_core/firebase_core.dart';
import 'app.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
//  await Firebase.initializeApp();
  runApp(const ParentingHelperApp());
}
