import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/living_pet_avatar.dart';
import '../core/pet_display.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/paw_components.dart';
import 'pet.dart';

/// The horizontal "which pet is this about?" rail — a circled portrait over the
/// name and a detail line, the chosen one ringed in the accent with a check
/// badge at its corner.
///
/// `add_memory` and `search_memories` draw exactly the same tile, one with a
/// dashed **New Pet** slot on the end and one with an **All Pets** slot. It
/// lives here rather than in either screen because a second implementation is
/// how two rails end up with different selection semantics — which is what
/// happened to the *other* rail shape, the one `memories_gallery` and
/// `conversation_history` use (portrait beside the name, not above it). That
/// one stays where it is; this is the tall variant.
class PetPickRail extends StatelessWidget {
  const PetPickRail({
    required this.pets,
    required this.selectedId,
    required this.onSelect,
    this.keyPrefix = 'pet_pick',
    this.allPets = false,
    this.onNewPet,
    super.key,
  });

  final List<Pet> pets;

  /// `null` selects the **All Pets** tile when [allPets] is set; otherwise it
  /// simply means nothing is chosen.
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  /// Namespaces the widget keys, so two rails on one screen never collide.
  final String keyPrefix;

  /// Draw the "All Pets" tile at the end, which selects `null`.
  final bool allPets;

  /// Draw the dashed "New Pet" tile at the end.
  final VoidCallback? onNewPet;

  static const double height = 118;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      height: height,
      child: ListView(
        key: Key('${keyPrefix}_rail'),
        scrollDirection: Axis.horizontal,
        children: [
          for (final pet in pets) ...[
            PetPickTile(
              tileKey: Key('${keyPrefix}_${pet.id}'),
              selected: pet.id == selectedId,
              name: petDisplayName(pet.name),
              detail: (pet.breed?.trim().isNotEmpty ?? false)
                  ? pet.breed!.trim()
                  : speciesName(pet.species),
              onTap: () => onSelect(pet.id),
              portrait: ClipOval(
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: PetPortrait(
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
                ),
              ),
            ),
            const SizedBox(width: 9),
          ],
          if (allPets) ...[
            PetPickTile(
              tileKey: Key('${keyPrefix}_all'),
              selected: selectedId == null,
              name: 'All Pets',
              detail: '${pets.length} in the book',
              onTap: () => onSelect(null),
              portrait: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent.withValues(alpha: 0.10),
                ),
                child: Icon(LucideIcons.pawPrint, size: 24, color: t.accent),
              ),
            ),
            const SizedBox(width: 9),
          ],
          if (onNewPet != null)
            SizedBox(
              width: 92,
              child: HealthDashedTile(
                key: Key('${keyPrefix}_new'),
                radius: 15,
                color: Colors.white.withValues(alpha: 0.18),
                onTap: onNewPet,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: t.accent.withValues(alpha: 0.55)),
                      ),
                      child: Icon(LucideIcons.plus, size: 19, color: t.accent),
                    ),
                    const SizedBox(height: 9),
                    const Text('New Pet',
                        style: TextStyle(
                            color: HealthTone.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One stop on a [PetPickRail].
class PetPickTile extends StatelessWidget {
  const PetPickTile({
    required this.tileKey,
    required this.selected,
    required this.name,
    required this.detail,
    required this.portrait,
    required this.onTap,
    super.key,
  });

  final Key tileKey;
  final bool selected;
  final String name;
  final String detail;
  final Widget portrait;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      width: 92,
      child: Material(
        color: selected ? t.accent.withValues(alpha: 0.08) : HealthTone.card,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          key: tileKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color:
                    selected ? t.accent : Colors.white.withValues(alpha: 0.08),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    portrait,
                    const SizedBox(height: 8),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: selected ? t.accent : Colors.white,
                            fontSize: 12.5,
                            height: 1.15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: HealthTone.muted,
                            fontSize: 10.5,
                            height: 1.2)),
                  ],
                ),
                Positioned(
                  right: -1,
                  top: -3,
                  child: selected
                      ? Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.accent,
                          ),
                          child: const Icon(LucideIcons.check,
                              size: 11, color: Color(0xFF06110A)),
                        )
                      : Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22)),
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
