import 'package:flutter/material.dart';
//import 'package:firebase_core/firebase_core.dart';
import 'services/premium_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //  await Firebase.initializeApp();

  // Not awaited: loads the cached Premium state, then checks Google Play in
  // the background so a slow store doesn't delay startup.
  PremiumService.instance.init();

  runApp(const ParentingHelperApp());
}
