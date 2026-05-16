/// Single-screen pet creation form. Auto-saves the in-progress draft to
/// SharedPreferences so a backgrounded session does not lose state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/models/pet.dart';
import '../../shared/providers/auth_provider.dart';
import '../pets/pets_controller.dart';
import 'onboarding_controller.dart';

class OnboardingPetScreen extends ConsumerWidget {
  const OnboardingPetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(sharedPreferencesProvider);
    return prefsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Could not load saved progress: $e')),
      ),
      data: (_) => const _PetForm(),
    );
  }
}

class _PetForm extends ConsumerStatefulWidget {
  const _PetForm();

  @override
  ConsumerState<_PetForm> createState() => _PetFormState();
}

class _PetFormState extends ConsumerState<_PetForm> {
  late final TextEditingController _name;
  late final TextEditingController _breed;
  late final TextEditingController _weight;
  late final TextEditingController _notes;
  String? _submitError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingControllerProvider);
    _name = TextEditingController(text: draft.name ?? '');
    _breed = TextEditingController(text: draft.breed ?? '');
    _weight = TextEditingController(text: draft.weightKg?.toString() ?? '');
    _notes = TextEditingController(text: draft.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _updateDraft(OnboardingDraft Function(OnboardingDraft) f) {
    final current = ref.read(onboardingControllerProvider);
    ref.read(onboardingControllerProvider.notifier).update(f(current));
  }

  Future<void> _pickBirthDate() async {
    final draft = ref.read(onboardingControllerProvider);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          draft.birthDate ?? DateTime(now.year - 1, now.month, now.day),
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (picked != null) {
      _updateDraft((d) => d.copyWith(birthDate: picked));
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final auth = ref.read(authStateProvider);
    if (auth is! Authenticated) {
      setState(() => _submitError = 'You need to be signed in to save a pet.');
      return;
    }
    final draft = ref.read(onboardingControllerProvider);
    final error = draft.validate();
    if (error != null) {
      setState(() => _submitError = error);
      return;
    }
    setState(() {
      _submitError = null;
      _submitting = true;
    });
    try {
      await ref
          .read(petsControllerProvider.notifier)
          .create(
            PetCreate(
              userId: auth.user.id,
              name: draft.name!.trim(),
              species: draft.species!,
              breed: draft.breed?.trim(),
              birthDate: draft.birthDate,
              sex: draft.sex,
              weightKg: draft.weightKg,
              medicalNotes: draft.notes?.trim(),
            ),
          );
      await ref.read(onboardingControllerProvider.notifier).clear();
      if (mounted) {
        // The router will redirect to /home once petsState reflects the
        // new pet.  Push directly to /home for snappiness.
        context.go('/home');
      }
    } on PetCreateFailure catch (e) {
      setState(() {
        _submitError = e.message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = ref.watch(onboardingControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tell us about your pet')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Species', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _SpeciesPicker(
                value: draft.species,
                onChanged: (s) => _updateDraft((d) => d.copyWith(species: s)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: "Pet's name",
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _updateDraft((d) => d.copyWith(name: v)),
              ),
              const SizedBox(height: 16),
              _DateField(
                label: 'Birth date',
                value: draft.birthDate,
                onTap: _pickBirthDate,
                onClear: () =>
                    _updateDraft((d) => d.copyWith(clearBirthDate: true)),
              ),
              const SizedBox(height: 16),
              _SexPicker(
                value: draft.sex,
                onChanged: (s) => _updateDraft((d) => d.copyWith(sex: s)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg) — optional',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  _updateDraft(
                    (d) => parsed == null
                        ? d.copyWith(clearWeight: true)
                        : d.copyWith(weightKg: parsed),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _breed,
                decoration: const InputDecoration(
                  labelText: 'Breed — optional',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _updateDraft((d) => d.copyWith(breed: v)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Anything we should know? — optional',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
                onChanged: (v) => _updateDraft((d) => d.copyWith(notes: v)),
              ),
              const SizedBox(height: 24),
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _submitError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeciesPicker extends StatelessWidget {
  const _SpeciesPicker({required this.value, required this.onChanged});

  final PetSpecies? value;
  final ValueChanged<PetSpecies> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in PetSpecies.values)
          ChoiceChip(
            label: Text('${s.emoji} ${s.displayName}'),
            selected: value == s,
            onSelected: (_) => onChanged(s),
          ),
      ],
    );
  }
}

class _SexPicker extends StatelessWidget {
  const _SexPicker({required this.value, required this.onChanged});

  final PetSex? value;
  final ValueChanged<PetSex> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final s in PetSex.values)
          ChoiceChip(
            label: Text(s.displayName),
            selected: value == s,
            onSelected: (_) => onChanged(s),
          ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Tap to choose'
        : DateFormat.yMMMd().format(value!);
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? null
              : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        ),
        child: Text(text),
      ),
    );
  }
}
