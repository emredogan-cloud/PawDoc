/// **Reading a Google Play subscription offer, and refusing to invent one.**
///
/// Google Play's model is three levels deep: a *subscription product* holds
/// *base plans*, and a base plan holds *offers*. RevenueCat surfaces the whole
/// tree on `StoreProduct.subscriptionOptions` — one [SubscriptionOption] per
/// base plan (`isBasePlan == true`) plus one per offer, each carrying the
/// `tags` typed into the Play Console and the exact `pricingPhases` Google will
/// charge.
///
/// ## Why offers are selected by tag, and why eligibility is ours
///
/// Play supports exactly three offer eligibility criteria: **New customer
/// acquisition**, **Upgrade**, and **Developer determined**. There is no
/// "win-back" criterion. Google filters the first two out of
/// `subscriptionOptions` when the user does not qualify; a *Developer
/// determined* offer is **always** returned, and deciding who may see it is
/// entirely the app's job.
///
/// That is the whole mechanism PawDoc's win-back and second-chance offers use,
/// and it is why [SubscriberPhase] exists: Play will happily sell a "come back"
/// discount to somebody who never left. The tag is how we find the offer; the
/// phase is how we decide whether anyone may see it.
///
/// > The iOS `WinBackOffer` type in this SDK is StoreKit-only
/// > (`getEligibleWinBackOffersForPackage` is documented "iOS only") and has no
/// > part in an Android build.
///
/// ## Why nothing here has a fallback
///
/// Every getter below returns null rather than a plausible default. A win-back
/// screen that renders when no win-back offer is configured would print a
/// discount nobody can buy — the *"unconfigured product presented as
/// purchasable"* failure. Null means the surface does not render at all.
library;

import 'package:purchases_flutter/purchases_flutter.dart';


/// The Play Console **offer tag** that marks the win-back offer.
///
/// Founder-typed, in Play Console → Monetize with Play → Products →
/// Subscriptions → *(subscription)* → *(base plan)* → Add offer → Tags. The
/// string must match character for character; nothing else identifies the
/// offer, because offer IDs are per-base-plan and would drift.
const String kWinBackOfferTag = 'pawdoc-winback';

/// The Play Console offer tag for the second-chance offer shown after a free
/// trial ended without converting.
const String kSecondChanceOfferTag = 'pawdoc-second-chance';

/// RevenueCat's own tag for "never auto-apply this offer to the package price".
///
/// Without it the SDK may pick a tagged offer as the default option for the
/// package, so the ordinary paywall would quietly print the win-back price to
/// everybody. Both PawDoc offers must carry it alongside their own tag.
const String kIgnoreOfferTag = 'rc-ignore-offer';

/// One purchasable Play offer, with only the facts the store supplied.
class StoreOffer {
  const StoreOffer({required this.option, required this.basePlan});

  /// The offer itself — what [PurchaseParams.subscriptionOption] is given.
  final SubscriptionOption option;

  /// The base plan the offer discounts. The comparison basis for any
  /// percentage, and the price that applies once the offer phases end.
  final SubscriptionOption basePlan;

  /// The store's own formatted price for the ongoing (post-offer) charge, e.g.
  /// `"₺299,99"`. Never computed here.
  String? get standardPriceString => basePlan.fullPricePhase?.price.formatted;

  /// The introductory phases, in the order Google will charge them. Excludes
  /// the trailing full-price phase, which is the standard price.
  List<PricingPhase> get introPhases {
    final phases = option.pricingPhases;
    if (phases.isEmpty) return const [];
    // The last phase of an offer is the ongoing full-price one whenever it
    // recurs indefinitely; anything before it is the offer.
    final last = phases.last;
    final ongoing = last.recurrenceMode == RecurrenceMode.infiniteRecurring;
    return ongoing ? phases.sublist(0, phases.length - 1) : phases;
  }

  /// True when Google will charge nothing for the first phase.
  bool get startsFree =>
      option.freePhase != null ||
      introPhases.any((p) => p.price.amountMicros == 0);

  /// The discount this offer applies to its base plan, as a whole percentage —
  /// **or null, which means print no percentage at all.**
  ///
  /// A percentage is only produced when every leg of the comparison is real:
  ///
  ///   * the offer has a paid introductory phase (a free trial is not a
  ///     percentage — it is a free trial, and says so),
  ///   * that phase and the base plan are priced in the **same currency**
  ///     (cross-currency arithmetic needs a rate we do not have),
  ///   * they cover the **same billing period** (a month at a discount versus
  ///     a year at full price is not a comparison, it is a trick),
  ///   * the base price is positive, and
  ///   * the offer is genuinely cheaper, by at least one percent.
  ///
  /// Anything else returns null. There is no rounding-up, no "up to", and no
  /// comparison against a price the store did not quote.
  int? get discountPercent {
    final full = basePlan.fullPricePhase;
    if (full == null || full.price.amountMicros <= 0) return null;
    final paid = introPhases
        .where((p) => p.price.amountMicros > 0)
        .toList(growable: false);
    if (paid.isEmpty) return null;
    final intro = paid.first;
    if (intro.price.currencyCode != full.price.currencyCode) return null;
    if (intro.billingPeriod?.iso8601 != full.billingPeriod?.iso8601) return null;
    if (intro.price.amountMicros >= full.price.amountMicros) return null;
    final pct =
        ((1 - intro.price.amountMicros / full.price.amountMicros) * 100).round();
    return pct >= 1 ? pct : null;
  }

  /// The offer in one sentence, built from the store's own numbers.
  ///
  /// Examples of what this produces, given what Play returned:
  ///   * `"7 days free, then ₺299,99 / year"`
  ///   * `"3 months at ₺74,99 / month, then ₺149,99 / month"`
  ///   * `"₺99,99 once for the first 3 months, then ₺149,99 / month"`
  ///
  /// Returns null when the phases cannot be described exactly — at which point
  /// the caller shows the Play purchase sheet's own wording instead of writing
  /// its own, which is the correct degradation.
  String? get termsSentence {
    final parts = <String>[];
    for (final phase in introPhases) {
      final leg = describePricingPhase(phase);
      if (leg == null) return null;
      parts.add(leg);
    }
    if (parts.isEmpty) return null;
    final standard = _ongoingLeg();
    return standard == null
        ? '${parts.join(', ')}.'
        : '${parts.join(', ')}, then $standard.';
  }

  String? _ongoingLeg() {
    final full = basePlan.fullPricePhase ?? option.pricingPhases.lastOrNull;
    if (full == null) return null;
    final per = periodWords(full.billingPeriod);
    return per == null
        ? full.price.formatted
        : '${full.price.formatted} / $per';
  }
}

/// Finds the base plan among a product's options — the one Google marks
/// `isBasePlan`, which is the only price that applies with no offer.
SubscriptionOption? basePlanOf(StoreProduct product) {
  for (final o in product.subscriptionOptions ?? const <SubscriptionOption>[]) {
    if (o.isBasePlan) return o;
  }
  return null;
}

/// Finds the offer carrying [tag], paired with its base plan.
///
/// Returns null when the tag is not present — which is the ordinary state
/// before the founder creates the offer in Play Console, and the state in which
/// no offer surface may render.
StoreOffer? findTaggedOffer(StoreProduct? product, String tag) {
  if (product == null) return null;
  final base = basePlanOf(product);
  if (base == null) return null;
  for (final o in product.subscriptionOptions ?? const <SubscriptionOption>[]) {
    if (!o.isBasePlan && o.tags.contains(tag)) {
      return StoreOffer(option: o, basePlan: base);
    }
  }
  return null;
}

/// One pricing phase in words, or null when it cannot be stated exactly.
String? describePricingPhase(PricingPhase phase) {
  final per = periodWords(phase.billingPeriod);
  final count = phase.billingCycleCount ?? 1;

  if (phase.price.amountMicros == 0) {
    final span = periodSpan(phase.billingPeriod, count);
    return span == null ? null : '$span free';
  }

  switch (phase.recurrenceMode) {
    case RecurrenceMode.nonRecurring:
      final span = periodSpan(phase.billingPeriod, count);
      return span == null
          ? phase.price.formatted
          : '${phase.price.formatted} once for the first $span';
    case RecurrenceMode.finiteRecurring:
      if (per == null) return null;
      final span = periodSpan(phase.billingPeriod, count);
      return span == null
          ? '${phase.price.formatted} / $per'
          : '$span at ${phase.price.formatted} / $per';
    case RecurrenceMode.infiniteRecurring:
      return per == null
          ? phase.price.formatted
          : '${phase.price.formatted} / $per';
    case RecurrenceMode.unknown:
    case null:
      return null;
  }
}

/// "week" / "month" / "year" for a single billing period, or null when the
/// store did not tell us — in which case nothing gets invented.
String? periodWords(Period? period) {
  if (period == null) return null;
  if (period.value != 1) {
    final plural = _unitWord(period.unit);
    return plural == null ? null : '${period.value} ${plural}s';
  }
  return _unitWord(period.unit);
}

/// "7 days", "3 months" — a span of [count] billing periods, or null.
String? periodSpan(Period? period, int count) {
  if (period == null) return null;
  final unit = _unitWord(period.unit);
  if (unit == null) return null;
  final total = period.value * count;
  return total == 1 ? '1 $unit' : '$total ${unit}s';
}

String? _unitWord(PeriodUnit unit) => switch (unit) {
      PeriodUnit.day => 'day',
      PeriodUnit.week => 'week',
      PeriodUnit.month => 'month',
      PeriodUnit.year => 'year',
      PeriodUnit.unknown => null,
    };
