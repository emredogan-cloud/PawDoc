import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/monetization/paywall_policy.dart';

void main() {
  final now = DateTime(2026, 5, 27, 12);

  PaywallContext ctx({
    bool first = true,
    bool emergency = false,
    bool onboarding = false,
    DateTime? lastShown,
    bool premium = false,
  }) =>
      PaywallContext(
        firstAnalysisCompleted: first,
        lastTriageWasEmergency: emergency,
        inOnboarding: onboarding,
        lastShownAt: lastShown,
        isPremium: premium,
      );

  test('shows after the first analysis when otherwise eligible', () {
    expect(shouldShowPaywall(ctx(), now: now), isTrue);
  });

  test('NEVER shows during/after an EMERGENCY', () {
    expect(shouldShowPaywall(ctx(emergency: true), now: now), isFalse);
  });

  test('NEVER shows during onboarding', () {
    expect(shouldShowPaywall(ctx(onboarding: true), now: now), isFalse);
  });

  test('only after the first analysis', () {
    expect(shouldShowPaywall(ctx(first: false), now: now), isFalse);
  });

  test('at most once per day', () {
    expect(shouldShowPaywall(ctx(lastShown: now.subtract(const Duration(hours: 3))), now: now), isFalse);
    expect(shouldShowPaywall(ctx(lastShown: now.subtract(const Duration(hours: 25))), now: now), isTrue);
  });

  test('never for premium users', () {
    expect(shouldShowPaywall(ctx(premium: true), now: now), isFalse);
  });
}
