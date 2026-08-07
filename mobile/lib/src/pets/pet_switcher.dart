import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/living_pet_avatar.dart';
import '../core/pet_display.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import 'active_pet.dart';
import 'pet.dart';
import 'pet_form_screen.dart';
import 'pets_repository.dart';

/// The pet switcher every record surface's header card opens.
///
/// Six mockups draw the same chevron beside the pet's name, and before this it
/// was six different (or missing) behaviours. One sheet, one selection, and the
/// whole surface re-points because [activePetProvider] is what every record
/// query is keyed on.
Future<void> showPetSwitcher(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PetSwitcherSheet(),
  );
}

class _PetSwitcherSheet extends ConsumerWidget {
  const _PetSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsListProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <Pet>[],
        );
    final active = ref.watch(activePetProvider);
    return PawSystemScope(
      system: PawSystem.b,
      child: Container(
        decoration: const BoxDecoration(
          color: HealthTone.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s16, AppSpace.s12, AppSpace.s16, AppSpace.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpace.s16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('Switch pet',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                for (final pet in pets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: HealthRecordRow(
                      key: Key('pet_switch_${pet.id}'),
                      background: pet.id == active?.id
                          ? PawTone.of(context).accent.withValues(alpha: 0.10)
                          : null,
                      leading: HealthRingPortrait(
                        size: 40,
                        portrait: PetPortrait(
                          pet: pet,
                          size: 40,
                          livingAvatar: pet.photoKey == null
                              ? null
                              : LivingPetAvatar(
                                  species: pet.species,
                                  size: 40,
                                  seed: pet.id,
                                  photoKey: pet.photoKey,
                                ),
                        ),
                      ),
                      title: petDisplayName(pet.name),
                      subtitle: [
                        pet.breed?.trim().isNotEmpty == true
                            ? pet.breed!.trim()
                            : speciesName(pet.species),
                        ?petAgeLabel(pet.birthDate),
                      ].join(' · '),
                      chevron: false,
                      trailing: pet.id == active?.id
                          ? Icon(LucideIcons.check,
                              size: 18, color: PawTone.of(context).accent)
                          : null,
                      onTap: () {
                        if (pet.id != null) {
                          ref.read(activePetIdProvider.notifier).select(pet.id!);
                        }
                        Navigator.pop(context);
                      },
                    ),
                  ),
                HealthAddCard(
                  title: 'Add a pet',
                  subtitle: 'Every pet keeps its own record.',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const PetFormScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
