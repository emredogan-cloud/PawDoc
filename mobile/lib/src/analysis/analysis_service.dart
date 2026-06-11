import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import '../models/analysis_result.dart';

/// The result of an analysis plus the stored row id.
class AnalysisOutcome {
  const AnalysisOutcome({required this.result, this.analysisId});
  final AnalysisResult result;
  final String? analysisId;
}

/// Connects the Phase 1.2 input (R2 storage key or text) to the Phase 1.3
/// `/analyze` Edge Function. Abstract so tests can inject a fake (mock the AI).
abstract class AnalysisService {
  Future<AnalysisOutcome> analyze({
    required String petId,
    required String inputType, // photo | video | text
    String? textDescription,
    String? imageStorageKey,
    List<String>? frameStorageKeys, // Phase 3.2 video keyframes
  });
}

class SupabaseAnalysisService implements AnalysisService {
  SupabaseAnalysisService(this._client);

  final SupabaseClient _client;

  @override
  Future<AnalysisOutcome> analyze({
    required String petId,
    required String inputType,
    String? textDescription,
    String? imageStorageKey,
    List<String>? frameStorageKeys,
  }) async {
    final res = await _client.functions.invoke('analyze', body: {
      'pet_id': petId,
      'input_type': inputType,
      'text_description': textDescription,
      'input_storage_key': imageStorageKey,
      if (frameStorageKeys != null && frameStorageKeys.isNotEmpty)
        'frame_storage_keys': frameStorageKeys,
    });
    final data = res.data;
    if (data is! Map || data['result'] is! Map) {
      throw Exception('Unexpected analysis response');
    }
    final result = AnalysisResult.fromJson(
      (data['result'] as Map).cast<String, dynamic>(),
    );
    return AnalysisOutcome(result: result, analysisId: data['analysis_id'] as String?);
  }
}

final analysisServiceProvider = Provider<AnalysisService>((ref) {
  return SupabaseAnalysisService(ref.watch(supabaseClientProvider));
});

/// The most recent completed check for a pet (M0 fix F-2/F-4): level for the
/// pets-list chip, timestamp for the home-hero "Last check: just now" line.
class LatestTriage {
  const LatestTriage({required this.level, required this.checkedAt});

  /// Wire triage level (EMERGENCY | MONITOR | NORMAL).
  final String level;

  /// Null only if the row's created_at is missing/unparsable (defensive).
  final DateTime? checkedAt;
}

/// Most-recent check for a pet (home "last check" line + pets-list chip).
/// RLS-scoped. Invalidated by the analysis runner the moment an analysis
/// completes, so a finished check is reflected immediately on return (F-2).
final latestTriageProvider =
    FutureProvider.autoDispose.family<LatestTriage?, String>((ref, petId) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('analyses')
      .select('triage_level, created_at')
      .eq('pet_id', petId)
      .order('created_at', ascending: false)
      .limit(1);
  final list = rows as List;
  if (list.isEmpty) return null;
  final row = list.first as Map;
  final level = row['triage_level'] as String?;
  if (level == null) return null;
  return LatestTriage(
    level: level,
    checkedAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
  );
});
