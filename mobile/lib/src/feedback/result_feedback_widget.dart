import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import 'analysis_feedback_repository.dart';

/// Thumbs up/down "Was this assessment helpful?" on the standard result screen.
/// Thumbs-down reveals an optional comment. Writes to `analysis_feedback`
/// (RLS-scoped via the parent analysis). Never blocks the result UI — a failure
/// shows a snackbar and leaves the result intact.
class ResultFeedbackWidget extends ConsumerStatefulWidget {
  const ResultFeedbackWidget({super.key, required this.analysisId});

  final String analysisId;

  @override
  ConsumerState<ResultFeedbackWidget> createState() => _ResultFeedbackWidgetState();
}

class _ResultFeedbackWidgetState extends ConsumerState<ResultFeedbackWidget> {
  bool _submitted = false;
  bool _showComment = false;
  bool _busy = false;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit({required int rating}) async {
    setState(() => _busy = true);
    try {
      await ref.read(analysisFeedbackRepositoryProvider).submit(
            analysisId: widget.analysisId,
            rating: rating,
            comment: rating == 1 ? _comment.text : null,
          );
      await Analytics.feedbackSubmitted('result_thumbs');
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send feedback. Please try again.')),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Thanks for the feedback 🐾'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Was this assessment helpful?', style: Theme.of(context).textTheme.titleSmall),
        Row(
          children: [
            IconButton(
              key: const Key('feedback_thumbs_up'),
              tooltip: 'Helpful',
              onPressed: _busy ? null : () => _submit(rating: 5),
              icon: const Icon(Icons.thumb_up_outlined),
            ),
            IconButton(
              key: const Key('feedback_thumbs_down'),
              tooltip: 'Not helpful',
              onPressed: _busy ? null : () => setState(() => _showComment = true),
              icon: const Icon(Icons.thumb_down_outlined),
            ),
          ],
        ),
        if (_showComment) ...[
          TextField(
            key: const Key('feedback_comment'),
            controller: _comment,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'What was off? (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('feedback_send'),
            onPressed: _busy ? null : () => _submit(rating: 1),
            child: const Text('Send feedback'),
          ),
        ],
      ],
    );
  }
}
