import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/analytics.dart';
import '../config/env.dart';

/// Phase 6.3 — Pet-insurance affiliate CTA (e.g. Trupanion / Healthy Paws).
///
/// Self-hides when [Env.petInsuranceAffiliateUrl] is empty (dev/test builds),
/// so the app stays safe even before the affiliate URL is signed. Tapping
/// fires `insurance_affiliate_clicked` and opens the partner URL externally.
class InsuranceAffiliateCta extends StatelessWidget {
  const InsuranceAffiliateCta({
    super.key,
    required this.source,
    this.dense = false,
  });

  /// Where the tap originated — analytics chip.
  final String source;
  final bool dense;

  Future<void> _onTap() async {
    final raw = Env.petInsuranceAffiliateUrl;
    if (raw.isEmpty) return;
    await Analytics.insuranceAffiliateClicked(source);
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (Env.petInsuranceAffiliateUrl.isEmpty) return const SizedBox.shrink();

    if (dense) {
      return TextButton.icon(
        key: const Key('insurance_affiliate_cta_dense'),
        onPressed: _onTap,
        icon: const Icon(Icons.shield_outlined),
        label: const Text('Get a pet-insurance quote'),
      );
    }
    return Card(
      key: const Key('insurance_affiliate_cta_card'),
      child: ListTile(
        leading: const Icon(Icons.shield_outlined),
        title: const Text('Pet insurance'),
        subtitle: const Text(
            'Compare plans from our partners — cover vet bills before the next surprise.'),
        trailing: FilledButton(
          key: const Key('insurance_affiliate_cta_button'),
          onPressed: _onTap,
          child: const Text('Get a quote'),
        ),
      ),
    );
  }
}
