import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/dates.dart';
import '../core/friendly_error.dart';
import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../health/health_event.dart';
import '../health/health_record_detail.dart';
import '../health/health_sections.dart';
import '../health/history_timeline_screen.dart';
import '../health/medication_tracker_screen.dart';
import '../health/timeline.dart';
import '../health/vaccination_manager_screen.dart';
import '../health/weight_tracking_screen.dart';
import '../home/home_sections.dart';
import '../memories/memories_repository.dart';
import '../memories/memories_screen.dart';
import '../memories/memory.dart';
import '../memories/memory_photo.dart';
import '../reminders/reminder.dart';
import '../reminders/reminder_detail_screen.dart';
import '../reminders/reminders_repository.dart';
import '../reminders/reminders_screen.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import '../vet_finder/maps_links.dart';
import 'active_pet.dart';
import 'pet.dart';
import 'pet_form_screen.dart';
import 'pet_statistics_screen.dart';
import 'pet_switcher.dart';
import 'pets_repository.dart';

/// Everything on one pet, rebuilt against mockup `pet_profile`.
///
/// Hero, the five-tab rail, Basic Information, the four record cards, About,
/// the vet card and the family banner — over the app's bottom navigation.
///
/// Until now `onViewProfile` pushed the *edit form*: there was no profile
/// screen at all. This is it, and the health module's five "View Profile"
/// pills now land here.
///
/// ## What the mockup claims, and what ships
///
/// This is the most contract-hostile mockup since the result screens. Four of
/// its readings are clinical assertions the product cannot make:
///
/// | Mockup | Shipped | Why |
/// |---|---|---|
/// | "Health Score · 92 · Excellent" | the Care Score, record completeness, banded in words about the record | **D-2**. A number that reads as a verdict on an animal's health, with nothing behind it, is exactly the reliance the product must not invite |
/// | "Vaccinations · 12/12 · Completed · Up to date" | how many are on file, and how many carry a next date | the app knows what was typed in. Records are partial, schedules are regional, and vaccines can fail |
/// | "Allergies · 2 · Known" | the owner's own medical notes, marked as theirs | an allergy is a diagnosis. There is no allergy column and there should not be one the app fills in |
/// | "Conditions · 0 · None · Great!" | **gone**, replaced by a counted record card | naming zero conditions is an all-clear, and `safety_copy_test` bans the exact string. "Great!" grades the animal |
///
/// The mockup also prints **Blood Type**, **Microchip ID**, **Colour** and
/// **Neutered**. `pets` has no column for any of them. Rather than drop the
/// row, Basic Information's expansion keeps the slot and marks it *Soon*.
///
/// Everything else is wired to something real: the counts come from the same
/// providers the modules use, the photo strip is the pet's actual memories, and
/// the vet card opens a maps search because there is no saved-vet table yet.
class PetProfileScreen extends ConsumerStatefulWidget {
  const PetProfileScreen({this.pet, super.key});

  /// The pet to show. Defaults to the active one, which is what every
  /// "View Profile" pill means.
  final Pet? pet;

  @override
  ConsumerState<PetProfileScreen> createState() => _PetProfileScreenState();
}

enum _ProfileTab {
  overview('Overview', LucideIcons.pawPrint),
  health('Health', LucideIcons.heartPulse),
  records('Records', LucideIcons.fileText),
  reminders('Reminders', LucideIcons.bell),
  files('Files', LucideIcons.folder);

  const _ProfileTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _PetProfileScreenState extends ConsumerState<PetProfileScreen> {
  _ProfileTab _tab = _ProfileTab.overview;
  bool _showAllFacts = false;

  Pet? get _pet => widget.pet ?? ref.watch(activePetProvider);

  Future<void> _edit(Pet pet) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)));
    ref.invalidate(petsListProvider);
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _soon(String what) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  void _openCareNote(Pet pet, int score) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HealthSheet(
        title: 'Care Score · ${careBand(score)}',
        children: [
          const _Point(
            icon: LucideIcons.fileText,
            text:
                'It measures how complete the record is — a name, a breed, a '
                'birthday, a sex, a photo, at least one check and at least one '
                'reminder. Seven things, all of them yours to fill in.',
          ),
          const _Point(
            icon: LucideIcons.heartPulse,
            text:
                'It is not a health score. PawDoc has not examined your pet '
                'and cannot grade them. A full record just means a vet reading '
                'it has more to go on.',
          ),
          _Point(
            icon: LucideIcons.pencil,
            text:
                'Right now it reads $score%. Editing the profile is what '
                'moves it.',
          ),
        ],
      ),
    );
  }

  Future<void> _findVet() async {
    final uri = vetSearchMapsUri();
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    if (pet == null) return const _NoPet();

    final timeline = ref.watch(healthTimelineProvider(pet.id!));
    final items = timeline.value ?? const <TimelineItem>[];
    final reminders =
        ref.watch(remindersForPetProvider(pet.id!)).value ?? const <Reminder>[];
    final memories =
        ref.watch(memoriesListProvider(pet.id!)).value ?? const <Memory>[];

    final score = careScore(
      pet,
      hasCheck: items.any((i) => i.kind == TimelineKind.analysis),
      hasReminder: reminders.isNotEmpty,
    );

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Pet Profile',
          subtitle: 'All about ',
          subtitleTrail: petDisplayName(pet.name),
          actionsWidth: 124,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: HealthActionPill(
                key: const Key('profile_edit'),
                label: 'Edit',
                icon: LucideIcons.pencil,
                dense: true,
                onTap: () => _edit(pet),
              ),
            ),
            HealthCircleButton(
              key: const Key('profile_switch'),
              icon: LucideIcons.ellipsis,
              tooltip: 'Switch pet',
              onTap: () => showPetSwitcher(context, ref),
            ),
          ],
        ),
        onRefresh: () async {
          ref.invalidate(healthTimelineProvider(pet.id!));
          ref.invalidate(remindersForPetProvider(pet.id!));
          ref.invalidate(memoriesListProvider(pet.id!));
          await ref.read(healthTimelineProvider(pet.id!).future);
        },
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(2),
          _ProfileHero(
            pet: pet,
            score: score,
            onPhoto: () => _edit(pet),
            onScore: () => _openCareNote(pet, score),
            onTraits: () => _soon('Personality traits'),
          ),
          gap(11),
          HealthBleed(
            child: _TabRail(
              selected: _tab,
              onSelect: (t) => setState(() => _tab = t),
            ),
          ),
          gap(11),
          ...switch (timeline) {
            AsyncError(:final error) => [
              _Notice(
                icon: LucideIcons.cloudOff,
                title: 'Could not load the record',
                body: friendlyLoadError(error, noun: 'record'),
              ),
            ],
            _ => switch (_tab) {
              _ProfileTab.overview => _overview(pet, items, memories),
              _ProfileTab.health => _health(pet, items, score),
              _ProfileTab.records => _records(pet, items),
              _ProfileTab.reminders => _reminders(pet, reminders),
              _ProfileTab.files => _files(pet, memories),
            },
          },
          gap(8),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Overview — the tab the mockup draws
  // -------------------------------------------------------------------------

  List<Widget> _overview(
    Pet pet,
    List<TimelineItem> items,
    List<Memory> memories,
  ) {
    return [
      _SectionCard(
        icon: LucideIcons.contact,
        title: 'Basic Information',
        padded: false,
        child: Column(
          children: [
            HealthInfoGrid(
              key: const Key('profile_basic_info'),
              cells: _facts(pet, items, expanded: _showAllFacts),
            ),
            InkWell(
              key: const Key('profile_show_more'),
              onTap: () => setState(() => _showAllFacts = !_showAllFacts),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showAllFacts ? 'Show less' : 'Show more',
                      style: TextStyle(
                        color: PawTone.of(context).accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _showAllFacts
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 15,
                      color: PawTone.of(context).accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      gap(9),
      _RecordCards(pet: pet, items: items),
      gap(9),
      _AboutCard(
        pet: pet,
        memories: memories,
        onEdit: () => _edit(pet),
        onAddPhoto: () => _push(MemoriesScreen(pet: pet)),
        onOpenMemories: () => _push(MemoriesScreen(pet: pet)),
      ),
      gap(9),
      _VetCard(onFind: _findVet),
      gap(9),
      _FamilyBanner(onTap: () => _soon('Sharing a pet with your family')),
    ];
  }

  /// Basic Information. Six real facts, then two more and the not-yet slot on
  /// expansion — the mockup's own "Show more" behaviour.
  List<HealthInfoCell> _facts(
    Pet pet,
    List<TimelineItem> items, {
    required bool expanded,
  }) {
    final age = petAgeLabel(pet.birthDate);
    return [
      HealthInfoCell(
        icon: LucideIcons.dog,
        label: 'Breed',
        value: pet.breed?.trim().isNotEmpty == true
            ? pet.breed!.trim()
            : speciesName(pet.species),
      ),
      HealthInfoCell(
        icon: LucideIcons.venusAndMars,
        label: 'Sex',
        value: switch (pet.sex) {
          'male' => 'Male',
          'female' => 'Female',
          _ => 'Not set',
        },
      ),
      HealthInfoCell(
        icon: LucideIcons.calendarDays,
        label: 'Date of birth',
        value: pet.birthDate == null ? 'Not set' : shortDate(pet.birthDate!),
      ),
      HealthInfoCell(
        icon: LucideIcons.cake,
        label: 'Age',
        value: age == null ? 'Not set' : '$age old',
      ),
      HealthInfoCell(
        icon: LucideIcons.scale,
        label: 'Weight',
        value: pet.weightKg == null ? 'Not set' : '${_kg(pet.weightKg!)} kg',
        caption: pet.weightKg == null ? null : 'Trend',
        onTap: () => _push(const WeightTrackingScreen()),
      ),
      HealthInfoCell(
        icon: LucideIcons.pawPrint,
        label: 'Species',
        value: speciesName(pet.species),
      ),
      if (expanded) ...[
        HealthInfoCell(
          icon: LucideIcons.fileText,
          label: 'Records on file',
          value: '${items.length}',
          onTap: () => _push(const HealthHistoryScreen()),
        ),
        HealthInfoCell(
          icon: LucideIcons.camera,
          label: 'Profile photo',
          value: pet.photoKey == null ? 'Not set' : 'Added',
          onTap: () => _edit(pet),
        ),
        // The mockup prints a microchip number, a coat colour, a neutered
        // flag and a blood type. `pets` has no column for any of them, so the
        // row keeps its place and says what it is rather than showing an
        // invented value.
        const HealthInfoCell(
          icon: LucideIcons.scanLine,
          label: 'Microchip & colour',
          value: 'Soon',
          tint: HealthTone.faint,
          caption: 'Not stored yet',
          captionColor: HealthTone.faint,
        ),
        const HealthInfoCell(
          icon: LucideIcons.droplet,
          label: 'Blood type',
          value: 'Soon',
          tint: HealthTone.faint,
          caption: 'Ask your vet',
          captionColor: HealthTone.faint,
        ),
      ],
    ];
  }

  // -------------------------------------------------------------------------
  // The other four tabs — real summaries over the modules' own providers
  // -------------------------------------------------------------------------

  List<Widget> _health(Pet pet, List<TimelineItem> items, int score) {
    final vaccines = items.where((i) => i.eventType == 'vaccination').length;
    final meds = items.where((i) => i.eventType == 'medication').length;
    final weights = items.where((i) => i.eventType == 'weight').length;
    final checks = items.where((i) => i.kind == TimelineKind.analysis).length;
    return [
      _SectionCard(
        icon: LucideIcons.heartPulse,
        title: 'Care Score',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$score% · ${careBand(score)}',
              style: TextStyle(
                color: PawTone.of(context).accent,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'How complete this record is — not a judgement on your pet. '
              'PawDoc has not examined them.',
              style: TextStyle(
                color: HealthTone.dim,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerLeft,
              child: HealthActionPill(
                label: 'What this measures',
                icon: LucideIcons.info,
                onTap: () => _openCareNote(pet, score),
              ),
            ),
          ],
        ),
      ),
      gap(9),
      _JumpRow(
        icon: LucideIcons.syringe,
        title: 'Vaccination Manager',
        subtitle: '$vaccines on file',
        onTap: () => _push(const VaccinationManagerScreen()),
      ),
      gap(7),
      _JumpRow(
        icon: LucideIcons.pill,
        title: 'Medication Tracker',
        subtitle: '$meds on file',
        tint: HealthTone.violet,
        onTap: () => _push(const MedicationTrackerScreen()),
      ),
      gap(7),
      _JumpRow(
        icon: LucideIcons.scale,
        title: 'Weight Tracking',
        subtitle: weights == 0 ? 'Nothing logged yet' : '$weights entries',
        tint: HealthTone.info,
        onTap: () => _push(const WeightTrackingScreen()),
      ),
      gap(7),
      _JumpRow(
        icon: LucideIcons.sparkles,
        title: 'AI Health Checks',
        subtitle: checks == 0 ? 'None yet' : '$checks on the timeline',
        tint: HealthTone.teal,
        onTap: () => _push(const HealthHistoryScreen()),
      ),
      gap(7),
      _JumpRow(
        icon: LucideIcons.chartColumn,
        title: 'Pet Statistics',
        subtitle: 'Everything on the record, counted',
        tint: HealthTone.gold,
        onTap: () => _push(const PetStatisticsScreen()),
      ),
    ];
  }

  List<Widget> _records(Pet pet, List<TimelineItem> items) {
    final shown = items.take(6).toList(growable: false);
    return [
      _SectionCard(
        icon: LucideIcons.fileText,
        title: 'Recent Records',
        action: items.isEmpty ? null : 'View all',
        onAction: () => _push(const HealthHistoryScreen()),
        child: shown.isEmpty
            ? const _EmptyLine(
                key: Key('profile_records_empty'),
                icon: LucideIcons.fileText,
                text:
                    'Nothing filed yet. A vet visit, a weight, a vaccine — '
                    'anything you add to the timeline shows up here.',
              )
            : Column(
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == shown.length - 1 ? 0 : 7,
                      ),
                      child: HealthRecordRow(
                        key: Key('profile_record_$i'),
                        // The type's own glyph, from the same helper the form
                        // and the timeline use — a row of identical document
                        // marks reads as a list of nothing in particular.
                        leading: HealthGlyphDisc(
                          icon: shown[i].kind == TimelineKind.analysis
                              ? LucideIcons.sparkles
                              : healthEventIcon(shown[i].eventType ?? 'custom'),
                          tint: shown[i].kind == TimelineKind.analysis
                              ? HealthTone.teal
                              : HealthTone.info,
                          size: 36,
                        ),
                        title: shown[i].title,
                        subtitle: shortDate(shown[i].date),
                        onTap: shown[i].kind == TimelineKind.analysis
                            ? () => _push(const HealthHistoryScreen())
                            : () => showHealthRecordDetail(
                                context,
                                ref,
                                item: shown[i],
                                pet: pet,
                                onChanged: () => ref.invalidate(
                                  healthTimelineProvider(pet.id!),
                                ),
                              ),
                      ),
                    ),
                ],
              ),
      ),
    ];
  }

  List<Widget> _reminders(Pet pet, List<Reminder> reminders) {
    final upcoming = [...reminders]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return [
      _SectionCard(
        icon: LucideIcons.bell,
        title: 'Reminders',
        action: 'Manage all',
        onAction: () => _push(const RemindersScreen()),
        child: upcoming.isEmpty
            ? const _EmptyLine(
                key: Key('profile_reminders_empty'),
                icon: LucideIcons.bellOff,
                text:
                    'No reminders set. A vaccine date, a monthly tablet, a '
                    'check-up — PawDoc will notify you on the day.',
              )
            : Column(
                children: [
                  for (var i = 0; i < upcoming.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == upcoming.length - 1 ? 0 : 7,
                      ),
                      child: HealthRecordRow(
                        key: Key('profile_reminder_$i'),
                        leading: HealthGlyphDisc(
                          icon: ReminderCategory.of(
                            upcoming[i].reminderType,
                          ).icon,
                          tint: reminderTint(
                            context,
                            ReminderCategory.of(upcoming[i].reminderType),
                          ),
                          size: 36,
                        ),
                        title: upcoming[i].reminderType,
                        subtitle: shortDate(upcoming[i].dueDate),
                        onTap: () => _push(
                          ReminderDetailScreen(
                            reminderId: upcoming[i].id!,
                            initial: upcoming[i],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ];
  }

  List<Widget> _files(Pet pet, List<Memory> memories) {
    return [
      _SectionCard(
        icon: LucideIcons.folder,
        title: 'Photos & Files',
        action: 'Open journal',
        onAction: () => _push(MemoriesScreen(pet: pet)),
        child: memories.isEmpty
            ? const _EmptyLine(
                key: Key('profile_files_empty'),
                icon: LucideIcons.image,
                text:
                    'No photos yet. Anything you save to the journal appears '
                    'here.',
              )
            : GridView.count(
                key: const Key('profile_files_grid'),
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                children: [
                  for (final m in memories.take(9))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MemoryPhoto(storageKey: m.storageKey),
                    ),
                ],
              ),
      ),
    ];
  }
}

String _kg(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.pet,
    required this.score,
    required this.onPhoto,
    required this.onScore,
    required this.onTraits,
  });

  final Pet pet;
  final int score;
  final VoidCallback onPhoto;
  final VoidCallback onScore;
  final VoidCallback onTraits;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final age = petAgeLabel(pet.birthDate);
    return HomeCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PortraitWithCamera(pet: pet, onTap: onPhoto),
              const SizedBox(width: 11),
              // Weighted shares, not two bare Flexibles: an even split squeezes
              // a name that had room, and a fixed score box overflows the row
              // under the em-square test font.
              Flexible(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            petDisplayName(pet.name),
                            key: const Key('profile_name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          LucideIcons.circleCheck,
                          size: 15,
                          color: t.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    _MetaLine(
                      text: [
                        if (pet.breed?.trim().isNotEmpty == true)
                          pet.breed!.trim()
                        else
                          speciesName(pet.species),
                        if (pet.sex == 'male')
                          'Male'
                        else if (pet.sex == 'female')
                          'Female',
                      ].join(' · '),
                    ),
                    if (age != null)
                      _MetaLine(
                        text: pet.birthDate == null
                            ? '$age old'
                            : '$age old (${shortDate(pet.birthDate!)})',
                      ),
                    if (pet.weightKg != null)
                      _MetaLine(text: '${_kg(pet.weightKg!)} kg'),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                flex: 4,
                child: _CareScoreBox(score: score, onTap: onScore),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The mockup tags the pet "Friendly · Playful · Good with kids".
          // There is no column for a personality trait, so the row keeps its
          // place as an invitation rather than showing three invented ones.
          Align(
            alignment: Alignment.centerLeft,
            child: HealthActionPill(
              key: const Key('profile_traits'),
              label: 'Add personality traits · Soon',
              icon: LucideIcons.smile,
              color: HealthTone.muted,
              onTap: onTraits,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 1),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: HealthTone.muted,
        fontSize: 12,
        height: 1.3,
      ),
    ),
  );
}

class _PortraitWithCamera extends StatelessWidget {
  const _PortraitWithCamera({required this.pet, required this.onTap});

  final Pet pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Semantics(
      button: true,
      label: 'Change photo',
      child: ExcludeSemantics(
        child: InkWell(
          key: const Key('profile_photo'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: t.accent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: t.accent.withValues(alpha: 0.30),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Center(
                      child: ClipOval(
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: PetPortrait(
                            pet: pet,
                            size: 80,
                            livingAvatar: pet.photoKey == null
                                ? null
                                : LivingPetAvatar(
                                    species: pet.species,
                                    size: 80,
                                    seed: pet.id,
                                    photoKey: pet.photoKey,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 1,
                  bottom: 4,
                  child: Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.accent,
                      border: const Border.fromBorderSide(
                        BorderSide(color: Color(0xFF0A0F0B), width: 2),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.camera,
                      size: 14,
                      color: Color(0xFF06110A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// **D-2.** The mockup's "Health Score · 92 · Excellent".
class _CareScoreBox extends StatelessWidget {
  const _CareScoreBox({required this.score, required this.onTap});

  final int score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return InkWell(
      key: const Key('profile_care_score'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 9, 7, 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        // Stacked, not glyph-beside-column. The mockup's box has room for
        // "Health Score / 92 / Excellent" beside its shield; at readable type
        // in a 94dp share, the same arrangement clipped the label to "Car…"
        // and the band to "Jus…" on the device. Giving the label the box's
        // full width fits both, and the shield keeps its place on the value
        // row where it still reads as the mark on a score.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Care Score',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HealthTone.muted,
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 12,
                  color: Colors.white54,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(LucideIcons.shieldCheck, size: 17, color: t.accent),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$score',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                careBand(score),
                maxLines: 1,
                style: TextStyle(
                  color: t.accent,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab rail
// ---------------------------------------------------------------------------

class _TabRail extends StatelessWidget {
  const _TabRail({required this.selected, required this.onSelect});

  final _ProfileTab selected;
  final ValueChanged<_ProfileTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Padding(
      padding: kRecordPadding,
      child: HomeCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          children: [
            for (final tab in _ProfileTab.values)
              Expanded(
                child: InkWell(
                  key: Key('profile_tab_${tab.name}'),
                  onTap: () => onSelect(tab),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: 17,
                          color: tab == selected ? t.accent : Colors.white60,
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            style: TextStyle(
                              color: tab == selected
                                  ? t.accent
                                  : HealthTone.muted,
                              fontSize: 10.5,
                              fontWeight: tab == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: 2,
                          width: 26,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: tab == selected
                                ? t.accent
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The four record cards
// ---------------------------------------------------------------------------

/// The mockup's `Vaccinations 12/12 Completed · Up to date`,
/// `Medications 3 Active`, `Allergies 2 Known` and `Conditions 0 None · Great!`
///
/// Two of those are diagnoses and one is an all-clear. All four cards keep
/// their position, glyph and density, and every number here is counted off the
/// timeline the owner filled in.
class _RecordCards extends StatelessWidget {
  const _RecordCards({required this.pet, required this.items});

  final Pet pet;
  final List<TimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final vaccines = items.where((i) => i.eventType == 'vaccination').length;
    final meds = items.where((i) => i.eventType == 'medication').length;
    final visits = items.where((i) => i.eventType == 'vet_visit').length;
    final notes = items
        .where((i) => i.eventType == 'note' || i.eventType == 'lab_result')
        .length;

    void push(Widget s) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

    // IntrinsicHeight, as `HealthStatTiles` does: a stretched Row inside the
    // scroll view's unbounded Column hands its children infinite height and
    // the constraint assertion fires. Every text in a card is single-line or
    // in a fixed slot, so the intrinsic pass is cheap and exact.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _RecordCard(
              key: const Key('profile_card_vaccines'),
              icon: LucideIcons.syringe,
              label: 'Vaccinations',
              value: '$vaccines',
              caption: vaccines == 0 ? 'None filed' : 'On file',
              action: 'Open',
              tint: t.accent,
              onTap: () => push(const VaccinationManagerScreen()),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _RecordCard(
              key: const Key('profile_card_meds'),
              icon: LucideIcons.pill,
              label: 'Medications',
              value: '$meds',
              caption: meds == 0 ? 'None filed' : 'On file',
              action: 'Schedule',
              tint: HealthTone.violet,
              onTap: () => push(const MedicationTrackerScreen()),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _RecordCard(
              key: const Key('profile_card_visits'),
              icon: LucideIcons.stethoscope,
              label: 'Vet visits',
              value: '$visits',
              caption: visits == 0 ? 'None filed' : 'On file',
              action: 'Timeline',
              tint: HealthTone.info,
              onTap: () => push(const HealthHistoryScreen()),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _RecordCard(
              key: const Key('profile_card_notes'),
              icon: LucideIcons.clipboardList,
              label: 'Notes & labs',
              value: '$notes',
              caption: notes == 0 ? 'None filed' : 'On file',
              action: 'Timeline',
              tint: HealthTone.teal,
              onTap: () => push(const HealthHistoryScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.action,
    required this.tint,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final String action;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(8, 9, 6, 8),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(height: 6),
          // A two-line slot, explicit: four cards across 393 points leave a
          // ~78dp label, and "Vaccinations" needs the second line. Inside a
          // stretched Row a Text reports its unwrapped height, so the slot has
          // to be a SizedBox or the second line is silently clipped.
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HealthTone.faint,
              fontSize: 9.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Flexible(
                child: Text(
                  action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tint,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 11, color: tint),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About
// ---------------------------------------------------------------------------

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.pet,
    required this.memories,
    required this.onEdit,
    required this.onAddPhoto,
    required this.onOpenMemories,
  });

  final Pet pet;
  final List<Memory> memories;
  final VoidCallback onEdit;
  final VoidCallback onAddPhoto;
  final VoidCallback onOpenMemories;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final notes = pet.medicalNotes?.trim();
    final has = notes != null && notes.isNotEmpty;
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
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
                    Text(
                      'About ${petDisplayName(pet.name)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      has
                          ? notes
                          : 'Nothing written down yet. Allergies, a chronic '
                                'condition, what they are like at the vet — it '
                                'goes in the vet report.',
                      style: const TextStyle(
                        color: HealthTone.dim,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                    if (has) ...[
                      const SizedBox(height: 6),
                      // V-22: a vet reading this must be able to tell what a
                      // model produced from what the owner typed.
                      const Text(
                        'Entered by the owner. PawDoc did not review it.',
                        style: TextStyle(
                          color: HealthTone.faint,
                          fontSize: 10,
                          height: 1.3,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.dog,
                size: 40,
                color: t.accent.withValues(alpha: 0.20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 78,
            child: ListView(
              key: const Key('profile_photo_strip'),
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in memories.take(6))
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: GestureDetector(
                      onTap: onOpenMemories,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 78,
                          height: 78,
                          child: MemoryPhoto(storageKey: m.storageKey),
                        ),
                      ),
                    ),
                  ),
                _AddPhotoTile(onTap: onAddPhoto),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: HealthActionPill(
              key: const Key('profile_edit_notes'),
              label: has ? 'Edit these notes' : 'Add notes',
              icon: LucideIcons.pencil,
              onTap: onEdit,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return InkWell(
      key: const Key('profile_add_photo'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: t.accent.withValues(alpha: 0.05),
          border: Border.all(color: t.accent.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.camera, size: 19, color: t.accent),
            const SizedBox(height: 5),
            Text(
              'Add Photo',
              style: TextStyle(
                color: t.accent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vet + family
// ---------------------------------------------------------------------------

/// The mockup names a veterinarian, a clinic and a phone number. There is no
/// saved-vet table, and inventing one would put a fake practice on a health
/// record. The card keeps its shape and offers the thing the app can actually
/// do: find a real clinic nearby.
class _VetCard extends StatelessWidget {
  const _VetCard({required this.onFind});

  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.10),
              border: Border.all(color: t.accent.withValues(alpha: 0.30)),
            ),
            child: Icon(LucideIcons.stethoscope, size: 22, color: t.accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your veterinarian',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Saving a practice is coming. For now, PawDoc can '
                  'point you at clinics nearby.',
                  style: TextStyle(
                    color: HealthTone.dim,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          HealthActionPill(
            key: const Key('profile_find_vet'),
            label: 'Find',
            icon: LucideIcons.mapPin,
            onTap: onFind,
          ),
        ],
      ),
    );
  }
}

class _FamilyBanner extends StatelessWidget {
  const _FamilyBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Material(
      color: t.accent.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('profile_family'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.accent.withValues(alpha: 0.40)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.accent.withValues(alpha: 0.65)),
                ),
                child: Icon(LucideIcons.plus, size: 16, color: t.accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Family Member · Soon',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.accent,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Share this profile with the rest of the house',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: HealthTone.dim,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.users,
                size: 19,
                color: t.accent.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 5),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.action,
    this.onAction,
    this.padded = true,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading: Icon(icon, size: 17, color: t.accent),
            title: title,
            actionLabel: action,
            onAction: onAction,
          ),
          SizedBox(height: padded ? 9 : 6),
          child,
        ],
      ),
    );
  }
}

class _JumpRow extends StatelessWidget {
  const _JumpRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = tint ?? PawTone.of(context).accent;
    return HealthRecordRow(
      background: HealthTone.card,
      padding: const EdgeInsets.all(11),
      leading: HealthGlyphDisc(icon: icon, tint: c, size: 38),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
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
          child: Text(
            text,
            style: const TextStyle(
              color: HealthTone.dim,
              fontSize: 12,
              height: 1.4,
            ),
          ),
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
            child: Text(
              text,
              style: const TextStyle(
                color: HealthTone.dim,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
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
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 26, color: HealthTone.muted),
          const SizedBox(height: 11),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HealthTone.dim,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
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
          title: 'Pet Profile',
          subtitle: 'All about ',
          subtitleTrail: 'your pet',
        ),
        bottomNavigationBar: const PawNavBar(detached: true),
        body: Padding(
          padding: kRecordPadding,
          child: Center(
            child: HealthAddCard(
              title: 'Add a pet to start a profile',
              subtitle: 'Everything on this page lives per pet.',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PetFormScreen())),
            ),
          ),
        ),
      ),
    );
  }
}
