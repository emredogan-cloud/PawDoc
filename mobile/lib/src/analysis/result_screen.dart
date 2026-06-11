import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../analytics/analytics.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../feedback/result_feedback_widget.dart';
import '../models/analysis_result.dart';
import '../monetization/insurance_affiliate_cta.dart';
import '../monetization/telehealth_button.dart';
import '../theme/design_tokens.dart';
import '../vet_finder/vet_finder_screen.dart';
import 'emergency_result_screen.dart';

/// Routes to the EMERGENCY screen or the standard result screen. [analysisId]
/// (null if the row failed to store) gates the in-app feedback widget.
/// [petName] feeds the M1 "Saved to {Pet}'s history" confirmation — standard
/// screen ONLY; the EMERGENCY screen receives no motion/celebration additions.
class ResultScreen extends StatelessWidget {
  const ResultScreen(
      {super.key, required this.result, this.analysisId, this.onDone, this.petName});
  final AnalysisResult result;
  final String? analysisId;
  final VoidCallback? onDone;
  final String? petName;

  @override
  Widget build(BuildContext context) {
    if (result.triageLevel == TriageLevel.emergency) {
      return EmergencyResultScreen(result: result);
    }
    return StandardResultScreen(
        result: result, analysisId: analysisId, onDone: onDone, petName: petName);
  }
}

// Safety-locked triage hues, codified to tokens (values unchanged).
Color _triageColor(TriageLevel l) => switch (l) {
      TriageLevel.emergency => AppColors.emergencyLight,
      TriageLevel.monitor => AppColors.monitorLight,
      TriageLevel.normal => AppColors.normalLight,
    };

// Distinct shape per triage level so the verdict is never conveyed by colour
// alone (a11y) — pairs with the colour + the text label.
IconData _triageIcon(TriageLevel l) => switch (l) {
      TriageLevel.emergency => Icons.warning_amber_rounded,
      TriageLevel.monitor => Icons.visibility_outlined,
      TriageLevel.normal => Icons.check_circle_rounded,
    };

// On-colour for the triage hero. MONITOR amber is light → dark text/icon for AA
// contrast; the saturated red/green carry white.
Color _triageOnColor(TriageLevel l) =>
    l == TriageLevel.monitor ? AppColors.ink900 : Colors.white;

String _triageLabel(TriageLevel l) => switch (l) {
      TriageLevel.emergency => 'EMERGENCY',
      TriageLevel.monitor => 'MONITOR — keep an eye out',
      TriageLevel.normal => 'LIKELY NORMAL',
    };

const _escalationTriggers = [
  'Symptoms get worse or new ones appear',
  'Your pet stops eating or drinking',
  'You feel something is wrong',
];

class StandardResultScreen extends ConsumerStatefulWidget {
  const StandardResultScreen(
      {super.key, required this.result, this.analysisId, this.onDone, this.petName});
  final AnalysisResult result;
  final String? analysisId;
  final VoidCallback? onDone;
  final String? petName;

  @override
  ConsumerState<StandardResultScreen> createState() => _StandardResultScreenState();
}

class _StandardResultScreenState extends ConsumerState<StandardResultScreen> {
  @override
  void initState() {
    super.initState();
    Analytics.resultViewed(widget.result.triageLevel.wireValue);
  }

  Future<void> _share() async {
    final r = widget.result;
    final text = 'PawDoc check: ${_triageLabel(r.triageLevel)}.\n'
        '${r.primaryConcern}\n\n'
        'Shared via PawDoc 🐾 — pawdoc.app';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        // M1 (matrix #7): sections fade-up in 280ms beats instead of popping
        // in; instant under reduce-motion. Decorative only — every element is
        // present and hittable from the first frame.
        children: _staggered(context, [
          _TriageHero(level: r.triageLevel),
          // "Saved to {Pet}'s history" — only when the row truly stored (honesty:
          // celebrations fire on real events only).
          if (widget.analysisId != null && widget.petName != null) ...[
            const SizedBox(height: 12),
            _SavedConfirmation(petName: widget.petName!),
          ],
          const SizedBox(height: 16),
          Text(r.primaryConcern, style: Theme.of(context).textTheme.titleMedium),
          if (r.visibleSymptoms.isNotEmpty) ...[
            const SizedBox(height: 16),
            _section('What we noticed', [for (final s in r.visibleSymptoms) '• $s']),
          ],
          if (r.differential.isNotEmpty) ...[
            const SizedBox(height: 16),
            _section('Possible causes', [for (final d in r.differential) '• $d']),
          ],
          const SizedBox(height: 16),
          _section('What to do', [
            for (var i = 0; i < r.recommendedActions.length; i++) '${i + 1}. ${r.recommendedActions[i]}',
          ]),
          const SizedBox(height: 16),
          _section('When to seek a vet (${r.urgencyTimeframe})', [for (final e in _escalationTriggers) '• $e']),
          if (r.disclaimerRequired) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(AppSpace.s12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.brSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      'PawDoc provides information, not a veterinary diagnosis. When in doubt, contact your vet.',
                      // AA contrast (onSurface on the raised container).
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          // MONITOR offers the location-aware vet finder (EMERGENCY has its own);
          // NORMAL offers sharing.
          if (r.triageLevel == TriageLevel.monitor) ...[
            OutlinedButton.icon(
              key: const Key('result_find_vet'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VetFinderScreen()),
              ),
              icon: const Icon(Icons.local_hospital_outlined),
              label: const Text('Find a nearby vet'),
            ),
            const SizedBox(height: 8),
            // Phase 5.4 — telehealth deep link as a parallel option on MONITOR.
            const TelehealthButton(source: 'monitor_result'),
          ],
          if (r.triageLevel == TriageLevel.normal)
            OutlinedButton.icon(
              key: const Key('result_share'),
              onPressed: _share,
              icon: const Icon(Icons.share),
              label: const Text('Share this result'),
            ),
          // Phase 6.3 — Pet-insurance affiliate CTA on the standard result.
          // Self-hides if PET_INSURANCE_AFFILIATE_URL isn't configured.
          const SizedBox(height: 8),
          InsuranceAffiliateCta(source: r.triageLevel == TriageLevel.monitor
              ? 'monitor_result'
              : 'normal_result'),
          // In-app feedback (Phase 4.1) — only when the analysis was stored.
          if (widget.analysisId != null) ...[
            const SizedBox(height: 16),
            ResultFeedbackWidget(analysisId: widget.analysisId!),
          ],
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('result_done'),
            onPressed: widget.onDone ?? () => Navigator.of(context).maybePop(),
            child: const Text('Done'),
          ),
        ]),
      ),
    );
  }

  /// 280ms fade-up beats, 40ms apart (M1 #7). Widgets are in the tree (and
  /// tappable) immediately; only opacity/offset animate. Reduce-motion: none.
  List<Widget> _staggered(BuildContext context, List<Widget> children) {
    if (reduceMotion(context)) return children;
    return [
      for (var i = 0; i < children.length; i++)
        children[i]
            .animate()
            .fadeIn(
                duration: const Duration(milliseconds: 280),
                delay: Duration(milliseconds: 40 * i))
            .slideY(
                begin: 0.04,
                end: 0,
                duration: const Duration(milliseconds: 280),
                curve: AppMotion.emphasized),
    ];
  }

  Widget _section(String title, List<String> lines) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final l in lines) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l)),
        ],
      );
}

/// M1 (matrix #7): the quiet "it's in the record" reassurance beat — a calm
/// confirmation chip, not a celebration. Slides in after the verdict lands;
/// static under reduce-motion.
class _SavedConfirmation extends StatelessWidget {
  const _SavedConfirmation({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = Container(
      key: const Key('result_saved_confirmation'),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12, vertical: AppSpace.s8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpace.s8),
          Flexible(
            child: Text(
              'Saved to ${petDisplayName(petName)}’s history',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
    if (reduceMotion(context)) return chip;
    return chip
        .animate()
        .fadeIn(
            delay: const Duration(milliseconds: 400),
            duration: const Duration(milliseconds: 280))
        .slideY(
            begin: -0.3,
            end: 0,
            delay: const Duration(milliseconds: 400),
            duration: const Duration(milliseconds: 280),
            curve: AppMotion.emphasized);
  }
}

/// Triage verdict hero: colour + distinct shape (icon) + text label — never
/// colour alone (a11y). AA on-colour; live-region announces the verdict first.
/// Gentle reduce-motion-gated reveal; no bounce (gravity, not party).
class _TriageHero extends StatelessWidget {
  const _TriageHero({required this.level});
  final TriageLevel level;

  @override
  Widget build(BuildContext context) {
    final onColor = _triageOnColor(level);
    final hero = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s20),
      decoration: BoxDecoration(
        color: _triageColor(level),
        borderRadius: AppRadius.brXl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_triageIcon(level), color: onColor, size: 28),
          const SizedBox(width: AppSpace.s12),
          Flexible(
            child: Semantics(
              liveRegion: true,
              child: Text(
                _triageLabel(level),
                style: TextStyle(
                    color: onColor, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
    if (reduceMotion(context)) return hero;
    return hero.animate().fadeIn(duration: AppMotion.standard).scaleXY(
        begin: 0.98,
        end: 1.0,
        duration: AppMotion.standard,
        curve: AppMotion.emphasized);
  }
}
