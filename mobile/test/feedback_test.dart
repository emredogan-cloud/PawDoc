import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/feedback/analysis_feedback_repository.dart';

void main() {
  test('thumbs-up row carries only analysis_id + rating (no user_id)', () {
    final c = feedbackColumns(analysisId: 'a1', rating: 5);
    expect(c['analysis_id'], 'a1');
    expect(c['rating'], 5);
    expect(c.containsKey('outcome'), isFalse);
    expect(c.containsKey('comment'), isFalse);
    expect(c.containsKey('user_id'), isFalse); // ownership is via the parent analysis (RLS)
  });

  test('comment is trimmed and empty comments are dropped', () {
    expect(feedbackColumns(analysisId: 'a1', rating: 1, comment: '   ').containsKey('comment'), isFalse);
    expect(feedbackColumns(analysisId: 'a1', rating: 1, comment: '  off  ')['comment'], 'off');
  });

  test('follow-up outcome row carries the outcome', () {
    final c = feedbackColumns(analysisId: 'a1', outcome: FeedbackOutcome.resolvedOnOwn);
    expect(c['outcome'], 'resolved_on_own');
    expect(c.containsKey('rating'), isFalse);
  });
}
