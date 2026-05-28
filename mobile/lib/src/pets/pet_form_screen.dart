import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pet.dart';
import 'pets_repository.dart';

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
  late final TextEditingController _clientName;
  late String _species;
  DateTime? _birthDate;
  bool _saving = false;
  bool _journalEnabled = false;

  bool get _isEdit => widget.pet != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.pet?.name ?? '');
    _breed = TextEditingController(text: widget.pet?.breed ?? '');
    _clientName = TextEditingController(text: widget.pet?.clientName ?? '');
    _species = widget.pet?.species ?? kSpecies.first;
    _birthDate = widget.pet?.birthDate;
    _journalEnabled = widget.pet?.isJournalEnabled ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _clientName.dispose();
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
      isJournalEnabled: _journalEnabled,
      clientName: _clientName.text.trim().isEmpty ? null : _clientName.text.trim(),
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
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('pet_name_field'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            const Text('Species'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in kSpecies)
                  ChoiceChip(
                    label: Text(speciesLabel(s)),
                    selected: _species == s,
                    onSelected: (_) => setState(() => _species = s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _breed,
              decoration: const InputDecoration(labelText: 'Breed (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            // Phase 5.4 — B2B-Lite sitter mode: free-text client label. Useful
            // for sitters managing several owners' pets under one account.
            TextFormField(
              key: const Key('pet_client_name_field'),
              controller: _clientName,
              decoration: const InputDecoration(
                labelText: 'Client name (optional — sitter mode)',
                helperText: 'Tag whose pet this is, e.g. "Smith family". Visible only to you.',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              key: const Key('pet_journal_toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Weekly AI Health Journal'),
              subtitle: const Text(
                  'Get an AI-written summary of your pet’s week every Sunday (Premium / Family).'),
              value: _journalEnabled,
              onChanged: (v) => setState(() => _journalEnabled = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('pet_save_button'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : (_isEdit ? 'Save changes' : 'Add pet')),
            ),
          ],
        ),
      ),
    );
  }
}
