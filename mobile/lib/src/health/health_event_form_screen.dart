import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../analytics/analytics.dart';
import '../core/dates.dart';
import '../core/living_pet_avatar.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../home/home_sections.dart';
import '../memories/memory_media_service.dart';
import '../memories/memory_photo.dart';
import '../notifications/local_notifications.dart';
import '../pets/active_pet.dart';
import '../pets/pet_profile_screen.dart';
import '../pets/pet_switcher.dart';
import '../reminders/reminder.dart';
import '../reminders/reminders_repository.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'health_event.dart';
import 'health_events_repository.dart';
import 'health_sections.dart';
import 'history_timeline_screen.dart';
import 'timeline.dart';

/// Filing a health record, rebuilt against mockup `add_health_record`.
///
/// Pet header, the six-tile type rail, the Record Details card (date, time,
/// clinic, veterinarian, reason, notes with its counter), the attachment
/// gallery, the reminder switch, the privacy card and the Save Record CTA over
/// the encryption line.
///
/// Which rows appear follows the type — a weight record has no clinic and a
/// medication has a schedule — but they are the same row component throughout,
/// so the card reads identically whatever is being filed.
///
/// **Departure from the mockup.** Its sixth type tile is "AI Analysis". An AI
/// check is produced by the Check flow, where the emergency override, the quota
/// rules and the action ladder all apply; offering it as something to type in
/// by hand would be a false affordance and a way around the safety path. The
/// tile ships as **Weight**, which the app has always recorded and which the
/// mockup's grid otherwise drops. See [kHealthEventTypes].
class HealthEventFormScreen extends ConsumerStatefulWidget {
  const HealthEventFormScreen({
    super.key,
    required this.petId,
    required this.petName,
    this.initialNotes,
    this.initialType,
  });

  final String petId;
  final String petName;

  /// Pre-fills the note field. Set when the form is opened from somewhere that
  /// already has the text — the assistant's "Save to Diary" action, which
  /// carries its own provenance line so a saved reply can never be read as a
  /// clinical finding.
  final String? initialNotes;

  /// Preselects a record type. Set when the form is opened from a surface that
  /// already knows what is being filed — the medication tracker's "Add
  /// Medication", the vaccination manager's "Add Vaccine Record".
  final String? initialType;

  @override
  ConsumerState<HealthEventFormScreen> createState() =>
      _HealthEventFormScreenState();
}

class _HealthEventFormScreenState extends ConsumerState<HealthEventFormScreen> {
  late String _type = widget.initialType ?? kHealthEventTypes.first;
  DateTime _date = DateTime.now();
  TimeOfDay? _time;

  final _notes = TextEditingController();
  final _weight = TextEditingController();
  final _vaccineName = TextEditingController();
  final _clinic = TextEditingController();
  final _vet = TextEditingController();
  final _reason = TextEditingController();
  final _medName = TextEditingController();
  final _dosage = TextEditingController();
  final _schedule = TextEditingController();

  String? _vaccineClass;
  String? _medForm;
  DateTime? _vaccineNextDue;
  DateTime? _endsOn;

  bool _remind = false;
  DateTime? _remindOn;

  final List<String> _attachments = [];
  bool _uploading = false;

  bool _saving = false;
  bool _saved = false;

  List<TextEditingController> get _controllers => [
        _notes, _weight, _vaccineName, _clinic, _vet, _reason,
        _medName, _dosage, _schedule,
      ];

  @override
  void initState() {
    super.initState();
    if (widget.initialNotes != null) _notes.text = widget.initialNotes!;
    // The save CTA and its hint depend on what's typed, so rebuild as it
    // changes.
    for (final c in _controllers) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Validation
  // -------------------------------------------------------------------------

  /// What the selected type needs before the record means anything.
  ///
  /// Device-found: with no validation, "Save event" on an untouched form wrote
  /// a vaccination row with `notes: null, metadata: null` — a record the owner
  /// can neither read nor act on, and an unparseable weight saved a weight
  /// event carrying no weight. A health record with no content is worse than
  /// no record: it pads the history the vet reads.
  String? get _missingRequirement {
    switch (_type) {
      case 'vaccination':
        return _vaccineName.text.trim().isEmpty
            ? 'Add the vaccine name to save this.'
            : null;
      case 'weight':
        final kg = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
        if (kg == null) return 'Add the weight to save this.';
        return kg > 0 && kg < 500
            ? null
            : 'Enter a weight between 0 and 500 kg.';
      case 'medication':
        return _medName.text.trim().isEmpty && _notes.text.trim().isEmpty
            ? 'Add the medicine name to save this.'
            : null;
      case 'vet_visit':
      case 'lab_result':
        return _reason.text.trim().isEmpty && _notes.text.trim().isEmpty
            ? 'Add a short note to save this.'
            : null;
      default:
        return _notes.text.trim().isEmpty
            ? 'Add a short note to save this.'
            : null;
    }
  }

  bool get _hasInput =>
      _controllers.any((c) => c.text.trim().isNotEmpty) ||
      _attachments.isNotEmpty;

  // -------------------------------------------------------------------------
  // Save
  // -------------------------------------------------------------------------

  Map<String, dynamic>? _metadata() {
    final m = <String, dynamic>{};
    void put(String key, String value) {
      if (value.trim().isNotEmpty) m[key] = value.trim();
    }

    switch (_type) {
      case 'weight':
        final kg = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
        if (kg != null) m['weight_kg'] = kg;
      case 'vaccination':
        put('vaccine_name', _vaccineName.text);
        put('clinic', _clinic.text);
        if (_vaccineClass != null) m['vaccine_class'] = _vaccineClass;
        if (_vaccineNextDue != null) m['next_due'] = _iso(_vaccineNextDue!);
      case 'medication':
        put('medication_name', _medName.text);
        put('dosage', _dosage.text);
        put('schedule', _schedule.text);
        put('purpose', _reason.text);
        if (_medForm != null) m['form'] = _medForm;
        if (_endsOn != null) m['ends_on'] = _iso(_endsOn!);
      case 'vet_visit':
      case 'lab_result':
        put('clinic', _clinic.text);
        put('veterinarian', _vet.text);
        put('reason', _reason.text);
    }
    if (_time != null) {
      m['time'] = '${_time!.hour.toString().padLeft(2, '0')}:'
          '${_time!.minute.toString().padLeft(2, '0')}';
    }
    if (_attachments.isNotEmpty) {
      m['attachments'] = List<String>.from(_attachments);
    }
    return m.isEmpty ? null : m;
  }

  static String _iso(DateTime d) => d.toIso8601String().split('T').first;

  Future<void> _save() async {
    if (_missingRequirement != null) return;
    setState(() => _saving = true);
    final event = HealthEvent(
      petId: widget.petId,
      eventType: _type,
      eventDate: _date,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      metadata: _metadata(),
    );
    try {
      await ref.read(healthEventsRepositoryProvider).create(event);

      // E7 generalised: a vaccination's next-due date and the reminder switch
      // both create a real reminder (and its on-device notification) — the
      // record is what drives the retention spine.
      final due = _vaccineNextDue ?? (_remind ? _remindOn : null);
      if (due != null) await _createReminder(due);

      await Analytics.healthEventLogged(_type);
      ref.invalidate(healthTimelineProvider(widget.petId));
      if (!mounted) return;
      // M3 (#16): one 300ms check-morph beat on the button before closing —
      // completion feel without delaying navigation meaningfully; skipped
      // entirely under reduce-motion.
      if (!reduceMotion(context)) {
        setState(() => _saved = true);
        await Future<void>.delayed(const Duration(milliseconds: 320));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save the record. Please try again.')));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _createReminder(DateTime due) async {
    final label = switch (_type) {
      'vaccination' => _vaccineName.text.trim().isEmpty
          ? 'Vaccine due'
          : 'Vaccine: ${_vaccineName.text.trim()}',
      'medication' => _medName.text.trim().isEmpty
          ? 'Medication'
          : 'Medication: ${_medName.text.trim()}',
      'vet_visit' => 'Vet follow-up',
      'lab_result' => 'Lab follow-up',
      _ => 'Health follow-up',
    };
    try {
      await ref.read(localNotificationsProvider).ensurePermission();
      await ref.read(remindersRepositoryProvider).create(
            Reminder(petId: widget.petId, reminderType: label, dueDate: due),
            petName: widget.petName,
          );
      await Analytics.reminderSet(_type);
    } catch (_) {
      // The record saved; a reminder hiccup must not fail the flow.
    }
  }

  // -------------------------------------------------------------------------
  // Attachments
  // -------------------------------------------------------------------------

  /// Uploads through the journal's media service, which is the pipeline that
  /// already exists and is already deployed: EXIF/GPS stripped in a background
  /// isolate, then a presigned PUT into the caller's own namespace. No R2
  /// credentials on the client, and the object is displayable and deletable by
  /// its owner.
  ///
  /// A dedicated `records/` scope would read better and is the right long-term
  /// home, but adding one means editing `_shared/upload_key.mjs` and
  /// redeploying `generate-upload-url`, `sign-media-url` and `delete-media` —
  /// founder-gated. Nothing is written to the `memories` table, so an
  /// attachment never appears in the journal gallery.
  Future<void> _addAttachment() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(children: [
        HealthRecordRow(
          key: const Key('record_attach_camera'),
          leading: const HealthGlyphDisc(
              icon: LucideIcons.camera, tint: HealthTone.teal),
          title: 'Take a photo',
          subtitle: 'Of a form, a label or the pet',
          chevron: false,
          onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
        ),
        HealthRecordRow(
          key: const Key('record_attach_gallery'),
          leading: const HealthGlyphDisc(
              icon: LucideIcons.images, tint: HealthTone.violet),
          title: 'Choose from gallery',
          subtitle: 'A scan, a receipt, a result sheet',
          chevron: false,
          onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
        ),
      ]),
    );
    if (source == null) return;
    setState(() => _uploading = true);
    try {
      final service = ref.read(memoryMediaServiceProvider);
      final Uint8List? raw = await service.pick(source);
      if (raw == null) {
        if (mounted) setState(() => _uploading = false);
        return;
      }
      final key = await service.compressAndUpload(raw);
      if (mounted) {
        setState(() {
          _attachments.add(key);
          _uploading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not attach that photo. Please try again.')));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Pickers
  // -------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<DateTime?> _pickFutureDate(DateTime? current, {int defaultDays = 30}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? now.add(Duration(days: defaultDays)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
  }

  Future<void> _close() async {
    if (!_hasInput) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this record?'),
        content: const Text('What you have typed will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            key: const Key('record_discard_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Discard',
                style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final pet = ref.watch(activePetProvider);
    final hint = _missingRequirement;

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: 'Add Health Record',
          subtitleLead: 'Keep ${petDisplayPossessive(widget.petName)}',
          subtitle: ' health journey complete',
          actions: [
            HealthCircleButton(
              key: const Key('record_close'),
              icon: LucideIcons.x,
              tooltip: 'Close without saving',
              onTap: _close,
            ),
          ],
        ),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Say what's missing rather than leaving a dead button.
            if (hint != null && !_saving && !_saved)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(hint,
                    key: const Key('event_save_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: HealthTone.muted, fontSize: 11.5)),
              ),
            _SaveButton(
              enabled: !_saving && !_saved && hint == null,
              saving: _saving,
              saved: _saved,
              onTap: _save,
            ),
            const SizedBox(height: 7),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(LucideIcons.lock, size: 11, color: HealthTone.faint),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                    'Encrypted and stored on your account only.',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: HealthTone.faint, fontSize: 10.5, height: 1.3)),
              ),
            ]),
          ],
        ),
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
          gap(14),
          const _SectionLabel('What type of record is this?'),
          gap(9),
          HealthBleed(
            child: _TypeRail(
              selected: _type,
              onSelect: (v) => setState(() => _type = v),
            ),
          ),
          gap(14),
          const _SectionLabel('Record Details'),
          gap(9),
          HomeCard(
            radius: 16,
            padding: const EdgeInsets.all(9),
            child: Column(children: _detailFields()),
          ),
          gap(10),
          _AttachmentsCard(
            keys: _attachments,
            uploading: _uploading,
            onAdd: _addAttachment,
            onRemove: (key) => setState(() => _attachments.remove(key)),
          ),
          gap(10),
          _ReminderCard(
            value: _remind || _vaccineNextDue != null,
            // A vaccination's next-due date already schedules one; the switch
            // would be a second, contradictory control over the same thing.
            locked: _vaccineNextDue != null,
            date: _vaccineNextDue ?? _remindOn,
            onChanged: (on) async {
              if (!on) {
                setState(() {
                  _remind = false;
                  _remindOn = null;
                });
                return;
              }
              final picked = await _pickFutureDate(_remindOn,
                  defaultDays: _type == 'vaccination' ? 365 : 30);
              if (picked != null) {
                setState(() {
                  _remind = true;
                  _remindOn = picked;
                });
              }
            },
            onPickDate: () async {
              final picked = await _pickFutureDate(_remindOn,
                  defaultDays: _type == 'vaccination' ? 365 : 30);
              if (picked != null) setState(() => _remindOn = picked);
            },
          ),
          gap(10),
          HealthPrivacyCard(
            title: 'Your data is private and secure',
            body: 'Only you can see ${petDisplayPossessive(widget.petName)} '
                'health records.',
            onTap: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => const HealthSheet(
                title: 'How this record is stored',
                children: [
                  _PrivacyPoint(
                    icon: LucideIcons.lock,
                    text: 'It is stored against your account and readable only '
                        'with your sign-in. Row-level security enforces that at '
                        'the database, not in the app.',
                  ),
                  _PrivacyPoint(
                    icon: LucideIcons.imageOff,
                    text: 'Attached photos have their location and camera data '
                        'stripped on this device before they are uploaded.',
                  ),
                  _PrivacyPoint(
                    icon: LucideIcons.userPen,
                    text: 'What you file here is yours. PawDoc does not review '
                        'it, and it is never shared with anyone unless you '
                        'export it yourself.',
                  ),
                ],
              ),
            ),
          ),
          gap(8),
          Text(
            'Tip: the details you add here are what makes the next vet '
            'appointment shorter.',
            style: TextStyle(color: t.textMuted, fontSize: 11, height: 1.35),
          ),
          gap(6),
        ],
      ),
    );
  }

  /// The rows the selected type needs. One component throughout, so the card
  /// reads the same whatever is being filed.
  List<Widget> _detailFields() {
    final rows = <Widget>[
      Row(children: [
        Expanded(
          child: HealthPickerField(
            fieldKey: const Key('event_date_field'),
            icon: LucideIcons.calendar,
            label: _dateLabel,
            value: shortDate(_date),
            onTap: _pickDate,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: HealthPickerField(
            fieldKey: const Key('event_time_field'),
            icon: LucideIcons.clock,
            label: 'Time (Optional)',
            value: _time == null ? 'Not set' : _time!.format(context),
            muted: _time == null,
            onTap: _pickTime,
            onClear: _time == null ? null : () => setState(() => _time = null),
          ),
        ),
      ]),
    ];

    switch (_type) {
      case 'vet_visit':
      case 'lab_result':
        rows.addAll([
          HealthTextField(
            fieldKey: const Key('event_clinic_field'),
            controller: _clinic,
            icon: LucideIcons.building2,
            label: _type == 'lab_result'
                ? 'Lab / Clinic Name'
                : 'Clinic / Hospital Name',
            hint: 'PawCare Veterinary Clinic',
          ),
          HealthTextField(
            fieldKey: const Key('event_vet_field'),
            controller: _vet,
            icon: LucideIcons.userRound,
            label: 'Veterinarian Name (Optional)',
            hint: 'Dr. Ayşe Yılmaz',
          ),
          HealthTextField(
            fieldKey: const Key('event_reason_field'),
            controller: _reason,
            icon: LucideIcons.clipboardList,
            label: _type == 'lab_result' ? 'Test / Panel' : 'Visit Reason',
            hint: _type == 'lab_result'
                ? 'Complete blood count'
                : 'What you went in for',
          ),
        ]);
      case 'vaccination':
        rows.addAll([
          HealthTextField(
            fieldKey: const Key('event_vaccine_name_field'),
            controller: _vaccineName,
            icon: LucideIcons.syringe,
            label: 'Vaccine name',
            hint: 'Rabies, DHPP, Leptospirosis…',
          ),
          HealthChoiceField(
            icon: LucideIcons.shieldCheck,
            label: 'Class (Optional)',
            value: _vaccineClass,
            options: kVaccineClasses,
            onSelect: (v) => setState(() => _vaccineClass = v),
          ),
          HealthPickerField(
            fieldKey: const Key('event_vaccine_next_due'),
            icon: LucideIcons.calendarClock,
            label: 'Next due (Optional) — sets a reminder',
            value:
                _vaccineNextDue == null ? 'Not set' : shortDate(_vaccineNextDue!),
            muted: _vaccineNextDue == null,
            onTap: () async {
              final picked =
                  await _pickFutureDate(_vaccineNextDue, defaultDays: 365);
              if (picked != null) setState(() => _vaccineNextDue = picked);
            },
            onClear: _vaccineNextDue == null
                ? null
                : () => setState(() => _vaccineNextDue = null),
          ),
          HealthTextField(
            fieldKey: const Key('event_clinic_field'),
            controller: _clinic,
            icon: LucideIcons.building2,
            label: 'Clinic (Optional)',
            hint: 'Where it was given',
          ),
        ]);
      case 'medication':
        rows.addAll([
          HealthTextField(
            fieldKey: const Key('event_medication_field'),
            controller: _medName,
            icon: LucideIcons.pill,
            label: 'Medicine name',
            hint: 'NexGard Spectra',
          ),
          Row(children: [
            Expanded(
              child: HealthTextField(
                fieldKey: const Key('event_dosage_field'),
                controller: _dosage,
                icon: LucideIcons.beaker,
                label: 'Dose (Optional)',
                hint: '250 mg',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HealthChoiceField(
                icon: LucideIcons.tablets,
                label: 'Form',
                value: _medForm,
                options: kMedicationForms,
                onSelect: (v) => setState(() => _medForm = v),
              ),
            ),
          ]),
          HealthTextField(
            fieldKey: const Key('event_schedule_field'),
            controller: _schedule,
            icon: LucideIcons.repeat2,
            label: 'Schedule',
            hint: 'Every 12 hours',
          ),
          HealthTextField(
            fieldKey: const Key('event_reason_field'),
            controller: _reason,
            icon: LucideIcons.target,
            label: 'What it is for (Optional)',
            hint: 'Flea & tick prevention',
          ),
          HealthPickerField(
            fieldKey: const Key('event_ends_on_field'),
            icon: LucideIcons.calendarX,
            label: 'Course ends (Optional)',
            value: _endsOn == null ? 'Ongoing' : shortDate(_endsOn!),
            muted: _endsOn == null,
            onTap: () async {
              final picked = await _pickFutureDate(_endsOn, defaultDays: 14);
              if (picked != null) setState(() => _endsOn = picked);
            },
            onClear:
                _endsOn == null ? null : () => setState(() => _endsOn = null),
          ),
        ]);
      case 'weight':
        rows.add(HealthTextField(
          fieldKey: const Key('event_weight_field'),
          controller: _weight,
          icon: LucideIcons.scale,
          label: 'Weight (kg)',
          hint: '28.0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ));
    }

    rows.add(HealthNotesField(controller: _notes, label: _notesLabel));
    return [
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 8),
          child: rows[i],
        ),
    ];
  }

  String get _dateLabel => switch (_type) {
        'vet_visit' => 'Visit Date',
        'vaccination' => 'Given On',
        'medication' => 'Started On',
        'lab_result' => 'Sample Date',
        'weight' => 'Weighed On',
        _ => 'Date',
      };

  String get _notesLabel => switch (_type) {
        'vet_visit' || 'lab_result' => 'Notes & Findings',
        _ => 'Notes (Optional)',
      };
}

/// The medication forms the tracker tints and filters by.
const List<String> kMedicationForms = [
  'Tablet',
  'Chewable',
  'Liquid',
  'Topical',
  'Injection',
];

/// The vaccine classes the manager filters by. Owner-selected, never inferred:
/// which vaccines are core is a regional veterinary judgement, not something
/// the app decides from a name.
const List<String> kVaccineClasses = ['Core', 'Non-core', 'Lifestyle'];

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700));
}

/// The six-across type rail, with the mockup's check badge on the selection.
class _TypeRail extends StatelessWidget {
  const _TypeRail({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        key: const Key('record_type_rail'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(kRecordGutter, 4, kRecordGutter, 0),
        itemCount: kHealthEventTypes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, i) => _TypeTile(
          key: Key('event_type_${kHealthEventTypes[i]}'),
          type: kHealthEventTypes[i],
          isSelected: kHealthEventTypes[i] == selected,
          onTap: () => onSelect(kHealthEventTypes[i]),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final label = healthEventLabel(type);
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? t.accent.withValues(alpha: 0.10)
                      : HealthTone.card,
                  border: Border.all(
                    color: isSelected
                        ? t.accent.withValues(alpha: 0.75)
                        : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(healthEventIcon(type),
                        size: 22,
                        color: isSelected ? t.accent : Colors.white70),
                    const SizedBox(height: 7),
                    // Shrink-to-fit: "Vaccination" is wider than the tile at a
                    // large text scale, and a type reading "Vaccina…" is worse
                    // than one a point smaller.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label,
                            maxLines: 1,
                            style: TextStyle(
                                color: isSelected ? t.accent : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.accent,
                      border: const Border.fromBorderSide(
                          BorderSide(color: Color(0xFF000608), width: 1.6)),
                    ),
                    child: const Icon(LucideIcons.check,
                        size: 12, color: Color(0xFF06110A)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The glyph a record type is drawn with, everywhere.
// `healthEventIcon` moved to `health_event.dart`, beside `healthEventLabel`.


/// The attachment gallery: what is already attached, plus the dashed add tile.
class _AttachmentsCard extends StatelessWidget {
  const _AttachmentsCard({
    required this.keys,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> keys;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.paperclip,
                size: 14, color: HealthTone.muted),
            const SizedBox(width: 7),
            const Text('Attachments',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 5),
            const Text('(Optional)',
                style: TextStyle(color: HealthTone.faint, fontSize: 11)),
          ]),
          const SizedBox(height: 9),
          SizedBox(
            height: 68,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final key in keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 68,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: MemoryPhoto(
                              storageKey: key,
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: InkWell(
                              onTap: () => onRemove(key),
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xCC000000),
                                ),
                                child: const Icon(LucideIcons.x,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                InkWell(
                  key: const Key('record_add_attachment'),
                  onTap: uploading ? null : onAdd,
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: CustomPaint(
                      painter: HealthDashedPainter(
                          t.accent.withValues(alpha: 0.55),
                          radius: 11),
                      child: uploading
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.camera,
                                    size: 17, color: t.accent),
                                const SizedBox(height: 4),
                                Text('Add More',
                                    style: TextStyle(
                                        color: t.accent,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          const Text(
              'Photos are stripped of location and camera data on this device '
              'before they leave it.',
              style: TextStyle(
                  color: HealthTone.faint, fontSize: 10.5, height: 1.3)),
        ],
      ),
    );
  }
}

/// The reminder switch, and the date it fires on.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.value,
    required this.locked,
    required this.date,
    required this.onChanged,
    required this.onPickDate,
  });

  final bool value;
  final bool locked;
  final DateTime? date;
  final ValueChanged<bool> onChanged;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 9, 9, 9),
      child: Column(
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.accent.withValues(alpha: 0.12),
              ),
              child: Icon(LucideIcons.bellRing, size: 17, color: t.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Set a reminder',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text(
                      locked
                          ? 'The next-due date above already sets one.'
                          : 'We’ll nudge you about the follow-up or re-check.',
                      style: const TextStyle(
                          color: HealthTone.dim, fontSize: 11, height: 1.3)),
                ],
              ),
            ),
            Switch(
              key: const Key('record_reminder_switch'),
              value: value,
              onChanged: locked ? null : onChanged,
            ),
          ]),
          if (value && !locked && date != null) ...[
            const SizedBox(height: 4),
            InkWell(
              key: const Key('record_reminder_date'),
              onTap: onPickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.03),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(children: [
                  const Icon(LucideIcons.calendarClock,
                      size: 15, color: HealthTone.muted),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text('Remind me on ${shortDate(date!)}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12.5)),
                  ),
                  const Icon(LucideIcons.chevronRight,
                      size: 15, color: HealthTone.muted),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.icon, required this.text});

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

/// The Save CTA, keeping the M3 check-morph beat.
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.enabled,
    required this.saving,
    required this.saved,
    required this.onTap,
  });

  final bool enabled;
  final bool saving;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final label = saved ? 'Saved' : (saving ? 'Saving…' : 'Save Record');
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color:
              enabled || saved ? t.accent : t.accent.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            key: const Key('event_save_button'),
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 50,
              width: double.infinity,
              child: AnimatedSwitcher(
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: Row(
                  key: ValueKey(label),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        saved
                            ? LucideIcons.circleCheck
                            : LucideIcons.circlePlus,
                        size: 19,
                        color: const Color(0xFF06110A)),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF06110A),
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
