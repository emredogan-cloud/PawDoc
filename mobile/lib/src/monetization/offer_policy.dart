/// **When PawDoc may bring up an offer by itself, and how often it may stop.**
///
/// `paywall_policy.dart` governs the ordinary paywall — the one shown after a
/// check. This file governs the two *unprompted* surfaces, which are a
/// different and more dangerous thing: the user did not ask, so the only thing
/// standing between "a reminder" and "nagging" is a rule with a memory.
///
/// The rules, and the failure each one exists to prevent:
///
/// | Rule | Prevents |
/// |---|---|
/// | Only in [SubscriberPhase.trialEnded] / [SubscriberPhase.lapsed] | selling to someone who is already paying, or "your trial ended" to someone who never had one |
/// | Only when the tagged Play offer really exists | a discount nobody can buy |
/// | Never during onboarding | interrupting the first five minutes |
/// | Never on an emergency result | monetising the red path — the standing rule |
/// | At most once every [kOfferCooldown] | a prompt on every launch |
/// | At most [kOfferMaxPrompts] times, ever | an endless loop for someone who has said no three times |
///
/// The last two are the ones that make dismissal mean something. The count is
/// **persisted and never reset by reopening the surface** — a counter that
/// resets when the user comes back is not a cap, and a countdown that restarts
/// when the sheet reopens is not a deadline. Neither ships.
///
/// ## On countdowns
///
/// There is no countdown in this module, and the omission is deliberate.
///
/// A truthful countdown needs an expiry that something outside the app
/// enforces. Google Play offers have no expiry the Billing Library exposes:
/// `SubscriptionOption` carries an id, tags and pricing phases, and nothing
/// resembling "valid until". The only end date that exists is the moment a
/// founder deactivates the offer in the Console, which the device cannot read.
///
/// So a timer here could only ever count down to a moment the app invented,
/// after which the price would not change. That is the definition of fake
/// urgency, and it is the one growth mechanic this file refuses to provide.
/// (If a genuine window is ever wanted, it has to be issued and enforced
/// server-side — a per-account offer window the server hands out and the server
/// honours — and the surface reads it rather than starting its own clock.)
library;

import 'store_offer.dart' show kSecondChanceOfferTag, kWinBackOfferTag;
import 'subscriber_phase.dart';


/// Minimum gap between two unprompted offer surfaces.
const Duration kOfferCooldown = Duration(days: 7);

/// How many times an unprompted offer may ever be shown, per surface.
const int kOfferMaxPrompts = 3;

/// Which unprompted surface, if any, may be shown right now.
enum OfferSurface {
  /// Show nothing. The overwhelmingly common answer.
  none,

  /// A trial ran and did not convert, and Play carries a second-chance offer.
  secondChance,

  /// A paid subscription lapsed, and Play carries a win-back offer.
  winBack,
}

/// Everything the decision depends on. Deliberately plain data: the rule is
/// unit-tested against every combination rather than inferred from a device.
class OfferContext {
  const OfferContext({
    required this.phase,
    required this.offerConfigured,
    this.inOnboarding = false,
    this.lastTriageWasEmergency = false,
    this.lastShownAt,
    this.timesShown = 0,
  });

  final SubscriberPhase phase;

  /// True only when the tagged offer was actually found on the store product
  /// for this phase's surface. False before the founder creates it in Play
  /// Console — and false is not a soft state: it means nothing renders.
  final bool offerConfigured;

  final bool inOnboarding;

  /// The standing rule, restated here because this surface can fire on any
  /// screen: nothing is ever sold on the back of an emergency result.
  final bool lastTriageWasEmergency;

  final DateTime? lastShownAt;

  /// How many times this surface has already been shown to this account.
  final int timesShown;
}

/// The rule. Pure, so every branch below is pinned by a test.
OfferSurface offerSurfaceFor(OfferContext c, {DateTime? now}) {
  if (!c.offerConfigured) return OfferSurface.none;
  if (c.inOnboarding) return OfferSurface.none;
  if (c.lastTriageWasEmergency) return OfferSurface.none;
  if (c.timesShown >= kOfferMaxPrompts) return OfferSurface.none;

  final at = now ?? DateTime.now();
  final last = c.lastShownAt;
  if (last != null && at.difference(last) < kOfferCooldown) {
    return OfferSurface.none;
  }

  return switch (c.phase) {
    SubscriberPhase.trialEnded => OfferSurface.secondChance,
    SubscriberPhase.lapsed => OfferSurface.winBack,
    // Everything else — including `unknown`, which is the state a build with no
    // RevenueCat key spends its whole life in.
    _ => OfferSurface.none,
  };
}

/// The Play Console offer tag each surface looks for. Kept beside the rule so a
/// new surface cannot be added without deciding which offer backs it.
String offerTagFor(OfferSurface surface) => switch (surface) {
      OfferSurface.secondChance => kSecondChanceOfferTag,
      OfferSurface.winBack => kWinBackOfferTag,
      OfferSurface.none => '',
    };
