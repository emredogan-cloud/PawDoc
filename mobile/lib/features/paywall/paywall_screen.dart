/// Paywall — surfaced when the analyze flow returns 402 quotaExceeded.
///
/// Discipline (per `phase1d-production-plan.md` §6.1):
///   - Annual-first display.
///   - "Maybe later" button is equally weighted to subscribe CTAs.
///   - "Restore purchases" link visible at the bottom.
///   - No scarcity language. No countdown timers. Clear price + renewal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'paywall_controller.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paywallControllerProvider);
    final theme = Theme.of(context);

    ref.listen<PaywallState>(paywallControllerProvider, (_, next) {
      if (next is PaywallSucceeded) {
        // Navigate the user back to home; the next analyze call will pick
        // up their new entitlement when the webhook lands.
        Future<void>.microtask(() {
          if (context.mounted) context.go('/home');
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Go unlimited'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: switch (state) {
          PaywallLoading() => const Center(child: CircularProgressIndicator()),
          PaywallEmpty(reason: final r) => _EmptyBody(reason: r),
          PaywallPurchasing() => const Center(
            child: CircularProgressIndicator(),
          ),
          PaywallSucceeded() => _SuccessBody(),
          PaywallFailed(kind: final k) => _FailedBody(message: k.userMessage),
          PaywallReady(offering: final offering, notice: final notice) =>
            _ReadyBody(
              offering: offering,
              notice: notice,
              onPurchase: (pkg) =>
                  ref.read(paywallControllerProvider.notifier).purchase(pkg),
              onRestore: () =>
                  ref.read(paywallControllerProvider.notifier).restore(),
              onMaybeLater: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              theme: theme,
            ),
        },
      ),
    );
  }
}

class _ReadyBody extends StatefulWidget {
  const _ReadyBody({
    required this.offering,
    required this.onPurchase,
    required this.onRestore,
    required this.onMaybeLater,
    required this.theme,
    this.notice,
  });

  final Offering offering;
  final String? notice;
  final void Function(Package package) onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onMaybeLater;
  final ThemeData theme;

  @override
  State<_ReadyBody> createState() => _ReadyBodyState();
}

class _ReadyBodyState extends State<_ReadyBody> {
  Package? _selected;

  @override
  void initState() {
    super.initState();
    final pkgs = widget.offering.availablePackages;
    // Annual-first: prefer the package whose store identifier ends in
    // "annual" or whose period > monthly. Fallback to first.
    _selected = _preferAnnual(pkgs);
  }

  Package? _preferAnnual(List<Package> pkgs) {
    if (pkgs.isEmpty) return null;
    for (final p in pkgs) {
      final id = p.storeProduct.identifier.toLowerCase();
      if (id.contains('annual') || id.contains('year')) return p;
    }
    return pkgs.first;
  }

  @override
  Widget build(BuildContext context) {
    final pkgs = widget.offering.availablePackages;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Unlimited triage for less than the cost of a vet visit.',
            style: widget.theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const _BulletPoints(
            items: [
              'Unlimited AI analyses, day or night',
              'Save analyses to your pet history',
              'Up to 2 pets on Premium',
              'Cancel anytime',
            ],
          ),
          const SizedBox(height: 16),
          if (widget.notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.notice!,
                style: widget.theme.textTheme.bodySmall,
              ),
            ),
          for (final p in pkgs)
            _PackageTile(
              package: p,
              isSelected: _selected?.identifier == p.identifier,
              onTap: () => setState(() => _selected = p),
              theme: widget.theme,
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () => widget.onPurchase(_selected!),
            child: const Text('Continue'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.onMaybeLater,
            child: const Text('Maybe later'),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: widget.onRestore,
              child: const Text('Restore purchases'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your subscription renews automatically and can be cancelled '
            'in your App Store / Play Store settings. Privacy Policy and '
            'Terms of Service are available at pawdoc.app.',
            style: widget.theme.textTheme.bodySmall?.copyWith(
              color: widget.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  final Package package;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final priceString = package.storeProduct.priceString;
    final title = package.storeProduct.title.isNotEmpty
        ? package.storeProduct.title
        : package.identifier;
    final description = package.storeProduct.description;
    final isAnnual =
        package.identifier.toLowerCase().contains('annual') ||
        package.storeProduct.identifier.toLowerCase().contains('annual');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        if (isAnnual) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Best value',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(priceString, style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletPoints extends StatelessWidget {
  const _BulletPoints({required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(i)),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.reason});
  final String reason;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(reason, textAlign: TextAlign.center),
    ),
  );
}

class _SuccessBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            "You're set. Your subscription is syncing in the background.",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _FailedBody extends StatelessWidget {
  const _FailedBody({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
