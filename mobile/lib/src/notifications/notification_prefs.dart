import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **The single source of truth for what PawDoc is allowed to notify about.**
///
/// The `notifications` reference draws six switchable categories (Health
/// Reminders, Health Alerts, Vet & App Updates, Tips & Education, Community,
/// Promotions & Offers), a quiet-hours window, and four delivery channels
/// (In-App, Push, Email, SMS) with three of them ticked.
///
/// PawDoc sends **two kinds of notification, both scheduled on the device**:
///
/// | Kind | Scheduled by | Channel |
/// |---|---|---|
/// | A health reminder you created | `RemindersRepository.create/update` → `LocalNotifications.scheduleReminder` | Android `reminders` / iOS local |
/// | The daily walk nudge | `walks_screen` → `LocalNotifications.scheduleDailyWalkReminder` | Android `walks` / iOS local |
///
/// There is no push vendor (OneSignal was removed in evolution H2), no device
/// token, no server cron, no transactional email and no SMS gateway. So four of
/// the reference's six categories describe messages nothing can send, and three
/// of its four delivery channels describe transports that do not exist. The
/// screen states that instead of drawing switches over nothing.
///
/// The two flags below are real, persisted, and **consulted at the point of
/// scheduling** — flipping one changes what the device actually does, which is
/// the whole difference between a preference and a picture of a preference.
class NotificationPrefs {
  const NotificationPrefs._();

  /// Health reminders. **Defaults to on**: every reminder created since
  /// evolution H2 has scheduled itself, and a preference that silently
  /// defaults to off would cancel behaviour existing users already rely on.
  static const healthRemindersKey = 'pawdoc.notify.health_reminders';

  /// The daily walk nudge. These two keys are **the same strings
  /// `walks_screen` has always written** — the walk card and this screen are
  /// two views of one setting, and a second key is how they end up disagreeing
  /// about whether the notification is scheduled.
  static const walkReminderKey = 'walk_reminder_on';
  static const walkReminderHourKey = 'walk_reminder_hour';

  /// The hour `walks_screen` falls back to when nothing has been chosen.
  static const int defaultWalkHour = 8;

  static Future<bool> healthRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(healthRemindersKey) ?? true;
  }

  static Future<void> setHealthRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(healthRemindersKey, enabled);
  }

  static Future<bool> walkReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(walkReminderKey) ?? false;
  }

  static Future<int> walkReminderHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(walkReminderHourKey) ?? defaultWalkHour;
  }

  static Future<void> setWalkReminder({required bool enabled, int? hour}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(walkReminderKey, enabled);
    if (hour != null) await prefs.setInt(walkReminderHourKey, hour);
  }
}

/// Both flags, read together, so the screen builds in one frame instead of
/// popping each switch in as its own future lands.
class NotificationSettings {
  const NotificationSettings({
    required this.healthReminders,
    required this.walkReminder,
    required this.walkHour,
  });

  final bool healthReminders;
  final bool walkReminder;
  final int walkHour;

  NotificationSettings copyWith({
    bool? healthReminders,
    bool? walkReminder,
    int? walkHour,
  }) =>
      NotificationSettings(
        healthReminders: healthReminders ?? this.healthReminders,
        walkReminder: walkReminder ?? this.walkReminder,
        walkHour: walkHour ?? this.walkHour,
      );
}

final notificationSettingsProvider =
    FutureProvider.autoDispose<NotificationSettings>((ref) async {
  return NotificationSettings(
    healthReminders: await NotificationPrefs.healthRemindersEnabled(),
    walkReminder: await NotificationPrefs.walkReminderEnabled(),
    walkHour: await NotificationPrefs.walkReminderHour(),
  );
});

/// Whether the operating system currently lets PawDoc post a notification.
///
/// The master switch on the settings screen is this, and not a preference of
/// our own: if the OS has revoked the permission, every category below it is
/// moot, and a PawDoc-level "Enable All Notifications" that flips to green
/// while Android silently drops the notifications would be the worst kind of
/// fake control.
///
/// `null` when the platform could not be asked (widget tests, or a plugin that
/// is not registered) — the row then offers the contextual request rather than
/// asserting a state it does not know. A provider so tests can override it.
final notificationPermissionProvider =
    FutureProvider.autoDispose<bool?>((ref) async {
  try {
    final status = await Permission.notification.status;
    return status.isGranted;
  } catch (_) {
    return null;
  }
});
