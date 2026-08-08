import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import '../core/data_timeout.dart';
import '../notifications/local_notifications.dart';
import '../notifications/notification_prefs.dart';
import 'reminder.dart';

/// CRUD for the `reminders` table. RLS-scoped to the signed-in user; inserts
/// carry user_id = auth.uid() to satisfy the WITH CHECK.
///
/// Evolution H2: every create/update (re)schedules an ON-DEVICE notification
/// and every delete cancels it — no push vendor, no server cron. Notification
/// failures are best-effort and never fail the DB write.
///
/// The settings surface can switch reminder notifications off
/// ([NotificationPrefs.healthRemindersEnabled]). That flag is consulted **here**,
/// at the one place scheduling happens, rather than in the screen: a reminder
/// created from the form, the detail screen or the timeline must all honour it,
/// and the row itself is stored either way — the preference silences the
/// notification, it does not delete the reminder.
class RemindersRepository {
  RemindersRepository(this._client, this._notifications);

  final SupabaseClient _client;
  final LocalNotifications _notifications;

  Future<List<Reminder>> listForPet(String petId) async {
    final rows = await _client
        .from('reminders')
        .select()
        .eq('pet_id', petId)
        .order('due_date')
        .timeout(kDataReadTimeout);
    return (rows as List)
        .map((r) => Reminder.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Every reminder the caller owns, soonest first (RLS-scoped).
  ///
  /// Needed by two things at once: the notifications screen, which shows the
  /// next one that will actually arrive rather than the reference's invented
  /// "Bruno's Rabies vaccine is due in 3 days", and [applyHealthReminderPref],
  /// which has to reach every scheduled notification to cancel or restore it.
  Future<List<Reminder>> listAll() async {
    final rows = await _client
        .from('reminders')
        .select()
        .order('due_date')
        .timeout(kDataReadTimeout);
    return (rows as List)
        .map((r) => Reminder.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Brings the device's scheduled notifications in line with [enabled].
  ///
  /// Off cancels every one of them; on re-schedules from the stored rows.
  /// `scheduleReminder` already skips past-due dates, so restoring is safe to
  /// run over the whole list.
  Future<void> applyHealthReminderPref(bool enabled) async {
    final all = await listAll();
    for (final r in all) {
      final id = r.id;
      if (id == null) continue;
      if (enabled) {
        await _notifications.scheduleReminder(
          reminderId: id,
          title: r.reminderType,
          dueDate: r.dueDate,
        );
      } else {
        await _notifications.cancelReminder(id);
      }
    }
  }

  /// One reminder, by id. RLS scopes it — a row belonging to someone else does
  /// not come back, it simply is not there.
  Future<Reminder?> byId(String id) async {
    final row = await _client
        .from('reminders')
        .select()
        .eq('id', id)
        .maybeSingle()
        .timeout(kDataReadTimeout);
    if (row == null) return null;
    return Reminder.fromJson(row);
  }

  Future<Reminder> create(Reminder reminder, {String? petName}) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('reminders')
        .insert({...reminder.toColumns(), 'user_id': userId})
        .select()
        .single();
    final created = Reminder.fromJson(row);
    if (created.id != null && await NotificationPrefs.healthRemindersEnabled()) {
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
    // Cancel unconditionally: if the preference was switched off while this
    // reminder had a notification pending, editing it must clear that too.
    await _notifications.cancelReminder(id);
    if (await NotificationPrefs.healthRemindersEnabled()) {
      await _notifications.scheduleReminder(
        reminderId: id,
        title: updated.reminderType,
        dueDate: updated.dueDate,
        petName: petName,
      );
    }
    return updated;
  }

  Future<void> delete(String id) async {
    await _client.from('reminders').delete().eq('id', id);
    await _notifications.cancelReminder(id);
  }
}

/// One reminder, live. `family` on the id so a detail screen re-reads its own
/// row rather than filtering a list it did not fetch.
final reminderByIdProvider =
    FutureProvider.autoDispose.family<Reminder?, String>((ref, id) {
  return ref.watch(remindersRepositoryProvider).byId(id);
});

final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  return RemindersRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localNotificationsProvider),
  );
});

/// Every reminder the caller owns, soonest first. Scoped to the signed-in user
/// so an identity change on a shared device recomputes rather than serving the
/// previous account's list.
final allRemindersProvider =
    FutureProvider.autoDispose<List<Reminder>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(remindersRepositoryProvider).listAll();
});

/// Reminders for a pet (RLS-scoped). `family` on petId so switching pets fetches
/// the right list.
final remindersForPetProvider =
    FutureProvider.autoDispose.family<List<Reminder>, String>((ref, petId) {
  return ref.watch(remindersRepositoryProvider).listForPet(petId);
});
