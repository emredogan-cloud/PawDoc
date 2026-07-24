import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pets/pet.dart' show speciesEmoji, speciesName;
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'breed.dart';

/// One breed, presented like a premium field-guide spread: hero photo, stat
/// band, personality, exercise/grooming meters, educational health notes
/// (always closing with the talk-to-your-vet line), facts, and the photo's
/// Commons attribution.
class BreedDetailScreen extends StatelessWidget {
  const BreedDetailScreen({super.key, required this.breed, this.credit});

  final Breed breed;
  final BreedCredit? credit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PawScaffold(
      safeArea: false,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: ListView(
        key: const Key('breed_detail_scroll'),
        padding: EdgeInsets.zero,
        children: [
          Hero(
            tag: 'breed_${breed.id}',
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.asset(
                breed.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: PawPalette.leaf.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: Text(speciesEmoji(breed.species),
                      style: const TextStyle(fontSize: 64)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  breed.name,
                  key: const Key('breed_detail_name'),
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: AppColors.ink50),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  '${speciesEmoji(breed.species)} ${speciesName(breed.species)} · '
                  '${breed.origin}'
                  '${breed.countries.isEmpty ? '' : ' (${breed.countries.join(', ')})'}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.ink300),
                ),
                const SizedBox(height: AppSpace.s16),

                // Stat band.
                PawCard(
                  child: Row(
                    children: [
                      _Stat(
                          icon: Icons.favorite_rounded,
                          label: 'Life expectancy',
                          value: breed.lifeExpectancyLabel),
                      _statDivider,
                      _Stat(
                          icon: Icons.straighten_rounded,
                          label: 'Size',
                          value: breed.sizeLabel),
                      _statDivider,
                      _Stat(
                          icon: Icons.monitor_weight_outlined,
                          label: 'Weight',
                          value: breed.weightLabel),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s16),

                _SectionTitle('Personality & temperament'),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    for (final t in breed.temperament)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s12, vertical: AppSpace.s4),
                        decoration: BoxDecoration(
                          color: PawPalette.teal.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          t,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: PawPalette.mint),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.s12),
                Text(
                  breed.personality,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink50, height: 1.5),
                ),
                const SizedBox(height: AppSpace.s16),

                _SectionTitle('Care at a glance'),
                PawCard(
                  child: Column(
                    children: [
                      _MeterRow(
                        icon: Icons.directions_run_rounded,
                        label: 'Exercise',
                        level: breed.exerciseLevel,
                        note: breed.exerciseNote,
                      ),
                      const Divider(height: AppSpace.s24),
                      _MeterRow(
                        icon: Icons.brush_rounded,
                        label: 'Grooming',
                        level: breed.groomingLevel,
                        note: breed.groomingNote,
                      ),
                      const Divider(height: AppSpace.s24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.pets_rounded,
                              size: 20, color: PawPalette.mint),
                          const SizedBox(width: AppSpace.s12),
                          Expanded(
                            child: Text(
                              breed.coat,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.ink300),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s16),

                _SectionTitle('Health, in general'),
                PawCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final note in breed.healthNotes)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpace.s8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(Icons.circle,
                                    size: 6, color: PawPalette.mint),
                              ),
                              const SizedBox(width: AppSpace.s12),
                              Expanded(
                                child: Text(
                                  note,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.ink50, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        'Every pet is an individual — breed tendencies are '
                        'general education, not a prediction. Your vet knows '
                        'what matters for yours.',
                        key: const Key('breed_health_disclaimer'),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.ink300),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s16),

                _SectionTitle('Worth knowing'),
                for (final fact in breed.funFacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s8),
                    child: PawCard(
                      padding: const EdgeInsets.all(AppSpace.s12),
                      radius: AppRadius.md,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 18, color: PawPalette.mint),
                          const SizedBox(width: AppSpace.s12),
                          Expanded(
                            child: Text(
                              fact,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.ink50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (credit != null) ...[
                  const SizedBox(height: AppSpace.s8),
                  InkWell(
                    key: const Key('breed_photo_credit'),
                    onTap: () => launchUrl(Uri.parse(credit!.sourceUrl),
                        mode: LaunchMode.externalApplication),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpace.s8),
                      child: Text(
                        'Photo: ${credit!.author} · ${credit!.license} · '
                        'Wikimedia Commons',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.ink300,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.ink600,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.s32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _statDivider = SizedBox(
  height: 40,
  child: VerticalDivider(width: AppSpace.s16),
);

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: PawPalette.mint),
          const SizedBox(height: AppSpace.s4),
          Text(value,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: AppColors.ink50)),
          Text(label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.ink300)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: PawPalette.mint),
        ),
      );
}

/// 1–5 level as filled paw dots + a one-line note.
class _MeterRow extends StatelessWidget {
  const _MeterRow({
    required this.icon,
    required this.label,
    required this.level,
    required this.note,
  });

  final IconData icon;
  final String label;
  final int level;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: PawPalette.mint),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: AppColors.ink50)),
                  const Spacer(),
                  Semantics(
                    label: '$label level $level of 5',
                    child: Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Icon(
                              Icons.pets_rounded,
                              size: 14,
                              color: i <= level
                                  ? PawPalette.mint
                                  : AppColors.ink600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(note,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.ink300)),
            ],
          ),
        ),
      ],
    );
  }
}
