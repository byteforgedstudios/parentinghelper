import 'package:flutter/foundation.dart';
import '../models/child.dart';

class AppState extends ChangeNotifier {
  Child? selectedChild;
  bool isPremium = false;

  void selectChild(Child child) {
    selectedChild = child;
    notifyListeners();
  }
}
