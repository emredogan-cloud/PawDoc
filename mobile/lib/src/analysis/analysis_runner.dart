import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../capture/upload_service.dart';
import '../core/motion.dart';
import '../experiments/feature_flags.dart';
import '../models/analysis_result.dart';
import '../monetization/maybe_show_paywall.dart';
import '../monetization/paywall_prefs.dart';
import '../theme/design_tokens.dart';
import 'analysis_service.dart';
import 'loading_screen.dart';
import 'result_screen.dart';

enum _Phase { loading, resolving, result, error }

/// Drives one analysis end-to-end: connects the Phase 1.2 input (R2 key/text)
/// to the Phase 1.3 `/analyze` Edge Function, shows the loading view, then the
/// result, then (for non-emergency) applies the paywall trust rule.
class AnalysisRunnerScreen extends ConsumerStatefulWidget {
  const AnalysisRunnerScreen({
    super.key,
    required this.petId,
    required this.petName,
    required this.inputType,
    this.petSpecies,
    this.textDescription,
    this.imageStorageKey,
    this.frameStorageKeys,
    this.isPremium = false,
  });

  final String petId;
  final String petName;
  final String inputType;

  /// M2 (#13): feeds the result screen's relief/attentive avatar beat.
  final String? petSpecies;
  final String? textDescription;
  final String? imageStorageKey;
  final List<String>? frameStorageKeys; // Phase 3.2 video keyframes
  final bool isPremium;

  @override
  ConsumerState<AnalysisRunnerScreen> createState() => _AnalysisRunnerScreenState();
}

class _AnalysisRunnerScreenState extends ConsumerState<AnalysisRunnerScreen> {
  _Phase _phase = _Phase.loading;
  AnalysisOutcome? _outcome;
  bool _firstCheckEver = false;
  // E8c: a specific upload failure reason, shown above (not instead of) the
  // safety nudge on the error screen.
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Analytics.analysisSubmitted(widget.inputType);
    if (widget.inputType == 'video') {
      Analytics.videoAnalysisSubmitted(widget.frameStorageKeys?.length ?? 0);
    }
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _phase = _Phase.loading;
      _errorMessage = null;
    });
    try {
      final outcome = await ref.read(analysisServiceProvider).analyze(
            petId: widget.petId,
            inputType: widget.inputType,
            textDescription: widget.textDescription,
            imageStorageKey: widget.imageStorageKey,
            frameStorageKeys: widget.frameStorageKeys,
          );
      if (!mounted) return;
      // M4 (#23, safety-review gated): non-emergency verdicts get one 450ms
      // pulse→verdict-hue resolve beat before the reveal. EMERGENCY keeps
      // the INSTANT cut (hard guardrail: never delay an emergency), and
      // reduce-motion users go straight to the result.
      final resolve =
          outcome.result.triageLevel != TriageLevel.emergency &&
              !reduceMotion(context);
      setState(() {
        _outcome = outcome;
        _phase = resolve ? _Phase.resolving : _Phase.result;
      });
      if (resolve) {
        unawaited(Future<void>.delayed(const Duration(milliseconds: 540))
            .then((_) {
          if (mounted && _phase == _Phase.resolving) {
            setState(() => _phase = _Phase.result);
          }
        }));
      }
      // F-2: the home hero + pets-list chip read this; refresh it the moment
      // the analysis completes so "No checks yet" can never outlive a check.
      ref.invalidate(latestTriageProvider(widget.petId));
      // Side effects must not block or error the result UI.
      unawaited(Analytics.analysisCompleted(outcome.result.triageLevel.wireValue));
      // M3 (#17): the one-time-ever "story has begun" toast — NEVER on an
      // EMERGENCY result (no celebration adjacency on the critical path).
      unawaited(PaywallPrefs.markFirstAnalysisCompleted().then((first) {
        if (first &&
            mounted &&
            outcome.result.triageLevel != TriageLevel.emergency) {
          setState(() => _firstCheckEver = true);
        }
      }));
    } on UploadException catch (e) {
      // E8c: surface the specific upload reason; the safety nudge still shows.
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _phase = _Phase.error;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _phase = _Phase.error;
        });
      }
    }
  }

  Future<void> _onResultDone() async {
    // EMERGENCY is never paywalled; the trust rule also enforces this.
    final wasEmergency = _outcome?.result.triageLevel == TriageLevel.emergency;
    await maybeShowPaywall(context,
        lastTriageWasEmergency: wasEmergency, isPremium: widget.isPremium);
    if (mounted) Navigator.of(context).pop();
  }

  Color _resolveColor(TriageLevel level) => switch (level) {
        TriageLevel.emergency => AppColors.emergencyLight, // never reached
        TriageLevel.monitor => AppColors.monitorLight,
        TriageLevel.normal => AppColors.normalLight,
      };

  @override
  Widget build(BuildContext context) {
    // M4 (#22) evaluation arm — PostHog 'pulse_pet_variant', control = OFF
    // (pulse-only). The A/B is decided by data, not taste; flipping the flag
    // exposes the calm pulse-pet without a release.
    final pulsePet = ref
                .watch(featureFlagProvider('pulse_pet_variant'))
                .maybeWhen(data: (v) => v, orElse: () => false) &&
            widget.petSpecies != null
        ? widget.petSpecies
        : null;

    switch (_phase) {
      case _Phase.loading:
        return Scaffold(body: AnalysisLoadingView(pulsePetSpecies: pulsePet));
      case _Phase.resolving:
        return Scaffold(
          body: AnalysisLoadingView(
            resolveColor: _resolveColor(_outcome!.result.triageLevel),
            pulsePetSpecies: pulsePet,
          ),
        );
      case _Phase.error:
        return Scaffold(
          appBar: AppBar(title: const Text('Analysis')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_errorMessage != null) ...[
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                  ],
                  const Text(
                    "We couldn't analyze this right now. If this seems urgent, contact a veterinarian.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _run, child: const Text('Try again')),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        );
      case _Phase.result:
        return ResultScreen(
          result: _outcome!.result,
          analysisId: _outcome!.analysisId,
          onDone: _onResultDone,
          petName: widget.petName,
          petSpecies: widget.petSpecies,
          firstCheckToast: _firstCheckEver,
        );
    }
  }
}
