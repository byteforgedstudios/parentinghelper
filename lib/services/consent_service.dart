import 'package:shared_preferences/shared_preferences.dart';
import '../state/app_info.dart';

/// Records that a parent (18+) agreed to the current privacy policy.
class ConsentService {
  static const _versionKey = 'consent_policy_version';
  static const _dateKey = 'consent_date';

  Future<bool> hasCurrentConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_versionKey) == kPrivacyPolicyVersion;
  }

  Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, kPrivacyPolicyVersion);
    await prefs.setString(_dateKey, DateTime.now().toIso8601String());
  }

  Future<void> clearConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_versionKey);
    await prefs.remove(_dateKey);
  }
}
