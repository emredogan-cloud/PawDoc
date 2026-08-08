/// The store reads behind the offer surfaces, and the one place they are joined.
///
/// Both calls below are bounded and both are skipped entirely when the SDK was
/// never configured. `Purchases.getOfferings()` and `getCustomerInfo()` on an
/// unconfigured SDK do not reject — they never answer, which has already
/// stranded two screens in this app on their placeholders (the subscription
/// tile on a Redmi, then the paywall's price read). Same shape, same guard.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../account/user_profile.dart' show kEntitlementProbeTimeout;
import '../config/env.dart';
import 'offer_policy.dart';
import 'offer_prefs.dart';
import 'store_offer.dart';
import 'subscriber_phase.dart';


/// What the store says about this account's history with PawDoc.
final subscriberSnapshotProvider =
    FutureProvider.autoDispose<SubscriberSnapshot>((ref) async {
  if (!Env.hasRevenueCat) return SubscriberSnapshot.unknown;
  try {
    final info =
        await Purchases.getCustomerInfo().timeout(kEntitlementProbeTimeout);
    return subscriberPhaseFrom(info.entitlements.all);
  } catch (_) {
    return SubscriberSnapshot.unknown;
  }
});

/// An offer that may actually be shown: the surface, the Play offer backing it,
/// and the package it is bought through.
///
/// Every field is non-null by construction, so a screen holding one of these
/// cannot render a price it does not have.
class OfferCandidate {
  const OfferCandidate({
    required this.surface,
    required this.offer,
    required this.package,
    required this.snapshot,
  });

  final OfferSurface surface;
  final StoreOffer offer;

  /// The package the offer hangs off. `Purchases.purchase` is given the
  /// *option*, not the package — but the package is what carries the offering
  /// context RevenueCat attributes the purchase to.
  final Package package;

  final SubscriberSnapshot snapshot;
}

/// The whole decision: phase → eligibility → is the offer actually configured.
///
/// Returns null far more often than not, and every null is a state in which
/// nothing may be shown. In order:
///
/// 1. the SDK is unconfigured, or the store could not be read → null,
/// 2. the phase is not one an unprompted offer belongs in → null,
/// 3. the offering has no package to hang an offer on → null,
/// 4. Play carries no offer with this surface's tag → null,
/// 5. the cooldown or the lifetime cap has not cleared → null.
///
/// Only when all five pass does a surface exist.
final offerCandidateProvider =
    FutureProvider.autoDispose<OfferCandidate?>((ref) async {
  if (!Env.hasRevenueCat) return null;

  final snapshot = await ref.watch(subscriberSnapshotProvider.future);
  if (!snapshot.mayBeSoldTo) return null;

  // Which surface would this phase get, if everything else allowed it? Asked
  // with `offerConfigured: true` so the phase check is isolated; the real
  // configuration check happens below, against the store.
  final wanted = offerSurfaceFor(
      OfferContext(phase: snapshot.phase, offerConfigured: true));
  if (wanted == OfferSurface.none) return null;

  final Offering? offering;
  try {
    offering = (await Purchases.getOfferings().timeout(kEntitlementProbeTimeout))
        .current;
  } catch (_) {
    return null;
  }
  if (offering == null) return null;

  final tag = offerTagFor(wanted);
  // The offer lives on whichever package the founder attached it to, so every
  // package in the offering is checked rather than assuming the annual one.
  for (final pkg in offering.availablePackages) {
    final offer = findTaggedOffer(pkg.storeProduct, tag);
    if (offer == null) continue;

    // Only now spend the eligibility budget — a cooldown must not be consulted
    // for an offer that does not exist, and a cap must never be *spent* here
    // (that happens in `OfferPrefs.markShown`, when it reaches a screen).
    final allowed = offerSurfaceFor(OfferContext(
      phase: snapshot.phase,
      offerConfigured: true,
      lastShownAt: await OfferPrefs.lastShownAt(wanted),
      timesShown: await OfferPrefs.timesShown(wanted),
    ));
    if (allowed == OfferSurface.none) return null;

    return OfferCandidate(
      surface: wanted,
      offer: offer,
      package: pkg,
      snapshot: snapshot,
    );
  }
  return null;
});
