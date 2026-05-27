import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../analytics/analytics.dart';

/// Annual-first paywall. Shown only after the first successful analysis and per
/// the trust rule (see maybe_show_paywall.dart). Never during an emergency.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Offering? _offering;
  bool _loading = true;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    Analytics.paywallShown();
    _load();
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
          const SizedBox(height: 24),
          // Annual first (featured).
          _PlanCard(
            key: const Key('paywall_annual'),
            title: 'Annual — best value',
            price: annual?.storeProduct.priceString ?? '\$59.99 / year',
            subtitle: 'About \$5/month, billed yearly',
            featured: true,
            busy: _purchasing,
            onTap: () => _purchase(annual),
          ),
          const SizedBox(height: 12),
          _PlanCard(
            key: const Key('paywall_monthly'),
            title: 'Monthly',
            price: monthly?.storeProduct.priceString ?? '\$9.99 / month',
            subtitle: 'Flexible, cancel anytime',
            featured: false,
            busy: _purchasing,
            onTap: () => _purchase(monthly),
          ),
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
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Not now'),
          ),
        ],
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
  });

  final String title;
  final String price;
  final String subtitle;
  final bool featured;
  final bool busy;
  final VoidCallback onTap;

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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
