import 'package:shared_preferences/shared_preferences.dart';

import 'offer_policy.dart';

/// The memory behind [offerSurfaceFor] — the half that makes "no" mean
/// something.
///
/// Two values per surface, both write-once-forward:
///
/// * **when it was last shown**, so the cooldown is a real gap rather than a
///   session-scoped one, and
/// * **how many times it has ever been shown**, which only ever increases.
///
/// Neither is cleared on dismissal, on reopening the surface, or on a new
/// launch. A counter that a user can reset by backing out is not a cap; a
/// deadline that restarts when the sheet reopens is the fake-urgency pattern
/// this module exists to avoid. The only thing that resets them is
/// [clearAll], which the account-switch path calls so one person's dismissals
/// are not charged to the next account on the device.
class OfferPrefs {
  const OfferPrefs._();

  static String _lastShownKey(OfferSurface s) => 'pawdoc.offer.${s.name}.last';
  static String _countKey(OfferSurface s) => 'pawdoc.offer.${s.name}.count';

  static Future<DateTime?> lastShownAt(OfferSurface surface) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_lastShownKey(surface));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<int> timesShown(OfferSurface surface) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_countKey(surface)) ?? 0;
  }

  /// Records a showing. Called when the surface is actually put on screen —
  /// never when it is merely considered, or the cap would be spent by
  /// eligibility checks the user never saw.
  static Future<void> markShown(OfferSurface surface, DateTime at) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_lastShownKey(surface), at.toIso8601String());
    await p.setInt(_countKey(surface), (p.getInt(_countKey(surface)) ?? 0) + 1);
  }

  /// Wipes both counters for every surface.
  ///
  /// Sign-out only. The prompt history belongs to the account, not the handset,
  /// and this device has already carried one cross-account bleed-through bug
  /// (the frozen `currentUserIdProvider`).
  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    for (final s in OfferSurface.values) {
      await p.remove(_lastShownKey(s));
      await p.remove(_countKey(s));
    }
  }
}
