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

  // Phase 3.1 retention events.
  static Future<void> healthEventLogged(String eventType) =>
      capture('health_event_logged', {'event_type': eventType});
  static Future<void> multiPetAdded(int petCount) =>
      capture('multi_pet_added', {'pet_count': petCount});

  // Phase 3.2 video analysis.
  static Future<void> videoAnalysisSubmitted(int frameCount) =>
      capture('video_analysis_submitted', {'frame_count': frameCount});

  // Phase 3.3 referral.
  static Future<void> referralCodeSubmitted() => capture('referral_code_submitted');
  static Future<void> referralSuccess() => capture('referral_success');
  static Future<void> referralFraudPrevented(String reason) =>
      capture('referral_fraud_prevented', {'reason': reason});

  // Phase 3.3 Part 2 — engagement.
  static Future<void> reminderSet(String reminderType) =>
      capture('reminder_set', {'reminder_type': reminderType});

  // Phase 3.4 — vet finder & health export.
  static Future<void> vetFinderOpened() => capture('vet_finder_opened');
  static Future<void> vetCalled() => capture('vet_called');
  static Future<void> healthReportExported() => capture('health_report_exported');
}
