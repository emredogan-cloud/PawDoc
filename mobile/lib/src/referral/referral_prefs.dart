import 'package:shared_preferences/shared_preferences.dart';

/// Stores a referral code captured from a deep link (https://pawdoc.app/r/CODE
/// or pawdoc://r/CODE) so it can be attributed at signup (payout logic: Phase 3.3).
class ReferralPrefs {
  static const _key = 'pawdoc.pending_referral_code';

  static Future<void> capture(String code) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, code.trim().toUpperCase());
  }

  static Future<String?> pending() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_key);
  }
}
