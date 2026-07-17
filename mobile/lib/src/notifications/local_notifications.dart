import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// On-device reminder notifications (evolution H2 — replaces OneSignal).
///
/// No push vendor, no device token, no server cron, no Data Safety row: a
/// reminder is scheduled locally when it is created and cancelled when it is
/// deleted. Delivery works offline. Permission is asked CONTEXTUALLY — the
/// first time the user creates a reminder — never as an upfront onboarding
/// step.
class LocalNotifications {
  LocalNotifications._();
  static final LocalNotifications instance = LocalNotifications._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationDetails(
    'reminders',
    'Pet health reminders',
    channelDescription: 'Vaccine, medication, and re-check reminders you set.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  /// Safe to call at boot; never throws (a notification failure must not
  /// break app start).
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        // Unknown zone -> keep the package default (UTC); reminders still
        // fire, at worst offset — never crash for a timezone lookup.
      }
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // Contextual ask: do NOT request at init.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('local notifications init failed: $e');
    }
  }

  /// Contextual permission ask (first reminder creation / "Enable now").
  /// Returns true when notifications are permitted.
  Future<bool> ensurePermission() async {
    try {
      await initialize();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? true;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted =
            await ios.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stable 31-bit id from the reminder's uuid so cancel() targets the same
  /// notification the create scheduled.
  @visibleForTesting
  static int idFor(String reminderId) => reminderId.hashCode & 0x7fffffff;

  /// Schedules a reminder for 09:00 local on its due date (date-granularity by
  /// design — reminders are day-based). Past-due dates are skipped silently.
  /// Inexact scheduling: no SCHEDULE_EXACT_ALARM permission needed.
  Future<void> scheduleReminder({
    required String reminderId,
    required String title,
    required DateTime dueDate,
    String? petName,
  }) async {
    try {
      await initialize();
      final when = tz.TZDateTime.local(
          dueDate.year, dueDate.month, dueDate.day, 9);
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
        idFor(reminderId),
        petName == null ? title : '$title — $petName',
        'Open PawDoc to check it off.',
        when,
        const NotificationDetails(
          android: _channel,
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('scheduleReminder failed: $e');
    }
  }

  Future<void> cancelReminder(String reminderId) async {
    try {
      await initialize();
      await _plugin.cancel(idFor(reminderId));
    } catch (_) {}
  }
}

final localNotificationsProvider =
    Provider<LocalNotifications>((ref) => LocalNotifications.instance);
