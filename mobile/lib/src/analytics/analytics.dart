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
}
