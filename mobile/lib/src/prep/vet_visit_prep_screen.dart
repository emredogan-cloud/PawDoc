import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../analytics/analytics.dart';
import '../auth/supabase_providers.dart';
import '../core/dates.dart';
import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../emergency/emergency_help_screen.dart';
import '../export/health_report.dart';
import '../health/health_event.dart';
import '../health/health_events_repository.dart';
import '../health/health_sections.dart';
import '../health/history_timeline_screen.dart';
import '../home/home_sections.dart';
import '../pets/active_pet.dart';
import '../pets/pet.dart';
import '../pets/pet_switcher.dart';
import '../reminders/reminder.dart';
import '../reminders/reminder_detail_screen.dart';
import '../reminders/reminder_form_screen.dart';
import '../reminders/reminders_repository.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'vet_visit_prep.dart';

/// `prepare_for_vet_visit`, rebuilt against its reference.
///
/// The Vet Visit Prep Pack is the record product's centrepiece: it answers the
/// five questions every owner fails in the exam room — when did it start, is
/// it better or worse, what has been logged, which vaccines and medications,
/// what did I want to ask. **Zero AI judgement.** It organises what the owner
/// recorded, which is exactly why a vet can use it.
///
/// The reference gives that idea a shape it never had — a six-stop progress
/// rail, reason chips, a symptom timeline, a bring-list and a question editor —
/// and the rebuild takes all of it. Three things did not survive:
///
/// | Reference | Shipped | Why |
/// |---|---|---|
/// | **Severity** — a signal-strength meter reading "Moderate" | **How it's changing** — [SymptomChange] | a bar meter beside a symptom reads as an assessment, and the only assessment here is the owner's. *Is it better or worse* is what a vet actually asks, and what this pack was built to answer |
/// | "Upcoming Visit · May 24, 2026 · 10:30 AM" | the next vet-visit **reminder**, date only | reminders store a calendar date and no time; an invented 10:30 is a time somebody might rely on |
/// | "These help your vet make accurate decisions." | "The things vets most often ask an owner to bring." | a claim about clinical accuracy PawDoc cannot make |
///
/// Everything an owner types is kept **on this device**, per pet — see
/// [VisitPrepDraft]. The screen says so.
class VetVisitPrepScreen extends ConsumerStatefulWidget {
  const VetVisitPrepScreen({super.key, required this.pet});

  final Pet pet;

  @override
  ConsumerState<VetVisitPrepScreen> createState() => _VetVisitPrepScreenState();
}

/// Recent checks for the prep pack (action + observation + date; RLS-scoped).
final _recentChecksProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, petId) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('analyses')
      .select('action, observation, created_at')
      .eq('pet_id', petId)
      .order('created_at', ascending: false)
      .limit(5);
  return (rows as List).cast<Map<String, dynamic>>();
});

final _eventsProvider = FutureProvider.autoDispose
    .family<List<HealthEvent>, String>((ref, petId) {
  return ref.watch(healthEventsRepositoryProvider).listForPet(petId);
});

class _VetVisitPrepScreenState extends ConsumerState<VetVisitPrepScreen> {
  VisitPrepDraft _draft = const VisitPrepDraft();

  /// Which pet [_draft] belongs to. Switching pets swaps the whole draft, and
  /// writing one pet's answers under another's key is the kind of bug an
  /// owner only finds in the exam room.
  String? _draftPetId;

  final _other = TextEditingController();
  final _notes = TextEditingController();
  final _questions = <TextEditingController>[];

  @override
  void dispose() {
    _other.dispose();
    _notes.dispose();
    for (final c in _questions) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load(String petId) async {
    final draft = await VisitPrepDraft.load(petId);
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _draftPetId = petId;
      _other.text = draft.otherReason;
      _notes.text = draft.notes;
      for (final c in _questions) {
        c.dispose();
      }
      _questions
        ..clear()
        ..addAll([
          for (final q in draft.questions) TextEditingController(text: q),
        ]);
      if (_questions.isEmpty) _questions.add(TextEditingController());
    });
  }

  /// Every mutation goes through here so nothing can change on screen without
  /// being written down — a draft that survives the back button only
  /// sometimes is worse than one that never did.
  void _update(VisitPrepDraft next) {
    final petId = _draftPetId;
    if (petId == null) return;
    setState(() => _draft = next);
    VisitPrepDraft.save(petId, next);
  }

  void _syncQuestions() {
    _update(_draft.copyWith(
        questions: [for (final c in _questions) c.text]));
  }

  // -------------------------------------------------------------------------
  // Data
  // -------------------------------------------------------------------------

  /// How much the record holds for this pet — the third stop of the rail is
  /// filled by what has been logged over time, not by anything typed here.
  int _recordItems(List<Map<String, dynamic>> checks, List<HealthEvent> events) =>
      checks.length + events.length;

  Reminder? _nextVisit(List<Reminder> reminders) {
    final upcoming = reminders
        .where((r) =>
            ReminderCategory.of(r.reminderType) == ReminderCategory.vetVisit &&
            !r.isPastDue)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.startedOn ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) _update(_draft.copyWith(startedOn: picked));
  }

  void _pickFrequency() => _pickEnum<SymptomFrequency>(
        title: 'How often does it happen?',
        values: SymptomFrequency.values,
        label: (v) => v.label,
        selected: _draft.frequency,
        onPick: (v) => _update(_draft.copyWith(frequency: v)),
      );

  void _pickChange() => _pickEnum<SymptomChange>(
        title: 'How is it changing?',
        values: SymptomChange.values,
        label: (v) => v.label,
        selected: _draft.change,
        onPick: (v) => _update(_draft.copyWith(change: v)),
      );

  void _pickEnum<T>({
    required String title,
    required List<T> values,
    required String Function(T) label,
    required T? selected,
    required ValueChanged<T> onPick,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: title,
        children: [
          for (final v in values)
            HealthRecordRow(
              key: Key('prep_option_${label(v)}'),
              leading: HealthGlyphDisc(
                  icon: v == selected
                      ? LucideIcons.circleCheck
                      : LucideIcons.circle,
                  tint: PawTone.of(context).accent),
              title: label(v),
              chevron: false,
              onTap: () {
                Navigator.pop(sheetContext);
                onPick(v);
              },
            ),
        ],
      ),
    );
  }

  void _showTips() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const HealthSheet(
        title: 'What to write here',
        scrollable: true,
        children: [
          HealthDetailRow(
            icon: LucideIcons.calendar,
            label: 'When it started',
            value: 'A rough date is fine — "about two weeks ago" is far more '
                'use to a vet than nothing at all.',
          ),
          HealthDetailRow(
            icon: LucideIcons.repeat,
            label: 'How often',
            value: 'Once, now and then, most days, all the time. Count it if '
                'you can: "three times since Friday".',
          ),
          HealthDetailRow(
            icon: LucideIcons.trendingUp,
            label: 'How it is changing',
            value: 'Better, worse, the same, or coming and going. This is the '
                'question vets ask most and owners answer least well.',
          ),
          HealthDetailRow(
            icon: LucideIcons.notebookPen,
            label: 'In your own words',
            value: 'What you saw, when, and what was different about it. '
                'Describe it — you do not have to name it.',
          ),
        ],
      ),
    );
  }

  void _showQuestionExamples() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Questions owners forget to ask',
        scrollable: true,
        children: [
          for (final q in kQuestionExamples)
            HealthRecordRow(
              key: Key('prep_example_${kQuestionExamples.indexOf(q)}'),
              leading: HealthGlyphDisc(
                  icon: LucideIcons.plus, tint: PawTone.of(context).accent),
              title: q,
              chevron: false,
              onTap: () {
                Navigator.pop(sheetContext);
                _addQuestion(q);
              },
            ),
        ],
      ),
    );
  }

  void _addQuestion([String? text]) {
    // Reuse a trailing blank row rather than stacking empties under it.
    if (text != null &&
        _questions.isNotEmpty &&
        _questions.last.text.trim().isEmpty) {
      _questions.last.text = text;
    } else {
      _questions.add(TextEditingController(text: text ?? ''));
    }
    _syncQuestions();
  }

  void _removeQuestion(int index) {
    final removed = _questions.removeAt(index);
    removed.dispose();
    if (_questions.isEmpty) _questions.add(TextEditingController());
    _syncQuestions();
  }

  String _buildPack(Pet pet, Reminder? visit) {
    final checks =
        ref.read(_recentChecksProvider(pet.id!)).asData?.value ?? const [];
    final events = ref.read(_eventsProvider(pet.id!)).asData?.value ?? const [];
    return buildVetVisitPrepPack(
      pet: pet,
      recentAnalyses: checks,
      events: events,
      ownerQuestions: _draft.liveQuestions,
      ownerAnswers: visitPrepAnswerLines(_draft),
      visitOn: visit?.dueDate,
    );
  }

  Future<void> _review(Pet pet, Reminder? visit) async {
    final pack = _buildPack(pet, visit);
    _update(_draft.copyWith(reviewedAt: DateTime.now()));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _SummarySheet(
        pack: pack,
        onShare: () async {
          Navigator.pop(sheetContext);
          await _share(pet, pack);
        },
      ),
    );
  }

  Future<void> _share(Pet pet, String pack) async {
    await Analytics.healthReportExported();
    await SharePlus.instance.share(
        ShareParams(text: pack, subject: 'Vet visit prep — ${pet.name}'));
  }

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // The header card's chevron opens the shared switcher, which repoints
    // `activePetProvider` — so the screen follows the app's active pet like
    // every other record surface, and only falls back to the pet it was
    // pushed with before the list has loaded.
    final pet = ref.watch(activePetProvider) ?? widget.pet;
    if (_draftPetId != pet.id) {
      // Not `setState` — this runs during build. The draft arrives on the
      // next frame; until it does the fields render empty rather than showing
      // the previous pet's answers.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _load(pet.id!));
    }
    final loaded = _draftPetId == pet.id;
    final checks = ref.watch(_recentChecksProvider(pet.id!));
    final events = ref.watch(_eventsProvider(pet.id!));
    final reminders = ref.watch(remindersForPetProvider(pet.id!));
    final visit = _nextVisit(reminders.asData?.value ?? const []);
    final recordItems = _recordItems(
        checks.asData?.value ?? const [], events.asData?.value ?? const []);
    final done = completedPrepSteps(_draft, recordItems: recordItems);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Prepare for Vet Visit',
          icon: LucideIcons.stethoscope,
          subtitle: 'Walk in with the story already written down.',
          actions: [
            HealthCircleButton(
              key: const Key('prep_help'),
              icon: LucideIcons.circleHelp,
              tooltip: 'What to write here',
              onTap: _showTips,
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        footer: HealthPrimaryCta(
          key: const Key('prep_review_summary'),
          label: 'Review summary',
          icon: LucideIcons.fileText,
          trailingIcon: LucideIcons.chevronRight,
          onTap: () => _review(pet, visit),
        ),
        children: [
          gap(4),
          PetModuleHeaderCard(
            portrait: PetPortrait(
              pet: pet,
              size: 54,
              livingAvatar: pet.photoKey == null
                  ? null
                  : LivingPetAvatar(
                      species: pet.species,
                      size: 54,
                      seed: pet.id,
                      photoKey: pet.photoKey,
                    ),
            ),
            name: petDisplayName(pet.name),
            meta: petMetaLine(pet),
            onSwitch: () => showPetSwitcher(context, ref),
            trailing: _UpcomingVisit(
              visit: visit,
              loading: reminders.isLoading,
              onOpen: visit == null
                  ? () => _addVisitReminder(pet)
                  : () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ReminderDetailScreen(
                            reminderId: visit.id!, initial: visit),
                      )),
            ),
          ),
          gap(11),
          _ProgressCard(done: done, total: PrepStep.values.length),
          gap(11),
          _ReasonCard(
            selected: _draft.reasons,
            otherController: _other,
            onToggle: (id) {
              final next = {..._draft.reasons};
              if (!next.remove(id)) next.add(id);
              _update(_draft.copyWith(reasons: next));
            },
            onOtherChanged: (v) => _update(_draft.copyWith(otherReason: v)),
          ),
          gap(11),
          _SymptomCard(
            draft: _draft,
            notes: _notes,
            onPickDate: _pickStartDate,
            onPickFrequency: _pickFrequency,
            onPickChange: _pickChange,
            onNotesChanged: (v) => _update(_draft.copyWith(notes: v)),
            onTips: _showTips,
          ),
          gap(11),
          _RecordCard(
            checks: checks.asData?.value.length,
            events: events.asData?.value ?? const [],
            loading: checks.isLoading || events.isLoading,
            onOpen: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const HealthHistoryScreen())),
          ),
          gap(11),
          _BringCard(
            selected: _draft.bring,
            onToggle: (id) {
              final next = {..._draft.bring};
              if (!next.remove(id)) next.add(id);
              _update(_draft.copyWith(bring: next));
            },
          ),
          gap(11),
          _QuestionsCard(
            controllers: _questions,
            enabled: loaded,
            onChanged: _syncQuestions,
            onAdd: _addQuestion,
            onRemove: _removeQuestion,
            onExamples: _showQuestionExamples,
          ),
          gap(11),
          const _UrgentStrip(),
          gap(11),
          HealthPrivacyCard(
            title: 'Saved on this device',
            body: 'Your reasons, notes and questions for this visit are kept '
                'on this phone, against this pet — not on PawDoc’s servers. '
                'They travel when you share the pack, and nowhere else.',
            onTap: _showStorageNote,
          ),
          gap(16),
        ],
      ),
    );
  }

  void _showStorageNote() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const HealthSheet(
        title: 'Where this draft lives',
        scrollable: true,
        children: [
          HealthDetailRow(
            icon: LucideIcons.smartphone,
            label: 'On this phone only',
            value: 'There is no visit-prep table on the server yet, so the '
                'draft is kept in this app’s own storage, keyed to the pet.',
          ),
          HealthDetailRow(
            icon: LucideIcons.share2,
            label: 'It moves when you share it',
            value: 'Sharing the pack hands the text to whichever app you '
                'pick. Nothing is uploaded by PawDoc.',
          ),
          HealthDetailRow(
            icon: LucideIcons.triangleAlert,
            label: 'A new phone starts blank',
            value: 'Reinstalling the app or moving to another device leaves '
                'the draft behind. The record itself is on the server and '
                'travels with your account.',
          ),
        ],
      ),
    );
  }

  Future<void> _addVisitReminder(Pet pet) async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => ReminderFormScreen(petId: pet.id!, petName: pet.name),
    ));
    ref.invalidate(remindersForPetProvider(pet.id!));
  }
}

// ---------------------------------------------------------------------------
// The pet card's right-hand block
// ---------------------------------------------------------------------------

class _UpcomingVisit extends StatelessWidget {
  const _UpcomingVisit({
    required this.visit,
    required this.loading,
    required this.onOpen,
  });

  final Reminder? visit;
  final bool loading;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    if (loading) {
      return const SizedBox(
        width: 108,
        child: Text('Checking your reminders…',
            style: TextStyle(color: HealthTone.faint, fontSize: 10.5)),
      );
    }
    if (visit == null) {
      return SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No visit booked',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: HealthTone.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            HealthActionPill(
                key: const Key('prep_add_visit'),
                label: 'Add a reminder',
                icon: LucideIcons.calendarPlus,
                onTap: onOpen),
          ],
        ),
      );
    }
    final days = visit!.daysUntilDue;
    return SizedBox(
      width: 116,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Upcoming visit',
              style: TextStyle(
                  color: t.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(shortDate(visit!.dueDate),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600)),
          Text(
              days == 0
                  ? 'Today'
                  : days == 1
                      ? 'Tomorrow'
                      : 'In $days days',
              style: const TextStyle(
                  color: HealthTone.muted, fontSize: 10.5, height: 1.3)),
          const SizedBox(height: 4),
          HealthActionPill(
              key: const Key('prep_open_visit'),
              label: 'Edit',
              icon: LucideIcons.pencil,
              onTap: onOpen),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress
// ---------------------------------------------------------------------------

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.done, required this.total});

  final Set<PrepStep> done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    // The highlight sits on the first thing still to do, so the rail always
    // points somewhere useful; when everything is done it rests on Summary.
    final next = PrepStep.values.firstWhere((s) => !done.contains(s),
        orElse: () => PrepStep.summary);
    return HomeCard(
      key: const Key('prep_progress'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Your preparation',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            height: 1.2,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Nothing here is required — each part just makes the '
                        'pack more use.',
                        style: TextStyle(
                            color: HealthTone.dim,
                            fontSize: 11,
                            height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${done.length} / $total',
                  style: TextStyle(
                      color: t.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          HealthStepRail(
            steps: [for (final s in PrepStep.values) s.label],
            current: next.index,
            completed: {for (final s in done) s.index},
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1 · reasons
// ---------------------------------------------------------------------------

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({
    required this.selected,
    required this.otherController,
    required this.onToggle,
    required this.onOtherChanged,
  });

  final Set<String> selected;
  final TextEditingController otherController;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onOtherChanged;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('prep_reasons'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HealthNumberedHead(
            number: 1,
            title: 'Why are you visiting?',
            subtitle: 'Select all that apply. Nothing is read back to you — '
                'these are notes for the vet.',
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in kVisitReasons)
                _ReasonChip(
                  reason: r,
                  selected: selected.contains(r.id),
                  onTap: () => onToggle(r.id),
                ),
            ],
          ),
          if (selected.contains('other')) ...[
            const SizedBox(height: 11),
            HealthCountedField(
              fieldKey: const Key('prep_other_reason'),
              controller: otherController,
              maxLength: 60,
              hint: 'e.g. second opinion on a dental quote',
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final VisitReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: reason.label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? t.accent.withValues(alpha: 0.10) : HealthTone.raised,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            key: Key('prep_reason_${reason.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: selected
                        ? t.accent.withValues(alpha: 0.70)
                        : Colors.white.withValues(alpha: 0.09)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(reason.icon,
                      size: 15,
                      color: selected ? t.accent : HealthTone.muted),
                  const SizedBox(width: 7),
                  Text(reason.label,
                      style: TextStyle(
                          color: selected ? t.accent : Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
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
// 2 · the symptom timeline
// ---------------------------------------------------------------------------

class _SymptomCard extends StatelessWidget {
  const _SymptomCard({
    required this.draft,
    required this.notes,
    required this.onPickDate,
    required this.onPickFrequency,
    required this.onPickChange,
    required this.onNotesChanged,
    required this.onTips,
  });

  final VisitPrepDraft draft;
  final TextEditingController notes;
  final VoidCallback onPickDate;
  final VoidCallback onPickFrequency;
  final VoidCallback onPickChange;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onTips;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('prep_symptoms'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthNumberedHead(
            number: 2,
            title: 'What you have noticed',
            suffix: '(Optional)',
            subtitle: 'When it started, and which way it is heading.',
            trailing: HealthActionPill(
                label: 'Tips', icon: LucideIcons.lightbulb, onTap: onTips),
          ),
          const SizedBox(height: 11),
          _PickerRow(
            fieldKey: const Key('prep_started_on'),
            icon: LucideIcons.calendar,
            label: 'Started',
            value: draft.startedOn == null
                ? 'Not set'
                : shortDate(draft.startedOn!),
            set: draft.startedOn != null,
            onTap: onPickDate,
          ),
          _PickerRow(
            fieldKey: const Key('prep_frequency'),
            icon: LucideIcons.repeat,
            label: 'How often',
            value: draft.frequency?.label ?? 'Not set',
            set: draft.frequency != null,
            onTap: onPickFrequency,
          ),
          _PickerRow(
            fieldKey: const Key('prep_change'),
            icon: LucideIcons.trendingUp,
            label: 'How it is changing',
            value: draft.change?.label ?? 'Not set',
            set: draft.change != null,
            onTap: onPickChange,
          ),
          const SizedBox(height: 11),
          HealthCountedField(
            fieldKey: const Key('prep_notes'),
            controller: notes,
            maxLength: 500,
            minLines: 3,
            maxLines: 6,
            hint: 'e.g. coughs mostly in the morning, quieter than usual on '
                'walks',
          ),
          const SizedBox(height: 7),
          const Text(
            'Describe what you saw. You do not have to name it — that is the '
            'vet’s job, and PawDoc will not guess at it either.',
            style:
                TextStyle(color: HealthTone.faint, fontSize: 10.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.fieldKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.set,
    required this.onTap,
  });

  final Key fieldKey;
  final IconData icon;
  final String label;
  final String value;
  final bool set;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: fieldKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 11),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: set ? PawTone.of(context).accent : HealthTone.muted),
            const SizedBox(width: 10),
            Flexible(
              flex: 4,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Flexible(
              flex: 6,
              child: Text(value,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: set
                          ? PawTone.of(context).accent
                          : HealthTone.faint,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(LucideIcons.chevronDown,
                  size: 15, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3 · what the record already holds
// ---------------------------------------------------------------------------

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.checks,
    required this.events,
    required this.loading,
    required this.onOpen,
  });

  final int? checks;
  final List<HealthEvent> events;
  final bool loading;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final vaccines =
        events.where((e) => e.eventType == 'vaccination').length;
    final meds = events.where((e) => e.eventType == 'medication').length;
    final weights = events.where((e) => e.eventType == 'weight').length;
    final other = events.length - vaccines - meds - weights;
    final empty = !loading && (checks ?? 0) == 0 && events.isEmpty;
    return HomeCard(
      key: const Key('prep_record'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthNumberedHead(
            number: 3,
            title: 'What PawDoc attaches',
            subtitle: 'Straight from the record — you do not type this part.',
            trailing: HealthActionPill(
                key: const Key('prep_open_timeline'),
                label: 'Open',
                icon: LucideIcons.history,
                onTap: onOpen),
          ),
          const SizedBox(height: 11),
          if (loading)
            const Text('Reading the record…',
                style: TextStyle(color: HealthTone.faint, fontSize: 11.5))
          else if (empty)
            const Text(
              'Nothing is filed for this pet yet. The pack still works — it '
              'will carry what you wrote above.',
              style:
                  TextStyle(color: HealthTone.dim, fontSize: 11.5, height: 1.4),
            )
          else
            HealthInfoGrid(cells: [
              HealthInfoCell(
                  icon: LucideIcons.sparkles,
                  label: 'Recent checks',
                  value: '${checks ?? 0}'),
              HealthInfoCell(
                  icon: LucideIcons.syringe,
                  label: 'Vaccinations',
                  value: '$vaccines'),
              HealthInfoCell(
                  icon: LucideIcons.pill,
                  label: 'Medications',
                  value: '$meds'),
              HealthInfoCell(
                  icon: LucideIcons.scale,
                  label: 'Weight entries',
                  value: '$weights'),
              if (other > 0)
                HealthInfoCell(
                    icon: LucideIcons.notebookPen,
                    label: 'Other events',
                    value: '$other'),
            ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · what to bring
// ---------------------------------------------------------------------------

class _BringCard extends StatelessWidget {
  const _BringCard({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('prep_bring'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HealthNumberedHead(
            number: 4,
            title: 'Don’t forget to bring',
            subtitle: 'The things vets most often ask an owner to bring. '
                'Tick them off as you pack.',
          ),
          const SizedBox(height: 11),
          // The reference sets five tiles across a 393dp screen, which is 68dp
          // for a two-line title and a two-line hint. They stack instead, and
          // become a real checklist rather than a picture of one.
          for (var i = 0; i < kBringItems.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _BringRow(
              item: kBringItems[i],
              checked: selected.contains(kBringItems[i].id),
              onTap: () => onToggle(kBringItems[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _BringRow extends StatelessWidget {
  const _BringRow({
    required this.item,
    required this.checked,
    required this.onTap,
  });

  final BringItem item;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Semantics(
      button: true,
      checked: checked,
      label: item.label,
      child: ExcludeSemantics(
        child: Material(
          color: checked ? t.accent.withValues(alpha: 0.07) : HealthTone.raised,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: Key('prep_bring_${item.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: checked
                        ? t.accent.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.07)),
              ),
              child: Row(
                children: [
                  Icon(item.icon,
                      size: 19,
                      color: checked ? t.accent : HealthTone.muted),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.label,
                            style: TextStyle(
                                color: checked ? t.accent : Colors.white,
                                fontSize: 12.5,
                                height: 1.2,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(item.hint,
                            style: const TextStyle(
                                color: HealthTone.dim,
                                fontSize: 10.5,
                                height: 1.3)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                      checked
                          ? LucideIcons.circleCheckBig
                          : LucideIcons.circle,
                      size: 19,
                      color: checked ? t.accent : Colors.white24),
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
// 5 · questions
// ---------------------------------------------------------------------------

class _QuestionsCard extends StatelessWidget {
  const _QuestionsCard({
    required this.controllers,
    required this.enabled,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onExamples,
  });

  final List<TextEditingController> controllers;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onExamples;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('prep_questions'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthNumberedHead(
            number: 5,
            title: 'Questions for your vet',
            subtitle: 'Written down now, so they are not forgotten in the '
                'room.',
            trailing: HealthActionPill(
                key: const Key('prep_question_examples'),
                label: 'Examples',
                icon: LucideIcons.lightbulb,
                onTap: onExamples),
          ),
          const SizedBox(height: 11),
          for (var i = 0; i < controllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: HealthCountedField(
                      fieldKey: Key('prep_question_$i'),
                      controller: controllers[i],
                      maxLength: 160,
                      enabled: enabled,
                      hint: 'e.g. how long should this take to settle?',
                    ),
                  ),
                  const SizedBox(width: 6),
                  HealthCircleButton(
                    key: Key('prep_question_remove_$i'),
                    icon: LucideIcons.trash2,
                    tooltip: 'Remove this question',
                    size: 30,
                    color: HealthTone.muted,
                    onTap: () => onRemove(i),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: HealthActionPill(
                key: const Key('prep_add_question'),
                label: 'Add another question',
                icon: LucideIcons.plus,
                onTap: onAdd),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: t.accent.withValues(alpha: 0.05),
              border: Border.all(color: t.accent.withValues(alpha: 0.20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.lightbulb, size: 18, color: t.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Write down the small things too',
                          style: TextStyle(
                              color: t.accent,
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      const Text(
                          'The detail that seems too minor to mention is '
                          'often the one worth mentioning.',
                          style: TextStyle(
                              color: HealthTone.dim,
                              fontSize: 10.5,
                              height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The one thing planning ahead must never crowd out
// ---------------------------------------------------------------------------

/// A calm, permanent route to the red path.
///
/// This screen is where an owner sits down and *plans* — which is exactly the
/// posture that turns "getting worse" into "I'll mention it on Tuesday". The
/// strip is identical for everyone and reads nothing: it is an affordance, not
/// a verdict, and no answer on this page changes it.
class _UrgentStrip extends StatelessWidget {
  const _UrgentStrip();

  @override
  Widget build(BuildContext context) {
    final red = AppColors.emergency(Theme.of(context).brightness);
    return HomeCard(
      key: const Key('prep_urgent_strip'),
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      accent: red.withValues(alpha: 0.30),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EmergencyHelpScreen())),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, size: 20, color: red),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('If it cannot wait for the appointment',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Emergency help — free, offline, on every plan.',
                    style: TextStyle(
                        color: HealthTone.dim, fontSize: 10.5, height: 1.3)),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 17, color: Colors.white54),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The summary
// ---------------------------------------------------------------------------

/// What "Review Summary" opens: the pack itself, exactly as it will be shared.
///
/// A preview that differs from what is sent is worse than none — this renders
/// the same string [buildVetVisitPrepPack] produces, so what an owner reads is
/// literally what the vet gets.
class _SummarySheet extends StatelessWidget {
  const _SummarySheet({required this.pack, required this.onShare});

  final String pack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return HealthSheet(
      title: 'Your prep pack',
      scrollable: true,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: SelectableText(
            pack,
            key: const Key('prep_summary_text'),
            style: const TextStyle(
                color: HealthTone.muted,
                fontSize: 11.5,
                height: 1.5,
                fontFamily: 'monospace'),
          ),
        ),
        HealthPrimaryCta(
          key: const Key('prep_share_button'),
          label: 'Share the pack',
          icon: LucideIcons.share2,
          onTap: onShare,
        ),
        const Text(
          'This is owner-recorded information organised by PawDoc, not a '
          'veterinary diagnosis.',
          textAlign: TextAlign.center,
          style: TextStyle(color: HealthTone.faint, fontSize: 10.5, height: 1.4),
        ),
      ],
    );
  }
}
