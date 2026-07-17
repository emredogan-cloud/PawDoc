import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/living_pet_avatar.dart';
import '../core/motion.dart';
import '../theme/design_tokens.dart';
import 'pet.dart';
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
  late String _species;
  DateTime? _birthDate;
  bool _saving = false;

  bool get _isEdit => widget.pet != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.pet?.name ?? '');
    _breed = TextEditingController(text: widget.pet?.breed ?? '');
    _species = widget.pet?.species ?? kSpecies.first;
    _birthDate = widget.pet?.birthDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    super.dispose();
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
    );
    try {
      if (_isEdit) {
        await repo.update(widget.pet!.id!, draft);
      } else {
        await repo.create(draft);
      }
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
            // M2 (#9): living avatar preview (identity) — re-rigs live as the
            // species pick changes. (A real photo picker is separate — see report.)
            Center(
              child: LivingPetAvatar(
                key: ValueKey('form_pal_$_species'),
                species: _species,
                size: 80,
                seed: widget.pet?.id,
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
