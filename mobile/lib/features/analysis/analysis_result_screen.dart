/// Result screen — renders an AnalysisResult.
///
/// Three triage variants share the same scaffold; the color, headline,
/// and CTA differ. EMERGENCY has an explicit acknowledgement gate before
/// the user can dismiss.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/models/analysis_result.dart';
import '../../shared/widgets/disclaimer.dart';
import '../../shared/widgets/triage_badge.dart';
import 'analysis_controller.dart';

class AnalysisResultScreen extends ConsumerWidget {
  const AnalysisResultScreen({super.key, required this.result});
  final AnalysisResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isEmergency = result.triageLevel == TriageLevel.emergency;

    return PopScope(
      canPop: !isEmergency,
      child: Scaffold(
        backgroundColor: _backgroundColor(theme, result.triageLevel),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: !isEmergency,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TriageBadge(level: result.triageLevel, large: true),
                const SizedBox(height: 20),
                Text(
                  _headline(result),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (result.crossVerifyDisagreement && !isEmergency)
                  const _Card(
                    title: "We're being cautious here",
                    body: Text(
                      "Our review wasn't fully sure. We've flagged this so you "
                      'can decide whether to see a vet sooner.',
                    ),
                  ),
                if (result.emergencyOverrideApplied)
                  const _Card(
                    title: 'Triggered by your description',
                    body: Text(
                      'We detected words that match a real emergency. Please '
                      'act on this even if your pet looks okay right now.',
                    ),
                  ),
                if (result.isGracefulDegradation)
                  const _Card(
                    title: 'Limited analysis',
                    body: Text(
                      "Our AI service couldn't process this with confidence. "
                      'Please consult a vet directly.',
                    ),
                  ),
                _Card(
                  title: 'What we noticed',
                  body: Text(result.primaryConcern),
                ),
                if (result.visibleSymptoms.isNotEmpty)
                  _Card(
                    title: 'Visible symptoms',
                    body: _BulletList(items: result.visibleSymptoms),
                  ),
                if (result.recommendedActions.isNotEmpty)
                  _Card(
                    title: 'What to do',
                    body: _NumberedList(items: result.recommendedActions),
                  ),
                _Card(title: 'Urgency', body: Text(result.urgencyTimeframe)),
                const SizedBox(height: 12),
                Text(
                  result.disclaimerText.isEmpty
                      ? kCanonicalDisclaimer
                      : result.disclaimerText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _backgroundColor(
                        theme,
                        result.triageLevel,
                      ),
                    ),
                    onPressed: () {
                      ref.read(analysisControllerProvider.notifier).reset();
                      context.go('/home');
                    },
                    child: Text(isEmergency ? 'I understand' : 'Back home'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _headline(AnalysisResult r) => switch (r.triageLevel) {
    TriageLevel.emergency => 'Seek veterinary care immediately.',
    TriageLevel.monitor => 'Worth a vet visit soon.',
    TriageLevel.normal => 'Looks routine for now.',
  };

  Color _backgroundColor(ThemeData theme, TriageLevel level) => switch (level) {
    TriageLevel.emergency => AppTheme.triageEmergency,
    TriageLevel.monitor => AppTheme.triageMonitor,
    TriageLevel.normal => AppTheme.triageNormal,
  };
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.body});
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodyMedium,
            child: body,
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final i in items)
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $i')),
    ],
  );
}

class _NumberedList extends StatelessWidget {
  const _NumberedList({required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('${i + 1}. ${items[i]}'),
        ),
    ],
  );
}
