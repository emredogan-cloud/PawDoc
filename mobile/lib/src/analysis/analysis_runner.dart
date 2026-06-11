import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../models/analysis_result.dart';
import '../monetization/maybe_show_paywall.dart';
import '../monetization/paywall_prefs.dart';
import 'analysis_service.dart';
import 'loading_screen.dart';
import 'result_screen.dart';

enum _Phase { loading, result, error }

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
    setState(() => _phase = _Phase.loading);
    try {
      final outcome = await ref.read(analysisServiceProvider).analyze(
            petId: widget.petId,
            inputType: widget.inputType,
            textDescription: widget.textDescription,
            imageStorageKey: widget.imageStorageKey,
            frameStorageKeys: widget.frameStorageKeys,
          );
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _phase = _Phase.result;
      });
      // F-2: the home hero + pets-list chip read this; refresh it the moment
      // the analysis completes so "No checks yet" can never outlive a check.
      ref.invalidate(latestTriageProvider(widget.petId));
      // Side effects must not block or error the result UI.
      unawaited(Analytics.analysisCompleted(outcome.result.triageLevel.wireValue));
      unawaited(PaywallPrefs.markFirstAnalysisCompleted());
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _onResultDone() async {
    // EMERGENCY is never paywalled; the trust rule also enforces this.
    final wasEmergency = _outcome?.result.triageLevel == TriageLevel.emergency;
    await maybeShowPaywall(context,
        lastTriageWasEmergency: wasEmergency, isPremium: widget.isPremium);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const Scaffold(body: AnalysisLoadingView());
      case _Phase.error:
        return Scaffold(
          appBar: AppBar(title: const Text('Analysis')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
        );
    }
  }
}
