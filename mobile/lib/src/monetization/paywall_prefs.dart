import 'package:shared_preferences/shared_preferences.dart';

/// Persists the bits the paywall trust-rule needs across launches.
class PaywallPrefs {
  static const _kFirst = 'pawdoc.first_analysis_completed';
  static const _kLastShown = 'pawdoc.paywall_last_shown';

  /// Returns true exactly once — when this call flipped the flag (M3 #17:
  /// the one-time-ever "story has begun" toast keys off it).
  static Future<bool> markFirstAnalysisCompleted() async {
    final p = await SharedPreferences.getInstance();
    final wasCompleted = p.getBool(_kFirst) ?? false;
    await p.setBool(_kFirst, true);
    return !wasCompleted;
  }

  static Future<bool> firstAnalysisCompleted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kFirst) ?? false;
  }

  static Future<void> markPaywallShown(DateTime at) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLastShown, at.toIso8601String());
  }

  static Future<DateTime?> lastShownAt() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kLastShown);
    return s == null ? null : DateTime.tryParse(s);
  }
}
