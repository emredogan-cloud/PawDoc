import 'package:shared_preferences/shared_preferences.dart';

/// Consent state (evolution Phase 7 / I2).
///
/// The privacy policy names CONSENT as the legal basis for product analytics —
/// so consent must actually exist: analytics are OFF until the user opts in
/// (signup checkbox or the Account toggle), and the choice is revocable at
/// any time. Crash reporting (Sentry, PII-stripped) is separate and disclosed
/// as legitimate interest.
class ConsentPrefs {
  static const _analyticsKey = 'pawdoc.analytics_consent';

  /// Default FALSE — no consent until an affirmative act.
  static Future<bool> analyticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_analyticsKey) ?? false;
  }

  static Future<void> setAnalyticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsKey, enabled);
  }
}
