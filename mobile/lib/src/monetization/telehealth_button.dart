import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../analytics/analytics.dart';
import '../config/env.dart';

/// Phase 5.4 — embedded telehealth (Airvet-style affiliate).
///
/// Self-hides when [Env.airvetAffiliateUrl] is empty (dev/test builds), so the
/// app is safe even if the founder hasn't set the build define yet. Tapping
/// fires `telehealth_clicked` (with the `source` chip) and opens the partner
/// URL in an external browser — revenue share. No PII leaves the app.
class TelehealthButton extends StatelessWidget {
  const TelehealthButton({
    super.key,
    required this.source,
    this.dense = false,
  });

  /// Where the tap originated (`emergency_result`, `monitor_result`, `home`).
  final String source;

  /// Compact rendering (icon + label) used on the Home card; the larger card
  /// rendering is used on result screens.
  final bool dense;

  Future<void> _onTap() async {
    final raw = Env.airvetAffiliateUrl;
    if (raw.isEmpty) return; // build define missing -> button is invisible anyway
    await Analytics.telehealthClicked(source);
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    // External launch — we never embed the partner in a webview (cookies/PII).
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (Env.airvetAffiliateUrl.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final title = l?.telehealthTitle ?? 'Talk to a vet now';
    final subtitle = l?.telehealthSubtitle ?? 'On-demand video consult with a licensed vet.';
    final cta = l?.telehealthCta ?? 'Consult a vet';

    if (dense) {
      return FilledButton.tonalIcon(
        key: const Key('telehealth_button_dense'),
        onPressed: _onTap,
        icon: const Icon(Icons.video_call_outlined),
        label: Text(cta),
      );
    }
    return Card(
      key: const Key('telehealth_button_card'),
      child: ListTile(
        leading: const Icon(Icons.video_call_outlined),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: FilledButton(
          key: const Key('telehealth_button_cta'),
          onPressed: _onTap,
          child: Text(cta),
        ),
      ),
    );
  }
}
