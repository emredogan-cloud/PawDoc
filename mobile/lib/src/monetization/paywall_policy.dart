/// When may the paywall be shown? Pure function so the trust rules are unit-tested.
///
/// Rules (roadmap §1.4 + EMERGENCY Trust Rule):
///  - NEVER during/after an EMERGENCY result,
///  - NEVER during onboarding,
///  - ONLY after the first successful analysis,
///  - at most ONCE per day,
///  - never to premium users.
class PaywallContext {
  const PaywallContext({
    required this.firstAnalysisCompleted,
    required this.lastTriageWasEmergency,
    required this.inOnboarding,
    this.lastShownAt,
    this.isPremium = false,
  });

  final bool firstAnalysisCompleted;
  final bool lastTriageWasEmergency;
  final bool inOnboarding;
  final DateTime? lastShownAt;
  final bool isPremium;
}

bool shouldShowPaywall(PaywallContext c, {DateTime? now}) {
  final at = now ?? DateTime.now();
  if (c.isPremium) return false;
  if (c.lastTriageWasEmergency) return false; // EMERGENCY is never paywalled
  if (c.inOnboarding) return false;
  if (!c.firstAnalysisCompleted) return false; // only after the first analysis
  if (c.lastShownAt != null && at.difference(c.lastShownAt!).inHours < 24) {
    return false; // at most once per day
  }
  return true;
}
