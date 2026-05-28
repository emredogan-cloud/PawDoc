import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import 'journal.dart';

/// Reads from the `health_journals` table. RLS-scoped to the signed-in user;
/// writes happen ONLY server-side via the cron Edge Function (clients have no
/// INSERT/UPDATE/DELETE here — see the Phase 5.3 migration).
class JournalRepository {
  JournalRepository(this._client);

  final SupabaseClient _client;

  Future<List<Journal>> listForPet(String petId) async {
    final rows = await _client
        .from('health_journals')
        .select()
        .eq('pet_id', petId)
        .order('week_start_date', ascending: false);
    return (rows as List)
        .map((r) => Journal.fromJson((r as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }
}

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(ref.watch(supabaseClientProvider));
});

final journalsForPetProvider =
    FutureProvider.autoDispose.family<List<Journal>, String>((ref, petId) {
  return ref.watch(journalRepositoryProvider).listForPet(petId);
});

/// The most recent journal for a pet, or null if none yet.
final latestJournalProvider =
    FutureProvider.autoDispose.family<Journal?, String>((ref, petId) async {
  final all = await ref.watch(journalsForPetProvider(petId).future);
  return all.isEmpty ? null : all.first;
});
