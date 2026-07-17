import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import 'health_event.dart';

/// CRUD for the `health_events` table. All access is RLS-scoped: the policy
/// derives ownership from the parent pet (`pet_id` → `pets.user_id = auth.uid()`),
/// so a successful insert proves the user owns the pet. No `user_id` is sent —
/// the table has none (owner-approved CR #2 design).
class HealthEventsRepository {
  HealthEventsRepository(this._client);

  final SupabaseClient _client;

  Future<HealthEvent> create(HealthEvent event) async {
    final row = await _client
        .from('health_events')
        .insert(event.toColumns())
        .select()
        .single();
    final created = HealthEvent.fromJson(row);
    // E4: a weight log also refreshes the profile's current weight, so the
    // vet report and AI pet-context stay accurate without a second edit.
    final kg = (event.metadata?['weight_kg'] as num?)?.toDouble();
    if (event.eventType == 'weight' && kg != null) {
      try {
        await _client
            .from('pets')
            .update({'weight_kg': kg}).eq('id', event.petId);
      } catch (_) {
        // Best-effort: the event row is the source of truth for the trend.
      }
    }
    return created;
  }

  Future<List<HealthEvent>> listForPet(String petId) async {
    final rows = await _client
        .from('health_events')
        .select()
        .eq('pet_id', petId)
        .order('event_date', ascending: false);
    return (rows as List)
        .map((r) => HealthEvent.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }
}

final healthEventsRepositoryProvider = Provider<HealthEventsRepository>((ref) {
  return HealthEventsRepository(ref.watch(supabaseClientProvider));
});
