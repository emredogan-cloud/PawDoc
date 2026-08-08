// The notifications screen's switches have to change what the DEVICE does, not
// just what the switch looks like. That is the whole difference between the
// preference this batch shipped and the six categories the reference draws over
// messages nothing in the stack can send.
//
// Two halves:
//
//  * the preference itself — defaults, persistence, and the fact that the walk
//    nudge shares its keys with the walk card rather than owning a second copy;
//  * the wiring — asserted at source level, because the only place scheduling
//    happens is `RemindersRepository`, whose methods need a live Supabase to
//    exercise. A source assertion is the same tool `safety_copy_test` uses for
//    the same reason: it catches the regression that matters (someone deleting
//    the gate) without pretending to a network round trip.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/notifications/local_notifications.dart';
import 'package:pawdoc/src/notifications/notification_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('defaults', () {
    test('health reminders default ON', () async {
      // Every reminder created since evolution H2 has scheduled itself. A
      // preference that silently defaulted to off would cancel behaviour
      // existing users already rely on, without them ever opening the screen.
      expect(await NotificationPrefs.healthRemindersEnabled(), isTrue);
    });

    test('the walk nudge defaults OFF', () async {
      expect(await NotificationPrefs.walkReminderEnabled(), isFalse);
      expect(await NotificationPrefs.walkReminderHour(),
          NotificationPrefs.defaultWalkHour);
    });
  });

  group('persistence', () {
    test('health reminders round-trip', () async {
      await NotificationPrefs.setHealthRemindersEnabled(false);
      expect(await NotificationPrefs.healthRemindersEnabled(), isFalse);
      await NotificationPrefs.setHealthRemindersEnabled(true);
      expect(await NotificationPrefs.healthRemindersEnabled(), isTrue);
    });

    test('the walk nudge round-trips, and keeps the hour when switched off',
        () async {
      await NotificationPrefs.setWalkReminder(enabled: true, hour: 19);
      expect(await NotificationPrefs.walkReminderEnabled(), isTrue);
      expect(await NotificationPrefs.walkReminderHour(), 19);

      // Switching back on must not silently reset the time the user picked.
      await NotificationPrefs.setWalkReminder(enabled: false);
      expect(await NotificationPrefs.walkReminderEnabled(), isFalse);
      expect(await NotificationPrefs.walkReminderHour(), 19);
    });

    test('the combined read reflects both flags', () async {
      await NotificationPrefs.setHealthRemindersEnabled(false);
      await NotificationPrefs.setWalkReminder(enabled: true, hour: 7);
      final settings = NotificationSettings(
        healthReminders: await NotificationPrefs.healthRemindersEnabled(),
        walkReminder: await NotificationPrefs.walkReminderEnabled(),
        walkHour: await NotificationPrefs.walkReminderHour(),
      );
      expect(settings.healthReminders, isFalse);
      expect(settings.walkReminder, isTrue);
      expect(settings.walkHour, 7);
    });
  });

  group('one setting, two views', () {
    test('the walk keys are the ones walks_screen already writes', () {
      expect(NotificationPrefs.walkReminderKey, 'walk_reminder_on');
      expect(NotificationPrefs.walkReminderHourKey, 'walk_reminder_hour');
    });

    test('walks_screen still writes exactly those keys', () {
      // If the walk card is ever refactored onto its own key, the settings
      // screen and the walk card start disagreeing about whether the nudge is
      // scheduled — and nothing else in the suite would notice.
      final src =
          File('lib/src/walks/walks_screen.dart').readAsStringSync();
      expect(src.contains("'walk_reminder_on'"), isTrue);
      expect(src.contains("'walk_reminder_hour'"), isTrue);
    });
  });

  group('the preference reaches the scheduler', () {
    final repo =
        File('lib/src/reminders/reminders_repository.dart').readAsStringSync();

    test('create() will not schedule while the preference is off', () {
      expect(
        repo.contains(
            'if (created.id != null && await NotificationPrefs.healthRemindersEnabled())'),
        isTrue,
        reason: 'creating a reminder must consult the preference before it '
            'schedules a notification — otherwise the switch is decorative',
      );
    });

    test('update() cancels unconditionally and only re-schedules when on', () {
      // Cancel must NOT be behind the flag: a reminder edited after the
      // preference was switched off would keep its old pending notification.
      final cancelIndex = repo.indexOf('await _notifications.cancelReminder(id);');
      final gateIndex =
          repo.indexOf('if (await NotificationPrefs.healthRemindersEnabled())');
      expect(cancelIndex, greaterThan(-1));
      expect(gateIndex, greaterThan(cancelIndex),
          reason: 'the cancel runs before the gate, so a pending notification '
              'is always cleared even when re-scheduling is suppressed');
    });

    test('the bulk apply exists and moves in both directions', () {
      expect(repo.contains('Future<void> applyHealthReminderPref(bool enabled)'),
          isTrue);
      expect(repo.contains('_notifications.scheduleReminder('), isTrue);
      expect(repo.contains('_notifications.cancelReminder(id)'), isTrue);
    });
  });

  group('the stated delivery time is the real one', () {
    test('the screen reads reminderHour rather than repeating a literal', () {
      expect(LocalNotifications.reminderHour, inInclusiveRange(0, 23));
      final screen =
          File('lib/src/account/notifications_settings_screen.dart')
              .readAsStringSync();
      expect(screen.contains('LocalNotifications.reminderHour'), isTrue,
          reason: 'a hardcoded "09:00" would drift the moment the scheduler '
              'changed, and this screen states it as a fact');
    });
  });
}
