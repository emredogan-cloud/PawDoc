import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_image.dart';
import '../core/motion.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import 'pet.dart';

/// Custom species chip shared by onboarding (§3.2.2) and the pet form (§3.7.2):
/// a branded species icon (with an emoji fallback while the icon asset is being
/// produced) + a plain-text label, with a fill + selection pop and proper
/// screen-reader semantics (fixes the OS-emoji a11y gap). Reduce-motion-aware.
/// How a [SpeciesChip] presents itself.
enum SpeciesChipVariant {
  /// Compact pill: small thumbnail + label. Used in the pet-edit form.
  chip,

  /// Photo card: large portrait above the label, with a check badge when
  /// selected. Matches onboarding mockup `008`, where the picker is the focus
  /// of the screen rather than one field among many.
  card,
}

class SpeciesChip extends StatelessWidget {
  const SpeciesChip({
    super.key,
    required this.species,
    required this.selected,
    required this.onTap,
    this.variant = SpeciesChipVariant.chip,
  });

  final String species;
  final bool selected;
  final VoidCallback onTap;
  final SpeciesChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final animate = !reduceMotion(context);
    if (variant == SpeciesChipVariant.card) {
      return _card(context, scheme, animate);
    }
    Widget icon = AppImage(
      AppAssets.species(species),
      width: 22,
      height: 22,
      fallback: Text(speciesEmoji(species), style: const TextStyle(fontSize: 18)),
    );
    // M2 (#12, "C scale-only" variant): the species icon does ONE micro-beat
    // when its chip becomes selected — ≤400ms, no loop, reduce-motion exempt.
    if (animate && selected) {
      icon = icon
          .animate(key: ValueKey('species_pop_$species'))
          .scaleXY(
              begin: 0.7,
              end: 1.0,
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutBack);
    }

    final chip = AnimatedContainer(
      duration: animate ? AppMotion.standard : Duration.zero,
      curve: AppMotion.standardCurve,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12, vertical: AppSpace.s8),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: AppSpace.s8),
          Text(speciesName(species)),
          if (selected) ...[
            const SizedBox(width: AppSpace.s4),
            Icon(Icons.check_rounded, size: 16, color: scheme.primary),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: speciesName(species),
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.97,
        duration: animate ? AppMotion.micro : Duration.zero,
        curve: Curves.easeOutBack,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: chip,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, ColorScheme scheme, bool animate) {
    // The portrait carries the meaning here, so it gets the space; the label
    // stays because an image-only picker is unusable with a screen reader or
    // when the art has not loaded.
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: true,
      selected: selected,
      label: speciesName(species),
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: animate ? AppMotion.standard : Duration.zero,
          curve: AppMotion.standardCurve,
          width: 104,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : Colors.white.withValues(alpha: 0.10),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.30),
                        blurRadius: 16,
                        spreadRadius: -2)
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: AppImage(
                      AppAssets.species(species),
                      width: 92,
                      height: 84,
                      fit: BoxFit.cover,
                      fallback: SizedBox(
                        width: 92,
                        height: 84,
                        child: Center(
                          child: Text(speciesEmoji(species),
                              style: const TextStyle(fontSize: 30)),
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: scheme.primary, shape: BoxShape.circle),
                        child: Icon(Icons.check_rounded,
                            size: 13, color: scheme.onPrimary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                speciesName(species),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? scheme.primary : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
