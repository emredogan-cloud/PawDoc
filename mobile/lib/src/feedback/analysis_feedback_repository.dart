import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';

/// Outcome values for the 72h follow-up (mirror the `analysis_feedback.outcome`
/// domain noted in the schema).
class FeedbackOutcome {
  const FeedbackOutcome._();
  static const resolvedOnOwn = 'resolved_on_own';
  static const vetConfirmed = 'vet_confirmed';
  static const vetSaidNothing = 'vet_said_nothing';
  static const stillMonitoring = 'still_monitoring';
  static const other = 'other';
}

/// Build the `analysis_feedback` insert row. Pure + unit-tested: omits absent
/// fields and trims the comment. No `user_id` — ownership is enforced by RLS
/// through the parent analysis (CR #2).
Map<String, dynamic> feedbackColumns({
  required String analysisId,
  int? rating,
  String? outcome,
  String? comment,
}) {
  final trimmed = comment?.trim();
  return {
    'analysis_id': analysisId,
    'rating': ?rating, // null-aware element: omitted when rating is null
    if (outcome != null && outcome.isNotEmpty) 'outcome': outcome,
    if (trimmed != null && trimmed.isNotEmpty) 'comment': trimmed,
  };
}

/// Writes user feedback to `analysis_feedback` (RLS-scoped via the parent
/// analysis — a user can only submit feedback for their own analyses).
class AnalysisFeedbackRepository {
  AnalysisFeedbackRepository(this._client);

  final SupabaseClient _client;

  Future<void> submit({
    required String analysisId,
    int? rating,
    String? outcome,
    String? comment,
  }) async {
    await _client.from('analysis_feedback').insert(
          feedbackColumns(analysisId: analysisId, rating: rating, outcome: outcome, comment: comment),
        );
  }
}

final analysisFeedbackRepositoryProvider = Provider<AnalysisFeedbackRepository>((ref) {
  return AnalysisFeedbackRepository(ref.watch(supabaseClientProvider));
});
