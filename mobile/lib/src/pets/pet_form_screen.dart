import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../capture/image_compressor.dart';
import '../core/dates.dart';
import '../core/living_pet_avatar.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../health/health_sections.dart';
import '../health/history_timeline_screen.dart';
import '../home/home_sections.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'pet.dart';
import 'pet_photo_crop_screen.dart';
import 'pet_photo_service.dart';
import 'pets_repository.dart';

/// Add or edit a pet, rebuilt against mockup `edit_pet`.
///
/// Identity card, Basic Information, Additional Information, Profile Photo, the
/// health-summary strip and the Cancel / Save pair — over the app's bottom
/// navigation. Pass an existing [pet] to edit; null to create.
///
/// Rebuilt **in place**, so every caller keeps working: the pets list, the
/// add-pet flow, the profile's Edit pill and the six "View Profile" surfaces.
///
/// ## What the mockup asks for that `pets` cannot store
///
/// The reference draws **Neutered**, **Colour**, **Microchip ID**, **Blood
/// Type** and **Pet Personality**. There is no column for any of them, and
/// there is nowhere honest to put them — folding a microchip number into
/// `medical_notes` would push it into the vet report as a clinical note.
///
/// Rather than delete the fields, each keeps its exact position in the grid,
/// renders as a real (disabled) control and says *Soon*. Adding the columns is
/// a migration plus an RLS review plus a deploy, all founder-gated.
///
/// Everything else writes: name, species, breed, sex, date of birth, weight,
/// notes and the photo — through the same pick → crop → EXIF-strip → presigned
/// PUT pipeline the form has always used, including the orphan sweep that stops
/// an abandoned edit leaving paid-for storage behind.
class PetFormScreen extends ConsumerStatefulWidget {
  const PetFormScreen({super.key, this.pet});

  final Pet? pet;

  @override
  ConsumerState<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends ConsumerState<PetFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _breed;
  late final TextEditingController _weight;
  late final TextEditingController _medicalNotes;
  late String _species;
  String? _sex;
  DateTime? _birthDate;
  bool _saving = false;

  /// Set once a save is attempted, so the name error appears on submit rather
  /// than scolding an empty form the moment it opens.
  bool _submitted = false;

  /// The photo as the form currently shows it. Uploaded immediately on pick so
  /// the preview is the real thing; the row only points at it on save.
  String? _photoKey;

  /// Keys uploaded during this edit that the pet no longer points at. Swept on
  /// save (replaced originals) or on cancel (everything picked this session),
  /// so abandoning the form cannot leave paid-for storage behind.
  final _orphanedKeys = <String>[];
  bool _photoBusy = false;

  bool get _isEdit => widget.pet != null;

  List<TextEditingController> get _controllers =>
      [_name, _breed, _weight, _medicalNotes];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.pet?.name ?? '');
    _breed = TextEditingController(text: widget.pet?.breed ?? '');
    _weight =
        TextEditingController(text: widget.pet?.weightKg?.toString() ?? '');
    _medicalNotes =
        TextEditingController(text: widget.pet?.medicalNotes ?? '');
    _species = widget.pet?.species ?? kSpecies.first;
    _sex = widget.pet?.sex;
    _birthDate = widget.pet?.birthDate;
    _photoKey = widget.pet?.photoKey;
    // The Save CTA, the age readout and the clear affordances all depend on
    // what is typed.
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

  String? get _nameError =>
      _name.text.trim().isEmpty ? 'Give your pet a name to save this.' : null;

  String? get _weightError {
    final t = _weight.text.trim();
    if (t.isEmpty) return null;
    final n = double.tryParse(t.replaceAll(',', '.'));
    if (n == null || n <= 0 || n > 200) {
      return 'Enter a weight in kg, for example 12.5.';
    }
    return null;
  }

  String? get _blocker => _nameError ?? _weightError;

  // -------------------------------------------------------------------------
  // Photo
  // -------------------------------------------------------------------------

  /// Pick → frame → upload. The upload happens before save so the preview is
  /// the real, cropped, EXIF-stripped image rather than a local placeholder.
  Future<void> _choosePhoto(ImageSource source) async {
    final service = ref.read(petPhotoServiceProvider);
    setState(() => _photoBusy = true);
    try {
      final raw = await service.pick(source);
      if (raw == null || !mounted) return;

      final crop = await Navigator.of(context).push<SquareCrop>(
        MaterialPageRoute(
          builder: (_) => PetPhotoCropScreen(
            bytes: raw,
            petName: _name.text.trim().isEmpty ? null : _name.text.trim(),
          ),
        ),
      );
      if (crop == null || !mounted) return;

      final key = await service.cropAndUpload(raw, crop);
      if (!mounted) return;
      setState(() {
        // The previous key is not deleted yet — the row still points at it
        // until this form saves.
        if (_photoKey != null) _orphanedKeys.add(_photoKey!);
        _photoKey = key;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't add that photo. Please try again."),
        ));
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _removePhoto() {
    setState(() {
      if (_photoKey != null) _orphanedKeys.add(_photoKey!);
      _photoKey = null;
    });
  }

  Future<void> _photoSheet() async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Profile photo',
        children: [
          HealthRecordRow(
            key: const Key('pet_photo_camera'),
            leading: HealthGlyphDisc(
                icon: LucideIcons.camera,
                tint: PawTone.of(context).accent,
                size: 36),
            title: 'Take a photo',
            subtitle: 'Use the camera now',
            onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.camera),
          ),
          HealthRecordRow(
            key: const Key('pet_photo_gallery'),
            leading: HealthGlyphDisc(
                icon: LucideIcons.image,
                tint: PawTone.of(context).accent,
                size: 36),
            title: 'Choose from gallery',
            subtitle: 'Location data is stripped before upload',
            onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.gallery),
          ),
          if (_photoKey != null)
            HealthRecordRow(
              key: const Key('pet_photo_remove'),
              leading: const HealthGlyphDisc(
                  icon: LucideIcons.trash2, tint: HealthTone.gold, size: 36),
              title: 'Remove photo',
              subtitle: 'Falls back to the species portrait',
              onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.remove),
            ),
        ],
      ),
    );
    switch (action) {
      case null:
        return;
      case _PhotoAction.camera:
        await _choosePhoto(ImageSource.camera);
      case _PhotoAction.gallery:
        await _choosePhoto(ImageSource.gallery);
      case _PhotoAction.remove:
        _removePhoto();
    }
  }

  // -------------------------------------------------------------------------
  // Save / delete
  // -------------------------------------------------------------------------

  Future<void> _save() async {
    setState(() => _submitted = true);
    final blocker = _blocker;
    if (blocker != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(blocker)));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(petsRepositoryProvider);
    final draft = (widget.pet ??
            Pet(userId: '', name: _name.text.trim(), species: _species))
        .copyWith(
      name: _name.text.trim(),
      species: _species,
      breed: _breed.text.trim().isEmpty ? null : _breed.text.trim(),
      birthDate: _birthDate,
      sex: _sex,
      weightKg: double.tryParse(_weight.text.trim().replaceAll(',', '.')),
      photoKey: _photoKey,
      clearPhotoKey: _photoKey == null,
      medicalNotes: _medicalNotes.text.trim().isEmpty
          ? null
          : _medicalNotes.text.trim(),
    );
    try {
      if (_isEdit) {
        await repo.update(widget.pet!.id!, draft);
      } else {
        await repo.create(draft);
      }
      // The row now points at the surviving key, so anything it replaced is
      // safe to delete. Best-effort: a failed sweep leaves an object the
      // account-deletion purge collects, never a broken save.
      final sweep = ref.read(petPhotoServiceProvider);
      for (final key in _orphanedKeys) {
        await sweep.discard(key);
      }
      _orphanedKeys.clear();
      ref.invalidate(petsListProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save the pet. Please try again.')));
        setState(() => _saving = false);
      }
    }
  }

  /// **Soft delete.** `is_active = false` keeps every past analysis and health
  /// record rather than firing the cascade — the confirmation says so, because
  /// "delete" and "hide, keeping the record" are very different promises.
  Future<void> _delete() async {
    final pet = widget.pet;
    if (pet?.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${petDisplayName(pet!.name)}?'),
        content: Text(
          '${petDisplayName(pet.name)} disappears from the app. Past health '
          'records and AI checks are kept, so nothing you have filed is lost.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              key: const Key('pet_delete_confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(petsRepositoryProvider).softDelete(pet!.id!);
    ref.invalidate(petsListProvider);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _cancel() async {
    // Everything picked this session is dropped, so backing out of the form
    // cannot leave an uploaded object nothing points at.
    final sweep = ref.read(petPhotoServiceProvider);
    final orphans = [
      ..._orphanedKeys,
      if (_photoKey != null && _photoKey != widget.pet?.photoKey) _photoKey!,
    ];
    for (final key in orphans) {
      await sweep.discard(key);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$what is not stored yet — it is coming soon.')));
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 1),
      firstDate: DateTime(now.year - 40),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _pickSpecies() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Species',
        scrollable: true,
        children: [
          for (final s in kSpecies)
            HealthRecordRow(
              key: Key('pet_species_$s'),
              leading: HealthGlyphDisc(
                icon: LucideIcons.pawPrint,
                tint: s == _species
                    ? PawTone.of(context).accent
                    : HealthTone.info,
                size: 36,
              ),
              title: speciesName(s),
              subtitle: s == _species ? 'Selected' : null,
              chevron: false,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _species = s);
              },
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final age = petAgeLabel(_birthDate);
    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          title: _isEdit ? 'Edit Pet' : 'Add a Pet',
          subtitle: _isEdit ? 'Update ' : 'Tell PawDoc about ',
          subtitleTrail: _isEdit
              ? '${petDisplayPossessive(widget.pet!.name)} information'
              : 'your pet',
          actionsWidth: _isEdit ? 118 : 48,
          onBack: _cancel,
          actions: [
            if (_isEdit)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: HealthActionPill(
                  key: const Key('pet_delete'),
                  label: 'Delete Pet',
                  icon: LucideIcons.trash2,
                  dense: true,
                  // The mockup paints this in the EMERGENCY red. That red means
                  // GET_HELP_NOW everywhere else in the app — including the nav
                  // bar six centimetres below — and the ladder's hues are
                  // locked against reuse. Gold is the substitute the vaccine
                  // and reminder screens already use for "needs your
                  // attention", and the confirmation carries the weight.
                  color: HealthTone.gold,
                  onTap: _delete,
                ),
              ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        footer: _FooterActions(
          saving: _saving,
          isEdit: _isEdit,
          blocked: _submitted && _blocker != null,
          onCancel: _cancel,
          onSave: _saving ? null : _save,
        ),
        children: [
          gap(2),
          _IdentityCard(
            species: _species,
            petId: widget.pet?.id,
            photoKey: _photoKey,
            busy: _photoBusy,
            nameController: _name,
            nameError: _submitted ? _nameError : null,
            onPhoto: _photoBusy ? null : _photoSheet,
          ),
          gap(9),
          _SectionCard(
            icon: LucideIcons.fileText,
            title: 'Basic Information',
            children: [
              _Pair(
                left: HealthPickerField(
                  fieldKey: const Key('pet_species_value'),
                  icon: LucideIcons.pawPrint,
                  label: 'Species',
                  value: speciesName(_species),
                  onTap: _pickSpecies,
                ),
                right: HealthTextField(
                  fieldKey: const Key('pet_breed_field'),
                  controller: _breed,
                  icon: LucideIcons.dog,
                  label: 'Breed',
                  // A hint that can never equal the value: `hintText` stays in
                  // the tree at zero opacity once a field is filled, so a hint
                  // spelled like real data reads as a duplicate to anything
                  // walking the widget tree — a test, or a screen reader.
                  hint: 'e.g. Labrador',
                ),
              ),
              _Pair(
                left: HealthChoiceField(
                  icon: LucideIcons.venusAndMars,
                  label: 'Sex',
                  value: switch (_sex) {
                    'male' => 'Male',
                    'female' => 'Female',
                    _ => null,
                  },
                  options: const ['Male', 'Female'],
                  onSelect: (v) => setState(() => _sex = switch (v) {
                        'Male' => 'male',
                        'Female' => 'female',
                        _ => null,
                      }),
                ),
                // The mockup's Yes/No pair. No column, so it draws and says so.
                right: _SoonField(
                  key: const Key('pet_neutered_soon'),
                  icon: LucideIcons.scissors,
                  label: 'Neutered',
                  onTap: () => _soon('Whether your pet is neutered'),
                ),
              ),
              _Pair(
                left: HealthPickerField(
                  fieldKey: const Key('pet_dob_field'),
                  icon: LucideIcons.calendarDays,
                  label: 'Date of birth',
                  value:
                      _birthDate == null ? 'Not set' : shortDate(_birthDate!),
                  muted: _birthDate == null,
                  onTap: _pickBirthDate,
                  onClear: _birthDate == null
                      ? null
                      : () => setState(() => _birthDate = null),
                ),
                // Read-only, exactly as the mockup marks it "(Calculated)".
                right: HealthFieldShell(
                  icon: LucideIcons.cake,
                  label: 'Age',
                  child: Row(children: [
                    Flexible(
                      child: Text(age == null ? 'Set a birthday' : '$age old',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: age == null
                                  ? HealthTone.faint
                                  : Colors.white,
                              fontSize: 14,
                              height: 1.25)),
                    ),
                    if (age != null) ...[
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text('Calculated',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: PawTone.of(context).accent,
                                fontSize: 11)),
                      ),
                    ],
                  ]),
                ),
              ),
              _Pair(
                left: HealthTextField(
                  fieldKey: const Key('pet_weight_field'),
                  controller: _weight,
                  icon: LucideIcons.scale,
                  label: 'Weight (kg)',
                  hint: 'e.g. 12.5',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                right: _SoonField(
                  key: const Key('pet_colour_soon'),
                  icon: LucideIcons.palette,
                  label: 'Colour',
                  onTap: () => _soon('Coat colour'),
                ),
              ),
              if (_submitted && _weightError != null)
                _FieldError(text: _weightError!),
              _SoonField(
                key: const Key('pet_microchip_soon'),
                icon: LucideIcons.scanLine,
                label: 'Microchip ID',
                onTap: () => _soon('The microchip number'),
              ),
            ],
          ),
          gap(9),
          _SectionCard(
            icon: LucideIcons.info,
            title: 'Additional Information',
            children: [
              _Pair(
                left: _SoonField(
                  key: const Key('pet_blood_soon'),
                  icon: LucideIcons.droplet,
                  label: 'Blood type',
                  onTap: () => _soon('Blood type'),
                ),
                right: _SoonField(
                  key: const Key('pet_personality_soon'),
                  icon: LucideIcons.smile,
                  label: 'Personality',
                  onTap: () => _soon('Personality traits'),
                ),
              ),
              HealthNotesField(
                controller: _medicalNotes,
                label: 'Notes',
                hint: 'Allergies, a chronic condition, how they are at the '
                    'vet…',
              ),
              const _NotesHint(),
            ],
          ),
          gap(9),
          _PhotoCard(
            species: _species,
            petId: widget.pet?.id,
            photoKey: _photoKey,
            busy: _photoBusy,
            onTap: _photoBusy ? null : _photoSheet,
            onRemove: _photoKey == null ? null : _removePhoto,
          ),
          gap(9),
          _HealthSummaryStrip(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HealthHistoryScreen()),
            ),
          ),
          gap(8),
        ],
      ),
    );
  }
}

/// What the photo sheet asked for.
enum _PhotoAction { camera, gallery, remove }

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.species,
    required this.petId,
    required this.photoKey,
    required this.busy,
    required this.nameController,
    required this.nameError,
    required this.onPhoto,
  });

  final String species;
  final String? petId;
  final String? photoKey;
  final bool busy;
  final TextEditingController nameController;
  final String? nameError;
  final VoidCallback? onPhoto;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final name = nameController.text.trim();
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhotoWell(
            species: species,
            petId: petId,
            photoKey: photoKey,
            busy: busy,
            onTap: onPhoto,
            size: 84,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                HealthTextField(
                  fieldKey: const Key('pet_name_field'),
                  controller: nameController,
                  icon: LucideIcons.pawPrint,
                  label: 'Pet name',
                  hint: 'What you call them',
                ),
                if (nameError != null) _FieldError(text: nameError!),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: t.accent.withValues(alpha: 0.06),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.pawPrint, size: 14, color: t.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name.isEmpty
                              ? 'This is how your pet will appear in the app.'
                              : 'This is how ${petDisplayName(name)} will '
                                  'appear in the app.',
                          style: const TextStyle(
                              color: HealthTone.dim,
                              fontSize: 11,
                              height: 1.3),
                        ),
                      ),
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

/// The ringed portrait with the camera badge, shared by the identity card and
/// the Profile Photo card.
class _PhotoWell extends StatelessWidget {
  const _PhotoWell({
    required this.species,
    required this.petId,
    required this.photoKey,
    required this.busy,
    required this.onTap,
    this.size = 84,
  });

  final String species;
  final String? petId;
  final String? photoKey;
  final bool busy;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Semantics(
      button: true,
      label: photoKey == null
          ? 'Add a photo of your pet'
          : "Change or remove your pet's photo",
      child: ExcludeSemantics(
        child: InkWell(
          key: const Key('pet_photo_button'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size + 6,
            height: size + 6,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: t.accent, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: t.accent.withValues(alpha: 0.28),
                            blurRadius: 14),
                      ],
                    ),
                    child: Center(
                      child: ClipOval(
                        child: SizedBox(
                          width: size - 8,
                          height: size - 8,
                          // The same portrait every other surface draws. The
                          // form used to render `LivingPetAvatar` directly,
                          // whose no-photo fallback is the cartoon paw pal —
                          // so a pet with no photo looked like a different
                          // animal here than on its own profile.
                          child: PetPortrait(
                            key: ValueKey('form_pal_${photoKey ?? species}'),
                            pet: Pet(
                              userId: '',
                              name: '',
                              species: species,
                              photoKey: photoKey,
                            ),
                            size: size - 8,
                            livingAvatar: photoKey == null
                                ? null
                                : LivingPetAvatar(
                                    species: species,
                                    size: size - 8,
                                    seed: petId,
                                    photoKey: photoKey,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 2,
                  child: Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.accent,
                      border: const Border.fromBorderSide(
                          BorderSide(color: Color(0xFF0A0F0B), width: 2)),
                    ),
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF06110A)),
                          )
                        : Icon(
                            photoKey == null
                                ? LucideIcons.camera
                                : LucideIcons.pencil,
                            size: 13,
                            color: const Color(0xFF06110A),
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

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading: Icon(icon, size: 17, color: t.accent),
            title: title,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Two fields side by side, as the mockup lays the grid out.
class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight so a two-line field does not leave its neighbour short,
    // and so neither is handed an unbounded height by the stretch.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 8),
          Expanded(child: right),
        ],
      ),
    );
  }
}

/// A field the mockup draws and `pets` cannot store.
///
/// Rendered as the real control, in its real place, disabled and labelled —
/// never removed. Tapping says what is missing rather than doing nothing.
class _SoonField extends StatelessWidget {
  const _SoonField({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HealthFieldShell(
      icon: icon,
      label: label,
      onTap: onTap,
      trailing: const Padding(
        padding: EdgeInsets.only(top: 8, right: 6),
        child: Icon(LucideIcons.clock, size: 14, color: HealthTone.faint),
      ),
      child: const Text('Soon',
          maxLines: 1,
          style: TextStyle(
              color: HealthTone.faint, fontSize: 14, height: 1.25)),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.circleAlert, size: 13, color: HealthTone.gold),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: HealthTone.gold, fontSize: 11, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class _NotesHint extends StatelessWidget {
  const _NotesHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 4, top: 1),
      child: Text(
        'Allergies, a chronic condition, how they are at the clinic. This is '
        'the one part of the profile your vet report quotes, and it is quoted '
        'as your words.',
        style: TextStyle(color: HealthTone.faint, fontSize: 10.5, height: 1.35),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.species,
    required this.petId,
    required this.photoKey,
    required this.busy,
    required this.onTap,
    required this.onRemove,
  });

  final String species;
  final String? petId;
  final String? photoKey;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading: Icon(LucideIcons.image, size: 17, color: t.accent),
            title: 'Profile Photo',
            actionLabel: photoKey == null ? null : 'Remove',
            actionColor: HealthTone.gold,
            chevron: false,
            onAction: onRemove,
          ),
          const SizedBox(height: 3),
          const Text(
            'One square photo. Location data is stripped on this device before '
            'anything is uploaded.',
            style: TextStyle(color: HealthTone.dim, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _PhotoWell(
                species: species,
                petId: petId,
                photoKey: photoKey,
                busy: busy,
                onTap: onTap,
                size: 74,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  key: const Key('pet_photo_change'),
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 74,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: t.accent.withValues(alpha: 0.05),
                      border:
                          Border.all(color: t.accent.withValues(alpha: 0.45)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            photoKey == null
                                ? LucideIcons.plus
                                : LucideIcons.repeat,
                            size: 19,
                            color: t.accent),
                        const SizedBox(height: 5),
                        Text(photoKey == null ? 'Add Photo' : 'Change Photo',
                            style: TextStyle(
                                color: t.accent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthSummaryStrip extends StatelessWidget {
  const _HealthSummaryStrip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      onTap: onTap,
      child: Row(
        children: [
          Icon(LucideIcons.heartPulse, size: 19, color: t.accent),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Flexible(
                    child: Text('Health Summary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text('Auto-updated',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: t.accent, fontSize: 10.5, height: 1.2)),
                  ),
                ]),
                const SizedBox(height: 1),
                const Text('Records, vaccines and weight are managed from the '
                    'health tab.',
                    style: TextStyle(
                        color: HealthTone.dim, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(LucideIcons.chevronRight, size: 16, color: Colors.white54),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.saving,
    required this.isEdit,
    required this.blocked,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final bool isEdit;
  final bool blocked;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (blocked)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Fix the highlighted field to save.',
                style: TextStyle(color: HealthTone.gold, fontSize: 11)),
          ),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Material(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  key: const Key('pet_cancel_button'),
                  onTap: onCancel,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: Semantics(
                button: true,
                label: isEdit ? 'Save changes' : 'Add pet',
                child: ExcludeSemantics(
                  child: Material(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      key: const Key('pet_save_button'),
                      onTap: onSave,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                                saving
                                    ? LucideIcons.loaderCircle
                                    : LucideIcons.save,
                                size: 16,
                                color: const Color(0xFF06110A)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                    saving
                                        ? 'Saving…'
                                        : (isEdit ? 'Save Changes' : 'Add Pet'),
                                    maxLines: 1,
                                    style: const TextStyle(
                                        color: Color(0xFF06110A),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
