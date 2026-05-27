import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import 'pet.dart';

/// CRUD for the `pets` table. All access is RLS-scoped to the signed-in user
/// (Phase 1.1 policies); inserts must carry user_id = auth.uid().
class PetsRepository {
  PetsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Pet>> list() async {
    final rows = await _client
        .from('pets')
        .select()
        .eq('is_active', true)
        .order('created_at');
    return (rows as List)
        .map((r) => Pet.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Pet> create(Pet pet) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('pets')
        .insert({...pet.toColumns(), 'user_id': userId})
        .select()
        .single();
    return Pet.fromJson(row);
  }

  Future<Pet> update(String id, Pet pet) async {
    final row = await _client
        .from('pets')
        .update(pet.toColumns())
        .eq('id', id)
        .select()
        .single();
    return Pet.fromJson(row);
  }

  /// Soft delete (is_active = false). Preserves the pet's analyses history
  /// rather than triggering the ON DELETE CASCADE on `analyses`.
  Future<void> softDelete(String id) async {
    await _client.from('pets').update({'is_active': false}).eq('id', id);
  }
}

final petsRepositoryProvider = Provider<PetsRepository>((ref) {
  return PetsRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's active pets.
final petsListProvider = FutureProvider.autoDispose<List<Pet>>((ref) {
  return ref.watch(petsRepositoryProvider).list();
});
