import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../analytics/analytics.dart';
import '../core/paw_nav_bar.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import '../theme/ui_assets.dart';
import '../config/legal_urls.dart';
import '../account/user_profile.dart';
import '../config/env.dart';
import 'entitlements.dart';
import 'paywall_pricing.dart';
import 'premium_sections.dart';
import 'premium_welcome.dart';
import 'purchase_error_message.dart';
import 'upgrade_benefits_screen.dart';

/// `subscription_plans`, rebuilt against its reference.
///
/// **The most claim-dense plate in the set.** It prints three tiers — Basic
/// $4.99, Premium $8.99, Family $14.99 — at prices nothing configures, sells
/// *"Unlock premium tools made by vets"*, *"Loved by pet parents worldwide"*,
/// a *"7-Day Free Trial"*, a *"7-Day Money-Back … full refund, no questions"*,
/// *"Join thousands of happy PawDoc families"* and *"★★★★★ 4.9/5 from 10,000+
/// reviews"*, and closes on a row of payment-network logos.
///
/// PawDoc has **one plan**, priced by the store, sold pre-launch to nobody.
/// So the composition survives and every figure on it is read at runtime:
///
/// | Reference | Shipped | Why |
/// |---|---|---|
/// | Basic / Premium / Family at $4.99 / $8.99 / $14.99 | Free and Premium, priced from the store's own `priceString` | the tiers do not exist and a hardcoded price is one we would not charge |
/// | "Save 33%" | computed by [PaywallPricing.savingsBadge], hidden unless both plans loaded in one currency and annual is genuinely cheaper | a savings claim is arithmetic, not decoration |
/// | "7-Day Free Trial · Experience all Premium features risk-free." | shown only when `storeProduct.introductoryPrice != null` | the store decides whether a trial exists; the app may not assert one |
/// | "7-Day Money-Back · Not happy? Get a full refund, no questions." | *(gone)* | PawDoc operates no refund programme — refunds are Google's, on Google's terms |
/// | "Unlock premium tools made by vets" | *(gone)* | no veterinarian authored any part of this product |
/// | "Loved by pet parents worldwide" / "Join thousands of happy families" | *(gone)* | pre-launch: there are none |
/// | "★ 4.9/5 from 10,000+ reviews" | *(gone)* | fabricated ratings, the same defect as the onboarding "★ 4.8" line |
/// | "Priority Vet Chat", "Multi-User Access (4)", "Advanced Analytics", "Dedicated Support", "Early Access to New Features" | *(gone)* | none exist in any plan |
/// | "Your data is encrypted and 100% private" | "No ads. No data sale." | an absolute privacy claim outruns any implementation |
/// | VISA / Mastercard / AMEX / Apple Pay / G Pay marks | a sentence naming Google Play | payment marks ship from official brand kits only (decision D-5), and none is sourced |
///
/// The purchase, restore and error-mapping logic below is **unchanged** — it
/// is the part that has been through a real store — and so is the trust rule
/// in `paywall_policy.dart`: nothing here can gate the emergency path.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

/// Which column of the toggle is selected.
///
/// `weekly` was added for the three-tier ladder (weekly / monthly / yearly).
/// Nothing here asserts that all three exist: the toggle renders only the
/// periods the store actually returned, so an offering configured with two
/// packages looks exactly as it did before, and one configured with a single
/// package shows no toggle at all.
enum BillingPeriod { annual, monthly, weekly }

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Offering? _offering;
  bool _loading = true;
  bool _purchasing = false;
  BillingPeriod _period = BillingPeriod.annual;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Analytics is fire-and-forget and the price read is not.
  ///
  /// These used to be sequential, so a PostHog call that never answered held
  /// the whole screen on its placeholder — a non-critical telemetry event
  /// gating the only thing the screen exists to show. `Analytics.capture`
  /// already swallows its own failures; it does not get to swallow the plans
  /// too.
  void _init() {
    unawaited(Analytics.paywallShown());
    unawaited(_load());
  }

  /// Ask the store what it will sell.
  ///
  /// **Bounded, and skipped entirely when the SDK was never configured.**
  /// `Purchases.getOfferings()` on an unconfigured SDK does not reject — it
  /// never answers, so `_loading` stayed true and the screen sat on its
  /// placeholder forever instead of reaching the honest "not on sale yet"
  /// state. The identical defect was found on a Redmi for
  /// `getCustomerInfo()` in the internal-test batch and fixed in
  /// `userProfileProvider`; this call had the same shape and was missed.
  Future<void> _load() async {
    try {
      if (Env.hasRevenueCat) {
        final offerings =
            await Purchases.getOfferings().timeout(kEntitlementProbeTimeout);
        _offering = offerings.current;
      }
    } catch (_) {
      // Offerings not configured yet (founder sets them in RevenueCat).
    } finally {
      if (mounted) {
        // Land on whichever period actually resolved, so the toggle never
        // opens on an empty column. Annual first — it is the plan the ladder is
        // built to recommend, and the only one whose saving is computable.
        if (_offering?.annual == null) {
          if (_offering?.monthly != null) {
            _period = BillingPeriod.monthly;
          } else if (_offering?.weekly != null) {
            _period = BillingPeriod.weekly;
          }
        }
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _purchase(Package? pkg) async {
    if (pkg == null || _purchasing) return;
    setState(() => _purchasing = true);
    try {
      if (pkg.storeProduct.introductoryPrice != null) {
        await Analytics.trialStarted();
      }
      // SUB-05: current purchase API (purchasePackage is deprecated).
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      if (result.customerInfo.entitlements.active.isNotEmpty) {
        await Analytics.subscriptionConverted();
        // SUB-02: reflect premium immediately from the SDK — never wait on
        // the webhook round-trip.
        ref.invalidate(userProfileProvider);
        if (mounted) {
          // Next Evolution Phase 8: the full premium welcome moment on a
          // REAL entitlement-active purchase (replaces the M3 toast).
          // Purchase/eligibility logic above is untouched (visual swap only).
          await showPremiumWelcome(context);
          if (mounted) Navigator.of(context).pop(true);
        }
        return;
      }
      // Store reported success but no entitlement is active yet (e.g. a
      // deferred payment). Say so — this path used to end in silence.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(purchaseNoEntitlementMessage)));
      }
    } on PlatformException catch (e) {
      // Never surface the raw exception: map to one sentence, and stay silent
      // when the user simply backed out of the store sheet.
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
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    // SUB-01: Restore was a silent no-op — Apple requires it to function.
    // Now it refreshes entitlements and SAYS what happened.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final info = await Purchases.restorePurchases();
      final active = info.entitlements.active.isNotEmpty;
      ref.invalidate(userProfileProvider);
      if (active) {
        // Phase 8: restoring is a premium transition too.
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

  // -------------------------------------------------------------------------

  Package? get _selected => switch (_period) {
        BillingPeriod.annual => _offering?.annual,
        BillingPeriod.monthly => _offering?.monthly,
        BillingPeriod.weekly => _offering?.weekly,
      };

  /// The periods this offering actually contains, in ladder order. The toggle
  /// is built from this, so it can never present a column with no product
  /// behind it.
  List<BillingPeriod> get _available => [
        if (_offering?.weekly != null) BillingPeriod.weekly,
        if (_offering?.monthly != null) BillingPeriod.monthly,
        if (_offering?.annual != null) BillingPeriod.annual,
      ];

  /// True only when the *store* reports an introductory offer on the selected
  /// product. Nothing else in this file may use the word "trial".
  bool get _storeOffersTrial =>
      _selected?.storeProduct.introductoryPrice != null;

  @override
  Widget build(BuildContext context) {
    final annual = _offering?.annual;
    final monthly = _offering?.monthly;
    final weekly = _offering?.weekly;
    // An offering can exist while the packages inside it don't (product not yet
    // active in the Play Console, or not attached to the offering). That is the
    // same user-facing situation as no offering at all, so it gets the same
    // production-safe state instead of a CTA-less void.
    final hasPlans = annual != null || monthly != null || weekly != null;
    final isPremium = ref.watch(userProfileProvider).maybeWhen(
        data: (p) => p.isPremium, orElse: () => false);
    final savings = annual == null
        ? null
        : PaywallPricing.savingsBadge(
            annualPrice: annual.storeProduct.price,
            annualCurrency: annual.storeProduct.currencyCode,
            monthlyPrice: monthly?.storeProduct.price,
            monthlyCurrency: monthly?.storeProduct.currencyCode,
          );

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Subscription Plans',
          icon: LucideIcons.crown,
          subtitle: 'One plan, everything included.',
          actions: [
            HealthCircleButton(
              key: const Key('paywall_benefits'),
              icon: LucideIcons.circleHelp,
              tooltip: 'What Premium changes',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const UpgradeBenefitsScreen())),
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(4),
          const _PlanTrustBand(),
          gap(13),
          if (_available.length > 1) ...[
            _PeriodToggle(
              periods: _available,
              period: _period,
              savings: savings,
              onChanged: (p) => setState(() => _period = p),
            ),
            gap(13),
          ],
          if (_loading)
            const _PlansLoading()
          else if (!hasPlans)
            const _PremiumComingSoon()
          else
            HealthBleed(
              child: _PlanCarousel(
                premium: _selected,
                period: _period,
                busy: _purchasing,
                isPremium: isPremium,
                storeOffersTrial: _storeOffersTrial,
                onChoose: () => _purchase(_selected),
              ),
            ),
          gap(13),
          _AssuranceStrip(showTrial: _storeOffersTrial),
          gap(13),
          PremiumFaq(
            title: 'Frequently asked questions',
            items: [
              (
                question: 'Can I cancel anytime?',
                answer: 'Yes. Subscriptions are managed by Google Play — '
                    'cancel there and Premium stays active until the end of '
                    'the period you have already paid for.',
              ),
              (
                question: 'Will I lose my data if I cancel?',
                answer: 'No. Pets, records, reminders, journal entries and '
                    'past checks stay exactly where they are. The free '
                    'allowances come back, so new photo checks, new journal '
                    'entries and new assistant messages are counted again — '
                    'nothing already saved is removed.',
              ),
              (
                question: 'Is there a free trial?',
                answer: _storeOffersTrial
                    ? 'Google Play is offering an introductory period on this '
                        'product. The exact terms are shown in the Play '
                        'purchase sheet before you confirm.'
                    : 'Not on this product today. If Google Play ever offers '
                        'an introductory period, it appears here and in the '
                        'Play purchase sheet — PawDoc does not run trials of '
                        'its own.',
              ),
              (
                question: 'Does PawDoc offer refunds?',
                answer: 'Refunds are handled by Google Play under Google’s '
                    'refund policy. PawDoc does not operate a separate '
                    'money-back guarantee.',
              ),
              (
                question: 'Do I need Premium in an emergency?',
                answer: 'No, and you never will. Emergency help, first aid '
                    'and symptom checks by text are unmetered on every plan, '
                    'and an emergency result is never paywalled — that is '
                    'enforced on the server as well as here.',
              ),
            ],
          ),
          gap(11),
          const _PaymentNote(),
          gap(9),
          // Apple 3.1.2 / Google Play: auto-renew disclosure + functional links
          // to Subscription Terms, Terms of Service, and Privacy Policy, shown
          // near the purchase CTAs whenever real plans are offered.
          if (hasPlans) const _SubscriptionLegal(),
          gap(6),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('paywall_restore'),
                  onPressed: _restore,
                  child: const Text('Restore purchases'),
                ),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('paywall_not_now'),
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
// The trust band
// ---------------------------------------------------------------------------

/// The reference's shield-and-duo banner, with its three bullets replaced.
///
/// Reference: "Unlock premium tools made by vets" · "Loved by pet parents
/// worldwide" · "Cancel anytime. 7-day money-back guarantee." Two are false
/// and the third is half false, so all three are rewritten to statements that
/// hold: one plan, safety free for everyone, and the actual cancellation path.
class _PlanTrustBand extends StatelessWidget {
  const _PlanTrustBand();

  static const _lines = <(IconData, String)>[
    (LucideIcons.circleCheck, 'One plan. Everything included, no add-ons.'),
    (LucideIcons.circleAlert, 'Emergency help stays free on every plan.'),
    (LucideIcons.repeat, 'Cancel anytime in Google Play.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 20,
      padding: EdgeInsets.zero,
      accent: t.accent.withValues(alpha: 0.26),
      glow: 0.08,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -6,
              bottom: -6,
              width: 168,
              child: IgnorePointer(
                child: BlendMask(
                  blendMode: BlendMode.screen,
                  child: Image.asset(
                    UiAssets.onbHeroDogCatHalo,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: FractionallySizedBox(
                widthFactor: 0.70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('The record, without limits.',
                        style: TextStyle(
                            color: t.accent,
                            fontSize: 15,
                            height: 1.2,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 9),
                    for (final (icon, line) in _lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child:
                                  Icon(icon, size: 13, color: t.accent),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(line,
                                  style: const TextStyle(
                                      color: HealthTone.dim,
                                      fontSize: 11,
                                      height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The period toggle
// ---------------------------------------------------------------------------

/// The ladder, rendered from whatever the store returned.
///
/// The columns are ordered shortest-commitment first, so the annual plan sits
/// at the end where the eye lands last and where the only computable saving
/// badge can appear beside it. That ordering is the whole of the "decoy"
/// arrangement PawDoc ships: three real prices in ascending commitment, each
/// labelled with what it actually costs. No column is inflated, no column is
/// struck through, and the badge on the yearly column is arithmetic
/// ([PaywallPricing.savingsBadge]) rather than positioning.
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.periods,
    required this.period,
    required this.onChanged,
    this.savings,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod period;
  final ValueChanged<BillingPeriod> onChanged;

  /// "Save 41%", computed from the two store prices. Null hides the badge —
  /// which is the case whenever the claim cannot be made truthfully.
  final String? savings;

  static const _labels = <BillingPeriod, (String, String, String)>{
    BillingPeriod.weekly: ('paywall_period_weekly', 'Weekly', 'Pay weekly'),
    BillingPeriod.monthly: ('paywall_period_monthly', 'Monthly', 'Pay monthly'),
    BillingPeriod.annual: ('paywall_period_annual', 'Yearly', 'Pay yearly'),
  };

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final p in periods)
            Expanded(
              child: _PeriodCell(
                fieldKey: Key(_labels[p]!.$1),
                title: _labels[p]!.$2,
                subtitle: _labels[p]!.$3,
                badge: p == BillingPeriod.annual ? savings : null,
                selected: period == p,
                onTap: () => onChanged(p),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodCell extends StatelessWidget {
  const _PeriodCell({
    required this.fieldKey,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final Key fieldKey;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $subtitle',
      child: ExcludeSemantics(
        child: Material(
          color:
              selected ? t.accent.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            key: fieldKey,
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: selected
                        ? t.accent.withValues(alpha: 0.55)
                        : Colors.transparent),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color:
                                    selected ? Colors.white : HealthTone.muted,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        PremiumChip(label: badge!, filled: selected),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: HealthTone.faint, fontSize: 10.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The plan cards
// ---------------------------------------------------------------------------

/// The reference's row of plan columns.
///
/// It draws three at ~33% width each, which on a 393dp screen gives a
/// twelve-row feature list 118dp — one or two words a line. There are two real
/// plans, so two cards scroll horizontally at 78% instead: the composition the
/// reference is after, at a width the copy survives.
class _PlanCarousel extends StatelessWidget {
  const _PlanCarousel({
    required this.premium,
    required this.period,
    required this.busy,
    required this.isPremium,
    required this.storeOffersTrial,
    required this.onChoose,
  });

  final Package? premium;
  final BillingPeriod period;
  final bool busy;
  final bool isPremium;
  final bool storeOffersTrial;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final width =
        (MediaQuery.sizeOf(context).width * 0.78).clamp(240.0, 320.0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: kRecordGutter),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: width,
              child: _PlanCard(
                key: const Key('paywall_plan_free'),
                title: 'Free',
                tagline: 'Everything that keeps a pet safe',
                price: 'Free',
                priceNote: 'No card, no expiry',
                featured: false,
                current: !isPremium,
                values: (e) => e.freeValue,
                cta: null,
                onCta: null,
                busy: false,
              ),
            ),
            const SizedBox(width: 11),
            SizedBox(
              width: width,
              child: _PlanCard(
                key: const Key('paywall_plan_premium'),
                title: 'Premium',
                tagline: 'The whole record, uncounted',
                price: premium?.storeProduct.priceString ?? '—',
                priceNote: _priceNote(),
                badge: storeOffersTrial ? 'INTRO OFFER' : null,
                featured: true,
                current: isPremium,
                values: (e) => e.premiumValue,
                cta: isPremium ? null : 'Choose Premium',
                onCta: onChoose,
                busy: busy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priceNote() {
    final product = premium?.storeProduct;
    if (product == null) return 'Not available in your store yet';
    switch (period) {
      case BillingPeriod.monthly:
        return 'Billed monthly';
      case BillingPeriod.weekly:
        // The most expensive way to buy a year, so it says so — with the
        // multiplier named, computed from the store's own weekly price.
        final note = PaywallPricing.weeklyAnnualisedNote(
          weeklyPrice: product.price,
          currencySymbolSource: product.priceString,
        );
        return note == null ? 'Billed weekly' : 'Billed weekly · $note';
      case BillingPeriod.annual:
        return PaywallPricing.annualSubtitle(product.pricePerMonthString);
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.tagline,
    required this.price,
    required this.priceNote,
    required this.featured,
    required this.current,
    required this.values,
    required this.cta,
    required this.onCta,
    required this.busy,
    this.badge,
    super.key,
  });

  final String title;
  final String tagline;
  final String price;
  final String priceNote;
  final bool featured;

  /// The plan this account is already on.
  final bool current;
  final String Function(Entitlement) values;
  final String? cta;
  final VoidCallback? onCta;
  final bool busy;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
      accent: featured ? t.accent.withValues(alpha: 0.55) : null,
      glow: featured ? 0.10 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumCrest(
                  size: 34,
                  icon: featured ? LucideIcons.crown : LucideIcons.pawPrint),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800)),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          PremiumChip(label: badge!),
                        ] else if (current) ...[
                          const SizedBox(width: 6),
                          const PremiumChip(
                              label: 'YOUR PLAN', tint: HealthTone.muted),
                        ],
                      ],
                    ),
                    Text(tagline,
                        maxLines: 2,
                        style: const TextStyle(
                            color: HealthTone.dim,
                            fontSize: 10.5,
                            height: 1.25)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(price,
                maxLines: 1,
                style: TextStyle(
                    color: featured ? t.accent : Colors.white,
                    fontSize: 27,
                    height: 1.1,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(priceNote,
              style: const TextStyle(
                  color: HealthTone.muted, fontSize: 11, height: 1.3)),
          const SizedBox(height: 13),
          if (cta != null)
            HealthPrimaryCta(
              key: Key('paywall_choose_${title.toLowerCase()}'),
              label: busy ? 'Opening the store…' : cta!,
              icon: null,
              trailingIcon: busy ? null : LucideIcons.chevronRight,
              enabled: !busy,
              onTap: onCta ?? () {},
            )
          else
            Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(current ? 'This is your plan' : 'Included',
                  style: const TextStyle(
                      color: HealthTone.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 13),
          for (final e in kEntitlements)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _PlanRow(entitlement: e, value: values(e)),
            ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.entitlement, required this.value});

  final Entitlement entitlement;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final absent = value == '—';
    final tint = absent ? PremiumTone.locked : t.accent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(absent ? LucideIcons.minus : LucideIcons.circleCheck,
              size: 14, color: tint),
        ),
        const SizedBox(width: 8),
        // 5:4 rather than two bare Flexibles: an even split squeezes the
        // capability name that had room and truncates it.
        Flexible(
          flex: 5,
          child: Text(entitlement.title,
              maxLines: 2,
              style: TextStyle(
                  color: absent ? HealthTone.faint : Colors.white,
                  fontSize: 11.5,
                  height: 1.25)),
        ),
        const SizedBox(width: 6),
        Flexible(
          flex: 4,
          child: Text(absent ? 'Not included' : value,
              maxLines: 2,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: absent ? HealthTone.faint : tint,
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Assurances, payment, legal
// ---------------------------------------------------------------------------

/// The reference's four-box strip. Its "7-Day Money-Back — Not happy? Get a
/// full refund, no questions" and "Loved by Pet Parents — Join thousands of
/// happy PawDoc families" boxes are gone; the trial box appears only when the
/// store reports an introductory offer.
class _AssuranceStrip extends StatelessWidget {
  const _AssuranceStrip({required this.showTrial});

  final bool showTrial;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, String body})>[
      if (showTrial)
        (
          icon: LucideIcons.gift,
          title: 'Intro offer',
          body: 'Google Play is offering an introductory period on this '
              'product. Terms appear in the purchase sheet.',
        ),
      (
        icon: LucideIcons.repeat,
        title: 'Cancel anytime',
        body: 'In Google Play. Premium runs to the end of the period you '
            'have paid for.',
      ),
      (
        icon: LucideIcons.lockKeyhole,
        title: 'No ads, no data sale',
        body: 'PawDoc is paid for by subscriptions. Your record is not the '
            'product.',
      ),
      (
        icon: LucideIcons.circleAlert,
        title: 'Emergency is never sold',
        body: 'The red path is free, offline and unmetered on every plan.',
      ),
    ];
    return HomeCard(
      key: const Key('paywall_assurances'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _Assurance(item: items[i])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < items.length
                        ? _Assurance(item: items[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Assurance extends StatelessWidget {
  const _Assurance({required this.item});

  final ({IconData icon, String title, String body}) item;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.022),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 19, color: t.accent),
          const SizedBox(height: 8),
          Text(item.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(item.body,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 10.5, height: 1.35)),
        ],
      ),
    );
  }
}

/// Replaces the reference's row of payment-network logos.
///
/// Owner decision D-5: payment marks ship from official brand kits only, never
/// AI-generated — and none has been sourced. A sentence naming the processor
/// carries the same reassurance and is verifiable.
class _PaymentNote extends StatelessWidget {
  const _PaymentNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.lock, size: 13, color: HealthTone.faint),
        const SizedBox(width: 7),
        const Expanded(
          child: Text(
            'Payment is taken by Google Play using the payment method on your '
            'Google account. PawDoc never sees your card details.',
            style: TextStyle(
                color: HealthTone.faint, fontSize: 10.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Subscription legal disclosure shown on the paywall, near the plan CTAs.
/// Required by Apple guideline 3.1.2 and Google Play subscription policy:
/// state the auto-renew terms and provide functional links to the Subscription
/// Terms, Terms of Service, and Privacy Policy before purchase.
class _SubscriptionLegal extends StatelessWidget {
  const _SubscriptionLegal();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    const muted = TextStyle(
        color: HealthTone.faint, fontSize: 10.5, height: 1.45);
    final linkStyle = TextStyle(
        color: t.accent, fontSize: 10.5, fontWeight: FontWeight.w600);

    Widget link(String label, String url) => GestureDetector(
          onTap: () => LegalUrls.open(url),
          child: Text(label, style: linkStyle),
        );

    return Column(
      children: [
        const Text(
          'Subscriptions auto-renew until cancelled. Manage or cancel anytime '
          'in the App Store or Google Play; payment is charged to your store '
          'account at confirmation. Emergency results are never paywalled.',
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

/// The placeholder while the store is being asked.
///
/// Static, not a spinner: PawDoc's motion foundation gives every animation a
/// reduce-motion equivalent, and a bare `CircularProgressIndicator` has none.
/// It also never settles, which means no widget test can pump past it — the
/// screen would be untestable in exactly the state a founder-gated build
/// spends most of its time in.
class _PlansLoading extends StatelessWidget {
  const _PlansLoading();

  @override
  Widget build(BuildContext context) => HomeCard(
        key: const Key('paywall_loading'),
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        child: Column(
          children: [
            Icon(LucideIcons.tag, size: 22, color: PawTone.of(context).accent),
            const SizedBox(height: 11),
            const Text('Asking your store for prices…',
                textAlign: TextAlign.center,
                style: TextStyle(color: HealthTone.dim, fontSize: 12)),
          ],
        ),
      );
}

/// Production-safe state shown when RevenueCat offerings aren't configured —
/// replaces the old internal "runbook 09" dev text. No purchasable CTAs here.
class _PremiumComingSoon extends StatelessWidget {
  const _PremiumComingSoon();

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('paywall_coming_soon'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        children: [
          const PremiumCrest(size: 46, icon: LucideIcons.lockKeyhole),
          const SizedBox(height: 12),
          const Text('Premium is not on sale yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 7),
          const Text(
            'Your store has no PawDoc subscription to offer right now, so '
            'there is no price to show you. Everything on the free plan keeps '
            'working exactly as it does today.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: HealthTone.dim, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
