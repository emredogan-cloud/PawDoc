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
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'health_event_form_screen.dart';
import 'health_record_detail.dart';
import 'health_sections.dart';
import 'history_timeline_screen.dart';
import 'timeline.dart';

/// One vaccination the owner has filed.
class Vaccination {
  const Vaccination({
    required this.id,
    required this.name,
    required this.givenOn,
    this.vaccineClass,
    this.nextDue,
    this.clinic,
    this.note,
  });

  final String id;
  final String name;
  final DateTime givenOn;

  /// Core / Non-core / Lifestyle — **owner-selected**. Which vaccines are core
  /// is a regional veterinary judgement, not something the app decides from a
  /// name, so an unset class stays unset and the record only appears under
  /// "All".
  final String? vaccineClass;

  final DateTime? nextDue;
  final String? clinic;
  final String? note;

  bool get isOverdue =>
      nextDue != null && nextDue!.isBefore(_today());

  bool dueWithin(Duration window) =>
      nextDue != null && !nextDue!.isAfter(_today().add(window));

  /// Days from today until it is next due; negative when it has passed.
  int? get daysUntilDue => nextDue?.difference(_today()).inDays;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static Vaccination? fromTimelineItem(TimelineItem item) {
    if (item.eventType != 'vaccination' || item.id == null) return null;
    final meta = item.payload ?? const <String, dynamic>{};
    final name = (meta['vaccine_name'] as String?)?.trim();
    return Vaccination(
      id: item.id!,
      name: (name == null || name.isEmpty)
          ? (item.subtitle?.trim().isNotEmpty == true
              ? item.subtitle!.trim()
              : 'Vaccination')
          : name,
      givenOn: item.date,
      vaccineClass: (meta['vaccine_class'] as String?)?.trim(),
      nextDue: meta['next_due'] == null
          ? null
          : DateTime.tryParse(meta['next_due'].toString()),
      clinic: (meta['clinic'] as String?)?.trim(),
      // `item.detail` only: when metadata carries a name, the timeline puts
      // that name in `subtitle` and the owner's note in `detail`. Falling back
      // to `subtitle` printed the vaccine's name twice on its own row.
      note: item.detail,
    );
  }
}

/// The vaccine record, rebuilt against mockup `vaccination_manager`.
///
/// Protection summary, four counted statistics, the class filter rail, what is
/// coming up, the history, the educational footer and the Add CTA.
///
/// **Copy departures from the mockup, and why** (layout reproduced in each
/// case):
///
/// | Mockup | Shipped | Reason |
/// |---|---|---|
/// | "Protection Status · Excellent · Fully protected" | what the *record* holds, and how much of it carries a next date | the app knows which records were typed in; it does not know whether an animal is immune. Records are partial, schedules are regional, and vaccines can fail |
/// | "100% · On Schedule · Great job!" | how many are past their due date | a fact the owner can act on, not a grade |
/// | "Vaccine Record · Up to date" | the soonest date that is coming | "up to date" is the same immunity claim in fewer words |
/// | "Vaccines help protect Buddy from serious diseases" | which vaccines, and when, is the vet's call | the app does not advise on a vaccination schedule |
class VaccinationManagerScreen extends ConsumerStatefulWidget {
  const VaccinationManagerScreen({super.key});

  @override
  ConsumerState<VaccinationManagerScreen> createState() =>
      _VaccinationManagerScreenState();
}

class _VaccinationManagerScreenState
    extends ConsumerState<VaccinationManagerScreen> {
  String _filter = 'all';

  static const _filters = [
    HealthFilter('all', 'All Vaccines', LucideIcons.syringe),
    HealthFilter('core', 'Core', LucideIcons.shieldCheck),
    HealthFilter('non-core', 'Non-core', LucideIcons.star),
    HealthFilter('lifestyle', 'Lifestyle', LucideIcons.dog),
    HealthFilter('unclassified', 'No class set', LucideIcons.circleHelp),
  ];

  static const _twelveMonths = Duration(days: 365);

  Future<void> _add(Pet pet) async {
    final logged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HealthEventFormScreen(
            petId: pet.id!, petName: pet.name, initialType: 'vaccination'),
      ),
    );
    ref.invalidate(healthTimelineProvider(pet.id!));
    if (logged == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to the vaccine record.')));
    }
  }

  void _openRecordNote() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const HealthSheet(
        title: 'What this summary means',
        children: [
          _Point(
            icon: LucideIcons.fileText,
            text: 'It describes the record, not the animal. PawDoc knows what '
                'you have filed here — it cannot know whether a vaccine took, '
                'whether one is missing, or what your region expects.',
          ),
          _Point(
            icon: LucideIcons.calendarClock,
            text: 'A vaccine only appears under "Coming up" if you gave it a '
                'next-due date. That date also sets a reminder.',
          ),
          _Point(
            icon: LucideIcons.stethoscope,
            text: 'Which vaccines a pet needs, and how often, is your vet’s '
                'call. This list exists so the two of you are reading the same '
                'record.',
          ),
        ],
      ),
    );
  }

  bool _matches(Vaccination v) {
    if (_filter == 'all') return true;
    final c = v.vaccineClass?.toLowerCase();
    if (_filter == 'unclassified') return c == null || c.isEmpty;
    return c == _filter;
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(activePetProvider);
    if (pet == null) return const _NoPet();

    final async = ref.watch(healthTimelineProvider(pet.id!));
    final all = [
      for (final item in async.value ?? const <TimelineItem>[])
        ?Vaccination.fromTimelineItem(item),
    ];
    final visible = all.where(_matches).toList(growable: false);

    // Coming up: anything with a next-due date inside a year, overdue first.
    final upcoming = visible
        .where((v) => v.dueWithin(_twelveMonths))
        .toList(growable: false)
      ..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));
    final history = visible.toList(growable: false)
      ..sort((a, b) => b.givenOn.compareTo(a.givenOn));

    final dated = all.where((v) => v.nextDue != null).length;
    final overdue = all.where((v) => v.isOverdue).length;
    final soonest = all
        .where((v) => v.nextDue != null && !v.isOverdue)
        .fold<DateTime?>(
            null,
            (best, v) =>
                best == null || v.nextDue!.isBefore(best) ? v.nextDue : best);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.shieldCheck,
          title: 'Vaccination Manager',
          subtitleLead: petDisplayPossessive(pet.name),
          subtitle: ' vaccine record',
          actions: [
            HealthCircleButton(
              key: const Key('vaccination_info'),
              icon: LucideIcons.info,
              tooltip: 'What this summary means',
              color: PawTone.of(context).accent,
              onTap: _openRecordNote,
            ),
          ],
        ),
        onRefresh: () async {
          ref.invalidate(healthTimelineProvider(pet.id!));
          await ref.read(healthTimelineProvider(pet.id!).future);
        },
        bottomNav: const PawNavBar(detached: true),
        footer: HealthPrimaryCta(
          key: const Key('vaccination_add_cta'),
          label: 'Add New Vaccine Record',
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
              onTap: _openRecordNote,
              child: HealthStatusBadge(
                key: const Key('vaccination_status'),
                caption: 'Vaccine record',
                value: all.isEmpty ? 'Empty' : '${all.length} on file',
                detail: all.isEmpty
                    ? 'Nothing filed yet'
                    : (dated == all.length
                        ? 'All have a next date'
                        : '${all.length - dated} without a next date'),
                icon: LucideIcons.shieldCheck,
                progress: all.isEmpty ? null : dated / all.length,
              ),
            ),
          ),
          gap(11),
          HealthStatTiles(
            // Stacked, not inline: four boxed tiles across 393 points leave a
            // 46dp label slot, where "Recorded" broke mid-word on the device.
            layout: HealthStatLayout.stacked,
            stats: [
              HealthStat(
                icon: LucideIcons.syringe,
                value: '${all.length}',
                label: 'Recorded',
              ),
              HealthStat(
                icon: LucideIcons.calendarDays,
                value: '${all.where((v) => v.dueWithin(_twelveMonths) && !v.isOverdue).length}',
                label: 'Due in a year',
              ),
              HealthStat(
                icon: LucideIcons.clockAlert,
                value: '$overdue',
                label: 'Past due',
                caption: overdue == 0 ? 'None' : 'Ask your vet',
                // No red: an overdue vaccine is a date that passed, not a
                // triage level, and the ladder's hues stay with the ladder.
                captionColor: overdue == 0 ? null : HealthTone.gold,
              ),
              HealthStat(
                icon: LucideIcons.calendarCheck,
                value: soonest == null ? '—' : _dayMonth(soonest),
                label: 'Next date',
              ),
            ],
          ),
          gap(11),
          HealthBleed(
            child: HealthFilterChips(
              filters: _filters,
              selected: _filter,
              onSelect: (id) => setState(() => _filter = id),
            ),
          ),
          gap(11),
          ...switch (async) {
            AsyncError(:final error) => [
                _Notice(
                  icon: LucideIcons.cloudOff,
                  title: 'Could not load the record',
                  body: friendlyLoadError(error, noun: 'vaccines'),
                ),
              ],
            AsyncLoading() when all.isEmpty => [
                const Center(child: CircularProgressIndicator()),
              ],
            _ => [
                _UpcomingCard(items: upcoming, pet: pet),
                gap(9),
                HealthAddCard(
                  key: const Key('vaccination_calendar_card'),
                  icon: LucideIcons.calendarDays,
                  title: 'View Full Schedule',
                  subtitle: 'Every due date, alongside the rest of '
                      '${petDisplayPossessive(pet.name)} reminders.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RemindersScreen()),
                  ),
                ),
                gap(11),
                _HistoryCard(items: history, pet: pet),
              ],
          },
          gap(9),
          const HealthEduCard(
            icon: LucideIcons.shieldCheck,
            title: 'Why this list is worth keeping',
            body: 'Which vaccines a pet needs, and how often, is your vet’s '
                'call — it depends on where you live, their age and how they '
                'spend their days. Keeping the dates here means you both read '
                'the same record.',
            art: _ShieldArt(),
          ),
          gap(8),
        ],
      ),
    );
  }
}

String _dayMonth(DateTime d) {
  final full = shortDate(d);
  return full.substring(0, full.lastIndexOf(','));
}

/// The tint a vaccine class is drawn in. Decorative, and clear of the action
/// ladder's four safety-locked hues.
Color vaccineTint(BuildContext context, String? vaccineClass) =>
    switch (vaccineClass?.toLowerCase()) {
      'core' => PawTone.of(context).accent,
      'non-core' => HealthTone.violet,
      'lifestyle' => HealthTone.teal,
      _ => HealthTone.info,
    };

// ---------------------------------------------------------------------------

class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard({required this.items, required this.pet});

  final List<Vaccination> items;
  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HealthSectionHead(
            title: 'Coming Up',
            actionLabel: 'Next 12 months',
            chevron: false,
          ),
          const SizedBox(height: 9),
          if (items.isEmpty)
            const _EmptyLine(
              key: Key('vaccination_none_upcoming'),
              icon: LucideIcons.calendarClock,
              text: 'Nothing due in the next year. A vaccine appears here once '
                  'you give it a next-due date — which also sets a reminder.',
            )
          else
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 7),
                child: _VaccinationRow(
                    vaccination: items[i], pet: pet, upcoming: true),
              ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({required this.items, required this.pet});

  final List<Vaccination> items;
  final Pet pet;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  static const _collapsed = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.items;
    final shown =
        _expanded ? rows : rows.take(_collapsed).toList(growable: false);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            title: 'Vaccine History',
            actionLabel: rows.length <= _collapsed
                ? null
                : (_expanded ? 'Show less' : 'View All History'),
            onAction: () => setState(() => _expanded = !_expanded),
          ),
          const SizedBox(height: 9),
          if (rows.isEmpty)
            const _EmptyLine(
              key: Key('vaccination_none_history'),
              icon: LucideIcons.syringe,
              text: 'Nothing filed under this filter yet.',
            )
          else
            for (var i = 0; i < shown.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == shown.length - 1 ? 0 : 7),
                child: _VaccinationRow(
                    vaccination: shown[i], pet: widget.pet, upcoming: false),
              ),
        ],
      ),
    );
  }
}

/// One vaccine. The same row draws both lists — upcoming leads with when it is
/// due, history with when it was given.
class _VaccinationRow extends ConsumerWidget {
  const _VaccinationRow({
    required this.vaccination,
    required this.pet,
    required this.upcoming,
  });

  final Vaccination vaccination;
  final Pet pet;
  final bool upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tint = vaccineTint(context, vaccination.vaccineClass);
    final days = vaccination.daysUntilDue;
    return HealthRecordRow(
      key: Key('vaccination_row_${vaccination.id}'),
      background: HealthTone.raised,
      leading: HealthGlyphDisc(
        icon: upcoming ? LucideIcons.syringe : LucideIcons.circleCheck,
        tint: tint,
        outlined: !upcoming,
      ),
      title: vaccination.name,
      titleChips: [
        if (vaccination.vaccineClass != null)
          HealthPill(label: vaccination.vaccineClass!, tint: tint),
      ],
      subtitle: upcoming
          ? (vaccination.clinic ?? 'Last given ${shortDate(vaccination.givenOn)}')
          : (vaccination.clinic ?? vaccination.note),
      middle: SizedBox(
        width: 96,
        child: HealthMetaBlock(
          leadColor: vaccination.isOverdue ? HealthTone.gold : null,
          lines: upcoming
              ? [
                  (
                    days == null
                        ? '—'
                        : (days < 0
                            ? '${-days} days ago'
                            : (days == 0 ? 'Due today' : 'In $days days')),
                    true
                  ),
                  (shortDate(vaccination.nextDue!), false),
                ]
              : [
                  (shortDate(vaccination.givenOn), true),
                  (
                    vaccination.nextDue == null
                        ? 'No next date'
                        : 'Next ${shortDate(vaccination.nextDue!)}',
                    false
                  ),
                ],
        ),
      ),
      onTap: () => showHealthRecordDetail(
        context,
        ref,
        item: TimelineItem(
          kind: TimelineKind.healthEvent,
          date: vaccination.givenOn,
          title: 'Vaccination',
          subtitle: vaccination.name,
          detail: vaccination.note,
          eventType: 'vaccination',
          id: vaccination.id,
          payload: {
            'vaccine_name': vaccination.name,
            'vaccine_class': ?vaccination.vaccineClass,
            'clinic': ?vaccination.clinic,
            if (vaccination.nextDue != null)
              'next_due':
                  vaccination.nextDue!.toIso8601String().split('T').first,
          },
        ),
        pet: pet,
        onChanged: () => ref.invalidate(healthTimelineProvider(pet.id!)),
      ),
    );
  }
}

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

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

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

class _ShieldArt extends StatelessWidget {
  const _ShieldArt();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.dog, size: 26, color: t.accent.withValues(alpha: 0.22)),
      const SizedBox(width: 4),
      Icon(LucideIcons.shieldCheck,
          size: 20, color: t.accent.withValues(alpha: 0.22)),
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
          icon: LucideIcons.shieldCheck,
          title: 'Vaccination Manager',
          subtitleLead: 'PawDoc',
          subtitle: ' vaccine record',
        ),
        bottomNavigationBar: const PawNavBar(detached: true),
        body: Padding(
          padding: kRecordPadding,
          child: Center(
            child: HealthAddCard(
              title: 'Add a pet to start a record',
              subtitle: 'Vaccines and their due dates live per pet.',
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
