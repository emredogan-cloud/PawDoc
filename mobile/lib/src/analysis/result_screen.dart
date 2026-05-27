import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../analytics/analytics.dart';
import '../models/analysis_result.dart';
import 'emergency_result_screen.dart';

/// Routes to the EMERGENCY screen or the standard result screen.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result, this.onDone});
  final AnalysisResult result;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    if (result.triageLevel == TriageLevel.emergency) {
      return EmergencyResultScreen(result: result);
    }
    return StandardResultScreen(result: result, onDone: onDone);
  }
}

Color _triageColor(TriageLevel l) => switch (l) {
      TriageLevel.emergency => const Color(0xFFC62828),
      TriageLevel.monitor => const Color(0xFFFFB300),
      TriageLevel.normal => const Color(0xFF2E7D32),
    };

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
  const StandardResultScreen({super.key, required this.result, this.onDone});
  final AnalysisResult result;
  final VoidCallback? onDone;

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
    final color = _triageColor(r.triageLevel);

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Text(
              _triageLabel(r.triageLevel),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PawDoc provides information, not a veterinary diagnosis. When in doubt, contact your vet.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (r.triageLevel == TriageLevel.normal)
            OutlinedButton.icon(
              key: const Key('result_share'),
              onPressed: _share,
              icon: const Icon(Icons.share),
              label: const Text('Share this result'),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('result_done'),
            onPressed: widget.onDone ?? () => Navigator.of(context).maybePop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
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
