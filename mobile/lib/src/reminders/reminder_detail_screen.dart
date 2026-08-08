import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/dates.dart';
import '../core/friendly_error.dart';
import '../core/living_pet_avatar.dart';
import '../core/local_tick_log.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../health/health_sections.dart';
import '../health/history_timeline_screen.dart';
import '../health/medication_tracker_screen.dart';
import '../health/vaccination_manager_screen.dart';
import '../home/home_sections.dart';
import '../notifications/local_notifications.dart';
import '../pets/active_pet.dart';
import '../pets/pet.dart';
import '../pets/pet_profile_screen.dart';
import '../pets/pet_switcher.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'reminder.dart';
import 'reminder_form_screen.dart';
import 'reminders_repository.dart';

/// One reminder, rebuilt against mockup `reminder_detail`.
///
/// Pet header, the reminder itself, the fact grid, what it is for, the
/// schedule rail, notification settings, history, the two actions and the
/// privacy line — over the app's bottom navigation, which the mockup draws.
///
/// **What is real, and what is not.** The `reminders` table holds five columns:
/// `reminder_type`, `due_date`, `is_sent`, `notification_sent_at`,
/// `created_at`. Everything this screen states comes from those:
///
/// * the next date and "in N days" — `due_date`
/// * the notification time — [LocalNotifications.reminderHour], which is
///   literally when the app schedules it
/// * "Set on" and the first history entry — `created_at`
/// * "Delivered" and the second history entry — `notification_sent_at`
/// * the category chip — a filing label read off the owner's own words, the
///   same derivation the reminders list has always used to pick its glyph
/// * Postpone — rewrites `due_date` through the repository, which cancels and
///   reschedules the notification
///
/// The mockup also draws a **dose**, a **repeat cadence** and a six-occurrence
/// recurring schedule. There is no column for any of them. Rather than invent
/// values, the repeat control keeps its place and says *Soon*, and the schedule
/// rail plots the pet's *actual* upcoming reminders with this one lit — which
/// is the same shape carrying real dates.
///
/// **"Mark as taken" is kept on this device, and the screen says so twice.**
/// There is no completion table; `is_sent` means the notification went out, not
/// that the owner did the thing. Writing a tick into `is_sent` would corrupt
/// the meaning of a column the cron owns. Device-local is honest and it
/// survives restarts — it just does not follow the owner to a second phone.
class ReminderDetailScreen extends ConsumerStatefulWidget {
  const ReminderDetailScreen({
    required this.reminderId,
    this.initial,
    super.key,
  });

  final String reminderId;

  /// The row the caller already had, so the page paints before the re-read
  /// lands instead of flashing a spinner.
  final Reminder? initial;

  /// The ticks this screen owns. Namespaced away from `pawdoc.dose.` so the
  /// medication tracker's adherence can never accidentally count one.
  static const tickPrefix = 'pawdoc.reminder.done.';
  static const tickLog = LocalTickLog(tickPrefix);

  /// Keyed by the *due* date, not by today: a reminder is done for the date it
  /// was set for, whenever the owner got round to ticking it.
  static String tickKey(String reminderId, DateTime dueDate) =>
      '$tickPrefix$reminderId.${LocalTickLog.dayKey(dueDate)}';

  @override
  ConsumerState<ReminderDetailScreen> createState() =>
      _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends ConsumerState<ReminderDetailScreen> {
  Map<String, DateTime>? _ticks;

  @override
  void initState() {
    super.initState();
    _loadTicks();
  }

  Future<void> _loadTicks() async {
    final ticks = await ReminderDetailScreen.tickLog.loadAll();
    if (mounted) setState(() => _ticks = ticks);
  }

  Future<void> _toggleTaken(Reminder reminder) async {
    final key = ReminderDetailScreen.tickKey(reminder.id!, reminder.dueDate);
    final current = Map<String, DateTime>.from(_ticks ?? const {});
    final wasSet = current.containsKey(key);
    if (wasSet) {
      current.remove(key);
      await LocalTickLog.clear(key);
    } else {
      final now = DateTime.now();
      current[key] = now;
      await LocalTickLog.set(key, now);
    }
    if (!mounted) return;
    setState(() => _ticks = current);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(wasSet
          ? 'Unmarked. Kept on this device.'
          : 'Marked as taken. Kept on this device.'),
    ));
  }

  Future<void> _edit(Reminder reminder, Pet pet) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReminderFormScreen(
          petId: reminder.petId, petName: pet.name, existing: reminder),
    ));
    _refresh(reminder.petId);
  }

  void _refresh(String petId) {
    ref.invalidate(reminderByIdProvider(widget.reminderId));
    ref.invalidate(remindersForPetProvider(petId));
  }

  Future<void> _postponeBy(Reminder reminder, Pet pet, Duration by) async {
    final next = DateTime(
      reminder.dueDate.year,
      reminder.dueDate.month,
      reminder.dueDate.day,
    ).add(by);
    await _writeDueDate(reminder, pet, next);
  }

  Future<void> _pickNewDate(Reminder reminder, Pet pet) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: reminder.dueDate.isBefore(now) ? now : reminder.dueDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) await _writeDueDate(reminder, pet, picked);
  }

  Future<void> _writeDueDate(Reminder reminder, Pet pet, DateTime when) async {
    try {
      await ref.read(remindersRepositoryProvider).update(
            reminder.id!,
            reminder.copyWith(dueDate: when),
            petName: pet.name,
          );
      // A tick belongs to the date it was for, so moving the reminder clears
      // it — you moved it because it had not happened. Dropping the old key
      // rather than leaving it behind also stops the log growing a dead entry
      // on every postpone.
      final stale = ReminderDetailScreen.tickKey(reminder.id!, reminder.dueDate);
      await LocalTickLog.clear(stale);
      final ticks = Map<String, DateTime>.from(_ticks ?? const {})
        ..remove(stale);
      if (mounted) setState(() => _ticks = ticks);
      _refresh(reminder.petId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Moved to ${shortDate(when)}. '
              'The notification was rescheduled.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not move the reminder. Please try again.')));
    }
  }

  /// Asks for the notification permission and reports what happened. A method
  /// rather than a closure in `build`, so it uses the State's own `context`
  /// after the await instead of one captured from a build that may be gone.
  Future<void> _checkPermission() async {
    final granted =
        await ref.read(localNotificationsProvider).ensurePermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(granted
            ? 'Notifications are on.'
            : 'Turn notifications on in system settings to be reminded.')));
  }

  void _openPostponeSheet(Reminder reminder, Pet pet) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Move this reminder',
        children: [
          _SheetAction(
            key: const Key('reminder_postpone_day'),
            icon: LucideIcons.calendarPlus,
            label: 'Tomorrow-ish · one day later',
            detail: shortDate(reminder.dueDate.add(const Duration(days: 1))),
            onTap: () {
              Navigator.pop(sheetContext);
              _postponeBy(reminder, pet, const Duration(days: 1));
            },
          ),
          _SheetAction(
            key: const Key('reminder_postpone_week'),
            icon: LucideIcons.calendarRange,
            label: 'One week later',
            detail: shortDate(reminder.dueDate.add(const Duration(days: 7))),
            onTap: () {
              Navigator.pop(sheetContext);
              _postponeBy(reminder, pet, const Duration(days: 7));
            },
          ),
          _SheetAction(
            key: const Key('reminder_postpone_pick'),
            icon: LucideIcons.calendarDays,
            label: 'Pick a date',
            detail: 'Choose any day',
            onTap: () {
              Navigator.pop(sheetContext);
              _pickNewDate(reminder, pet);
            },
          ),
          const SizedBox(height: 4),
          const _SheetNote(
            text: 'This reminder happens once, so there is nothing to skip to '
                '— moving the date is the same thing. Repeating reminders are '
                'coming soon.',
          ),
        ],
      ),
    );
  }

  void _openMoreSheet(Reminder reminder, Pet pet) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: reminder.reminderType,
        children: [
          _SheetAction(
            icon: LucideIcons.pencil,
            label: 'Edit reminder',
            detail: 'Change the name or the date',
            onTap: () {
              Navigator.pop(sheetContext);
              _edit(reminder, pet);
            },
          ),
          _SheetAction(
            icon: LucideIcons.bellRing,
            label: 'Notification permission',
            detail: 'Check whether PawDoc may notify you',
            onTap: () {
              Navigator.pop(sheetContext);
              _checkPermission();
            },
          ),
          _SheetAction(
            key: const Key('reminder_delete'),
            icon: LucideIcons.trash2,
            label: 'Delete reminder',
            detail: 'Removes it and cancels its notification',
            tint: HealthTone.gold,
            onTap: () {
              Navigator.pop(sheetContext);
              _confirmDelete(reminder);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Reminder reminder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('This removes "${reminder.reminderType}" and cancels '
            'its notification.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(remindersRepositoryProvider).delete(reminder.id!);
    await LocalTickLog.clear(ReminderDetailScreen.tickKey(reminder.id!, reminder.dueDate));
    ref.invalidate(remindersForPetProvider(reminder.petId));
    if (mounted) Navigator.of(context).pop();
  }

  void _openScheduleNote() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const HealthSheet(
        title: 'How reminders fire',
        children: [
          _SheetNote(
            icon: LucideIcons.clock,
            text: 'PawDoc notifies you at 9:00 in the morning, local time, on '
                'the day a reminder is due. Reminders are day-based, so that '
                'is the one time there is.',
          ),
          _SheetNote(
            icon: LucideIcons.smartphone,
            text: 'The notification is scheduled on this device. The reminder '
                'itself lives on your account, so it follows you; the pending '
                'notification does not.',
          ),
          _SheetNote(
            icon: LucideIcons.repeat,
            text: 'Every reminder happens once. Repeating schedules, a '
                'lead-up nudge and a follow-up for a missed one are all coming.',
          ),
          _SheetNote(
            icon: LucideIcons.circleCheck,
            text: 'Marking one as taken is kept on this device — there is no '
                'completion record on your account yet, and a tick that was '
                'silently forgotten would be worse than no tick.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(activePetProvider);
    final async = ref.watch(reminderByIdProvider(widget.reminderId));
    final reminder = async.value ?? widget.initial;

    if (reminder == null) {
      return _Shell(
        petName: pet?.name,
        body: switch (async) {
          AsyncError(:final error) => _Notice(
              icon: LucideIcons.cloudOff,
              title: 'Could not load this reminder',
              body: friendlyLoadError(error, noun: 'reminder'),
            ),
          AsyncData() => const _Notice(
              icon: LucideIcons.bellOff,
              title: 'This reminder is gone',
              body: 'It was deleted, or it belongs to another account.',
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      );
    }

    final category = ReminderCategory.of(reminder.reminderType);
    final tint = reminderTint(context, category);
    final takenAt = _ticks?[ReminderDetailScreen.tickKey(reminder.id!, reminder.dueDate)];
    final siblings = ref.watch(remindersForPetProvider(reminder.petId)).value ??
        <Reminder>[reminder];

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Reminder Detail',
          subtitle: 'Never miss what matters for ',
          subtitleTrail: petDisplayName(pet?.name),
          actionsWidth: 124,
          actions: [
            if (pet != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: HealthActionPill(
                  key: const Key('reminder_edit'),
                  label: 'Edit',
                  icon: LucideIcons.pencil,
                  dense: true,
                  onTap: () => _edit(reminder, pet),
                ),
              ),
            HealthCircleButton(
              key: const Key('reminder_more'),
              icon: LucideIcons.ellipsis,
              tooltip: 'More',
              onTap: pet == null ? () {} : () => _openMoreSheet(reminder, pet),
            ),
          ],
        ),
        onRefresh: () async {
          _refresh(reminder.petId);
          await _loadTicks();
        },
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(2),
          if (pet != null)
            PetModuleHeaderCard(
              portrait: PetPortrait(
                pet: pet,
                size: 52,
                livingAvatar: pet.photoKey == null
                    ? null
                    : LivingPetAvatar(
                        species: pet.species,
                        size: 52,
                        seed: pet.id,
                        photoKey: pet.photoKey,
                      ),
              ),
              name: petDisplayName(pet.name),
              meta: petMetaLine(pet),
              onSwitch: () => showPetSwitcher(context, ref),
              onViewProfile: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PetProfileScreen(pet: pet)),
              ),
            ),
          gap(11),
          _ReminderCard(
            reminder: reminder,
            category: category,
            tint: tint,
            takenAt: takenAt,
          ),
          gap(9),
          HealthInfoGrid(
            key: const Key('reminder_facts'),
            cells: _facts(reminder, category, tint),
          ),
          gap(9),
          _AboutCard(reminder: reminder, category: category, pet: pet),
          gap(9),
          _ScheduleCard(
            reminder: reminder,
            siblings: siblings,
            petName: pet?.name,
            onExplain: _openScheduleNote,
          ),
          gap(9),
          _NotificationSettingsCard(
            onExplain: _openScheduleNote,
            onPermission: _checkPermission,
          ),
          gap(9),
          _HistoryCard(
            reminder: reminder,
            takenAt: takenAt,
            onUndo: takenAt == null ? null : () => _toggleTaken(reminder),
          ),
          gap(11),
          _ActionBar(
            taken: takenAt != null,
            onTaken: () => _toggleTaken(reminder),
            onPostpone:
                pet == null ? () {} : () => _openPostponeSheet(reminder, pet),
          ),
          gap(9),
          HealthPrivacyCard(
            title: 'Safe & Secure',
            body: 'Your reminders live on your account and only you can read '
                'them.',
            actionLabel: 'How',
            onTap: _openScheduleNote,
          ),
          gap(8),
        ],
      ),
    );
  }

  /// The mockup's 2×3 fact grid. Every cell is a column of the row, the time
  /// the app really fires at, or a count derived from one of those.
  List<HealthInfoCell> _facts(
      Reminder reminder, ReminderCategory category, Color tint) {
    final days = reminder.daysUntilDue;
    final fireHour = DateTime(2026, 1, 1, LocalNotifications.reminderHour);
    return [
      HealthInfoCell(
        icon: category.icon,
        label: 'Category',
        value: category.label,
        tint: tint,
      ),
      const HealthInfoCell(
        icon: LucideIcons.repeat,
        label: 'Repeats',
        value: 'One-time',
        caption: 'Recurring · Soon',
        captionColor: HealthTone.faint,
      ),
      HealthInfoCell(
        icon: LucideIcons.clock,
        label: 'Time',
        value: clockTime(fireHour),
        caption: 'Local time',
        captionColor: HealthTone.faint,
      ),
      HealthInfoCell(
        icon: LucideIcons.calendarClock,
        label: 'Next reminder',
        value: shortDate(reminder.dueDate),
        caption: switch (days) {
          < 0 => '${-days} days ago',
          0 => 'Today',
          1 => 'Tomorrow',
          _ => 'In $days days',
        },
        captionColor: days < 0 ? HealthTone.gold : null,
      ),
      HealthInfoCell(
        icon: LucideIcons.calendarPlus,
        label: 'Set on',
        value: reminder.createdAt == null
            ? '—'
            : shortDate(reminder.createdAt!.toLocal()),
      ),
      HealthInfoCell(
        icon: LucideIcons.bell,
        label: 'Notification',
        value: reminder.notificationSentAt != null
            ? 'Delivered'
            : (reminder.isPastDue ? 'Date passed' : 'Scheduled'),
        caption: reminder.notificationSentAt != null
            ? shortDate(reminder.notificationSentAt!.toLocal())
            : null,
        captionColor: HealthTone.faint,
      ),
    ];
  }
}

/// The tint a reminder category is drawn in.
///
/// Decorative, and clear of the action ladder's four safety-locked hues — the
/// mockup paints its Skip control in the EMERGENCY red, and a red control
/// beside a medicine reads as a severity signal. `reminder_detail_test` pins
/// the separation, as `vaccineTint` and `AssistantTone` are pinned.
Color reminderTint(BuildContext context, ReminderCategory category) =>
    switch (category) {
      ReminderCategory.medication => HealthTone.violet,
      ReminderCategory.vaccine => PawTone.of(context).accent,
      ReminderCategory.vetVisit => HealthTone.info,
      ReminderCategory.grooming => HealthTone.teal,
      ReminderCategory.parasite => HealthTone.gold,
      ReminderCategory.general => HealthTone.info,
    };

// ---------------------------------------------------------------------------
// The reminder itself
// ---------------------------------------------------------------------------

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.category,
    required this.tint,
    required this.takenAt,
  });

  final Reminder reminder;
  final ReminderCategory category;
  final Color tint;
  final DateTime? takenAt;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final (statusLabel, statusIcon, statusTint) = switch (reminder) {
      _ when takenAt != null =>
        ('Marked as taken', LucideIcons.circleCheck, t.accent),
      _ when reminder.isPastDue =>
        ('Date passed', LucideIcons.clockAlert, HealthTone.gold),
      _ => ('Scheduled', LucideIcons.circleCheck, t.accent),
    };
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthGlyphDisc(icon: category.icon, tint: tint, size: 58, square: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: HealthPill(label: category.label, tint: tint),
                ),
                const SizedBox(height: 6),
                Text(reminder.reminderType,
                    key: const Key('reminder_title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(_subtitleFor(reminder, category),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.dim, fontSize: 11.5, height: 1.3)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: HealthPill(
                    key: const Key('reminder_status'),
                    label: statusLabel,
                    tint: statusTint,
                    icon: statusIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What the reminder is for, in the app's own words — never a claim about
  /// the animal, and never a dosing instruction.
  static String _subtitleFor(Reminder r, ReminderCategory c) => switch (c) {
        ReminderCategory.medication => 'A medication you asked to be reminded '
            'about',
        ReminderCategory.vaccine => 'A vaccination date you are tracking',
        ReminderCategory.vetVisit => 'An appointment you are tracking',
        ReminderCategory.grooming => 'Part of the grooming routine',
        ReminderCategory.parasite => 'Part of the parasite-control routine',
        ReminderCategory.general => 'A reminder you set yourself',
      };
}

// ---------------------------------------------------------------------------
// About
// ---------------------------------------------------------------------------

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.reminder,
    required this.category,
    required this.pet,
  });

  final Reminder reminder;
  final ReminderCategory category;
  final Pet? pet;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final who = petDisplayName(pet?.name);
    // Which module owns this kind of record — a real destination, not a label.
    final (linkLabel, linkTarget) = switch (category) {
      ReminderCategory.medication ||
      ReminderCategory.parasite =>
        ('Open the medication tracker', const MedicationTrackerScreen()),
      ReminderCategory.vaccine =>
        ('Open the vaccination manager', const VaccinationManagerScreen()),
      _ => (null, null),
    };
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.fileText, size: 18, color: t.accent),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('About this reminder',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    // Short, like the reference. The mockup fills this card
                    // with what a named product does; PawDoc has no drug
                    // database and would be guessing, so the card says what
                    // PawDoc will do and points the rest at the vet.
                    Text(
                      'PawDoc keeps this date for $who and will notify you on '
                      '${shortDate(reminder.dueDate)}. What it is for, and how '
                      'often it should happen, is between you and your vet.',
                      style: const TextStyle(
                          color: HealthTone.dim, fontSize: 11.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PetArt(),
            ],
          ),
          if (linkLabel != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: HealthActionPill(
                key: const Key('reminder_module_link'),
                label: linkLabel,
                icon: LucideIcons.arrowRight,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => linkTarget!)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PetArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Icon(LucideIcons.dog,
        size: 40, color: t.accent.withValues(alpha: 0.20));
  }
}

// ---------------------------------------------------------------------------
// Schedule
// ---------------------------------------------------------------------------

/// The mockup's connected date rail.
///
/// It draws six future occurrences of one repeating reminder. There is no
/// recurrence in the schema, so the rail plots what genuinely exists — the
/// pet's upcoming reminders, in date order, with this one lit and check-badged.
/// Same shape, real dates.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.reminder,
    required this.siblings,
    required this.petName,
    required this.onExplain,
  });

  final Reminder reminder;
  final List<Reminder> siblings;
  final String? petName;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final ordered = [...siblings]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final rail = ordered.isEmpty ? [reminder] : ordered;
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading: Icon(LucideIcons.bell,
                size: 17, color: PawTone.of(context).accent),
            title: 'Reminder Schedule',
            actionLabel: 'View Calendar',
            actionIcon: LucideIcons.calendarDays,
            actionBoxed: true,
            onAction: onExplain,
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: 84,
            child: ListView.builder(
              key: const Key('reminder_schedule_rail'),
              scrollDirection: Axis.horizontal,
              itemCount: rail.length,
              itemBuilder: (context, i) => Row(
                children: [
                  if (i > 0) const _RailConnector(),
                  _DateChip(
                    date: rail[i].dueDate,
                    lit: rail[i].id == reminder.id,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(LucideIcons.repeat, size: 13, color: HealthTone.faint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Each reminder happens once · '
                  '${rail.length} scheduled for ${petDisplayName(petName)}',
                  maxLines: 2,
                  style: const TextStyle(
                      color: HealthTone.dim, fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RailConnector extends StatelessWidget {
  const _RailConnector();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      width: 22,
      height: 76,
      child: Center(
        child: Row(
          children: [
            Expanded(
              child: Container(
                  height: 1, color: Colors.white.withValues(alpha: 0.14)),
            ),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent.withValues(alpha: 0.75)),
            ),
            Expanded(
              child: Container(
                  height: 1, color: Colors.white.withValues(alpha: 0.14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.lit});

  final DateTime date;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      width: 68,
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: lit
                    ? t.accent.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.02),
                border: Border.all(
                    color: lit
                        ? t.accent
                        : Colors.white.withValues(alpha: 0.12),
                    width: lit ? 1.6 : 1),
                boxShadow: lit
                    ? [
                        BoxShadow(
                            color: t.accent.withValues(alpha: 0.28),
                            blurRadius: 12)
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(monthAbbrev(date),
                      style: TextStyle(
                          color: lit ? t.accent : HealthTone.muted,
                          fontSize: 10,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6)),
                  const SizedBox(height: 1),
                  Text('${date.day}',
                      style: TextStyle(
                          color: lit ? t.accent : Colors.white,
                          fontSize: 21,
                          height: 1.1,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 1),
                  Text('${date.year}',
                      style: const TextStyle(
                          color: HealthTone.faint, fontSize: 9.5, height: 1.1)),
                ],
              ),
            ),
          ),
          if (lit)
            Positioned(
              right: 2,
              top: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent,
                  border: const Border.fromBorderSide(
                      BorderSide(color: Color(0xFF0A0F0B), width: 1.6)),
                ),
                child: const Icon(LucideIcons.check,
                    size: 10, color: Color(0xFF06110A)),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification settings
// ---------------------------------------------------------------------------

class _NotificationSettingsCard extends StatelessWidget {
  const _NotificationSettingsCard({
    required this.onExplain,
    required this.onPermission,
  });

  final VoidCallback onExplain;
  final VoidCallback onPermission;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final fireHour = DateTime(2026, 1, 1, LocalNotifications.reminderHour);
    final hairline = Colors.white.withValues(alpha: 0.06);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading: Icon(LucideIcons.bell, size: 17, color: t.accent),
            title: 'Notification Settings',
            actionLabel: 'Check',
            onAction: onPermission,
          ),
          const SizedBox(height: 3),
          HealthSettingRow(
            key: const Key('reminder_setting_lead'),
            icon: LucideIcons.calendarClock,
            label: 'Remind me',
            value: 'A day-before nudge · Soon',
            soon: true,
          ),
          Divider(height: 1, thickness: 1, color: hairline),
          HealthSettingRow(
            key: const Key('reminder_setting_ontime'),
            icon: LucideIcons.clock,
            label: 'When it’s time',
            value: 'At ${clockTime(fireHour)} on the due date',
            onTap: onExplain,
          ),
          Divider(height: 1, thickness: 1, color: hairline),
          const HealthSettingRow(
            key: Key('reminder_setting_missed'),
            icon: LucideIcons.repeat,
            label: 'Missed reminder',
            value: 'Nudge until it is done · Soon',
            soon: true,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.reminder,
    required this.takenAt,
    required this.onUndo,
  });

  final Reminder reminder;
  final DateTime? takenAt;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final entries = <(DateTime, String, String, IconData, bool)>[
      if (takenAt != null)
        (
          takenAt!,
          'Marked as taken',
          'Kept on this device',
          LucideIcons.circleCheck,
          true
        ),
      if (reminder.notificationSentAt != null)
        (
          reminder.notificationSentAt!.toLocal(),
          'Notification delivered',
          'Sent by PawDoc',
          LucideIcons.bellRing,
          false
        ),
      if (reminder.createdAt != null)
        (
          reminder.createdAt!.toLocal(),
          'Reminder created',
          'Saved to your account',
          LucideIcons.calendarPlus,
          false
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading: Icon(LucideIcons.fileText, size: 17, color: t.accent),
            title: 'History',
            actionLabel: entries.isEmpty
                ? null
                : '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
            chevron: false,
          ),
          const SizedBox(height: 9),
          if (entries.isEmpty)
            const _EmptyLine(
              key: Key('reminder_history_empty'),
              icon: LucideIcons.history,
              text: 'Nothing has happened yet. Once the notification goes out '
                  '— or you mark this as taken — it is listed here.',
            )
          else
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding:
                    EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 7),
                child: HealthRecordRow(
                  key: Key('reminder_history_$i'),
                  padding: const EdgeInsets.all(9),
                  leading: HealthGlyphDisc(
                    icon: entries[i].$4,
                    tint: entries[i].$5 ? t.accent : HealthTone.info,
                    size: 34,
                    outlined: true,
                  ),
                  title: dateAtTime(entries[i].$1),
                  subtitle: '${entries[i].$2} · ${entries[i].$3}',
                  chevron: entries[i].$5,
                  onTap: entries[i].$5 ? onUndo : null,
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/// The mockup's two footer buttons.
///
/// It paints "Skip / Postpone" in the EMERGENCY red. The action ladder's four
/// hues are safety-locked against decoration — a red control on a flea-tablet
/// reminder reads as a severity signal — so the button keeps its position, its
/// weight and its glyph in [HealthTone.gold], the substitute the vaccine screen
/// already uses for "a date passed".
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.taken,
    required this.onTaken,
    required this.onPostpone,
  });

  final bool taken;
  final VoidCallback onTaken;
  final VoidCallback onPostpone;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(
      children: [
        Expanded(
          child: _OutlinedAction(
            key: const Key('reminder_mark_taken'),
            icon: taken ? LucideIcons.circleCheckBig : LucideIcons.circleCheck,
            label: taken ? 'Taken · undo' : 'Mark as Taken',
            tint: t.accent,
            filled: taken,
            onTap: onTaken,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OutlinedAction(
            key: const Key('reminder_postpone'),
            icon: LucideIcons.calendarClock,
            label: 'Skip / Postpone',
            tint: HealthTone.gold,
            onTap: onPostpone,
          ),
        ),
      ],
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: tint.withValues(alpha: filled ? 0.20 : 0.07),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tint.withValues(alpha: 0.55)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: tint),
                  const SizedBox(width: 7),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          maxLines: 1,
                          style: TextStyle(
                              color: tint,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = tint ?? PawTone.of(context).accent;
    return HealthRecordRow(
      leading: HealthGlyphDisc(icon: icon, tint: c, size: 36),
      title: label,
      subtitle: detail,
      onTap: onTap,
    );
  }
}

class _SheetNote extends StatelessWidget {
  const _SheetNote({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon ?? LucideIcons.info,
            size: 16, color: PawTone.of(context).accent),
        const SizedBox(width: 11),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
      decoration: BoxDecoration(
        color: HealthTone.raised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: HealthTone.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: HealthTone.dim, fontSize: 11.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: kRecordPadding,
        child: HomeCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: HealthTone.muted),
              const SizedBox(height: 11),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: HealthTone.dim, fontSize: 11.5, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.body, this.petName});

  final Widget body;
  final String? petName;

  @override
  Widget build(BuildContext context) {
    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PetModuleAppBar(
          title: 'Reminder Detail',
          subtitle: 'Never miss what matters for ',
          subtitleTrail: petDisplayName(petName),
        ),
        bottomNavigationBar: const PawNavBar(detached: true),
        body: body,
      ),
    );
  }
}
