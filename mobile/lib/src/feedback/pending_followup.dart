import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/supabase_providers.dart';
import 'followup_prefs.dart';

class PendingFollowup {
  const PendingFollowup({required this.analysisId, required this.triageLevel});
  final String analysisId;
  final String triageLevel;
}

/// The most recent analysis eligible for the 72h "was this helpful?" prompt
/// (older than 72h, no feedback yet) via the RLS-scoped `pending_followup_analyses`
/// RPC. Returns null when nothing is pending, the banner is snoozed, or on any
/// error — never throws, so it can't break the home screen.
final pendingFollowupProvider = FutureProvider.autoDispose<PendingFollowup?>((ref) async {
  if (await FollowUpPrefs.isSnoozed()) return null;
  try {
    final client = ref.watch(supabaseClientProvider);
    final rows = await client.rpc('pending_followup_analyses');
    if (rows is List && rows.isNotEmpty) {
      final r = (rows.first as Map).cast<String, dynamic>();
      final id = r['id'] as String?;
      if (id != null) {
        return PendingFollowup(
          analysisId: id,
          triageLevel: (r['triage_level'] as String?) ?? '',
        );
      }
    }
  } catch (_) {
    // Offline / RPC error -> no banner (never block the home screen).
  }
  return null;
});
