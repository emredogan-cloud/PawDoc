import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/paw_nav_bar.dart';
import '../health/health_sections.dart';
import '../notifications/local_notifications.dart';
import '../notifications/notification_prefs.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import '../reminders/reminder.dart';
import '../reminders/reminders_repository.dart';
import '../reminders/reminders_screen.dart';
import '../theme/paw_ui.dart';
import 'account_sections.dart';

/// `notifications`, rebuilt against its reference.
///
/// **PawDoc sends exactly two kinds of notification, and both are scheduled on
/// the device.** OneSignal was removed in evolution H2: there is no push
/// vendor, no device token, no server cron, no transactional email and no SMS
/// gateway anywhere in the stack.
///
/// | Reference | Shipped | Why |
/// |---|---|---|
/// | "Enable All Notifications ✅" as a PawDoc switch | the operating system's permission, read live | a PawDoc-level master that reads green while Android drops every notification is the worst possible control |
/// | "Health Reminders · On" | the real switch, which cancels and restores the scheduled notifications | wired through `RemindersRepository`, so it changes what the device does |
/// | "Health Alerts · AI health insights, symptom changes" | *(gone)* | nothing watches a pet in the background; there is no process that could notice a change and no channel to send it on |
/// | "Vet & App Updates · New features and announcements" | *(gone)* | PawDoc cannot send an announcement — there is no server-side sender at all |
/// | "Tips & Education" | *(gone)* | same: nothing sends these |
/// | "Community · replies and messages from other pet parents" | *(gone)*, and stated | community messages are read in the app; no notification exists for them |
/// | "Promotions & Offers" | *(gone)*, and stated | PawDoc sends no marketing, and a switch implies it might |
/// | "Quiet Hours · 22:00 – 07:00 · Every day" | the real delivery time (09:00 local) | quiet hours are not implemented; the honest version is telling you when reminders actually arrive |
/// | "Delivery Preferences · In-App ✅ Push ✅ Email ✅ SMS ○" | four facts, none of them switches | three of those transports do not exist. A ticked Email box is a promise nothing can keep |
/// | "Bruno's Rabies vaccine is due in 3 days" as a static preview | your own next reminder, or an empty state | a fabricated preview from a fabricated pet |
///
/// The daily walk nudge shares [NotificationPrefs.walkReminderKey] with the
/// walk card on the Smart Walks screen — one setting, two views. A second key
/// is how the two surfaces end up disagreeing about whether it is scheduled.
class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Notifications',
          icon: LucideIcons.bell,
          subtitle: 'What PawDoc sends, and ',
          subtitleTrail: 'when.',
          actionsWidth: 56,
          actions: [
            HealthCircleButton(
              key: const Key('notifications_help'),
              icon: LucideIcons.circleHelp,
              tooltip: 'How PawDoc notifies you',
              onTap: () => _explain(context),
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        onRefresh: () async {
          ref.invalidate(notificationPermissionProvider);
          ref.invalidate(notificationSettingsProvider);
          ref.invalidate(allRemindersProvider);
        },
        children: [
          gap(6),
          const _Hero(),
          gap(14),
          const _PermissionCard(),
          gap(16),
          const _Categories(),
          gap(16),
          const _Timing(),
          gap(16),
          const _Delivery(),
          gap(16),
          const _NextUp(),
          gap(10),
        ],
      ),
    );
  }

  static void _explain(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HealthSheet(
        title: 'How PawDoc notifies you',
        scrollable: true,
        children: [
          const HealthDetailRow(
            icon: LucideIcons.smartphone,
            label: 'On the device',
            value: 'A reminder is scheduled on your phone the moment you '
                'create it. It arrives even with no signal, and PawDoc’s '
                'servers are not involved.',
          ),
          const HealthDetailRow(
            icon: LucideIcons.serverOff,
            label: 'No push service',
            value: 'There is no push vendor and no device token. Nothing can '
                'send you a message you did not schedule yourself.',
          ),
          HealthDetailRow(
            icon: LucideIcons.clock,
            label: 'When they arrive',
            value: 'Reminders are day-based and fire at '
                '${LocalNotifications.reminderHour}:00 in your device’s time '
                'zone. The walk nudge fires at the hour you pick.',
          ),
          const HealthDetailRow(
            icon: LucideIcons.circleAlert,
            label: 'Never for an emergency',
            value: 'PawDoc cannot watch your pet and will never notify you '
                'that something is wrong. If you are worried, open the app — '
                'emergency help is one tap from every screen.',
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => const AccountHero(
        icon: LucideIcons.bellRing,
        title: 'Reminders come from ',
        highlight: 'this device',
        body: 'PawDoc schedules the reminders you create directly on your '
            'phone. There is no push service behind it, which is why they work '
            'offline — and why nothing arrives that you did not ask for.',
        assurances: [
          AccountAssurance(icon: LucideIcons.wifiOff, label: 'Works offline'),
          AccountAssurance(icon: LucideIcons.serverOff, label: 'No push server'),
          AccountAssurance(icon: LucideIcons.megaphoneOff, label: 'No marketing'),
        ],
      );
}

/// The system permission — the real master switch.
class _PermissionCard extends ConsumerWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(notificationPermissionProvider).value;

    Future<void> request() async {
      final ok =
          await ref.read(localNotificationsProvider).ensurePermission();
      ref.invalidate(notificationPermissionProvider);
      if (!context.mounted) return;
      if (!ok) {
        // A denied-forever permission can only be restored in system settings;
        // asking again silently does nothing, which reads as a broken button.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Notifications are off for PawDoc.'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ));
      }
    }

    if (granted == true) {
      return const AccountGroup(
        children: [
          AccountFactRow(
            key: Key('notifications_permission_granted'),
            icon: LucideIcons.bellRing,
            title: 'Notifications are allowed',
            subtitle: 'Your device will show the reminders PawDoc schedules. '
                'You can revoke this in system settings at any time.',
            value: 'Allowed',
            positive: true,
          ),
        ],
      );
    }

    return AccountGroup(
      children: [
        AccountSettingRow(
          key: const Key('notifications_permission_row'),
          icon: LucideIcons.bellOff,
          title: granted == false
              ? 'Notifications are turned off'
              : 'Allow notifications',
          subtitle: granted == false
              ? 'Your reminders are still saved, but nothing will appear on '
                  'this device until you allow notifications.'
              : 'Reminders you create can only appear if the system lets '
                  'PawDoc post them.',
          value: granted == false ? 'Turn on' : 'Allow',
          onTap: request,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

class _Categories extends ConsumerWidget {
  const _Categories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider).value;

    Future<void> setHealth(bool v) async {
      await NotificationPrefs.setHealthRemindersEnabled(v);
      ref.invalidate(notificationSettingsProvider);
      if (v) {
        // Asking for permission only when switching ON keeps the contextual
        // ask contextual: turning something off must never open a dialog.
        await ref.read(localNotificationsProvider).ensurePermission();
        ref.invalidate(notificationPermissionProvider);
      }
      // Bring the device's scheduled notifications in line with the new value.
      // Best-effort: a scheduling failure must not leave the switch lying.
      try {
        await ref.read(remindersRepositoryProvider).applyHealthReminderPref(v);
      } catch (_) {}
    }

    Future<void> setWalk(bool v) async {
      final hour = settings?.walkHour ?? NotificationPrefs.defaultWalkHour;
      final notifications = ref.read(localNotificationsProvider);
      if (v) {
        final ok = await notifications.ensurePermission();
        ref.invalidate(notificationPermissionProvider);
        if (!ok) {
          await NotificationPrefs.setWalkReminder(enabled: false);
          ref.invalidate(notificationSettingsProvider);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Notifications are off for PawDoc.'),
            action:
                SnackBarAction(label: 'Settings', onPressed: openAppSettings),
          ));
          return;
        }
        await NotificationPrefs.setWalkReminder(enabled: true, hour: hour);
        await notifications.scheduleDailyWalkReminder(hour: hour, minute: 0);
      } else {
        await NotificationPrefs.setWalkReminder(enabled: false);
        await notifications.cancelDailyWalkReminder();
      }
      ref.invalidate(notificationSettingsProvider);
    }

    Future<void> pickHour() async {
      final chosen = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => HealthSheet(
          title: 'Walk nudge time',
          scrollable: true,
          children: [
            for (final h in const [6, 7, 8, 9, 17, 18, 19, 20])
              HealthSettingRow(
                key: Key('walk_hour_$h'),
                icon: LucideIcons.clock,
                label: '${h.toString().padLeft(2, '0')}:00',
                value: h == (settings?.walkHour) ? 'Selected' : 'Choose',
                onTap: () => Navigator.pop(context, h),
              ),
          ],
        ),
      );
      if (chosen == null) return;
      await NotificationPrefs.setWalkReminder(enabled: true, hour: chosen);
      await ref
          .read(localNotificationsProvider)
          .scheduleDailyWalkReminder(hour: chosen, minute: 0);
      ref.invalidate(notificationSettingsProvider);
    }

    return AccountGroup(
      title: 'What PawDoc sends',
      caption: 'Two things, both scheduled by you.',
      children: [
        AccountToggleRow(
          switchKey: const Key('notify_health_reminders'),
          icon: LucideIcons.calendarCheck,
          title: 'Health reminders',
          subtitle: 'Vaccines, medication, re-checks and vet appointments you '
              'have set. Turning this off silences them on this device — the '
              'reminders themselves are kept.',
          value: settings?.healthReminders ?? true,
          onChanged: setHealth,
        ),
        AccountToggleRow(
          switchKey: const Key('notify_walk_reminder'),
          icon: LucideIcons.footprints,
          title: 'Daily walk nudge',
          subtitle: settings?.walkReminder == true
              ? 'One reminder a day at '
                  '${(settings?.walkHour ?? NotificationPrefs.defaultWalkHour).toString().padLeft(2, '0')}:00 '
                  'to check today’s walk window.'
              : 'One reminder a day to check today’s walk window. Off by '
                  'default.',
          value: settings?.walkReminder ?? false,
          onChanged: setWalk,
        ),
        if (settings?.walkReminder == true)
          AccountSettingRow(
            key: const Key('notify_walk_hour'),
            icon: LucideIcons.clock,
            title: 'Walk nudge time',
            subtitle: 'When the daily nudge arrives.',
            value:
                '${settings!.walkHour.toString().padLeft(2, '0')}:00',
            onTap: pickHour,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Timing (replaces "Quiet Hours")
// ---------------------------------------------------------------------------

class _Timing extends StatelessWidget {
  const _Timing();

  @override
  Widget build(BuildContext context) {
    return AccountGroup(
      key: const Key('notifications_timing'),
      title: 'When they arrive',
      children: [
        AccountFactRow(
          icon: LucideIcons.clock,
          title: 'Reminders fire at '
              '${LocalNotifications.reminderHour}:00',
          subtitle: 'Reminders are day-based by design, so there is one time '
              'and this is it — in your device’s time zone.',
          value: 'Fixed',
        ),
        const AccountUnavailableRow(
          key: Key('notifications_quiet_hours'),
          icon: LucideIcons.moon,
          title: 'Quiet hours',
          subtitle: 'PawDoc has no quiet-hours window. Because everything it '
              'sends is a reminder you scheduled in daylight, there is nothing '
              'to mute at night — but if that changes, this is where it would '
              'live.',
          badge: 'Not built',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Delivery (facts, not switches)
// ---------------------------------------------------------------------------

class _Delivery extends StatelessWidget {
  const _Delivery();

  @override
  Widget build(BuildContext context) {
    return const AccountGroup(
      key: Key('notifications_delivery'),
      title: 'How they reach you',
      caption: 'These are facts about the app, not settings — three of the '
          'reference channels do not exist here.',
      children: [
        AccountFactRow(
          icon: LucideIcons.smartphone,
          title: 'On this device',
          subtitle: 'Scheduled locally and delivered by your operating system.',
          value: 'Yes',
          positive: true,
        ),
        AccountFactRow(
          icon: LucideIcons.appWindow,
          title: 'Inside the app',
          subtitle: 'Due and upcoming reminders are always on the reminders '
              'screen, whatever the switches above say.',
          value: 'Yes',
          positive: true,
        ),
        AccountFactRow(
          icon: LucideIcons.mail,
          title: 'Email',
          subtitle: 'PawDoc sends no reminder or marketing email. Account '
              'emails — a password reset, a sign-in link — come from Supabase '
              'only when you ask for one.',
          value: 'Not sent',
          positive: false,
        ),
        AccountFactRow(
          icon: LucideIcons.messageSquare,
          title: 'SMS',
          subtitle: 'No phone number is stored and no text message is ever '
              'sent.',
          value: 'Not sent',
          positive: false,
        ),
        AccountFactRow(
          icon: LucideIcons.serverOff,
          title: 'Push from our servers',
          subtitle: 'There is no push vendor in the stack. Nothing can be sent '
              'to this device that it did not schedule.',
          value: 'None',
          positive: false,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The real preview
// ---------------------------------------------------------------------------

/// The reference's "Notification Preview" card, filled with the user's own next
/// reminder instead of an invented one.
class _NextUp extends ConsumerWidget {
  const _NextUp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(allRemindersProvider);
    final pets = ref.watch(petsListProvider).value ?? const <Pet>[];

    // hasError before isLoading: Riverpod 3's retry re-enters `loading` while
    // keeping the error, so an offline open would sit on a spinner forever.
    if (remindersAsync.hasError && !remindersAsync.hasValue) {
      return const AccountGroup(
        title: 'Next reminder',
        children: [
          AccountFactRow(
            key: Key('notifications_next_error'),
            icon: LucideIcons.cloudOff,
            title: 'Could not read your reminders',
            subtitle: 'Anything already scheduled will still arrive — the '
                'schedule lives on this device, not on the network.',
            value: 'Offline',
          ),
        ],
      );
    }

    final all = remindersAsync.value;
    if (all == null) {
      return const AccountGroup(
        title: 'Next reminder',
        children: [
          AccountFactRow(
            icon: LucideIcons.loader,
            title: 'Checking your reminders…',
            subtitle: 'One moment.',
          ),
        ],
      );
    }

    final upcoming = all.where((r) => !r.isPastDue).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (upcoming.isEmpty) {
      return AccountGroup(
        title: 'Next reminder',
        children: [
          AccountSettingRow(
            key: const Key('notifications_next_empty'),
            icon: LucideIcons.calendarPlus,
            title: 'Nothing scheduled',
            subtitle: 'When you set a vaccine, medication or re-check '
                'reminder, the next one due appears here.',
            value: 'Set one',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const RemindersScreen())),
          ),
        ],
      );
    }

    final next = upcoming.first;
    final petName = pets
        .where((p) => p.id == next.petId)
        .map((p) => p.name)
        .firstOrNull;
    final days = next.daysUntilDue;

    return AccountGroup(
      title: 'Next reminder',
      children: [
        AccountSettingRow(
          key: const Key('notifications_next_reminder'),
          icon: ReminderCategory.of(next.reminderType).icon,
          title: petName == null
              ? next.reminderType
              : '${next.reminderType} — $petName',
          subtitle: switch (days) {
            0 => 'Due today, at '
                '${LocalNotifications.reminderHour}:00.',
            1 => 'Due tomorrow, at '
                '${LocalNotifications.reminderHour}:00.',
            _ => 'Due in $days days, at '
                '${LocalNotifications.reminderHour}:00.',
          },
          value: 'Open',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const RemindersScreen())),
        ),
      ],
    );
  }
}
