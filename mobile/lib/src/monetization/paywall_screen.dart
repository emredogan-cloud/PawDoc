import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../analytics/analytics.dart';
import '../core/app_image.dart';
import '../core/app_motion_asset.dart';
import '../core/celebration_overlay.dart';
import '../experiments/feature_flags.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'paywall_copy.dart';

/// Annual-first paywall (Variant A control). Phase 4.2 adds layout variants via
/// the `paywall_variant` flag — B: monthly featured; C: social proof. The flag
/// only changes the LAYOUT, never WHEN the paywall is shown, so the EMERGENCY
/// trust rule (enforced in paywall_policy.dart) is untouched. Fail-safe: an
/// unknown/missing flag renders Variant A.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Offering? _offering;
  bool _loading = true;
  bool _purchasing = false;
  String _variant = 'A'; // control until the flag resolves (fail-safe)

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final variant = await ref.read(featureFlagsProvider).getVariant(
          FeatureFlagKeys.paywallVariant,
          allowed: FeatureFlagKeys.paywallVariants,
        );
    if (mounted) setState(() => _variant = variant);
    await Analytics.paywallShown(variant); // variant captured for the A/B funnel
    await _load();
  }

  Future<void> _load() async {
    try {
      final offerings = await Purchases.getOfferings();
      _offering = offerings.current;
    } catch (_) {
      // Offerings not configured yet (founder sets them in RevenueCat).
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _purchase(Package? pkg) async {
    if (pkg == null || _purchasing) return;
    setState(() => _purchasing = true);
    try {
      if (pkg.storeProduct.introductoryPrice != null) {
        await Analytics.trialStarted();
      }
      // ignore: deprecated_member_use
      final result = await Purchases.purchasePackage(pkg);
      if (result.customerInfo.entitlements.active.isNotEmpty) {
        await Analytics.subscriptionConverted();
        if (mounted) {
          // M3 (#15): calm welcome moment on a REAL entitlement-active
          // purchase — ≤2.5s, tap-skippable, reduce-motion → text snackbar.
          // Purchase/eligibility logic above is untouched (visual swap only).
          await showCelebration(
            context,
            motionAsset: AppMotionAssets.premiumWelcome,
            fallbackAsset: AppAssets.paywallPeace,
            message: 'Welcome to Premium 🎉',
            duration: const Duration(milliseconds: 2500),
          );
          if (mounted) Navigator.of(context).pop(true);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Purchase did not complete: $e')));
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  // Plan cards in the order/emphasis dictated by the variant.
  List<Widget> _plans(Package? annual, Package? monthly) {
    final annualCard = _PlanCard(
      key: const Key('paywall_annual'),
      title: 'Annual',
      price: annual?.storeProduct.priceString ?? '\$59.99 / year',
      subtitle: 'About \$5/month, billed yearly',
      featured: _variant != 'B', // featured in A/C; in B it's the badged secondary
      badge: _variant == 'B' ? 'Best value' : 'Save 50%',
      busy: _purchasing,
      onTap: () => _purchase(annual),
    );
    final monthlyCard = _PlanCard(
      key: const Key('paywall_monthly'),
      title: 'Monthly',
      price: monthly?.storeProduct.priceString ?? '\$9.99 / month',
      subtitle: 'Flexible, cancel anytime',
      featured: _variant == 'B', // monthly is the hero in Variant B
      busy: _purchasing,
      onTap: () => _purchase(monthly),
    );
    final cards = _variant == 'B'
        ? [monthlyCard, annualCard] // monthly first (Variant B)
        : [annualCard, monthlyCard]; // annual-first (A control + C)
    return [
      cards.first,
      const SizedBox(height: 12),
      cards.last,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final annual = _offering?.annual;
    final monthly = _offering?.monthly;

    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('PawDoc Premium'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.s20),
        children: [
          Text('Unlimited peace of mind',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.ink50, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpace.s8),
          Text(
              'Unlimited AI health checks, history, and reminders for all your pets.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.ink300)),
          const SizedBox(height: AppSpace.s16),
          Center(
            // M1 (A4): sleeper breathes with floating "z"; static PNG (the new
            // premium night hero) under reduce-motion.
            child: AppMotionAsset(
              AppMotionAssets.paywallPeaceLoop,
              fallbackAsset: AppAssets.premiumSleepingDog,
              height: 180,
              fallback: const SizedBox.shrink(), // graceful: hide if no art yet
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          const _TrustPillars(),
          const SizedBox(height: AppSpace.s16),
          const _ValueStack(),
          // Variant C: a truthful value/trust card (was a fabricated testimonial;
          // honesty-fixed in Phase B). Layout-only A/B arm — analytics unchanged.
          if (_variant == 'C') ...[
            const SizedBox(height: AppSpace.s16),
            const _SocialProof(),
          ],
          const SizedBox(height: AppSpace.s24),
          // Plans render only when RevenueCat offerings are configured. When they
          // aren't, we show a production-safe "coming soon" state instead of
          // placeholder-priced CTAs or any internal/dev text.
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpace.s24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_offering == null)
            const _PremiumComingSoon()
          else
            ..._plans(annual, monthly),
          const SizedBox(height: AppSpace.s16),
          TextButton(
            onPressed: () async {
              try {
                await Purchases.restorePurchases();
              } catch (_) {}
            },
            child: const Text('Restore purchases'),
          ),
          TextButton(
            key: const Key('paywall_not_now'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Not now'),
          ),
        ],
      ),
      ),
    );
  }
}

/// Variant C card. Honesty-fixed (Phase B): truthful value/trust copy (see
/// paywall_copy.dart), CMS-swappable; no fabricated testimonial, no medical
/// guarantee implied.
class _SocialProof extends StatelessWidget {
  const _SocialProof();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('paywall_social_proof'),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primary,
                  child: Icon(Icons.verified_user_rounded, color: scheme.onPrimary),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(PaywallSocialProof.trustTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(PaywallSocialProof.trustSubtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s12),
            Text(PaywallSocialProof.valueLine,
                style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}

/// Production-safe state shown when RevenueCat offerings aren't configured —
/// replaces the old internal "runbook 09" dev text. No purchasable CTAs here.
class _PremiumComingSoon extends StatelessWidget {
  const _PremiumComingSoon();

  @override
  Widget build(BuildContext context) {
    return PawCard(
      key: const Key('paywall_coming_soon'),
      padding: const EdgeInsets.all(AppSpace.s20),
      child: Column(
        children: [
          AppImage(
            AppAssets.premiumEnvelopePaw,
            height: 96,
            fallback: const Icon(Icons.lock_clock_rounded,
                size: 40, color: PawPalette.mint),
          ),
          const SizedBox(height: AppSpace.s12),
          Text('Premium is coming soon',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink50, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.s8),
          Text(
            'Subscriptions aren’t available just yet. Keep using PawDoc — '
            'we’ll let you know the moment Premium opens.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.ink300),
          ),
        ],
      ),
    );
  }
}

/// Truthful trust pillars (replaces the deliberately-omitted fabricated social
/// proof from the 011 mockup). No metrics, ratings, or testimonials — only
/// defensible statements about how PawDoc is built. CMS-swappable later.
class _TrustPillars extends StatelessWidget {
  const _TrustPillars();

  static const _pillars = <(IconData, String)>[
    (Icons.medical_services_outlined, 'Designed with veterinarians in mind'),
    (Icons.health_and_safety_outlined, 'Built to err on the safe side'),
    (Icons.event_repeat_rounded, 'Trusted routines for everyday pet care'),
  ];

  @override
  Widget build(BuildContext context) {
    return PawCard(
      key: const Key('paywall_trust_pillars'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, text) in _pillars)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: PawPalette.mint),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Text(text,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.ink50)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "What you get" — the real Premium features (§3.8 value stack).
class _ValueStack extends StatelessWidget {
  const _ValueStack();

  static const _features = [
    'Unlimited AI health checks',
    'Full health history',
    'Reminders for every pet',
    'Weekly AI health journal',
    'Family & sitter sharing',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in _features)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: AppSpace.s12),
                Expanded(child: Text(f, style: Theme.of(context).textTheme.bodyLarge)),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.subtitle,
    required this.featured,
    required this.busy,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final String subtitle;
  final bool featured;
  final bool busy;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: featured ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: featured ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: AppRadius.brSm,
                ),
                child: Text(badge!, style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer)),
              ),
            ],
          ],
        ),
        subtitle: Text('$price\n$subtitle'),
        isThreeLine: true,
        trailing: FilledButton(
          onPressed: busy ? null : onTap,
          child: Text(featured ? 'Start' : 'Choose'),
        ),
      ),
    );
  }
}
