import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/dates.dart';
import '../core/friendly_error.dart';
import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../home/home_sections.dart';
import '../pets/active_pet.dart';
import '../pets/pet.dart';
import '../pets/pet_form_screen.dart';
import '../pets/pet_switcher.dart';
import '../reminders/reminders_screen.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'health_event_form_screen.dart';
import 'health_record_detail.dart';
import 'health_sections.dart';
import 'history_timeline_screen.dart';
import 'medication_plan.dart';
import 'timeline.dart';

/// The medication plan, rebuilt against mockup `medication_tracker`.
///
/// Hero with the adherence bar, four counted statistics, the current
/// medications, today's schedule with a real tick, the finished courses, the
/// tips card and the Add CTA.
///
/// **Copy departures from the mockup, and why** (layout reproduced in each
/// case):
///
/// | Mockup | Shipped | Reason |
/// |---|---|---|
/// | "Medication Adherence · 96% · Excellent" | counted from the doses actually ticked, banded about the routine | see [Adherence] — the mockup's number is over nothing, and "Excellent" is a judgement |
/// | "100% · This Week · On track" | the same figure for the week, or "—" when nothing was scheduled | 0% would read as a failure that never happened |
/// | "Give medications with food if recommended and praise Buddy after each dose!" | what the label and the vet said, unchanged by this list | dosing guidance is not the app's to give |
class MedicationTrackerScreen extends ConsumerStatefulWidget {
  const MedicationTrackerScreen({super.key});

  @override
  ConsumerState<MedicationTrackerScreen> createState() =>
      _MedicationTrackerScreenState();
}

class _MedicationTrackerScreenState
    extends ConsumerState<MedicationTrackerScreen> {
  Future<void> _add(Pet pet) async {
    final logged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HealthEventFormScreen(
            petId: pet.id!, petName: pet.name, initialType: 'medication'),
      ),
    );
    ref.invalidate(healthTimelineProvider(pet.id!));
    if (logged == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to the medication plan.')));
    }
  }

  void _openPlanNote() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const HealthSheet(
        title: 'How this plan works',
        children: [
          _PlanPoint(
            icon: LucideIcons.listChecks,
            text: 'Every medicine here is one you filed. PawDoc does not '
                'prescribe, adjust or stop anything.',
          ),
          _PlanPoint(
            icon: LucideIcons.clock,
            text: 'Today\'s doses are worked out from the schedule you typed. '
                'If it could not be read as a repeating one, the medicine is '
                'still listed — there is just nothing to tick.',
          ),
          _PlanPoint(
            icon: LucideIcons.smartphone,
            text: 'Ticked doses are kept on this device, so they do not follow '
                'you to a second phone. The medicines themselves are on your '
                'account.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(activePetProvider);
    if (pet == null) return const _NoPet();

    final async = ref.watch(healthTimelineProvider(pet.id!));
    final log = ref.watch(doseLogProvider).value ?? const <String, DateTime>{};
    final now = DateTime.now();

    final all = [
      for (final item in async.value ?? const <TimelineItem>[])
        ?Medication.fromTimelineItem(item),
    ];
    final active =
        all.where((m) => m.activeOn(now)).toList(growable: false);
    final finished =
        all.where((m) => !m.activeOn(now)).toList(growable: false);
    final today = _todaysSlots(active, now);

    final monthAdherence = Adherence.over(all, log,
        from: now.subtract(const Duration(days: 30)), to: now);
    final weekAdherence = Adherence.over(all, log,
        from: now.subtract(const Duration(days: 7)), to: now);
    final takenThisMonth = monthAdherence.taken;

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.pill,
          title: 'Medication Tracker',
          subtitleLead: petDisplayPossessive(pet.name),
          subtitle: ' medication & treatment plan',
          actions: [
            HealthCircleButton(
              key: const Key('medication_reminders'),
              icon: LucideIcons.bell,
              tooltip: 'Reminders',
              badge: today.any((s) =>
                  !log.containsKey(s.key) && s.at.isBefore(now)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RemindersScreen()),
              ),
            ),
          ],
        ),
        onRefresh: () async {
          ref
            ..invalidate(healthTimelineProvider(pet.id!))
            ..invalidate(doseLogProvider);
          await ref.read(healthTimelineProvider(pet.id!).future);
        },
        bottomNav: const PawNavBar(detached: true),
        footer: HealthPrimaryCta(
          key: const Key('medication_add_cta'),
          label: 'Add New Medication',
          onTap: () => _add(pet),
        ),
        children: [
          gap(2),
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
              MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)),
            ),
            trailing: GestureDetector(
              onTap: _openPlanNote,
              child: HealthStatusBadge(
                key: const Key('medication_adherence'),
                caption: 'Doses ticked off',
                value: monthAdherence.percent == null
                    ? '—'
                    : '${monthAdherence.percent}%',
                // The short band: "Just getting started this month" does not
                // fit the badge, and a truncated reading is worse than a
                // terser one.
                detail: monthAdherence.percent == null
                    ? monthAdherence.band
                    : '${monthAdherence.tileBand} this month',
                icon: LucideIcons.listChecks,
                progress: monthAdherence.ratio,
              ),
            ),
          ),
          gap(11),
          HealthStatTiles(
            layout: HealthStatLayout.stacked,
            stats: [
              HealthStat(
                icon: LucideIcons.pill,
                value: '${active.length}',
                label: 'Active medicines',
                caption: 'Right now',
              ),
              HealthStat(
                icon: LucideIcons.calendarClock,
                value: '${today.length}',
                label: 'Doses today',
                caption: today.isEmpty
                    ? 'None due'
                    : '${today.where((s) => log.containsKey(s.key)).length} ticked',
              ),
              HealthStat(
                icon: LucideIcons.chartNoAxesColumn,
                value: weekAdherence.percent == null
                    ? '—'
                    : '${weekAdherence.percent}%',
                label: 'This week',
                caption: weekAdherence.tileBand,
              ),
              HealthStat(
                icon: LucideIcons.circleCheck,
                value: '$takenThisMonth',
                label: 'Doses ticked',
                caption: 'This month',
              ),
            ],
          ),
          gap(11),
          ...switch (async) {
            AsyncError(:final error) => [
                _Notice(
                  icon: LucideIcons.cloudOff,
                  title: 'Could not load the plan',
                  body: friendlyLoadError(error, noun: 'medications'),
                ),
              ],
            AsyncLoading() when all.isEmpty => [
                const Center(child: CircularProgressIndicator()),
              ],
            _ => [
                _CurrentCard(
                  medications: active,
                  pet: pet,
                  onAdd: () => _add(pet),
                ),
                gap(9),
                HealthAddCard(
                  key: const Key('medication_add_card'),
                  title: 'Add New Medication',
                  subtitle: 'Add a medicine or supplement to '
                      '${petDisplayPossessive(pet.name)} plan.',
                  onTap: () => _add(pet),
                ),
                gap(11),
                _ScheduleCard(slots: today, log: log, pet: pet),
                gap(11),
                _HistoryCard(medications: finished, pet: pet),
              ],
          },
          gap(9),
          const HealthEduCard(
            title: 'Tips for success',
            body: 'How and when to give a dose — and what to do about one you '
                'missed — is on the label or in your vet’s instructions. '
                'Keeping the list here does not change either.',
            art: _PillArt(),
          ),
          gap(8),
        ],
      ),
    );
  }

  /// Every dose due today across the active plan, in time order.
  static List<DoseSlot> _todaysSlots(List<Medication> active, DateTime now) {
    final out = <DoseSlot>[];
    for (final med in active) {
      final slots = med.schedule.slotsOn(now, med.startedOn);
      for (var i = 0; i < slots.length; i++) {
        out.add(DoseSlot(medication: med, at: slots[i], index: i));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}

/// The tint a medicine's form is drawn in. Decorative, and clear of the action
/// ladder's four safety-locked hues — a red pill glyph beside a medicine name
/// reads as a severity signal.
Color medicationTint(BuildContext context, String? form) =>
    switch (form?.toLowerCase()) {
      'chewable' => HealthTone.violet,
      'tablet' => HealthTone.info,
      'liquid' => HealthTone.gold,
      'topical' => HealthTone.coral,
      'injection' => HealthTone.teal,
      _ => PawTone.of(context).accent,
    };

// ---------------------------------------------------------------------------
// Current medications
// ---------------------------------------------------------------------------

class _CurrentCard extends ConsumerWidget {
  const _CurrentCard({
    required this.medications,
    required this.pet,
    required this.onAdd,
  });

  final List<Medication> medications;
  final Pet pet;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            title: 'Current Medications',
            actionLabel: 'View Treatment Plan',
            actionBoxed: true,
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HealthHistoryScreen()),
            ),
          ),
          const SizedBox(height: 9),
          if (medications.isEmpty)
            const _EmptyLine(
              key: Key('medication_none_active'),
              icon: LucideIcons.pill,
              text: 'Nothing on the plan right now. Add a medicine and its '
                  'schedule and today\'s doses appear below.',
            )
          else
            for (var i = 0; i < medications.length; i++)
              Padding(
                padding: EdgeInsets.only(
                    bottom: i == medications.length - 1 ? 0 : 7),
                child: _MedicationRow(
                    medication: medications[i], pet: pet),
              ),
        ],
      ),
    );
  }
}

/// One medicine on the plan. Reused by the history card, which draws the same
/// row with a completed mark.
class _MedicationRow extends ConsumerWidget {
  const _MedicationRow({
    required this.medication,
    required this.pet,
    this.completed = false,
  });

  final Medication medication;
  final Pet pet;
  final bool completed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tint = medicationTint(context, medication.form);
    final next = medication.schedule
        .nextDoseAfter(DateTime.now(), medication.startedOn,
            endsOn: medication.endsOn);
    return HealthRecordRow(
      key: Key('medication_row_${medication.id}'),
      background: HealthTone.raised,
      leading: completed
          ? HealthGlyphDisc(
              icon: LucideIcons.circleCheck, tint: tint, outlined: true)
          : HealthGlyphDisc(icon: LucideIcons.pill, tint: tint),
      title: medication.name,
      titleChips: [
        // Not Flexible: two flexible children in one Row split the space
        // evenly, which squeezed "Amoxicillin" into "Amoxic…" beside a 45dp
        // chip. A form name is short and fixed; the title is what should give.
        if (medication.form != null)
          HealthPill(label: medication.form!, tint: tint),
      ],
      subtitle: [
        ?medication.dosage,
        ?medication.purpose,
      ].join(' · ').trim().isEmpty
          ? medication.note
          : [?medication.dosage, ?medication.purpose].join(' · '),
      middle: SizedBox(
        width: 96,
        child: HealthMetaBlock(
          align: CrossAxisAlignment.start,
          lines: [
            (medication.schedule.label, true),
            if (next != null)
              ('Next ${_shortStamp(next)}', false)
            else if (medication.endsOn != null)
              ('Ends ${shortDate(medication.endsOn!)}', false)
            else
              ('Started ${shortDate(medication.startedOn)}', false),
          ],
        ),
      ),
      onTap: () => showHealthRecordDetail(
        context,
        ref,
        item: TimelineItem(
          kind: TimelineKind.healthEvent,
          date: medication.startedOn,
          title: 'Medication',
          subtitle: medication.name,
          detail: medication.note,
          eventType: 'medication',
          id: medication.id,
          payload: {
            'medication_name': medication.name,
            if (medication.dosage != null) 'dosage': medication.dosage,
            if (medication.form != null) 'form': medication.form,
            if (medication.purpose != null) 'purpose': medication.purpose,
            if (medication.schedule.raw.isNotEmpty)
              'schedule': medication.schedule.raw,
            if (medication.endsOn != null)
              'ends_on': medication.endsOn!.toIso8601String().split('T').first,
          },
        ),
        pet: pet,
        onChanged: () => ref.invalidate(healthTimelineProvider(pet.id!)),
      ),
    );
  }
}

String _shortStamp(DateTime at) {
  final now = DateTime.now();
  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  if (sameDay) return _clock(at);
  return shortDate(at);
}

String _clock(DateTime at) {
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  return '$h:${at.minute.toString().padLeft(2, '0')} '
      '${at.hour < 12 ? 'AM' : 'PM'}';
}

// ---------------------------------------------------------------------------
// Today's schedule
// ---------------------------------------------------------------------------

class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({
    required this.slots,
    required this.log,
    required this.pet,
  });

  final List<DoseSlot> slots;
  final Map<String, DateTime> log;
  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            title: 'Today’s Schedule',
            actionLabel: 'View Reminders',
            actionBoxed: true,
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RemindersScreen()),
            ),
          ),
          const SizedBox(height: 9),
          if (slots.isEmpty)
            const _EmptyLine(
              key: Key('medication_none_today'),
              icon: LucideIcons.calendarCheck,
              text: 'No doses due today. A schedule like “Every 12 hours” or '
                  '“Every 30 days” fills this in.',
            )
          else
            for (var i = 0; i < slots.length; i++)
              Padding(
                padding:
                    EdgeInsets.only(bottom: i == slots.length - 1 ? 0 : 7),
                child: _DoseRow(
                  slot: slots[i],
                  takenAt: log[slots[i].key],
                  onToggle: () =>
                      ref.read(doseLogProvider.notifier).toggle(slots[i].key),
                ),
              ),
          if (slots.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(LucideIcons.smartphone,
                  size: 11, color: HealthTone.faint),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Ticks are kept on this device.',
                    style:
                        TextStyle(color: HealthTone.faint, fontSize: 10.5)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.slot,
    required this.takenAt,
    required this.onToggle,
  });

  final DoseSlot slot;
  final DateTime? takenAt;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final tint = medicationTint(context, slot.medication.form);
    final upcoming = takenAt == null && slot.at.isAfter(DateTime.now());
    return HealthRecordRow(
      key: Key('dose_${slot.key}'),
      background: HealthTone.raised,
      chevron: false,
      leading: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_clock(slot.at).split(' ').first,
                style: TextStyle(
                    color: t.accent,
                    fontSize: 13,
                    height: 1.1,
                    fontWeight: FontWeight.w700)),
            Text(_clock(slot.at).split(' ').last,
                style: const TextStyle(
                    color: HealthTone.faint, fontSize: 10, height: 1.2)),
          ],
        ),
      ),
      title: slot.medication.name,
      titleChips: [
        if (slot.medication.dosage != null)
          HealthPill(label: slot.medication.dosage!, tint: tint),
      ],
      subtitle: slot.medication.form == null
          ? slot.medication.purpose
          : '1 ${slot.medication.form!.toLowerCase()}',
      trailing: _DoseAction(
        takenAt: takenAt,
        upcoming: upcoming,
        onToggle: onToggle,
      ),
    );
  }
}

class _DoseAction extends StatelessWidget {
  const _DoseAction({
    required this.takenAt,
    required this.upcoming,
    required this.onToggle,
  });

  final DateTime? takenAt;
  final bool upcoming;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    if (takenAt != null) {
      return InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.circleCheck, size: 15, color: t.accent),
            const SizedBox(width: 5),
            Flexible(
              child: Text('Taken ${_clock(takenAt!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      );
    }
    if (upcoming) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text('Upcoming',
            style: TextStyle(color: HealthTone.faint, fontSize: 11)),
      );
    }
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: t.accent.withValues(alpha: 0.12),
          border: Border.all(color: t.accent.withValues(alpha: 0.45)),
        ),
        child: Center(
          child: Text('Mark as taken',
              style: TextStyle(
                  color: t.accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({required this.medications, required this.pet});

  final List<Medication> medications;
  final Pet pet;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  static const _collapsed = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.medications;
    final shown =
        _expanded ? rows : rows.take(_collapsed).toList(growable: false);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            title: 'Medication History',
            actionLabel: rows.length <= _collapsed
                ? null
                : (_expanded ? 'Show less' : 'View All History'),
            onAction: () => setState(() => _expanded = !_expanded),
          ),
          const SizedBox(height: 9),
          if (rows.isEmpty)
            const _EmptyLine(
              key: Key('medication_none_finished'),
              icon: LucideIcons.history,
              text: 'Finished courses land here once their end date passes.',
            )
          else
            for (var i = 0; i < shown.length; i++)
              Padding(
                padding:
                    EdgeInsets.only(bottom: i == shown.length - 1 ? 0 : 7),
                child: _MedicationRow(
                    medication: shown[i], pet: widget.pet, completed: true),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small pieces
// ---------------------------------------------------------------------------

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

class _PlanPoint extends StatelessWidget {
  const _PlanPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: PawTone.of(context).accent),
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

class _PillArt extends StatelessWidget {
  const _PillArt();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.heart, size: 18, color: t.accent.withValues(alpha: 0.22)),
      const SizedBox(width: 4),
      Icon(LucideIcons.dog, size: 26, color: t.accent.withValues(alpha: 0.22)),
    ]);
  }
}

class _NoPet extends StatelessWidget {
  const _NoPet();

  @override
  Widget build(BuildContext context) {
    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const PetModuleAppBar(
          icon: LucideIcons.pill,
          title: 'Medication Tracker',
          subtitleLead: 'PawDoc',
          subtitle: ' medication plan',
        ),
        bottomNavigationBar: const PawNavBar(detached: true),
        body: Padding(
          padding: kRecordPadding,
          child: Center(
            child: HealthAddCard(
              title: 'Add a pet to start a plan',
              subtitle: 'Medicines, doses and schedules live per pet.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PetFormScreen()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
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
    );
  }
}
