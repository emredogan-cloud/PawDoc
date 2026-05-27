import 'package:posthog_flutter/posthog_flutter.dart';

/// Thin PostHog wrapper. Analytics must never break the UX, so every call is
/// best-effort (failures are swallowed).
class Analytics {
  const Analytics._();

  static Future<void> capture(String event, [Map<String, Object>? properties]) async {
    try {
      await Posthog().capture(eventName: event, properties: properties);
    } catch (_) {
      // ignore: analytics is non-critical
    }
  }

  static Future<void> onboardingStepCompleted(int step, String screen) =>
      capture('onboarding_step_completed', {'step': step, 'screen': screen});

  static Future<void> onboardingCompleted() => capture('onboarding_completed');

  // Phase 1.4 key-action events.
  static Future<void> analysisSubmitted(String inputType) =>
      capture('analysis_submitted', {'input_type': inputType});
  static Future<void> analysisCompleted(String triageLevel, [int? tierUsed]) =>
      capture('analysis_completed', {
        'triage_level': triageLevel,
        'tier_used': ?tierUsed,
      });
  static Future<void> resultViewed(String triageLevel) =>
      capture('result_viewed', {'triage_level': triageLevel});
  static Future<void> emergencyTriggered() => capture('emergency_triggered');
  static Future<void> paywallShown() => capture('paywall_shown');
  static Future<void> trialStarted() => capture('trial_started');
  static Future<void> subscriptionConverted() => capture('subscription_converted');
}
