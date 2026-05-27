import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Feature-flag keys for A/B tests. Centralized so usage is grep-able.
class FeatureFlagKeys {
  const FeatureFlagKeys._();

  /// Varies paywall timing. Infrastructure only here — the first real use lands
  /// in Phase 4.2; reading it must never change the EMERGENCY/trust rules.
  static const String paywallTiming = 'paywall-timing';
}

/// Thin, RESILIENT wrapper over PostHog feature flags. Any failure — PostHog not
/// configured, network offline, SDK error — returns the CONTROL default; it
/// never throws and never blocks the UI. Bucketing is deterministic + stable
/// per user because PostHog is identified with the Supabase uid (see main.dart),
/// so a given user always lands in the same variant across sessions/devices.
class FeatureFlags {
  FeatureFlags(this._isEnabled);

  /// Injectable so the fallback logic is unit-tested without the SDK.
  final Future<bool> Function(String key) _isEnabled;

  Future<bool> isEnabled(String key, {bool defaultValue = false}) async {
    try {
      return await _isEnabled(key);
    } catch (_) {
      return defaultValue; // PostHog down / offline -> control group
    }
  }
}

final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  return FeatureFlags((key) => Posthog().isFeatureEnabled(key));
});

/// A single flag's value, defaulting to control (false). Safe to `watch` in a
/// widget — errors resolve to the control default, never an error state.
final featureFlagProvider = FutureProvider.autoDispose.family<bool, String>((ref, key) {
  return ref.watch(featureFlagsProvider).isEnabled(key);
});
