import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import 'reminder.dart';

/// CRUD for the `reminders` table. RLS-scoped to the signed-in user; inserts
/// carry user_id = auth.uid() to satisfy the WITH CHECK.
class RemindersRepository {
  RemindersRepository(this._client);

  final SupabaseClient _client;

  Future<List<Reminder>> listForPet(String petId) async {
    final rows = await _client
        .from('reminders')
        .select()
        .eq('pet_id', petId)
        .order('due_date');
    return (rows as List)
        .map((r) => Reminder.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Reminder> create(Reminder reminder) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('reminders')
        .insert({...reminder.toColumns(), 'user_id': userId})
        .select()
        .single();
    return Reminder.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _client.from('reminders').delete().eq('id', id);
  }
}

final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  return RemindersRepository(ref.watch(supabaseClientProvider));
});

/// Reminders for a pet (RLS-scoped). `family` on petId so switching pets fetches
/// the right list.
final remindersForPetProvider =
    FutureProvider.autoDispose.family<List<Reminder>, String>((ref, petId) {
  return ref.watch(remindersRepositoryProvider).listForPet(petId);
});
