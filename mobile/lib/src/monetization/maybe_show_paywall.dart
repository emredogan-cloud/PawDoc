import 'package:flutter/material.dart';

import 'paywall_policy.dart';
import 'paywall_prefs.dart';
import 'paywall_screen.dart';

/// Applies the trust rule and shows the paywall at most once/day, after the
/// first analysis, never for an emergency, never to premium users.
Future<void> maybeShowPaywall(
  BuildContext context, {
  required bool lastTriageWasEmergency,
  required bool isPremium,
}) async {
  final ctx = PaywallContext(
    firstAnalysisCompleted: await PaywallPrefs.firstAnalysisCompleted(),
    lastTriageWasEmergency: lastTriageWasEmergency,
    inOnboarding: false,
    lastShownAt: await PaywallPrefs.lastShownAt(),
    isPremium: isPremium,
  );
  if (!shouldShowPaywall(ctx)) return;
  await PaywallPrefs.markPaywallShown(DateTime.now());
  if (context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
  }
}
