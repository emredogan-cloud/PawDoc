import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../account/user_profile.dart';
import '../capture/upload_service.dart' show UploadException;
import '../core/dates.dart';
import '../core/pet_display.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../pets/pet.dart';
import '../pets/pet_form_screen.dart';
import '../pets/pet_pick_rail.dart';
import '../pets/pets_repository.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'memories_repository.dart';
import 'memory.dart';
import 'memory_media_service.dart';

/// The memory creation flow, built to mockup `add_memory`.
///
/// It replaces the half-height frosted sheet the journal's "+" used to open —
/// a sheet cannot hold six numbered cards, a four-stop wizard and an upload
/// run, and the reference draws all three.
///
/// ## How the reference's four steps map onto the page it draws
///
/// The plate highlights step **1 · Media** while showing sections 1–6, and its
/// own button reads "Next: Add Tags" — which is step **3**. The render stacked
/// Media and Details onto one canvas. Every card is reproduced here at the
/// reference's composition; they are dealt across the two steps the rail names,
/// so the button that says "Next: Add Tags" is the one that goes to the tags.
///
/// ## What the reference draws that `pet_memories` cannot hold
///
/// * **Video.** There is no video pipeline — no upload path, no thumbnail, no
///   duration. The picker takes photographs and the copy says so; the journal's
///   type filter already carries the same *Soon*.
/// * **A time of day.** `taken_on` is a date column. The field keeps its place
///   beside the date and says *Soon* rather than accepting a time the save
///   would silently drop.
/// * **Tags.** No column, and folding them into the note would put the owner's
///   filing labels into the body of their own writing. Step 3 draws the full
///   picker and marks it *Soon*.
/// * **Family and Public.** Every row of `pet_memories` is RLS-scoped to the
///   account that wrote it; there is no share table and no community bridge.
///   **Private is not a setting here, it is the fact** — the tile says that,
///   and the other two keep their place, marked *Soon*.
///
/// ## Many photos, one column
///
/// A memory row holds one `storage_key`. The reference's "up to 10" is honoured
/// by writing one entry per photograph, sharing the pet, date, title and note —
/// which is what the gallery would draw for a multi-photo memory anyway. The
/// review step states it in as many words before anything is written, and the
/// free-tier allowance is checked against the *whole batch*, not one row.
class AddMemoryScreen extends ConsumerStatefulWidget {
  const AddMemoryScreen({super.key, required this.pet});

  /// The pet the journal was showing. The picker can change it.
  final Pet pet;

  /// The reference's ceiling, and the one the copy quotes.
  static const int maxPhotos = 10;

  @override
  ConsumerState<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

/// The rail's four stops.
enum MemoryStep {
  media('Media'),
  details('Details'),
  tags('Tags'),
  review('Review');

  const MemoryStep(this.label);

  final String label;
}

/// Who can see a memory.
///
/// Only [private] is real: `pet_memories` is RLS-scoped per row to the account
/// that wrote it, so "private" is a description of the table, not a preference.
/// The other two are drawn, disabled and captioned — never silently accepted
/// and dropped.
enum MemoryAudience {
  private('Private', 'Only you', LucideIcons.lock),
  family('Family', 'Family members', LucideIcons.users),
  public('Public', 'Share with community', LucideIcons.globe);

  const MemoryAudience(this.label, this.detail, this.icon);

  final String label;
  final String detail;
  final IconData icon;

  bool get available => this == MemoryAudience.private;
}

/// A photograph waiting to be written, in the order the strip shows it.
class PendingPhoto {
  const PendingPhoto({required this.id, required this.bytes});

  final String id;
  final Uint8List bytes;
}

/// How many of [wanted] photos the free plan still has room for.
///
/// Pure, and unit-tested: the allowance is per *entry*, and a five-photo pick
/// against two remaining slots must take two rather than failing the batch or
/// silently writing five.
int allowedPhotoCount({
  required int wanted,
  required int currentCount,
  required bool isPremium,
  int max = AddMemoryScreen.maxPhotos,
}) {
  final byMax = wanted.clamp(0, max);
  if (isPremium) return byMax;
  final room = kFreeMemoryLimit - currentCount;
  return byMax.clamp(0, room < 0 ? 0 : room);
}

class _AddMemoryScreenState extends ConsumerState<AddMemoryScreen> {
  final _title = TextEditingController();
  final _note = TextEditingController();

  MemoryStep _step = MemoryStep.media;
  final List<PendingPhoto> _photos = [];
  late String? _petId = widget.pet.id;
  DateTime _takenOn = DateTime.now();
  MemoryAudience _audience = MemoryAudience.private;

  bool _picking = false;
  bool _saving = false;
  int _written = 0;
  String? _error;
  int _seq = 0;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Data
  // -------------------------------------------------------------------------

  List<Pet> get _pets =>
      ref.watch(petsListProvider).value ?? <Pet>[widget.pet];

  Pet get _pet {
    for (final p in _pets) {
      if (p.id == _petId) return p;
    }
    return widget.pet;
  }

  bool get _isPremium => ref.read(userProfileProvider).maybeWhen(
        data: (p) => p.isPremium,
        orElse: () => false,
      );

  int get _memoryCount => ref.read(memoriesCountProvider).maybeWhen(
        data: (c) => c,
        orElse: () => 0,
      );

  bool get _hasInput =>
      _photos.isNotEmpty ||
      _title.text.trim().isNotEmpty ||
      _note.text.trim().isNotEmpty;

  /// What still stands between this form and a save, in the owner's words.
  String? get _blocker {
    if (_photos.isEmpty) return 'Add at least one photo to save this memory.';
    if (_petId == null) return 'Choose which pet this memory is about.';
    return null;
  }

  // -------------------------------------------------------------------------
  // Media
  // -------------------------------------------------------------------------

  Future<void> _pick() async {
    if (_photos.length >= AddMemoryScreen.maxPhotos) {
      _say('That is ${AddMemoryScreen.maxPhotos} photos — the most one memory '
          'can carry.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Add a photo',
        children: [
          HealthRecordRow(
            key: const Key('memory_pick_camera'),
            leading: const HealthGlyphDisc(
                icon: LucideIcons.camera, tint: HealthTone.teal),
            title: 'Take a photo',
            subtitle: 'Straight from the camera',
            chevron: false,
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          HealthRecordRow(
            key: const Key('memory_pick_gallery'),
            leading: const HealthGlyphDisc(
                icon: LucideIcons.images, tint: HealthTone.violet),
            title: 'Choose from gallery',
            subtitle: 'A photo already on this phone',
            chevron: false,
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
          const HealthRecordRow(
            key: Key('memory_pick_video'),
            leading: HealthGlyphDisc(
                icon: LucideIcons.video, tint: HealthTone.faint),
            title: 'Record a video',
            subtitle: 'Soon — the journal keeps photographs for now',
            chevron: false,
          ),
        ],
      ),
    );
    if (source == null) return;

    final room = allowedPhotoCount(
      wanted: _photos.length + 1,
      currentCount: _memoryCount,
      isPremium: _isPremium,
    );
    if (room <= _photos.length) {
      _showLimitSheet();
      return;
    }

    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final bytes = await ref.read(memoryMediaServiceProvider).pick(source);
      if (!mounted) return;
      setState(() {
        _picking = false;
        if (bytes != null) {
          _photos.add(PendingPhoto(id: 'p${_seq++}', bytes: bytes));
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Could not open the picker. Please try again.';
      });
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final to = newIndex > oldIndex ? newIndex - 1 : newIndex;
      _photos.insert(to, _photos.removeAt(oldIndex));
    });
  }

  void _showLimitSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Your memory book is full',
        children: [
          const Text(
            'The free plan holds $kFreeMemoryLimit entries, and each photo is '
            'one entry. Premium keeps the whole story — across all your pets.',
            style: TextStyle(
                color: HealthTone.dim, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 4),
          HealthPrimaryCta(
            key: const Key('add_memory_upgrade'),
            icon: LucideIcons.crown,
            label: 'See Premium',
            onTap: () => Navigator.pop(sheetContext),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Pickers
  // -------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _takenOn.isAfter(now) ? now : _takenOn,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (picked != null) setState(() => _takenOn = picked);
  }

  Future<void> _newPet() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PetFormScreen()),
    );
    if (created == true && mounted) ref.invalidate(petsListProvider);
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  /// The wizard walks freely; only the *save* is gated. A form that refuses to
  /// show step 3 until step 1 is complete hides what it is asking for, and the
  /// reference draws no validation state anywhere.
  void _goto(MemoryStep step) => setState(() => _step = step);

  void _next() {
    final i = _step.index;
    if (i < MemoryStep.values.length - 1) {
      _goto(MemoryStep.values[i + 1]);
    } else {
      _save();
    }
  }

  Future<void> _close() async {
    if (!_hasInput || _saving) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this memory?'),
        content: const Text('The photos and words here will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            key: const Key('add_memory_discard_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------------------------------------------------------------
  // Save
  // -------------------------------------------------------------------------

  Future<void> _save() async {
    final blocker = _blocker;
    if (blocker != null) {
      _say(blocker);
      return;
    }
    setState(() {
      _step = MemoryStep.review;
      _saving = true;
      _written = 0;
      _error = null;
    });

    final repo = ref.read(memoriesRepositoryProvider);
    final media = ref.read(memoryMediaServiceProvider);
    final title = _title.text.trim();
    final note = _note.text.trim();
    final petId = _pet.id!;

    try {
      for (final photo in _photos) {
        final storageKey = await media.compressAndUpload(photo.bytes);
        await repo.create(Memory(
          userId: '', // the repository injects auth.uid()
          petId: petId,
          title: title.isEmpty ? _fallbackTitle() : title,
          note: note.isEmpty ? null : note,
          storageKey: storageKey,
          takenOn: _takenOn,
        ));
        if (!mounted) return;
        setState(() => _written++);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on UploadException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _written == 0
              ? 'Could not save the memory. Please try again.'
              : 'Saved $_written of ${_photos.length}. Try the rest again.';
        });
      }
    }
  }

  /// The reference makes the title optional but the gallery lists by title, so
  /// an untitled entry needs something to be found by. The date is the one
  /// thing that is always true about it.
  String _fallbackTitle() => shortDate(_takenOn);

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final saveable = _blocker == null && !_saving;

    return PopScope(
      canPop: !_hasInput && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: PawBackground(
        variant: PawSurface.dark,
        child: HealthRecordScaffold(
          appBar: PetModuleAppBar(
            icon: LucideIcons.pawPrint,
            title: 'Add Memory',
            subtitle: 'Capture the moments that matter',
            onBack: _close,
            actionsWidth: 74,
            actions: [
              _SavePill(
                enabled: saveable,
                onTap: _save,
              ),
            ],
          ),
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(_error!,
                      key: const Key('add_memory_error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.accent, fontSize: 11.5)),
                )
              else if (_blocker != null && _step != MemoryStep.media)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(_blocker!,
                      key: const Key('add_memory_hint'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: HealthTone.muted, fontSize: 11.5)),
                ),
              HealthPrimaryCta(
                key: const Key('add_memory_next'),
                icon: null,
                trailingIcon: _step == MemoryStep.review
                    ? LucideIcons.heart
                    : LucideIcons.chevronRight,
                enabled: !_saving,
                label: switch (_step) {
                  MemoryStep.media => 'Next: Details',
                  MemoryStep.details => 'Next: Add Tags',
                  MemoryStep.tags => 'Next: Review',
                  MemoryStep.review =>
                    _saving ? 'Saving…' : _saveLabel(_photos.length),
                },
                onTap: _next,
              ),
            ],
          ),
          children: [
            gap(4),
            HealthStepRail(
              key: const Key('add_memory_steps'),
              steps: [for (final s in MemoryStep.values) s.label],
              current: _step.index,
              onSelect: _saving
                  ? null
                  : (i) => setState(() => _step = MemoryStep.values[i]),
            ),
            gap(14),
            ...switch (_step) {
              MemoryStep.media => _mediaStep(),
              MemoryStep.details => _detailsStep(),
              MemoryStep.tags => _tagsStep(),
              MemoryStep.review => _reviewStep(),
            },
            gap(8),
          ],
        ),
      ),
    );
  }

  String _saveLabel(int n) =>
      n <= 1 ? 'Save to the Book' : 'Save $n Entries';

  // --- step 1 --------------------------------------------------------------

  List<Widget> _mediaStep() => [
        HomeCard(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthNumberedHead(
                number: 1,
                title: 'Add Photos',
                subtitle: 'Share a special moment with your pet',
              ),
              const SizedBox(height: 11),
              _MediaStrip(
                photos: _photos,
                picking: _picking,
                onAdd: _pick,
                onRemove: (id) =>
                    setState(() => _photos.removeWhere((p) => p.id == id)),
                onReorder: _reorder,
              ),
              const SizedBox(height: 9),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _photos.isEmpty
                          ? 'You can add up to ${AddMemoryScreen.maxPhotos} '
                              'photos'
                          : '${_photos.length} of ${AddMemoryScreen.maxPhotos} '
                              '· drag to reorder',
                      key: const Key('add_memory_count'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: HealthTone.dim, fontSize: 11, height: 1.3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  InkWell(
                    key: const Key('add_memory_media_info'),
                    onTap: _explainMedia,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(LucideIcons.info,
                          size: 13, color: HealthTone.faint),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        gap(11),
        HomeCard(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthNumberedHead(
                number: 2,
                title: 'Choose Pet',
                subtitle: 'Who is this memory about?',
              ),
              const SizedBox(height: 11),
              PetPickRail(
                keyPrefix: 'add_memory_pet',
                pets: _pets,
                selectedId: _petId,
                onSelect: (id) => setState(() => _petId = id),
                onNewPet: _newPet,
              ),
            ],
          ),
        ),
        gap(11),
        HealthPrivacyCard(
          title: 'Stripped before it leaves',
          body: 'Location and camera data are removed on this phone, then the '
              'photo is uploaded straight to your own private storage.',
          onTap: _explainMedia,
        ),
      ];

  void _explainMedia() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const HealthSheet(
        title: 'About photos in the book',
        scrollable: true,
        children: [
          HealthDetailRow(
            icon: LucideIcons.images,
            label: 'How many',
            value: 'Up to ${AddMemoryScreen.maxPhotos} at a time. Each photo '
                'becomes its own entry, sharing this pet, date, title and note.',
          ),
          HealthDetailRow(
            icon: LucideIcons.mapPinOff,
            label: 'Location',
            value: 'EXIF and GPS data are stripped on this device, before the '
                'photo is uploaded. PawDoc never sees where it was taken.',
          ),
          HealthDetailRow(
            icon: LucideIcons.lock,
            label: 'Who can see it',
            value: 'Only you. Every entry is scoped to your account in the '
                'database itself, not by a setting.',
          ),
          HealthDetailRow(
            icon: LucideIcons.video,
            label: 'Video',
            value: 'Soon. The journal keeps photographs for now.',
          ),
        ],
      ),
    );
  }

  // --- step 2 --------------------------------------------------------------

  List<Widget> _detailsStep() => [
        HomeCard(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthNumberedHead(
                  number: 3, title: 'When did it happen?'),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(
                  child: _StampField(
                    fieldKey: const Key('add_memory_date'),
                    icon: LucideIcons.calendarDays,
                    value: shortDate(_takenOn),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _StampField(
                    fieldKey: const Key('add_memory_time'),
                    icon: LucideIcons.clock,
                    value: 'Time · Soon',
                    soon: true,
                    onTap: () => _say('A memory is filed by day. Times are '
                        'coming with the next update.'),
                  ),
                ),
              ]),
            ],
          ),
        ),
        gap(11),
        HomeCard(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthNumberedHead(
                  number: 4, title: 'Add a Title', suffix: '(Optional)'),
              const SizedBox(height: 11),
              HealthCountedField(
                fieldKey: const Key('memory_title_field'),
                controller: _title,
                maxLength: 60,
                hint: 'e.g. First day at the beach',
              ),
            ],
          ),
        ),
        gap(11),
        HomeCard(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthNumberedHead(number: 5, title: 'Write a Note'),
              const SizedBox(height: 11),
              HealthCountedField(
                fieldKey: const Key('memory_note_field'),
                controller: _note,
                maxLength: 500,
                minLines: 3,
                maxLines: 6,
                hint: 'Write something about this moment…',
              ),
            ],
          ),
        ),
        gap(11),
        HomeCard(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthNumberedHead(
                number: 6,
                title: 'Privacy',
                subtitle: 'Who can see this memory',
              ),
              const SizedBox(height: 11),
              _AudienceRow(
                selected: _audience,
                onSelect: (a) {
                  if (a.available) {
                    setState(() => _audience = a);
                  } else {
                    _say('${a.label} sharing is coming. Every memory is '
                        'private to your account today.');
                  }
                },
              ),
            ],
          ),
        ),
      ];

  // --- step 3 --------------------------------------------------------------

  List<Widget> _tagsStep() => [
        HomeCard(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthNumberedHead(
                number: 7,
                title: 'Add Tags',
                subtitle: 'Group moments so they are easy to find later',
                suffix: '(Soon)',
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _kSuggestedTags)
                    _TagChip(
                      label: tag.$1,
                      icon: tag.$2,
                      onTap: () => _say('Tags are coming. Search already reads '
                          'every title and note.'),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              HealthDashedTile(
                key: const Key('add_memory_custom_tag'),
                radius: 12,
                color: Colors.white.withValues(alpha: 0.14),
                onTap: () => _say('Tags are coming. Search already reads every '
                    'title and note.'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  child: Row(children: [
                    Icon(LucideIcons.plus, size: 15, color: HealthTone.faint),
                    SizedBox(width: 9),
                    Text('Write your own tag',
                        style:
                            TextStyle(color: HealthTone.faint, fontSize: 13)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        gap(11),
        const HealthEduCard(
          icon: LucideIcons.search,
          title: 'Findable without tags',
          body: 'The journal searches every title and note as you type, so a '
              'memory worth finding is already reachable.',
        ),
      ];

  // --- step 4 --------------------------------------------------------------

  List<Widget> _reviewStep() {
    final title = _title.text.trim();
    final note = _note.text.trim();
    return [
      HomeCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HealthNumberedHead(
              number: 8,
              title: 'Review',
              subtitle: _photos.length <= 1
                  ? 'One entry will be added to ${petDisplayPossessive(_pet.name)} book'
                  : '${_photos.length} entries will be added to '
                      '${petDisplayPossessive(_pet.name)} book, one per photo',
            ),
            const SizedBox(height: 11),
            if (_photos.isNotEmpty)
              SizedBox(
                height: 82,
                child: ListView.separated(
                  key: const Key('add_memory_review_strip'),
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_photos[i].bytes,
                        width: 82, height: 82, fit: BoxFit.cover),
                  ),
                ),
              ),
            const SizedBox(height: 11),
            HealthDetailRow(
              icon: LucideIcons.pawPrint,
              label: 'Pet',
              value: petDisplayName(_pet.name),
            ),
            HealthDetailRow(
              icon: LucideIcons.calendarDays,
              label: 'Happened on',
              value: shortDate(_takenOn),
            ),
            HealthDetailRow(
              icon: LucideIcons.type,
              label: 'Title',
              value: title.isEmpty ? '${_fallbackTitle()} (from the date)' : title,
            ),
            HealthDetailRow(
              icon: LucideIcons.notebookPen,
              label: 'Note',
              value: note.isEmpty ? 'None' : note,
            ),
            HealthDetailRow(
              icon: LucideIcons.lock,
              label: 'Visible to',
              value: 'You only',
            ),
          ],
        ),
      ),
      gap(11),
      if (_saving)
        _UploadProgress(done: _written, total: _photos.length)
      else
        const HealthEduCard(
          icon: LucideIcons.heart,
          title: 'Kept for as long as you want it',
          body: 'Memories are never used to train anything and never leave '
              'your account. You can edit or delete any entry later.',
        ),
    ];
  }
}

const List<(String, IconData)> _kSuggestedTags = [
  ('First time', LucideIcons.sparkles),
  ('Playtime', LucideIcons.dog),
  ('Travel', LucideIcons.map),
  ('Birthday', LucideIcons.cake),
  ('Nap', LucideIcons.moon),
  ('Friends', LucideIcons.users),
];

// ---------------------------------------------------------------------------
// The save pill
// ---------------------------------------------------------------------------

/// The lime "Save" lozenge the reference puts in the header. Distinct from
/// [HealthCircleButton] — it is the only titled action in the module's chrome.
class _SavePill extends StatelessWidget {
  const _SavePill({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Save memory',
      child: ExcludeSemantics(
        child: Material(
          color: enabled ? t.accent : t.accent.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            key: const Key('add_memory_save'),
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              height: 34,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text('Save',
                  style: TextStyle(
                      color: enabled
                          ? const Color(0xFF06110A)
                          : Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The media strip
// ---------------------------------------------------------------------------

/// The dashed "Add" well followed by the picked photographs, which drag to
/// reorder. The well sits outside the reorderable list on purpose: it is not a
/// photo, and a draggable "Add" tile is a slot that can be dropped into the
/// middle of the batch.
class _MediaStrip extends StatelessWidget {
  const _MediaStrip({
    required this.photos,
    required this.picking,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  final List<PendingPhoto> photos;
  final bool picking;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final void Function(int, int) onReorder;

  static const double _tile = 96;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      height: _tile,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 84,
            child: HealthDashedTile(
              key: const Key('add_memory_add_tile'),
              radius: 13,
              onTap: picking ? null : onAdd,
              fill: t.accent.withValues(alpha: 0.05),
              child: picking
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.imagePlus, size: 26, color: t.accent),
                        const SizedBox(height: 8),
                        Text('Add',
                            style: TextStyle(
                                color: t.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: photos.isEmpty
                ? const _EmptyStrip()
                : ReorderableListView.builder(
                    key: const Key('add_memory_strip'),
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    itemCount: photos.length,
                    onReorder: onReorder,
                    proxyDecorator: (child, _, _) => Opacity(
                        opacity: 0.9,
                        child: Transform.scale(scale: 1.04, child: child)),
                    itemBuilder: (context, i) {
                      final photo = photos[i];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(photo.id),
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _PhotoTile(
                            photo: photo,
                            index: i,
                            width: _tile - 12,
                            onRemove: () => onRemove(photo.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStrip extends StatelessWidget {
  const _EmptyStrip();

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: Colors.white.withValues(alpha: 0.02),
        ),
        child: const Text(
          'Photos you pick appear here, in the order they are saved.',
          textAlign: TextAlign.center,
          style: TextStyle(color: HealthTone.faint, fontSize: 11, height: 1.35),
        ),
      );
}

/// One picked photograph: the frame, the lime remove badge the reference puts
/// at its top right, and the position marker that replaces the reference's
/// video duration — order is what this strip actually decides.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.index,
    required this.width,
    required this.onRemove,
  });

  final PendingPhoto photo;
  final int index;
  final double width;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.memory(photo.bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          Positioned(
            right: -4,
            top: -4,
            child: Semantics(
              button: true,
              label: 'Remove photo ${index + 1}',
              child: ExcludeSemantics(
                child: InkWell(
                  key: Key('add_memory_remove_${photo.id}'),
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.accent,
                      border: const Border.fromBorderSide(
                          BorderSide(color: Color(0xFF06110A), width: 1.6)),
                    ),
                    child: const Icon(LucideIcons.x,
                        size: 13, color: Color(0xFF06110A)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Privacy
// ---------------------------------------------------------------------------

class _AudienceRow extends StatelessWidget {
  const _AudienceRow({required this.selected, required this.onSelect});

  final MemoryAudience selected;
  final ValueChanged<MemoryAudience> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in MemoryAudience.values) ...[
            if (a != MemoryAudience.values.first) const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: a == selected
                    ? t.accent.withValues(alpha: 0.08)
                    : HealthTone.card,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  key: Key('add_memory_audience_${a.name}'),
                  onTap: () => onSelect(a),
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 10, 6, 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: a == selected
                            ? t.accent
                            : Colors.white.withValues(alpha: 0.08),
                        width: a == selected ? 1.5 : 1,
                      ),
                    ),
                    // Glyph beside the label, as the reference sets it — not
                    // above. The detail line stays short precisely so the
                    // reference's horizontal tile survives readable type.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(a.icon,
                            size: 17,
                            color: a.available
                                ? t.accent
                                : HealthTone.faint),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(a.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: a.available
                                          ? Colors.white
                                          : HealthTone.muted,
                                      fontSize: 12.5,
                                      height: 1.15,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(a.available ? a.detail : 'Soon',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: HealthTone.faint,
                                      fontSize: 10.5,
                                      height: 1.25)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small parts
// ---------------------------------------------------------------------------

/// The date / time lozenge the reference sets two-up under "When did it
/// happen?" — a tinted glyph, the value, and a chevron.
class _StampField extends StatelessWidget {
  const _StampField({
    required this.fieldKey,
    required this.icon,
    required this.value,
    required this.onTap,
    this.soon = false,
  });

  final Key fieldKey;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.022),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: fieldKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(children: [
            Icon(icon, size: 17, color: soon ? HealthTone.faint : t.accent),
            const SizedBox(width: 9),
            Expanded(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: soon ? HealthTone.faint : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            Icon(LucideIcons.chevronDown,
                size: 15,
                color: soon ? HealthTone.faint : HealthTone.muted),
          ]),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 8, 13, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: HealthTone.faint),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      color: HealthTone.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

/// The upload run: one bar for the batch, and a line naming which entry is in
/// flight. Real progress — it counts rows actually written, not a timer.
class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final fraction = total == 0 ? 0.0 : done / total;
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  total <= 1
                      ? 'Saving the memory…'
                      : 'Saving entry ${done + 1 > total ? total : done + 1} '
                          'of $total…',
                  key: const Key('add_memory_progress_label'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            Text('$done/$total',
                style:
                    const TextStyle(color: HealthTone.muted, fontSize: 11.5)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              key: const Key('add_memory_progress'),
              value: fraction,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation<Color>(t.accent),
            ),
          ),
          const SizedBox(height: 9),
          const Text(
              'Each photo is stripped of location data, compressed on this '
              'phone, then uploaded to your own storage.',
              style: TextStyle(
                  color: HealthTone.faint, fontSize: 10.5, height: 1.3)),
        ],
      ),
    );
  }
}
