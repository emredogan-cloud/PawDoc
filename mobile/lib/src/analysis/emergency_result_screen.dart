import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../analytics/analytics.dart';
import '../models/analysis_result.dart';
import '../monetization/insurance_affiliate_cta.dart';
import '../monetization/telehealth_button.dart';
import '../theme/design_tokens.dart';
import '../vet_finder/vet_finder_screen.dart';
import '../config/legal_urls.dart';
import 'result_l10n.dart';

/// EMERGENCY result: warm red, urgent copy, a vet-finder deep link, and an
/// explicit acknowledgment gate — the user MUST acknowledge before leaving
/// (back is blocked until then). Never paywalled.
class EmergencyResultScreen extends ConsumerStatefulWidget {
  const EmergencyResultScreen({super.key, required this.result});
  final AnalysisResult result;

  @override
  ConsumerState<EmergencyResultScreen> createState() => _EmergencyResultScreenState();
}

class _EmergencyResultScreenState extends ConsumerState<EmergencyResultScreen> {
  bool _acknowledged = false;

  @override
  void initState() {
    super.initState();
    Analytics.emergencyTriggered();
    Analytics.resultViewed('EMERGENCY');
  }

  void _findVet() {
    // Opens the location-aware finder; it falls back to native maps if location
    // is denied/unavailable, so this always works in an emergency.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VetFinderScreen(emergency: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safety-locked emergency red (#C62828, light variant). Phase H restyle was
    // deliberately the lightest possible touch on this screen: secondary text
    // raised from white70 → white for AA contrast. The ack gate, back-block,
    // find-vet prominence, paywall bypass, and all logic are UNCHANGED; no
    // illustration/glass/celebration/added motion (static = safest here).
    const red = AppColors.emergencyLight;
    final r = widget.result;
    // CR #11 (Phase 5.4): localized strings. `l!` is safe — AppLocalizations
    // is set up via the MaterialApp delegates; if missing in dev/test we'd
    // fail fast (acceptable, since this screen is safety-critical).
    final l = AppLocalizations.of(context)!;

    return PopScope(
      canPop: _acknowledged, // acknowledgment gate
      child: Scaffold(
        backgroundColor: red,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 64),
                const SizedBox(height: 12),
                Text(l.emergencyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                // M0 F-3: dynamic values are display-localized (template +
                // urgency mapping); unknown values pass through verbatim.
                // Pure string presentation — gate/logic untouched.
                Text(localizedPrimaryConcern(l, r.primaryConcern),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 8),
                Text(l.emergencyRecommendedPrefix(localizedUrgency(l, r.urgencyTimeframe)),
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('emergency_find_vet'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: red,
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(56),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _findVet,
                  icon: const Icon(Icons.local_hospital),
                  label: Text(l.emergencyFindVet),
                ),
                const SizedBox(height: 12),
                // Phase 5.4 — Airvet-style telehealth deep-link, prominently
                // placed on the emergency screen (revenue-share affiliate).
                const TelehealthButton(source: 'emergency_result'),
                const SizedBox(height: 8),
                // Phase 6.3 — pet-insurance affiliate CTA. Self-hides if
                // PET_INSURANCE_AFFILIATE_URL isn't configured.
                const InsuranceAffiliateCta(source: 'emergency_result'),
                const SizedBox(height: 24),
                if (r.disclaimerRequired)
                  Container(
                    padding: const EdgeInsets.all(AppSpace.s12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: AppRadius.brMd,
                    ),
                    child: Text(
                      l.emergencyDisclaimer,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                if (r.disclaimerRequired)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () => LegalUrls.open(LegalUrls.emergency),
                      child: const Text(
                        'Read the full Emergency Disclaimer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  key: const Key('emergency_ack_checkbox'),
                  value: _acknowledged,
                  onChanged: (v) => setState(() => _acknowledged = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  tileColor: Colors.white24,
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
                  title: Text(l.emergencyAcknowledge,
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('emergency_continue'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: red,
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(56),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _acknowledged ? () => Navigator.of(context).maybePop() : null,
                  child: Text(l.actionContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
