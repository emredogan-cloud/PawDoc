import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/experiments/feature_flags.dart';

void main() {
  test('returns the resolved value when the flag loads', () async {
    expect(await FeatureFlags((_) async => true).isEnabled(FeatureFlagKeys.paywallTiming), isTrue);
    expect(await FeatureFlags((_) async => false).isEnabled('x'), isFalse);
  });

  test('falls back to CONTROL on any error (PostHog down / offline)', () async {
    final ff = FeatureFlags((_) async => throw Exception('offline'));
    expect(await ff.isEnabled('x'), isFalse); // default control
    expect(await ff.isEnabled('x', defaultValue: true), isTrue); // explicit default honored
  });

  test('flag keys + variant sets are defined', () {
    expect(FeatureFlagKeys.paywallTiming, 'paywall-timing');
    expect(FeatureFlagKeys.onboardingVariant, 'onboarding_variant');
    expect(FeatureFlagKeys.onboardingVariants, {'A', 'B'});
    expect(FeatureFlagKeys.paywallVariant, 'paywall_variant');
    expect(FeatureFlagKeys.paywallVariants, {'A', 'B', 'C'});
  });

  group('getVariant (multivariate, fail-safe to A)', () {
    FeatureFlags withFlag(Object? value) =>
        FeatureFlags((_) async => false, getFlag: (_) async => value);

    test('returns an allowed variant', () async {
      expect(await withFlag('B').getVariant(FeatureFlagKeys.paywallVariant,
          allowed: FeatureFlagKeys.paywallVariants), 'B');
      expect(await withFlag('C').getVariant(FeatureFlagKeys.paywallVariant,
          allowed: FeatureFlagKeys.paywallVariants), 'C');
    });

    test('falls back to A on null / empty / disallowed / non-string / error', () async {
      expect(await withFlag(null).getVariant('k'), 'A');
      expect(await withFlag('').getVariant('k'), 'A');
      expect(await withFlag('Z').getVariant('k', allowed: {'A', 'B'}), 'A'); // unrecognized
      expect(await withFlag(42).getVariant('k'), 'A'); // non-string
      final boom = FeatureFlags((_) async => false, getFlag: (_) async => throw Exception('offline'));
      expect(await boom.getVariant('k'), 'A'); // error -> control
    });

    test('default constructor (no getFlag) yields control A', () async {
      expect(await FeatureFlags((_) async => false).getVariant('k'), 'A');
    });
  });
}
