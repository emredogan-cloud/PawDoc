import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/image_compressor.dart';
import '../core/living_pet_avatar.dart';
import '../core/motion.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'pet.dart';
import 'pet_photo_crop_screen.dart';
import 'pet_photo_service.dart';
import 'pets_repository.dart';
import 'species_chip.dart';

/// Add or edit a pet. Pass an existing [pet] to edit; null to create.
class PetFormScreen extends ConsumerStatefulWidget {
  const PetFormScreen({super.key, this.pet});

  final Pet? pet;

  @override
  ConsumerState<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends ConsumerState<PetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _breed;
  late final TextEditingController _weight;
  late final TextEditingController _medicalNotes;
  late String _species;
  String? _sex;
  DateTime? _birthDate;
  bool _saving = false;

  /// The photo as the form currently shows it. Uploaded immediately on pick so
  /// the preview is the real thing; the row only points at it on save.
  String? _photoKey;

  /// Keys uploaded during this edit that the pet no longer points at. Swept on
  /// save (replaced originals) or on cancel (everything picked this session),
  /// so abandoning the form cannot leave paid-for storage behind.
  final _orphanedKeys = <String>[];
  bool _photoBusy = false;

  bool get _isEdit => widget.pet != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.pet?.name ?? '');
    _breed = TextEditingController(text: widget.pet?.breed ?? '');
    _weight = TextEditingController(
        text: widget.pet?.weightKg?.toString() ?? '');
    _medicalNotes =
        TextEditingController(text: widget.pet?.medicalNotes ?? '');
    _species = widget.pet?.species ?? kSpecies.first;
    _sex = widget.pet?.sex;
    _birthDate = widget.pet?.birthDate;
    _photoKey = widget.pet?.photoKey;
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _weight.dispose();
    _medicalNotes.dispose();
    super.dispose();
  }

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
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('pet_photo_camera'),
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_PhotoAction.camera),
            ),
            ListTile(
              key: const Key('pet_photo_gallery'),
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_PhotoAction.gallery),
            ),
            if (_photoKey != null)
              ListTile(
                key: const Key('pet_photo_remove'),
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove photo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoAction.remove),
              ),
          ],
        ),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the pet. Please try again.')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit pet' : 'Add a pet')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s16),
          children: [
            // Identity: the owner's own photo when there is one, else the
            // living avatar, which re-rigs live as the species pick changes.
            Center(
              child: Semantics(
                button: true,
                label: _photoKey == null
                    ? 'Add a photo of your pet'
                    : 'Change or remove your pet\'s photo',
                child: InkWell(
                  key: const Key('pet_photo_button'),
                  customBorder: const CircleBorder(),
                  onTap: _photoBusy ? null : _photoSheet,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      LivingPetAvatar(
                        key: ValueKey('form_pal_${_photoKey ?? _species}'),
                        species: _species,
                        size: 96,
                        seed: widget.pet?.id,
                        photoKey: _photoKey,
                      ),
                      Container(
                        padding: const EdgeInsets.all(AppSpace.s4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              colors: [PawPalette.mint, PawPalette.teal]),
                        ),
                        child: _photoBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: PawPalette.bgBottom),
                              )
                            : Icon(
                                _photoKey == null
                                    ? Icons.add_a_photo_rounded
                                    : Icons.edit_rounded,
                                size: 18,
                                color: PawPalette.bgBottom,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s24),
            _section(context, 'Identity'),
            TextFormField(
              key: const Key('pet_name_field'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name', filled: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: AppSpace.s16),
            Text('Species', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final s in kSpecies)
                  SpeciesChip(
                    species: s,
                    selected: _species == s,
                    onTap: () => setState(() => _species = s),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s24),
            _section(context, 'Details'),
            TextFormField(
              controller: _breed,
              decoration: const InputDecoration(labelText: 'Breed (optional)', filled: true),
            ),
            const SizedBox(height: AppSpace.s8),
            // E5: the record fields the vet report reads (sex/weight) are now
            // actually editable — they existed in the DB with no UI for months.
            Text('Sex', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              children: [
                for (final (value, label) in const [
                  ('male', 'Male'),
                  ('female', 'Female'),
                ])
                  ChoiceChip(
                    key: Key('pet_sex_$value'),
                    label: Text(label),
                    selected: _sex == value,
                    onSelected: (sel) =>
                        setState(() => _sex = sel ? value : null),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s16),
            TextFormField(
              key: const Key('pet_weight_field'),
              controller: _weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Weight in kg (optional)', filled: true),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = double.tryParse(t.replaceAll(',', '.'));
                if (n == null || n <= 0 || n > 200) {
                  return 'Enter a weight in kg (e.g. 12.5)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpace.s8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date of birth (optional)'),
              subtitle: Text(_birthDate == null
                  ? 'Not set'
                  : _birthDate!.toIso8601String().split('T').first),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birthDate ?? DateTime(now.year - 1),
                  firstDate: DateTime(now.year - 30),
                  lastDate: now,
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
            ),
            const SizedBox(height: AppSpace.s16),
            TextFormField(
              key: const Key('pet_medical_notes_field'),
              controller: _medicalNotes,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Medical notes (optional)',
                helperText:
                    'Allergies, chronic conditions, medications — appears in the vet report.',
                helperMaxLines: 2,
                filled: true,
              ),
            ),
            const SizedBox(height: AppSpace.s24),
            AppButton(
              key: const Key('pet_save_button'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : (_isEdit ? 'Save changes' : 'Add pet')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );
}

/// What the photo sheet asked for.
enum _PhotoAction { camera, gallery, remove }
