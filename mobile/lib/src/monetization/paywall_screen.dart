import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../analytics/analytics.dart';
import '../experiments/feature_flags.dart';
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
        if (mounted) Navigator.of(context).pop(true);
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
      badge: _variant == 'B' ? 'Best value' : null,
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

    return Scaffold(
      appBar: AppBar(title: const Text('PawDoc Premium')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Unlimited peace of mind', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Unlimited AI health checks, history, and reminders for all your pets.'),
          // Variant C: social proof (testimonial + vet advisor badge).
          if (_variant == 'C') ...[
            const SizedBox(height: 16),
            const _SocialProof(),
          ],
          const SizedBox(height: 24),
          ..._plans(annual, monthly),
          const SizedBox(height: 16),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _offering == null)
            const Text(
              'Subscriptions activate once products are configured in RevenueCat (runbook 09).',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
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
    );
  }
}

/// Social-proof block for Variant C. Copy is placeholder (see paywall_copy.dart)
/// and CMS-swappable; no medical guarantee implied.
class _SocialProof extends StatelessWidget {
  const _SocialProof();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('paywall_social_proof'),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primary,
                  child: const Icon(Icons.verified_user, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(PaywallSocialProof.vetAdvisorTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(PaywallSocialProof.vetAdvisorSubtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(PaywallSocialProof.testimonialQuote,
                style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Text(PaywallSocialProof.testimonialAuthor,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
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
        borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(8),
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
