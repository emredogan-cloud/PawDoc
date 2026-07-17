import 'package:shared_preferences/shared_preferences.dart';

/// Phase 6.3.1 — when an unauthenticated user opens a /invite/:token deep
/// link, the auth redirect bounces them to /sign-in. We capture the original
/// path here so that on successful sign-in the router can `pop()` it and
/// route directly to the invite acceptance screen without losing the token.
///
/// Parks a deep-link across the sign-in detour.
class PendingInvitePrefs {
  static const _key = 'pending_family_invite_path';

  static Future<void> capture(String path) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, path);
  }

  static Future<String?> pop() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    if (v != null) await p.remove(_key);
    return v;
  }
}
