import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/analysis_service.dart';
import '../core/app_views.dart';
import '../core/living_pet_avatar.dart';
import '../core/motion.dart';
import '../core/pet_display.dart';
import '../theme/design_tokens.dart';
import 'add_pet_flow.dart';
import 'pet.dart';
import 'pet_form_screen.dart';
import 'pets_repository.dart';

class PetsListScreen extends ConsumerWidget {
  const PetsListScreen({super.key});

  Future<void> _openForm(BuildContext context, {Pet? pet}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)),
    );
  }

  // Confirm step is PRESERVED (soft-delete keeps past analyses).
  Future<bool> _confirmDelete(BuildContext context, Pet pet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${petDisplayName(pet.name)}?'),
        content: const Text('This hides the pet. Past analyses are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    return confirm == true;
  }

  Future<void> _doDelete(WidgetRef ref, Pet pet) async {
    await ref.read(petsRepositoryProvider).softDelete(pet.id!);
    ref.invalidate(petsListProvider);
  }

  void _longPressMenu(BuildContext context, WidgetRef ref, Pet pet) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _openForm(context, pet: pet);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (await _confirmDelete(context, pet)) await _doDelete(ref, pet);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My pets')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_pet_fab'),
        // Tier-gated (Free/Premium = 2, Family = unlimited) + fires multi_pet_added.
        onPressed: () => startAddPetFlow(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add pet'),
      ),
      body: pets.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpace.s16),
          child: Column(
            children: [
              SkeletonCard(height: 64),
              SizedBox(height: AppSpace.s8),
              SkeletonCard(height: 64),
            ],
          ),
        ),
        error: (e, _) => AppErrorView(
          message: 'Could not load your pets.',
          onRetry: () => ref.invalidate(petsListProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return AppEmptyView(
              icon: Icons.pets_rounded,
              message: 'No pets yet.\nAdd your first companion to get started.',
              action: FilledButton.icon(
                onPressed: () => startAddPetFlow(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add a pet'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final pet = list[i];
              final tile = Dismissible(
                key: ValueKey('pet_${pet.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
                  child: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                confirmDismiss: (_) => _confirmDelete(context, pet),
                onDismissed: (_) => _doDelete(ref, pet),
                child: _PetListTile(
                  pet: pet,
                  onTap: () => _openForm(context, pet: pet),
                  onLongPress: () => _longPressMenu(context, ref, pet),
                ),
              );
              if (reduceMotion(context)) return tile;
              return tile
                  .animate()
                  .fadeIn(
                      duration: AppMotion.standard,
                      delay: Duration(milliseconds: 40 * i))
                  .slideX(begin: 0.05, end: 0, curve: AppMotion.emphasized);
            },
          );
        },
      ),
    );
  }
}

/// A pet row with species-tinted identity, meta (species · breed · age), and a
/// last-check chip (§3.7.1). Photo identity (a real picker) is a separate
/// feature — the species avatar gives identity today via [AppImage] fallback.
class _PetListTile extends ConsumerWidget {
  const _PetListTile({required this.pet, required this.onTap, required this.onLongPress});
  final Pet pet;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  String _meta() {
    final parts = <String>[speciesName(pet.species)];
    if (pet.breed != null && pet.breed!.trim().isNotEmpty) parts.add(pet.breed!.trim());
    final age = _age(pet.birthDate);
    if (age != null) parts.add(age);
    return parts.join(' · ');
  }

  static String? _age(DateTime? birth) {
    if (birth == null) return null;
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    if (years >= 1) return '$years yr';
    var months = (now.year - birth.year) * 12 + now.month - birth.month;
    if (now.day < birth.day) months--;
    months = months.clamp(0, 11);
    return '$months mo';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lastTriage = ref.watch(latestTriageProvider(pet.id!));
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      // M2 (#9): living species avatar; per-pet seed de-syncs blink phases so
      // rows never blink in unison; offscreen rows pause via visibility.
      leading: LivingPetAvatar(species: pet.species, size: 44, seed: pet.id),
      title: Text(petDisplayName(pet.name)),
      subtitle: Text(_meta()),
      // F-4: the last-check chip — fed by latestTriageProvider, which the
      // analysis runner now invalidates on completion, so it can't go stale.
      trailing: lastTriage.maybeWhen(
        data: (t) => t == null
            ? null
            : Chip(
                key: ValueKey('last_check_chip_${pet.id}'),
                label: Text(t.level, style: Theme.of(context).textTheme.labelSmall),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                backgroundColor: scheme.secondaryContainer,
              ),
        orElse: () => null,
      ),
    );
  }
}
