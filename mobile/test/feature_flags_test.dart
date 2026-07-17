import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/experiments/feature_flags.dart';

void main() {
  group('isEnabledUnlessKilled (operational kill-switch)', () {
    FeatureFlags withFlag(Object? v) => FeatureFlags(getFlag: (_) async => v);

    test('absent flag defaults ON (kill-switches gate incidents, not rollout)', () async {
      expect(await withFlag(null).isEnabledUnlessKilled('paw_pals_enabled'), isTrue);
    });

    test('explicit false/off/disabled kills the feature', () async {
      expect(await withFlag(false).isEnabledUnlessKilled('k'), isFalse);
      expect(await withFlag('false').isEnabledUnlessKilled('k'), isFalse);
      expect(await withFlag('off').isEnabledUnlessKilled('k'), isFalse);
      expect(await withFlag('disabled').isEnabledUnlessKilled('k'), isFalse);
    });

    test('truthy values keep the feature on', () async {
      expect(await withFlag(true).isEnabledUnlessKilled('k'), isTrue);
      expect(await withFlag('on').isEnabledUnlessKilled('k'), isTrue);
    });

    test('PostHog failure fails ON (an outage must not kill features)', () async {
      final boom = FeatureFlags(getFlag: (_) async => throw Exception('down'));
      expect(await boom.isEnabledUnlessKilled('k'), isTrue);
    });
  });
}
