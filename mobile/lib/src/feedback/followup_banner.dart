import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import 'analysis_feedback_repository.dart';
import 'followup_prefs.dart';
import 'pending_followup.dart';

/// Home-screen banner asking the outcome of an analysis from >72h ago that the
/// user hasn't reviewed. Self-hides when nothing is pending (or while loading).
/// Recording an outcome (or "Not now") removes it.
class FollowUpBanner extends ConsumerWidget {
  const FollowUpBanner({super.key});

  Future<void> _record(WidgetRef ref, String analysisId, String outcome) async {
    try {
      await ref.read(analysisFeedbackRepositoryProvider)
          .submit(analysisId: analysisId, outcome: outcome);
      await Analytics.feedbackSubmitted('followup');
    } catch (_) {
      // best-effort; eligibility refresh below still hides the banner
    }
    ref.invalidate(pendingFollowupProvider);
  }

  Future<void> _snooze(WidgetRef ref) async {
    await FollowUpPrefs.snooze(const Duration(hours: 24));
    ref.invalidate(pendingFollowupProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingFollowupProvider).asData?.value;
    if (pending == null) return const SizedBox.shrink();
    return Card(
      key: const Key('followup_banner'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Was your recent check helpful?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Tell us how it turned out — it helps us improve.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Resolved on its own'),
                  onPressed: () => _record(ref, pending.analysisId, FeedbackOutcome.resolvedOnOwn),
                ),
                ActionChip(
                  label: const Text('Vet confirmed it'),
                  onPressed: () => _record(ref, pending.analysisId, FeedbackOutcome.vetConfirmed),
                ),
                ActionChip(
                  label: const Text('Still monitoring'),
                  onPressed: () => _record(ref, pending.analysisId, FeedbackOutcome.stillMonitoring),
                ),
                ActionChip(
                  label: const Text("Wasn't accurate"),
                  onPressed: () => _record(ref, pending.analysisId, FeedbackOutcome.other),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('followup_not_now'),
                onPressed: () => _snooze(ref),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
