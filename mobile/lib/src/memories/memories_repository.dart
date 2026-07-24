import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import 'memory.dart';

/// CRUD for `pet_memories`. All access is RLS-scoped to the signed-in user
/// (per-op policies; inserts must carry user_id = auth.uid() and a pet the
/// caller owns). Photo objects are lifecycle-managed separately:
/// upload via generate-upload-url(scope=memories), delete via delete-media.
class MemoriesRepository {
  MemoriesRepository(this._client);

  final SupabaseClient _client;

  static const int _fetchCap = 500;

  /// Newest-first journal for one pet.
  Future<List<Memory>> listForPet(String petId) async {
    final rows = await _client
        .from('pet_memories')
        .select()
        .eq('pet_id', petId)
        .order('taken_on', ascending: false)
        .order('created_at', ascending: false)
        .limit(_fetchCap);
    return (rows as List)
        .map((r) => Memory.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Total memories across the user's pets (free-tier allowance check).
  Future<int> countAll() async {
    final rows = await _client.from('pet_memories').select('id');
    return (rows as List).length;
  }

  Future<Memory> create(Memory memory) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('pet_memories')
        .insert({...memory.toColumns(), 'user_id': userId})
        .select()
        .single();
    return Memory.fromJson(row);
  }

  Future<Memory> update(String id, Memory memory) async {
    final row = await _client
        .from('pet_memories')
        .update({
          ...memory.toColumns(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return Memory.fromJson(row);
  }

  /// Deletes the row (source of truth), then best-effort deletes the R2
  /// object. A failed object delete only leaves a private orphan that the
  /// account-deletion purge sweeps later — never surfaced as a user error.
  Future<void> delete(Memory memory) async {
    await _client.from('pet_memories').delete().eq('id', memory.id!);
    await deleteObject(memory.storageKey);
  }

  /// Best-effort R2 object delete (own `memories/<uid>/…` keys only —
  /// enforced server-side by the delete-media Edge Function).
  Future<void> deleteObject(String storageKey) async {
    try {
      await _client.functions.invoke(
        'delete-media',
        body: {'key': storageKey},
      );
    } catch (_) {
      // Best-effort by design.
    }
  }
}

final memoriesRepositoryProvider = Provider<MemoriesRepository>((ref) {
  return MemoriesRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's memories for one pet (newest first).
final memoriesListProvider = FutureProvider.autoDispose
    .family<List<Memory>, String>((ref, petId) {
  return ref.watch(memoriesRepositoryProvider).listForPet(petId);
});

/// Total memory count across pets — drives the free-tier allowance UI.
final memoriesCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(memoriesRepositoryProvider).countAll();
});
