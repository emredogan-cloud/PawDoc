import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Feature-flag keys + variant values for A/B tests. Centralized so usage is
/// grep-able and the founder knows exactly what to configure in PostHog.
class FeatureFlagKeys {
  const FeatureFlagKeys._();

  /// Boolean flag reserved earlier; kept for compatibility.
  static const String paywallTiming = 'paywall-timing';

  /// Onboarding experiment — multivariate: 'A' (control, paywall after the first
  /// analysis) | 'B' (aggressive, paywall inside onboarding). Phase 4.2.
  static const String onboardingVariant = 'onboarding_variant';
  static const Set<String> onboardingVariants = {'A', 'B'};

  /// Paywall layout experiment — 'A' (annual-first control) | 'B' (monthly
  /// featured) | 'C' (social proof). Phase 4.2.
  static const String paywallVariant = 'paywall_variant';
  static const Set<String> paywallVariants = {'A', 'B', 'C'};
}

/// Thin, RESILIENT wrapper over PostHog feature flags. Any failure — PostHog not
/// configured, network offline, SDK error — returns the CONTROL default; it
/// never throws and never blocks the UI. Bucketing is deterministic + stable
/// per user because PostHog is identified with the Supabase uid (see main.dart),
/// so a given user always lands in the same variant across sessions/devices.
class FeatureFlags {
  FeatureFlags(this._isEnabled, {Future<Object?> Function(String key)? getFlag})
      : _getFlag = getFlag ?? ((_) async => null);

  /// Injectable so the fallback logic is unit-tested without the SDK.
  final Future<bool> Function(String key) _isEnabled;
  final Future<Object?> Function(String key) _getFlag;

  Future<bool> isEnabled(String key, {bool defaultValue = false}) async {
    try {
      return await _isEnabled(key);
    } catch (_) {
      return defaultValue; // PostHog down / offline -> control group
    }
  }

  /// Multivariate variant string. Returns [defaultValue] (the CONTROL variant)
  /// when the flag is null/empty, not one of [allowed], or on ANY error —
  /// "fail-safe to control" (Phase 4.2 strict rule).
  Future<String> getVariant(
    String key, {
    String defaultValue = 'A',
    Set<String>? allowed,
  }) async {
    try {
      final value = await _getFlag(key);
      if (value is String && value.isNotEmpty && (allowed == null || allowed.contains(value))) {
        return value;
      }
      return defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }
}

final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  return FeatureFlags(
    (key) => Posthog().isFeatureEnabled(key),
    getFlag: (key) => Posthog().getFeatureFlag(key),
  );
});

/// A boolean flag's value, defaulting to control (false). Safe to `watch`.
final featureFlagProvider = FutureProvider.autoDispose.family<bool, String>((ref, key) {
  return ref.watch(featureFlagsProvider).isEnabled(key);
});
