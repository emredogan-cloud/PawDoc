/// Tests for the analytics service contracts.
///
/// The PostHog implementation needs a real plugin channel, so we don't
/// drive it here. Instead we exercise:
///   - [NoopAnalyticsService]: every method is silent and never throws
///   - [RecordingAnalyticsService]: captures events for downstream
///     controller tests
///   - The provider falls back to a Noop service when the config has
///     no PostHog key
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/app/config.dart';
import 'package:pawdoc/shared/services/analytics_events.dart';
import 'package:pawdoc/shared/services/analytics_service.dart';

void main() {
  group('NoopAnalyticsService', () {
    test('every method is silent and never throws', () async {
      const svc = NoopAnalyticsService();
      await svc.initialize();
      await svc.identify('user-1');
      await svc.resetIdentity();
      await svc.track(const RestorePurchaseEvent());
      // No assertion needed — the test is the absence of exceptions.
    });
  });

  group('RecordingAnalyticsService', () {
    test('captures events in order', () async {
      final svc = RecordingAnalyticsService();
      await svc.initialize();
      await svc.identify('user-1');
      await svc.track(const OnboardingStartedEvent());
      await svc.track(const OnboardingCompletedEvent());
      await svc.resetIdentity();

      expect(svc.initialised, isTrue);
      expect(svc.identified, ['user-1']);
      expect(svc.resetCount, 1);
      expect(
        svc.trackedEvents.map((e) => e.name),
        ['onboarding_started', 'onboarding_completed'],
      );
    });

    test('preserves event property maps', () async {
      final svc = RecordingAnalyticsService();
      await svc.track(
        const AnalysisCompletedEvent(
          triageLevel: 'NORMAL',
          tierUsed: 2,
          latencyMs: 1500,
        ),
      );
      final event = svc.trackedEvents.single;
      expect(event, isA<AnalysisCompletedEvent>());
      expect(event.properties, {
        'triage_level': 'NORMAL',
        'tier_used': 2,
        'latency_ms': 1500,
      });
    });
  });

  group('analyticsServiceProvider', () {
    test('falls back to NoopAnalyticsService when PostHog key is empty', () {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              env: AppEnv.local,
              supabaseUrl: 'http://localhost',
              supabaseAnonKey: 'anon',
              aiServiceUrl: 'http://localhost',
              sentryDsn: '',
              posthogApiKey: '',
              posthogHost: 'https://eu.posthog.com',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(analyticsServiceProvider);
      expect(svc, isA<NoopAnalyticsService>());
    });

    test('returns PostHogAnalyticsService when a key is configured', () {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              env: AppEnv.prod,
              supabaseUrl: 'http://localhost',
              supabaseAnonKey: 'anon',
              aiServiceUrl: 'http://localhost',
              sentryDsn: 'https://sentry.example/1',
              posthogApiKey: 'phc_test',
              posthogHost: 'https://eu.posthog.com',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(analyticsServiceProvider);
      expect(svc, isA<PostHogAnalyticsService>());
    });
  });
}
