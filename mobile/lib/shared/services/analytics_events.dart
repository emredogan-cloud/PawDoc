/// Typed event hierarchy for product analytics.
///
/// Every Phase-1 PostHog event is represented as a subclass of
/// [AnalyticsEvent]. The hierarchy is **sealed** so the type system tells
/// us when we've forgotten to map a new event in a service implementation
/// or a test, and so the privacy-contract test in
/// `test/analytics_events_test.dart` can enumerate every event by walking
/// the sealed sub-types.
///
/// Privacy contract:
///   - No event property may carry email, raw text descriptions, raw
///     image bytes, storage keys, or pet names.
///   - Properties are restricted to enums, counts, durations, booleans,
///     and category strings (e.g., species/breed are categories — pet
///     name is not).
/// =============================================================================
library;

import 'package:flutter/foundation.dart';

/// Base class. Concrete events override [name] and (optionally)
/// [properties]. Constructors are `const` so events are cheap to build at
/// the call site and the linter can flag mutation accidents.
@immutable
sealed class AnalyticsEvent {
  const AnalyticsEvent();

  /// snake_case event identifier sent to PostHog.
  String get name;

  /// Properties accompanying the event. Default: none. Implementations
  /// MUST NOT include PII per the class-level contract.
  Map<String, Object?> get properties => const {};
}

/// Auth succeeded — either method.
class AuthCompletedEvent extends AnalyticsEvent {
  const AuthCompletedEvent({required this.method});
  final AuthMethod method;
  @override
  String get name => 'auth_completed';
  @override
  Map<String, Object?> get properties => {'method': method.value};
}

enum AuthMethod {
  emailOtp('email_otp'),
  apple('apple');

  const AuthMethod(this.value);
  final String value;
}

/// Fired the first time the onboarding flow records *any* user input.
class OnboardingStartedEvent extends AnalyticsEvent {
  const OnboardingStartedEvent();
  @override
  String get name => 'onboarding_started';
}

/// Fired when the onboarding draft is successfully submitted and cleared.
class OnboardingCompletedEvent extends AnalyticsEvent {
  const OnboardingCompletedEvent();
  @override
  String get name => 'onboarding_completed';
}

/// A new pet row was inserted in `public.pets`.
class PetCreatedEvent extends AnalyticsEvent {
  const PetCreatedEvent({required this.species});
  // Species is a fixed enum — safe category.
  final String species;
  @override
  String get name => 'pet_created';
  @override
  Map<String, Object?> get properties => {'species': species};
}

/// User picked an image and the controller transitioned to Uploading.
class UploadStartedEvent extends AnalyticsEvent {
  const UploadStartedEvent({required this.inputType});
  // photo | text — never the file path or storage key.
  final String inputType;
  @override
  String get name => 'upload_started';
  @override
  Map<String, Object?> get properties => {'input_type': inputType};
}

/// Image upload to R2 finished.
class UploadCompletedEvent extends AnalyticsEvent {
  const UploadCompletedEvent({required this.durationMs});
  final int durationMs;
  @override
  String get name => 'upload_completed';
  @override
  Map<String, Object?> get properties => {'duration_ms': durationMs};
}

/// /analyze edge-function request was dispatched.
class AnalysisRequestedEvent extends AnalyticsEvent {
  const AnalysisRequestedEvent({required this.inputType});
  final String inputType;
  @override
  String get name => 'analysis_requested';
  @override
  Map<String, Object?> get properties => {'input_type': inputType};
}

/// Analysis came back successfully.
class AnalysisCompletedEvent extends AnalyticsEvent {
  const AnalysisCompletedEvent({
    required this.triageLevel,
    required this.tierUsed,
    required this.latencyMs,
  });
  final String triageLevel; // EMERGENCY|MONITOR|NORMAL
  final int? tierUsed;
  final int latencyMs;
  @override
  String get name => 'analysis_completed';
  @override
  Map<String, Object?> get properties => {
    'triage_level': triageLevel,
    'tier_used': tierUsed,
    'latency_ms': latencyMs,
  };
}

/// /analyze failed — typed reason only.
class AnalysisFailedEvent extends AnalyticsEvent {
  const AnalysisFailedEvent({required this.kind});
  final String kind; // AnalyzeFailureKind.name
  @override
  String get name => 'analysis_failed';
  @override
  Map<String, Object?> get properties => {'kind': kind};
}

/// A result with `EMERGENCY` triage level was rendered to the user.
class EmergencyResultSeenEvent extends AnalyticsEvent {
  const EmergencyResultSeenEvent();
  @override
  String get name => 'emergency_result_seen';
}

/// Paywall reached the Ready state (user can now see plans).
class PaywallSeenEvent extends AnalyticsEvent {
  const PaywallSeenEvent({required this.offeringId});
  final String offeringId;
  @override
  String get name => 'paywall_seen';
  @override
  Map<String, Object?> get properties => {'offering_id': offeringId};
}

/// Purchase succeeded. We deliberately do NOT log the raw price or
/// receipt — RevenueCat is the authoritative source for that.
class SubscriptionStartedEvent extends AnalyticsEvent {
  const SubscriptionStartedEvent({required this.packageId});
  final String packageId;
  @override
  String get name => 'subscription_started';
  @override
  Map<String, Object?> get properties => {'package_id': packageId};
}

/// Restore purchases succeeded.
class RestorePurchaseEvent extends AnalyticsEvent {
  const RestorePurchaseEvent();
  @override
  String get name => 'restore_purchase';
}

/// Convenience: all concrete event constructors used in tests + audits.
/// Update when adding a new event class.
const Iterable<AnalyticsEvent> kAllAnalyticsEventSamples = [
  AuthCompletedEvent(method: AuthMethod.emailOtp),
  OnboardingStartedEvent(),
  OnboardingCompletedEvent(),
  PetCreatedEvent(species: 'dog'),
  UploadStartedEvent(inputType: 'photo'),
  UploadCompletedEvent(durationMs: 123),
  AnalysisRequestedEvent(inputType: 'photo'),
  AnalysisCompletedEvent(
    triageLevel: 'NORMAL',
    tierUsed: 2,
    latencyMs: 800,
  ),
  AnalysisFailedEvent(kind: 'network'),
  EmergencyResultSeenEvent(),
  PaywallSeenEvent(offeringId: 'pawdoc_premium'),
  SubscriptionStartedEvent(packageId: 'annual'),
  RestorePurchaseEvent(),
];
