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

  test('flag keys are defined', () {
    expect(FeatureFlagKeys.paywallTiming, 'paywall-timing');
  });
}
