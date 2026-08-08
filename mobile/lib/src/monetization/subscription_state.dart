import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../account/user_profile.dart' show kEntitlementProbeTimeout;
import '../config/env.dart';

/// What the store says about this account's subscription — and nothing else.
///
/// `premium_home` draws **"Yearly Plan · Active · Next billing date: May 24,
/// 2027"**. Every one of those three facts is real and readable; none of them
/// may be assumed. So this snapshot carries exactly what RevenueCat returned,
/// with a [readable] flag for the case that matters most in practice: the SDK
/// is not configured in this build (dev, tests, any build without a public
/// key), in which case the plan card must say *"we could not read your plan"*
/// rather than draw a plausible one.
class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.readable,
    this.active = false,
    this.planLabel,
    this.renewsAt,
    this.willRenew = false,
    this.inTrial = false,
    this.hasBillingIssue = false,
  });

  /// The one honest state for "the store could not be asked".
  static const unreadable = SubscriptionSnapshot(readable: false);

  /// False when the SDK is unconfigured or the probe failed.
  final bool readable;

  final bool active;

  /// "Annual", "Monthly", or null when the period cannot be told from the
  /// product identifier. Never guessed from price.
  final String? planLabel;

  /// `expirationDate` — the next charge when [willRenew], the end of access
  /// when not. The card labels it accordingly rather than always calling it a
  /// billing date, because after a cancellation it is the opposite.
  final DateTime? renewsAt;

  final bool willRenew;

  /// `periodType == PeriodType.trial` — the ONLY thing that entitles any
  /// surface to use the word "trial".
  final bool inTrial;

  /// RevenueCat saw a billing problem. Worth surfacing: the subscription is
  /// still active but is about to stop being.
  final bool hasBillingIssue;
}

/// Reads the period out of a store product identifier.
///
/// Deliberately conservative: it recognises the suffixes RevenueCat products
/// are conventionally named with and returns null otherwise. A wrong plan name
/// on a billing card is worse than no plan name.
String? planLabelFor(String productIdentifier) {
  final id = productIdentifier.toLowerCase();
  if (id.contains('annual') || id.contains('yearly') || id.contains('year')) {
    return 'Annual';
  }
  if (id.contains('monthly') || id.contains('month')) return 'Monthly';
  if (id.contains('weekly') || id.contains('week')) return 'Weekly';
  return null;
}

/// The store's view of this account. Never throws; never hangs — an
/// unconfigured SDK does not reject, it simply never answers, which is what
/// stranded the subscription tile on a Redmi in the internal-test batch.
final subscriptionSnapshotProvider =
    FutureProvider.autoDispose<SubscriptionSnapshot>((ref) async {
  if (!Env.hasRevenueCat) return SubscriptionSnapshot.unreadable;
  try {
    final info =
        await Purchases.getCustomerInfo().timeout(kEntitlementProbeTimeout);
    final active = info.entitlements.active.values.firstOrNull;
    if (active == null) {
      return const SubscriptionSnapshot(readable: true, active: false);
    }
    return SubscriptionSnapshot(
      readable: true,
      active: true,
      planLabel: planLabelFor(active.productIdentifier),
      renewsAt: DateTime.tryParse(active.expirationDate ?? ''),
      willRenew: active.willRenew,
      inTrial: active.periodType == PeriodType.trial,
      hasBillingIssue: active.billingIssueDetectedAt != null,
    );
  } catch (_) {
    return SubscriptionSnapshot.unreadable;
  }
});
