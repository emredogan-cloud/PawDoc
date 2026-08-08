import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../account/manage_subscription.dart';
import '../account/user_profile.dart';
import '../config/env.dart';
import '../core/dates.dart';
import '../core/paw_nav_bar.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'entitlements.dart';
import 'paywall_pricing.dart';
import 'paywall_screen.dart';
import 'premium_sections.dart';
import 'subscription_state.dart';
import 'upgrade_benefits_screen.dart';
import 'usage_limits_screen.dart';

/// `premium_home`, rebuilt against its reference — the hub the other three
/// monetization surfaces hang off.
///
/// **Its six feature cards sell four things that do not exist.** *"Vet Chat
/// Priority — Get faster responses from verified veterinarians when it matters
/// most"* is the single most consequential invention in the whole reference
/// set: it sells a licensed opinion, in a health app, to an owner with a sick
/// animal. *"Unlimited Cloud Storage"* meters bytes nothing counts.
/// *"Generate professional health reports"* claims a standard the PDF does not
/// meet. *"Advanced AI analysis, risk detection & personalised
/// recommendations"* promises a severity grade the contract forbids outright.
/// The hero adds *"Premium tools made by vets. Loved by pet parents."* and a
/// *"7-day money-back guarantee"*.
///
/// What ships is the same composition driven by [kEntitlements], and a plan
/// card whose every field — plan name, active state, next billing date — is
/// read from the store at runtime or not shown at all.
///
/// | Reference | Shipped | Why |
/// |---|---|---|
/// | "Premium tools made by vets. Loved by pet parents." | "Everything you record, kept without limits." | no veterinarian authored this; there are no customers yet |
/// | "Cancel anytime. 7-day money-back guarantee." | "Cancel anytime in Google Play." | PawDoc runs no refund programme |
/// | "Vet Chat Priority · verified veterinarians" | *(gone)* | there is no veterinarian, verified or otherwise |
/// | "Unlimited Cloud Storage · Store all photos … in the cloud" | "Photo & file storage · Not metered" | no storage quota exists to lift |
/// | "Health Reports PDF · Generate professional health reports" | "PDF health report · the record as a printable PDF" | "professional" implies a standard nothing certifies |
/// | "AI Health Insights · risk detection & personalised recommendations" | "Photo health checks · unlimited" | risk grading is banned by the action-ladder contract |
/// | "Smart Alerts · health alerts" | "Reminders · free for everyone" | reminders are what exists, and they are not premium |
/// | "Multi-Pet Management · Manage multiple pets" | "Pets · unlimited on both plans" | never limited on any plan |
/// | "MOST POPULAR" / "EXCLUSIVE" / "UNLIMITED" badges | a state chip: PREMIUM / SOON | nothing measures popularity pre-launch, and nothing is exclusive |
/// | "Yearly Plan · Active · Next billing date: May 24, 2027" | the same three facts from `CustomerInfo`, or an honest "could not be read" | the store is the only authority on a billing date |
/// | "Yearly plan is 33% off compared to monthly" | [PaywallPricing.savingsBadge] over two live store prices | a savings claim is arithmetic |
/// | `Premium` in the bottom navigation | `Emergency` keeps the slot | decision C-7 / review V-24 — the fastest route to help does not move for a sales tab |
class PremiumHomeScreen extends ConsumerStatefulWidget {
  const PremiumHomeScreen({super.key});

  @override
  ConsumerState<PremiumHomeScreen> createState() => _PremiumHomeScreenState();
}

class _PremiumHomeScreenState extends ConsumerState<PremiumHomeScreen> {
  Offering? _offering;
  bool _loadingOffering = true;

  @override
  void initState() {
    super.initState();
    _loadOffering();
  }

  /// Read once, for the savings band only. The purchase itself always goes
  /// through [PaywallScreen], which reads its own offerings — this screen
  /// never holds a package it could accidentally charge.
  ///
  /// Guarded and bounded for the same reason `_load()` there is: an
  /// unconfigured SDK never answers, and a band that waits forever is a band
  /// that never renders.
  Future<void> _loadOffering() async {
    try {
      if (Env.hasRevenueCat) {
        final offerings =
            await Purchases.getOfferings().timeout(kEntitlementProbeTimeout);
        _offering = offerings.current;
      }
    } catch (_) {
      // Not configured, or offline. The band simply does not render.
    } finally {
      if (mounted) setState(() => _loadingOffering = false);
    }
  }

  void _openPlans() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()));
  }

  void _openBenefits() {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const UpgradeBenefitsScreen()));
  }

  void _openUsage() {
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const UsageLimitsScreen()));
  }

  /// A feature card explains itself rather than linking to a marketing page
  /// that does not exist. The reference's "Learn more ›" went nowhere.
  void _explain(Entitlement e) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HealthSheet(
        title: e.title,
        scrollable: true,
        children: [
          HealthDetailRow(icon: e.icon, label: 'What it is', value: e.blurb),
          HealthDetailRow(
              icon: LucideIcons.pawPrint,
              label: 'On the free plan',
              value: e.freeValue == '—' ? 'Not included' : e.freeValue),
          HealthDetailRow(
              icon: LucideIcons.crown,
              label: 'On Premium',
              value: e.premiumValue == '—'
                  ? 'Not included — this is not built yet'
                  : e.premiumValue),
        ],
      ),
    );
  }

  String? get _savings {
    final annual = _offering?.annual;
    if (annual == null) return null;
    return PaywallPricing.savingsBadge(
      annualPrice: annual.storeProduct.price,
      annualCurrency: annual.storeProduct.currencyCode,
      monthlyPrice: _offering?.monthly?.storeProduct.price,
      monthlyCurrency: _offering?.monthly?.storeProduct.currencyCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final isPremium =
        profile.maybeWhen(data: (p) => p.isPremium, orElse: () => false);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'PawDoc Premium',
          icon: LucideIcons.crown,
          subtitleLead: 'More room for the record',
          subtitle: ', not a different kind of care.',
          actions: [
            HealthCircleButton(
              key: const Key('premium_home_help'),
              icon: LucideIcons.circleHelp,
              tooltip: 'What Premium changes',
              onTap: _openBenefits,
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(4),
          if (isPremium)
            _ActivePlanCard(onManage: openManageSubscription)
          else
            PremiumHeroCard(
              headline: 'Keep everything\nyou record ',
              headlineAccent: 'for your pet.',
              deck: 'Unlimited photo checks, an unlimited journal, unlimited '
                  'assistant messages and the PDF report.',
              ctaLabel: 'See plans',
              onCta: _openPlans,
              footnote: 'Cancel anytime in Google Play. Emergency help is '
                  'free on every plan.',
            ),
          gap(13),
          PremiumFeatureStrip(entitlements: kEntitlements, onTap: _explain),
          gap(13),
          _StatusCard(
            isPremium: isPremium,
            onManage: isPremium ? openManageSubscription : _openPlans,
            onUsage: _openUsage,
          ),
          gap(14),
          HealthSectionHead(
            title: isPremium ? 'What your plan includes' : 'What Premium adds',
            actionLabel: 'Compare plans',
            onAction: _openBenefits,
          ),
          gap(9),
          PremiumFeatureGrid(
            entitlements: premiumUnlocks,
            isPremium: isPremium,
            onTap: _explain,
          ),
          gap(14),
          const HealthSectionHead(title: 'Free for everyone, on every plan'),
          gap(9),
          _FreeForEveryoneCard(onTap: _explain),
          gap(13),
          if (!isPremium && !_loadingOffering && _savings != null) ...[
            PremiumBand(
              key: const Key('premium_home_savings'),
              icon: LucideIcons.tag,
              title: 'Yearly costs less',
              body: 'Paying yearly works out ${_savings!.toLowerCase()} '
                  'against twelve monthly charges, in your store’s own '
                  'prices.',
              ctaLabel: 'See plans & pricing',
              onCta: _openPlans,
            ),
            gap(13),
          ] else if (!isPremium) ...[
            PremiumBand(
              key: const Key('premium_home_band'),
              title: 'One plan, everything included',
              body: 'No tiers, no add-ons, nothing sold separately.',
              ctaLabel: 'See plans & pricing',
              onCta: _openPlans,
            ),
            gap(13),
          ],
          const PremiumHonestyNote(lines: [
            'PawDoc employs no veterinarians. No plan connects you to one, '
                'and nothing here is reviewed by one.',
            'Premium changes how much you can do, never what the AI is '
                'allowed to say. It never grades a risk or names a condition.',
            'No ratings, review counts or customer numbers appear on these '
                'screens, because there are none to report.',
          ]),
          gap(18),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The reference's "Your Premium Plan · Yearly Plan · Active · Next billing
/// date" card, and its free-plan counterpart.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({
    required this.isPremium,
    required this.onManage,
    required this.onUsage,
  });

  final bool isPremium;
  final VoidCallback onManage;
  final VoidCallback onUsage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = PawTone.of(context);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final snap = ref.watch(subscriptionSnapshotProvider).asData?.value;
    return HomeCard(
      key: const Key('premium_status_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      accent: isPremium ? t.accent.withValues(alpha: 0.26) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumCrest(
                  size: 38,
                  icon: isPremium ? LucideIcons.crown : LucideIcons.pawPrint),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                              isPremium ? 'Your Premium plan' : 'Your plan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: isPremium ? t.accent : Colors.white,
                                  fontSize: 14.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 7),
                        PremiumChip(
                          label: isPremium ? 'ACTIVE' : 'FREE',
                          tint: isPremium ? null : HealthTone.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(_line(isPremium, profile, snap),
                        style: const TextStyle(
                            color: HealthTone.dim,
                            fontSize: 11,
                            height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: HealthActionPill(
                  key: const Key('premium_manage'),
                  label: isPremium ? 'Manage plan' : 'See plans',
                  icon: isPremium
                      ? LucideIcons.externalLink
                      : LucideIcons.crown,
                  onTap: onManage,
                  dense: true,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: HealthActionPill(
                  key: const Key('premium_usage'),
                  label: 'Your usage',
                  icon: LucideIcons.gauge,
                  color: HealthTone.muted,
                  onTap: onUsage,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The billing line. Never invents a date: an unreadable store says so.
  static String _line(
      bool isPremium, UserProfile? profile, SubscriptionSnapshot? snap) {
    if (!isPremium) {
      final left = profile?.photoLogsRemaining;
      return left == null
          ? 'Text checks and emergency help are unlimited. Photo checks draw '
              'on a monthly allowance.'
          : '$left of $kFreePhotoChecksPerMonth photo checks left this '
              'month. Text checks and emergency help are unlimited.';
    }
    if (profile?.subscriptionStatus == UserProfile.internalTesterStatus) {
      return 'Internal test account — Premium is granted directly, not '
          'bought, so there is no store subscription behind it.';
    }
    if (snap == null || !snap.readable) {
      return 'Active on this account. Your store could not be reached, so '
          'there is no renewal date to show.';
    }
    if (!snap.active) {
      return 'Active on this account. No store subscription is attached to '
          'this device — restoring a purchase will link it.';
    }
    final at = snap.renewsAt;
    final plan = snap.planLabel == null ? '' : '${snap.planLabel} plan. ';
    if (at == null) return '${plan}Active.';
    if (snap.hasBillingIssue) {
      return '${plan}Google Play reported a billing problem. Access runs to '
          '${shortDate(at)} unless it is resolved.';
    }
    return snap.willRenew
        ? '${plan}Next billing date ${shortDate(at)}.'
        : '${plan}Cancelled — access continues until ${shortDate(at)}.';
  }
}

/// What a paying account sees instead of the sales hero.
class _ActivePlanCard extends ConsumerWidget {
  const _ActivePlanCard({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('premium_active_hero'),
      radius: 20,
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
      accent: t.accent.withValues(alpha: 0.30),
      glow: 0.10,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumCrest(size: 46),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Thank you.',
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 19,
                        height: 1.15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const Text(
                    'Your subscription is what keeps emergency help and text '
                    'symptom checks free for everyone who installs PawDoc.',
                    style: TextStyle(
                        color: HealthTone.dim, fontSize: 11.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The counterweight the reference never draws: the long list of things an
/// owner does **not** have to buy.
class _FreeForEveryoneCard extends StatelessWidget {
  const _FreeForEveryoneCard({required this.onTap});

  final void Function(Entitlement) onTap;

  @override
  Widget build(BuildContext context) {
    final rows = includedForEveryone;
    return HomeCard(
      key: const Key('premium_free_for_everyone'),
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06)),
            HealthSettingRow(
              key: Key('free_row_${rows[i].id}'),
              icon: rows[i].icon,
              label: rows[i].title,
              value: rows[i].freeValue,
              onTap: () => onTap(rows[i]),
            ),
          ],
        ],
      ),
    );
  }
}
