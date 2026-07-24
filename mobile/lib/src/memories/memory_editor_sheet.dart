import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/upload_service.dart' show UploadException;
import '../pets/pet.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'memories_repository.dart';
import 'memory.dart';
import 'memory_media_service.dart';
import 'memory_photo.dart';

/// Opens the frosted create/edit sheet. Returns true when a memory was saved.
Future<bool?> showMemoryEditorSheet(
  BuildContext context, {
  required Pet pet,
  Memory? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MemoryEditorSheet(pet: pet, existing: existing),
  );
}

class MemoryEditorSheet extends ConsumerStatefulWidget {
  const MemoryEditorSheet({super.key, required this.pet, this.existing});

  final Pet pet;
  final Memory? existing;

  @override
  ConsumerState<MemoryEditorSheet> createState() => _MemoryEditorSheetState();
}

class _MemoryEditorSheetState extends ConsumerState<MemoryEditorSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _takenOn = widget.existing?.takenOn ?? DateTime.now();

  Uint8List? _pickedBytes; // freshly picked (pre-upload) photo
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;
  bool get _hasPhoto => _pickedBytes != null || _isEdit;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _error = null);
    try {
      final bytes = await ref.read(memoryMediaServiceProvider).pick(source);
      if (bytes != null && mounted) setState(() => _pickedBytes = bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the picker. Please try again.');
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _takenOn,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _takenOn = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give this memory a title.');
      return;
    }
    if (!_hasPhoto) {
      setState(() => _error = 'Add a photo — memories live on pictures.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(memoriesRepositoryProvider);
    final media = ref.read(memoryMediaServiceProvider);
    try {
      final note = _note.text.trim();
      if (_isEdit) {
        final existing = widget.existing!;
        var storageKey = existing.storageKey;
        if (_pickedBytes != null) {
          storageKey = await media.compressAndUpload(_pickedBytes!);
        }
        await repo.update(
          existing.id!,
          existing.copyWith(
            title: title,
            note: note.isEmpty ? null : note,
            storageKey: storageKey,
            takenOn: _takenOn,
          ),
        );
        if (_pickedBytes != null && storageKey != existing.storageKey) {
          // Replaced photo: sweep the old object (best-effort).
          await repo.deleteObject(existing.storageKey);
        }
      } else {
        final storageKey = await media.compressAndUpload(_pickedBytes!);
        await repo.create(Memory(
          userId: '', // repository injects auth.uid()
          petId: widget.pet.id!,
          title: title,
          note: note.isEmpty ? null : note,
          storageKey: storageKey,
          takenOn: _takenOn,
        ));
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
          _error = 'Could not save the memory. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppGlass.sheetBlur, sigmaY: AppGlass.sheetBlur),
          child: Container(
            color: scheme.surface.withValues(alpha: AppGlass.sheetOpacity),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpace.s12),
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      _isEdit ? 'Edit memory' : 'New memory',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpace.s16),
                    _PhotoArea(
                      pickedBytes: _pickedBytes,
                      existingKey: widget.existing?.storageKey,
                    ),
                    const SizedBox(height: AppSpace.s12),
                    Row(
                      children: [
                        Expanded(
                          child: PawSecondaryButton(
                            key: const Key('memory_camera_button'),
                            icon: Icons.photo_camera_rounded,
                            onPressed:
                                _saving ? null : () => _pick(ImageSource.camera),
                            child: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: AppSpace.s8),
                        Expanded(
                          child: PawSecondaryButton(
                            key: const Key('memory_gallery_button'),
                            icon: Icons.photo_library_rounded,
                            onPressed: _saving
                                ? null
                                : () => _pick(ImageSource.gallery),
                            child: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s16),
                    TextField(
                      key: const Key('memory_title_field'),
                      controller: _title,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'First day at the beach',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: AppSpace.s12),
                    TextField(
                      key: const Key('memory_note_field'),
                      controller: _note,
                      maxLength: 600,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'What made this moment special?',
                        counterText: '',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s12),
                    OutlinedButton.icon(
                      key: const Key('memory_date_button'),
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.event_rounded),
                      label: Text(_dateLabel(_takenOn)),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpace.s12),
                      Text(
                        _error!,
                        key: const Key('memory_error'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.error),
                      ),
                    ],
                    const SizedBox(height: AppSpace.s16),
                    PawPrimaryButton(
                      key: const Key('memory_save_button'),
                      icon: _saving ? null : Icons.favorite_rounded,
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEdit ? 'Save changes' : 'Save memory'),
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

class _PhotoArea extends StatelessWidget {
  const _PhotoArea({required this.pickedBytes, required this.existingKey});

  final Uint8List? pickedBytes;
  final String? existingKey;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (pickedBytes != null) {
      child = Image.memory(pickedBytes!, fit: BoxFit.cover);
    } else if (existingKey != null) {
      child = MemoryPhoto(storageKey: existingKey!);
    } else {
      child = Container(
        key: const Key('memory_photo_placeholder'),
        decoration: BoxDecoration(
          color: PawPalette.teal.withValues(alpha: 0.10),
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: PawPalette.mint.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_rounded,
                size: 40, color: PawPalette.mint),
            const SizedBox(height: AppSpace.s8),
            Text(
              'Add a photo',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: PawPalette.mint),
            ),
          ],
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(borderRadius: AppRadius.brMd, child: child),
    );
  }
}

String _dateLabel(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
