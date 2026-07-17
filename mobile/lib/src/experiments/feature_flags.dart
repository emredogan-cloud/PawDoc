import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Operational kill-switches only. The A/B experiment machinery (onboarding /
/// paywall / pulse-pet variants) was removed pre-launch — with no traffic there
/// is nothing to experiment on, and every variant silently served control
/// anyway. Kill-switches remain: they exist to turn a feature OFF in an
/// incident without a release, not to gate rollout.
class FeatureFlags {
  FeatureFlags({Future<Object?> Function(String key)? getFlag})
      : _getFlag = getFlag ?? ((_) async => null);

  /// Injectable so the fallback logic is unit-tested without the SDK.
  final Future<Object?> Function(String key) _getFlag;

  /// Kill-switch semantics (M2 Paw Pals — device finding D-2): the feature is
  /// ON unless the flag EXISTS and is explicitly off. PostHog's
  /// isFeatureEnabled returns false for an ABSENT flag, which would silently
  /// disable a default-on feature the founder never created a flag for. Absent
  /// flag or any PostHog failure -> ON.
  Future<bool> isEnabledUnlessKilled(String key) async {
    try {
      final value = await _getFlag(key);
      if (value == null) return true; // absent -> default ON
      if (value is bool) return value;
      final s = value.toString().toLowerCase();
      return !(s == 'false' || s == 'off' || s == 'disabled');
    } catch (_) {
      return true;
    }
  }
}

final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  return FeatureFlags(getFlag: (key) => Posthog().getFeatureFlag(key));
});
