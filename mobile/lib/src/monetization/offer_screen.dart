import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../account/user_profile.dart';
import '../analytics/analytics.dart';
import '../config/legal_urls.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'entitlements.dart';
import 'offer_policy.dart';
import 'offer_recommendation.dart';
import 'offer_state.dart';
import 'premium_sections.dart';
import 'premium_welcome.dart';
import 'purchase_error_message.dart';
import 'store_offer.dart';
import 'subscriber_phase.dart';
import 'usage_state.dart';

/// The second-chance and win-back surface.
///
/// One screen, two headlines, and every figure on it read from Google Play at
/// the moment it opened. It exists for exactly two states — a trial that ended
/// without converting, and a subscription that lapsed — and it cannot be
/// constructed without an [OfferCandidate], which cannot be built unless Play
/// actually carries a tagged offer for that state.
///
/// ## What is on it, and where each part comes from
///
/// | Element | Source |
/// |---|---|
/// | "Your free trial ended on 3 August" | `EntitlementInfo.expirationDate` — omitted entirely when unreadable |
/// | "Save 50%" | [StoreOffer.discountPercent] — the offer's own intro phase against the base plan's full price, same currency, same billing period |
/// | "3 months at ₺74,99 / month, then ₺149,99 / month" | [StoreOffer.termsSentence] — the pricing phases Google will charge, in order |
/// | The recommendation | [recommendUpgrade] over this account's own counters |
/// | The capability rows | [kEntitlements] — the audited catalogue |
///
/// ## What is deliberately not on it
///
/// * **A countdown.** Play exposes no offer expiry, so any timer here would
///   count down to a moment PawDoc invented (see `offer_policy.dart`).
/// * **A struck-through "original price".** The base-plan price is shown as
///   what the charge becomes after the offer, which is what it is — not as a
///   price the user was ever about to pay.
/// * **Scarcity.** No "spots left", no "selected", no "last chance".
/// * **A blocking close.** The dismiss control is a plain, always-enabled
///   button in the app bar, and Restore purchases sits beside the CTA on every
///   state of the screen.
class OfferScreen extends ConsumerStatefulWidget {
  const OfferScreen({required this.candidate, super.key});

  final OfferCandidate candidate;

  @override
  ConsumerState<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends ConsumerState<OfferScreen> {
  bool _busy = false;

  OfferCandidate get _c => widget.candidate;

  @override
  void initState() {
    super.initState();
    Analytics.capture('offer_shown', {'surface': _c.surface.name});
  }

  /// Buys the tagged offer specifically — not the package.
  ///
  /// `PurchaseParams.package(pkg)` would buy the package's default option,
  /// which is the base plan; the discount would silently not apply and the user
  /// would be charged full price on a screen that promised otherwise.
  /// `PurchaseParams.subscriptionOption` is the only call that buys the offer
  /// the screen is showing.
  Future<void> _purchase() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await Purchases.purchase(
          PurchaseParams.subscriptionOption(_c.offer.option));
      if (result.customerInfo.entitlements.active.isNotEmpty) {
        await Analytics.capture('offer_converted', {'surface': _c.surface.name});
        ref.invalidate(userProfileProvider);
        ref.invalidate(subscriberSnapshotProvider);
        if (mounted) {
          await showPremiumWelcome(context);
          if (mounted) Navigator.of(context).pop(true);
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(purchaseNoEntitlementMessage)));
      }
    } on PlatformException catch (e) {
      final message = purchaseErrorMessage(PurchasesErrorHelper.getErrorCode(e));
      if (mounted && message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('The purchase did not complete. Please try again — '
                'you have not been charged.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final info = await Purchases.restorePurchases();
      ref.invalidate(userProfileProvider);
      ref.invalidate(subscriberSnapshotProvider);
      if (info.entitlements.active.isNotEmpty) {
        if (mounted) await showPremiumWelcome(context, restored: true);
        if (mounted) navigator.pop(true);
      } else {
        messenger.showSnackBar(const SnackBar(
            content:
                Text('No previous purchase found for this store account.')));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not restore right now. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final winBack = _c.surface == OfferSurface.winBack;
    final profile = ref.watch(userProfileProvider);
    final usage = ref.watch(accountUsageProvider);
    final recommendation = recommendUpgrade(
      photoChecksUsedThisMonth:
          profile.maybeWhen(data: (p) => p.photoLogsUsedThisMonth, orElse: () => null),
      journalEntries:
          usage.maybeWhen(data: (u) => u.journalEntries, orElse: () => null),
      assistantMessagesToday:
          usage.maybeWhen(data: (u) => u.assistantMessagesToday, orElse: () => null),
    );

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: winBack ? 'Come back to Premium' : 'Your trial has ended',
          icon: LucideIcons.crown,
          subtitle: 'One plan. Priced by Google Play.',
          actions: [
            HealthCircleButton(
              key: const Key('offer_close'),
              icon: LucideIcons.x,
              tooltip: 'Close',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        children: [
          gap(4),
          _EndedBanner(snapshot: _c.snapshot, winBack: winBack),
          gap(13),
          _RecommendationCard(recommendation: recommendation),
          gap(13),
          _OfferCard(
            offer: _c.offer,
            busy: _busy,
            onBuy: _purchase,
          ),
          gap(13),
          _WhatChanges(recommendation: recommendation),
          gap(13),
          const _OfferLegal(),
          gap(6),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('offer_restore'),
                  onPressed: _restore,
                  child: const Text('Restore purchases'),
                ),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('offer_not_now'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
          gap(14),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// States what ended and when — or, when the store did not give a date, states
/// what ended and stops there.
class _EndedBanner extends StatelessWidget {
  const _EndedBanner({required this.snapshot, required this.winBack});

  final SubscriberSnapshot snapshot;
  final bool winBack;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final on = snapshot.endedAt;
    final what = winBack ? 'Premium' : 'Your free trial';
    final line = on == null
        ? '$what has ended on this account.'
        : '$what ended on ${_longDate(on)}.';
    return HomeCard(
      key: const Key('offer_ended_banner'),
      radius: 18,
      accent: t.accent.withValues(alpha: 0.26),
      glow: 0.08,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumCrest(size: 38, icon: LucideIcons.calendarClock),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(line,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const Text(
                  'Everything you saved is still here, and everything on the '
                  'free plan still works — including emergency help, which is '
                  'never counted and never sold.',
                  style: TextStyle(
                      color: HealthTone.dim, fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The recommendation, with its own provenance printed underneath it.
///
/// The basis line is not fine print and is not collapsible: a personalised
/// claim that does not say what it is based on is the thing this whole file is
/// trying not to be.
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});

  final OfferRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('offer_recommendation'),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 16, color: t.accent),
              const SizedBox(width: 7),
              // Expanded, not bare: at 1.3× text scale this eyebrow is wider
              // than the card, and an unconstrained Row overflows rather than
              // wrapping.
              Expanded(
                child: Text(
                  recommendation.personalised
                      ? 'What PawDoc can see on this account'
                      : 'What Premium changes',
                  style: TextStyle(
                      color: t.accent,
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(recommendation.headline,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(recommendation.body,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 12, height: 1.4)),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: Colors.white.withValues(alpha: 0.022),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.info, size: 12, color: HealthTone.faint),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(recommendation.basis,
                      key: const Key('offer_recommendation_basis'),
                      style: const TextStyle(
                          color: HealthTone.faint,
                          fontSize: 10.5,
                          height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The offer, priced entirely by the store.
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.busy,
    required this.onBuy,
  });

  final StoreOffer offer;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final pct = offer.discountPercent;
    final terms = offer.termsSentence;
    final standard = offer.standardPriceString;

    return HomeCard(
      key: const Key('offer_card'),
      radius: 18,
      accent: t.accent.withValues(alpha: 0.55),
      glow: 0.10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PremiumCrest(size: 34),
              const SizedBox(width: 9),
              const Expanded(
                child: Text('PawDoc Premium',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: FontWeight.w800)),
              ),
              // Only when the arithmetic held. Null hides the chip entirely.
              if (pct != null)
                PremiumChip(key: const Key('offer_discount'), label: 'SAVE $pct%'),
              if (pct == null && offer.startsFree)
                const PremiumChip(
                    key: Key('offer_free_phase'), label: 'STARTS FREE'),
            ],
          ),
          const SizedBox(height: 13),
          // The store's sentence, or — when the phases could not be described
          // exactly — nothing, and the Play sheet does the talking.
          if (terms != null)
            Text(terms,
                key: const Key('offer_terms'),
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.4))
          else
            const Text(
              'Google Play will show the exact price and billing period before '
              'you confirm.',
              key: Key('offer_terms_deferred'),
              style:
                  TextStyle(color: HealthTone.dim, fontSize: 13, height: 1.4),
            ),
          if (standard != null) ...[
            const SizedBox(height: 5),
            Text(
              'The standard price is $standard. The offer applies to the '
              'phases above; after them the standard price applies and the '
              'subscription renews until you cancel.',
              style: const TextStyle(
                  color: HealthTone.muted, fontSize: 11, height: 1.4),
            ),
          ],
          const SizedBox(height: 13),
          HealthPrimaryCta(
            key: const Key('offer_buy'),
            label: busy ? 'Opening the store…' : 'Continue in Google Play',
            icon: null,
            trailingIcon: busy ? null : LucideIcons.chevronRight,
            enabled: !busy,
            onTap: onBuy,
          ),
        ],
      ),
    );
  }
}

/// The rows an upgrade actually changes, straight out of the catalogue.
class _WhatChanges extends StatelessWidget {
  const _WhatChanges({required this.recommendation});

  final OfferRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('offer_what_changes'),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What changes on Premium',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'These four rows, and nothing else. Everything else on PawDoc is '
            'identical on both plans.',
            style:
                TextStyle(color: HealthTone.faint, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 11),
          for (final e in premiumUnlocks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(e.icon,
                        size: 14,
                        color: e.id == recommendation.entitlementId
                            ? t.accent
                            : HealthTone.muted),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 5,
                    child: Text(e.title,
                        maxLines: 2,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11.5, height: 1.25)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 4,
                    child: Text('${e.freeValue}  →  ${e.premiumValue}',
                        maxLines: 2,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: t.accent,
                            fontSize: 10.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Auto-renew disclosure and the three links, in the same wording the paywall
/// uses. Required near a purchase CTA by Play's subscription policy, and the
/// one block on this screen that is not allowed to be shorter than the offer.
class _OfferLegal extends StatelessWidget {
  const _OfferLegal();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    const muted =
        TextStyle(color: HealthTone.faint, fontSize: 10.5, height: 1.45);
    final linkStyle = TextStyle(
        color: t.accent, fontSize: 10.5, fontWeight: FontWeight.w600);

    Widget link(String label, String url) => GestureDetector(
          onTap: () => LegalUrls.open(url),
          child: Text(label, style: linkStyle),
        );

    return Column(
      children: [
        const Text(
          'Payment is charged to your Google account at confirmation. The '
          'subscription renews automatically at the standard price until you '
          'cancel it in Google Play. Cancelling stops the next charge; access '
          'runs to the end of the period you have paid for. Refunds are '
          'Google’s, under Google’s refund policy.',
          key: Key('offer_renewal_disclosure'),
          textAlign: TextAlign.center,
          style: muted,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            link('Subscription Terms', LegalUrls.subscriptions),
            const Text('·', style: muted),
            link('Terms', LegalUrls.terms),
            const Text('·', style: muted),
            link('Privacy', LegalUrls.privacy),
          ],
        ),
      ],
    );
  }
}

String _longDate(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
