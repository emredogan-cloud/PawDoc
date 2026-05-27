import 'package:shared_preferences/shared_preferences.dart';

/// Local "snooze" so the 72h follow-up banner doesn't nag every launch when the
/// user taps "Not now". (Answering an outcome removes eligibility server-side.)
class FollowUpPrefs {
  static const _key = 'pawdoc.followup_snoozed_until';

  static Future<void> snooze(Duration duration) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, DateTime.now().add(duration).toIso8601String());
  }

  static Future<bool> isSnoozed() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    if (s == null) return false;
    final until = DateTime.tryParse(s);
    return until != null && DateTime.now().isBefore(until);
  }
}
