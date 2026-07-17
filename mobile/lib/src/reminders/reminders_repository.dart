import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import '../notifications/local_notifications.dart';
import 'reminder.dart';

/// CRUD for the `reminders` table. RLS-scoped to the signed-in user; inserts
/// carry user_id = auth.uid() to satisfy the WITH CHECK.
///
/// Evolution H2: every create/update (re)schedules an ON-DEVICE notification
/// and every delete cancels it — no push vendor, no server cron. Notification
/// failures are best-effort and never fail the DB write.
class RemindersRepository {
  RemindersRepository(this._client, this._notifications);

  final SupabaseClient _client;
  final LocalNotifications _notifications;

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

  Future<Reminder> create(Reminder reminder, {String? petName}) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('reminders')
        .insert({...reminder.toColumns(), 'user_id': userId})
        .select()
        .single();
    final created = Reminder.fromJson(row);
    if (created.id != null) {
      await _notifications.scheduleReminder(
        reminderId: created.id!,
        title: created.reminderType,
        dueDate: created.dueDate,
        petName: petName,
      );
    }
    return created;
  }

  Future<Reminder> update(String id, Reminder reminder,
      {String? petName}) async {
    final row = await _client
        .from('reminders')
        .update(reminder.toColumns())
        .eq('id', id)
        .select()
        .single();
    final updated = Reminder.fromJson(row);
    await _notifications.cancelReminder(id);
    await _notifications.scheduleReminder(
      reminderId: id,
      title: updated.reminderType,
      dueDate: updated.dueDate,
      petName: petName,
    );
    return updated;
  }

  Future<void> delete(String id) async {
    await _client.from('reminders').delete().eq('id', id);
    await _notifications.cancelReminder(id);
  }
}

final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  return RemindersRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localNotificationsProvider),
  );
});

/// Reminders for a pet (RLS-scoped). `family` on petId so switching pets fetches
/// the right list.
final remindersForPetProvider =
    FutureProvider.autoDispose.family<List<Reminder>, String>((ref, petId) {
  return ref.watch(remindersRepositoryProvider).listForPet(petId);
});
