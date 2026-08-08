import 'package:purchases_flutter/purchases_flutter.dart';

/// **Where this account actually stands with the store.**
///
/// The offer surfaces in this module all answer one question — *may we say
/// something to this person about buying?* — and every wrong answer is a
/// consumer-protection problem rather than a cosmetic one:
///
/// * telling someone their trial ended when they never had one,
/// * offering a win-back discount to someone who never subscribed,
/// * pitching anything at all to someone who is already paying.
///
/// So the phase is derived from `CustomerInfo.entitlements.all` and nothing
/// else. `all` carries every entitlement the account has *ever* held, active or
/// not, with its `periodType`, its `expirationDate`, whether it `willRenew` and
/// whether the store has seen a billing problem. That is the whole input.
///
/// There is deliberately **no** local "the user started a trial on…" record.
/// A locally-stamped trial is a claim the app made about itself; the store's
/// `PeriodType.trial` is a fact the store reports. Only the second one may
/// reach a user, and only the second one survives a reinstall.
enum SubscriberPhase {
  /// The store could not be asked — the SDK is unconfigured (dev, tests, any
  /// build without a public key) or the probe timed out.
  ///
  /// **No offer surface may render in this state.** Not a neutral default: it
  /// is the state a build spends most of its pre-launch life in, and a
  /// "your trial has ended" screen shown to someone whose store we never
  /// reached is a fabrication.
  unknown,

  /// The account has never held any entitlement. The ordinary paywall applies;
  /// there is nothing to win back.
  neverSubscribed,

  /// An active entitlement in `PeriodType.trial` — i.e. Google Play is running
  /// the free-trial phase of an offer. The **only** state in which any surface
  /// may use the word "trial" about the present.
  inTrial,

  /// Active, paid, renewing. Nothing may be sold here.
  active,

  /// Active and paid, but `willRenew` is false: the user cancelled and access
  /// runs to [SubscriberSnapshot.accessEndsAt].
  ///
  /// Deliberately **not** a win-back state. The entitlement is still owned, so
  /// Google Play will not sell it again — a discounted "come back" offer here
  /// is un-purchasable. What is honest is telling them when access ends and
  /// how to resume renewal, which costs nothing and is not a sale.
  cancelledStillActive,

  /// Active, but the store has flagged a billing problem — the grace /
  /// account-hold window. Access has not stopped yet; it is about to.
  billingRetry,

  /// A trial expired and was never converted. This is the *only* state the
  /// post-trial offer surface may render in.
  trialEnded,

  /// A paid subscription expired. This is the *only* state the win-back offer
  /// surface may render in.
  lapsed,
}

/// The store's answer, reduced to the facts an offer surface is allowed to use.
class SubscriberSnapshot {
  const SubscriberSnapshot({
    required this.phase,
    this.accessEndsAt,
    this.endedAt,
    this.lastProductIdentifier,
  });

  /// The one honest state for "we could not ask the store".
  static const unknown = SubscriberSnapshot(phase: SubscriberPhase.unknown);

  final SubscriberPhase phase;

  /// While access is still running: when it stops. Non-null only for
  /// [SubscriberPhase.cancelledStillActive] and [SubscriberPhase.billingRetry].
  final DateTime? accessEndsAt;

  /// After access has stopped: when it stopped. Non-null only for
  /// [SubscriberPhase.trialEnded] and [SubscriberPhase.lapsed].
  ///
  /// This is the date the post-trial and win-back screens print. It is the
  /// store's `expirationDate`, never a computed guess, so a screen that cannot
  /// read it says nothing rather than estimating.
  final DateTime? endedAt;

  /// The product the account last held. Used only to label the plan the user
  /// had ("Annual"), never to price anything.
  final String? lastProductIdentifier;

  /// True while the account has any store access at all.
  bool get hasAccess =>
      phase == SubscriberPhase.inTrial ||
      phase == SubscriberPhase.active ||
      phase == SubscriberPhase.cancelledStillActive ||
      phase == SubscriberPhase.billingRetry;

  /// True when a purchase surface may be shown at all. `unknown` is excluded
  /// deliberately — see [SubscriberPhase.unknown].
  bool get mayBeSoldTo =>
      phase == SubscriberPhase.neverSubscribed ||
      phase == SubscriberPhase.trialEnded ||
      phase == SubscriberPhase.lapsed;
}

/// Derives the phase from the entitlement records the store returned.
///
/// [entitlements] is `CustomerInfo.entitlements.all` — active **and** inactive.
/// Passing only `active` would collapse `trialEnded`, `lapsed` and
/// `neverSubscribed` into one another, which is exactly the distinction every
/// offer decision turns on.
///
/// [now] is injectable so the tests can pin the clock; production passes null.
SubscriberSnapshot subscriberPhaseFrom(
  Map<String, EntitlementInfo> entitlements, {
  DateTime? now,
}) {
  if (entitlements.isEmpty) {
    return const SubscriberSnapshot(phase: SubscriberPhase.neverSubscribed);
  }
  final at = now ?? DateTime.now();

  // --- Access is live -------------------------------------------------------
  //
  // `isActive` is the store's own verdict and is preferred over comparing
  // expirationDate to the device clock, which the user controls.
  final live = entitlements.values.where((e) => e.isActive).toList();
  if (live.isNotEmpty) {
    // With one entitlement configured there is exactly one; if a project ever
    // adds a second, the one that runs longest is the one that governs access.
    live.sort((a, b) => _endOf(b).compareTo(_endOf(a)));
    final e = live.first;
    final ends = _parse(e.expirationDate);
    if (e.periodType == PeriodType.trial) {
      return SubscriberSnapshot(
        phase: SubscriberPhase.inTrial,
        accessEndsAt: ends,
        lastProductIdentifier: e.productIdentifier,
      );
    }
    if (e.billingIssueDetectedAt != null) {
      return SubscriberSnapshot(
        phase: SubscriberPhase.billingRetry,
        accessEndsAt: ends,
        lastProductIdentifier: e.productIdentifier,
      );
    }
    if (!e.willRenew) {
      return SubscriberSnapshot(
        phase: SubscriberPhase.cancelledStillActive,
        accessEndsAt: ends,
        lastProductIdentifier: e.productIdentifier,
      );
    }
    return SubscriberSnapshot(
      phase: SubscriberPhase.active,
      accessEndsAt: ends,
      lastProductIdentifier: e.productIdentifier,
    );
  }

  // --- Access has stopped ---------------------------------------------------
  //
  // The most recently ended record decides which of the two lapsed states this
  // is. A record with no readable expiry sorts last: it cannot be the evidence
  // for a dated sentence on a screen.
  final ended = entitlements.values.toList()
    ..sort((a, b) => _endOf(b).compareTo(_endOf(a)));
  final last = ended.first;
  final endedAt = _parse(last.expirationDate);

  // Guard the device clock in the one direction that matters. `isActive` is
  // false, so the store says access has stopped; if the expiry nonetheless
  // reads as future, the clock is wrong and the date is not printable.
  final printable = (endedAt != null && !endedAt.isAfter(at)) ? endedAt : null;

  return SubscriberSnapshot(
    phase: last.periodType == PeriodType.trial
        ? SubscriberPhase.trialEnded
        : SubscriberPhase.lapsed,
    endedAt: printable,
    lastProductIdentifier: last.productIdentifier,
  );
}

DateTime? _parse(String? iso) =>
    iso == null ? null : DateTime.tryParse(iso)?.toLocal();

/// Sort key: a record with no readable expiry sorts to the bottom.
DateTime _endOf(EntitlementInfo e) =>
    _parse(e.expirationDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
