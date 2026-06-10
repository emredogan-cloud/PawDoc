import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_image.dart';
import '../core/motion.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import 'pet.dart';

/// Custom species chip shared by onboarding (§3.2.2) and the pet form (§3.7.2):
/// a branded species icon (with an emoji fallback while the icon asset is being
/// produced) + a plain-text label, with a fill + selection pop and proper
/// screen-reader semantics (fixes the OS-emoji a11y gap). Reduce-motion-aware.
class SpeciesChip extends StatelessWidget {
  const SpeciesChip({
    super.key,
    required this.species,
    required this.selected,
    required this.onTap,
  });

  final String species;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final animate = !reduceMotion(context);
    final icon = AppImage(
      AppAssets.species(species),
      width: 22,
      height: 22,
      fallback: Text(speciesEmoji(species), style: const TextStyle(fontSize: 18)),
    );

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
}
