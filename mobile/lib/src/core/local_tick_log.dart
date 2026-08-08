import 'package:shared_preferences/shared_preferences.dart';

/// A set of "done" marks kept **on the device**, keyed by a namespaced string.
///
/// Two surfaces need the same thing and neither has a table behind it: the
/// medication tracker's dose ticks (`pawdoc.dose.…`) and a reminder's "Mark as
/// taken" (`pawdoc.reminder.done.…`). Adding either table is a migration plus
/// an RLS policy plus a deploy, all founder-gated.
///
/// Device-local persistence is *real* persistence — it survives restarts. It
/// just does not follow the owner to a second phone, and **every screen that
/// uses this says so in as many words**. A button whose answer is silently
/// forgotten would be worse than no button at all.
class LocalTickLog {
  const LocalTickLog(this.prefix);

  /// The key namespace this log owns. Must end in a `.` so two prefixes can
  /// never collide by being one another's stem.
  final String prefix;

  /// Every tick under [prefix], as `key -> when it was ticked`.
  Future<Map<String, DateTime>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, DateTime>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final at = DateTime.tryParse(prefs.getString(key) ?? '');
      if (at != null) out[key] = at;
    }
    return out;
  }

  static Future<void> set(String key, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, at.toIso8601String());
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// `2026-08-07` — the day part of a tick key. Two ticks on the same calendar
  /// day are the same tick unless the caller adds its own discriminator.
  static String dayKey(DateTime at) =>
      '${at.year}-${_two(at.month)}-${_two(at.day)}';

  static String _two(int v) => v.toString().padLeft(2, '0');
}
