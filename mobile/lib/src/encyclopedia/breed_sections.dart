import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import 'breed.dart';

/// The pieces `breed_encyclopedia` and `breed_detail` share.
///
/// ## What these two references assert that the catalogue cannot
///
/// | Reference | Shipped |
/// |---|---|
/// | "Common Health Conditions · Hip Dysplasia · **Risk: Moderate**" with a filled dot meter | the catalogue's own `health_notes`, authored hedged ("can be prone to…", "reputable breeders screen their stock"). **No risk level, no meter, no percentage** — a graded risk beside a named condition is a claim about an animal, and a reader whose dog *is* a Golden Retriever will read it as one |
/// | "Popularity · #3 · AKC Rankings" | the save control. There is no ranking in the catalogue and citing a registry's is fabrication |
/// | "Trainability ★4.7", "Good With Kids 5/5", "Watchdog Ability 2/5" | the two levels the catalogue actually authors — exercise and grooming — as meters. The rest are subjective ratings nobody wrote |
/// | "Height 51–61 cm", "Coat Length Medium to Long", "Colors ●●●●+2", "FCI Group 8", "AKC Recognition 1925" | absent from the catalogue; the rows they filled hold facts that are in it |
/// | "Nutrition · High quality dog food" | dietary advice with no source. The row holds the coat description instead |
/// | "With proper care… can live a long, healthy and happy life" | the life-expectancy range, and nothing after it |
/// | "Take Breed Match Quiz" | the card, marked *Soon*. There is no quiz |
///
/// Every breed page closes with [kBreedHealthDisclaimer]: this is general
/// breed information, not a statement about your pet.

// ---------------------------------------------------------------------------
// The standing line
// ---------------------------------------------------------------------------

/// The sentence every health block on a breed page ends with.
const String kBreedHealthDisclaimer =
    'General information about the breed — not a statement about your pet. '
    'Any breed is a starting point for a conversation with your vet, never a '
    'diagnosis or a prediction.';

// ---------------------------------------------------------------------------
// Species filters
// ---------------------------------------------------------------------------

/// The reference's six-tile species rail.
///
/// The catalogue holds dogs and cats. The other three keep their tile and say
/// *Soon* rather than being deleted — the same convention the rest of the app
/// uses for a drawn affordance with nothing behind it.
enum BreedSpecies {
  all('All Breeds', LucideIcons.pawPrint, null),
  dogs('Dogs', LucideIcons.dog, 'dog'),
  cats('Cats', LucideIcons.cat, 'cat'),
  small('Small Pets', LucideIcons.rabbit, null, available: false),
  birds('Birds', LucideIcons.bird, null, available: false),
  reptiles('Reptiles', LucideIcons.turtle, null, available: false);

  const BreedSpecies(this.label, this.icon, this.species,
      {this.available = true});

  final String label;
  final IconData icon;

  /// The `species` value to filter on. `null` on [all] means no filter.
  final String? species;
  final bool available;

  List<Breed> filter(List<Breed> breeds) =>
      species == null ? breeds : [for (final b in breeds) if (b.species == species) b];
}

// ---------------------------------------------------------------------------
// Facts
// ---------------------------------------------------------------------------

/// One entry of the reference's fact strip.
typedef BreedFact = ({IconData icon, String label, String value});

/// The facts the catalogue really holds, in the reference's own order.
///
/// Its own strip includes **Height**, **Coat Length**, **Colors**, **Breed
/// Group**, **AKC Recognition** and **FCI Group**. None of those is in
/// `breeds_v1.json`, and a fact strip that invents six of ten values is not a
/// fact strip.
List<BreedFact> breedFacts(Breed breed) => [
      (icon: LucideIcons.ruler, label: 'Size', value: breed.sizeLabel),
      (icon: LucideIcons.scale, label: 'Weight', value: breed.weightLabel),
      (icon: LucideIcons.mapPin, label: 'Origin', value: breed.origin),
      (
        icon: LucideIcons.heart,
        label: 'Life span',
        value: breed.lifeExpectancyLabel
      ),
    ];

/// `Canis lupus familiaris` — the species binomial, which is a fact about the
/// species and not one the catalogue has to carry per breed.
String breedBinomial(String species) =>
    species == 'cat' ? 'Felis catus' : 'Canis lupus familiaris';

/// Breeds worth putting beside this one: same species first, then the closest
/// size class, then the most shared temperament words.
///
/// The reference lists four "Similar Breeds" with no stated basis. This one
/// has a basis, and the card says what it is.
List<Breed> similarBreeds(List<Breed> all, Breed breed, {int max = 4}) {
  final pool = [
    for (final b in all)
      if (b.id != breed.id && b.species == breed.species) b,
  ];
  final traits = breed.temperament.map((t) => t.toLowerCase()).toSet();
  int score(Breed b) {
    var s = 0;
    if (b.sizeClass == breed.sizeClass) s += 3;
    for (final t in b.temperament) {
      if (traits.contains(t.toLowerCase())) s += 1;
    }
    if (b.exerciseLevel == breed.exerciseLevel) s += 1;
    return s;
  }

  pool.sort((a, b) {
    final byScore = score(b).compareTo(score(a));
    return byScore != 0 ? byScore : a.name.compareTo(b.name);
  });
  return pool.take(max).toList(growable: false);
}

// ---------------------------------------------------------------------------
// Saved breeds
// ---------------------------------------------------------------------------

/// The breeds an owner bookmarked.
///
/// **On the device, and the UI says so.** There is no saved-breeds table, and
/// the catalogue is a bundled asset — a bookmark is a reading preference, not
/// health data, and it does not warrant a migration.
class SavedBreeds {
  const SavedBreeds._();

  static const String key = 'pawdoc.breeds.saved';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? const <String>[]).toSet();
  }

  /// Flips [id] and returns the new set.
  static Future<Set<String>> toggle(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(key) ?? const <String>[]).toSet();
    if (!current.remove(id)) current.add(id);
    await prefs.setStringList(key, current.toList()..sort());
    return current;
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

/// The bordered chip the references set a temperament word in.
class BreedTraitChip extends StatelessWidget {
  const BreedTraitChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: t.accent.withValues(alpha: 0.45)),
      ),
      child: Text(_title(label),
          style: TextStyle(
              color: t.accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }

  static String _title(String raw) {
    final words = raw.replaceAll('-', ' ').split(' ');
    return [
      for (final w in words)
        if (w.isEmpty) w else w[0].toUpperCase() + w.substring(1),
    ].join(' ');
  }
}

/// A 1–5 level drawn as the reference's segmented meter.
///
/// Only [Breed.exerciseLevel] and [Breed.groomingLevel] feed one, because they
/// are the only two levels the catalogue authors.
class BreedMeterRow extends StatelessWidget {
  const BreedMeterRow({
    required this.label,
    required this.level,
    required this.caption,
    super.key,
  });

  final String label;

  /// 1–5.
  final int level;
  final String caption;

  static const List<String> words = [
    'Very low',
    'Low',
    'Moderate',
    'High',
    'Very high',
  ];

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: HealthTone.muted, fontSize: 11.5)),
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 1; i <= 5; i++) ...[
                  if (i > 1) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i <= level
                            ? t.accent
                            : Colors.white.withValues(alpha: 0.09),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 66,
            child: Text(caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// The fact strip both references set under the breed name.
class BreedFactStrip extends StatelessWidget {
  const BreedFactStrip({required this.facts, this.columns = 2, super.key});

  final List<BreedFact> facts;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < facts.length; i += columns) {
      final slice = facts.skip(i).take(columns).toList();
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const SizedBox(width: 10),
              Expanded(
                child: c < slice.length
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(slice[c].icon,
                                size: 14, color: t.accent),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(slice[c].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: HealthTone.muted,
                                        fontSize: 10.5,
                                        height: 1.2)),
                                Text(slice[c].value,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        height: 1.25,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ));
      if (i + columns < facts.length) rows.add(const SizedBox(height: 10));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

/// The health block both pages carry: the catalogue's hedged notes and the
/// standing line, with no risk level anywhere.
class BreedHealthCard extends StatelessWidget {
  const BreedHealthCard({required this.breed, this.compact = false, super.key});

  final Breed breed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final notes = compact ? breed.healthNotes.take(2) : breed.healthNotes;
    return HomeCard(
      key: const Key('breed_health_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The reference titles this "Common Health Conditions" and puts a
          // risk meter beside each. What the catalogue holds is what breeders
          // and vets screen for — which is a different sentence.
          HealthSectionHead(
            title: 'What Vets Watch For',
            leading: Icon(LucideIcons.stethoscope, size: 15, color: t.accent),
          ),
          const SizedBox(height: 9),
          if (notes.isEmpty)
            const Text('No breed health notes in this guide yet.',
                style: TextStyle(
                    color: HealthTone.faint, fontSize: 11.5, height: 1.4))
          else
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.accent.withValues(alpha: 0.7)),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(note,
                          style: const TextStyle(
                              color: HealthTone.dim,
                              fontSize: 11.5,
                              height: 1.45)),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 3),
          Container(
            key: const Key('breed_health_disclaimer'),
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.028),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(LucideIcons.info, size: 14, color: HealthTone.muted),
                SizedBox(width: 9),
                Expanded(
                  child: Text(kBreedHealthDisclaimer,
                      style: TextStyle(
                          color: HealthTone.dim, fontSize: 11, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The save control the reference draws as a "Popularity #3" badge on one page
/// and a heart on the other.
class BreedSaveButton extends StatelessWidget {
  const BreedSaveButton({
    required this.saved,
    required this.onTap,
    this.size = 38,
    super.key,
  });

  final bool saved;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Semantics(
      button: true,
      label: saved ? 'Remove from saved breeds' : 'Save this breed',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: saved
                  ? t.accent.withValues(alpha: 0.16)
                  : const Color(0xCC0A0F0B),
              border: Border.all(
                  color: saved
                      ? t.accent
                      : Colors.white.withValues(alpha: 0.18)),
            ),
            child: Icon(LucideIcons.bookmark,
                size: size * 0.44,
                color: saved ? t.accent : Colors.white70),
          ),
        ),
      ),
    );
  }
}

/// A bundled breed photograph, with a calm fallback.
///
/// Five call sites used a bare `Image.asset`, which **throws** when the file
/// is missing — a corrupt or renamed asset would take the page down rather
/// than leave a gap. It also makes the catalogue testable without shipping
/// twenty webp files into the test bundle.
class BreedPhoto extends StatelessWidget {
  const BreedPhoto({
    required this.breed,
    this.fit = BoxFit.cover,
    super.key,
  });

  final Breed breed;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.asset(
        breed.image,
        fit: fit,
        errorBuilder: (context, _, _) => ColoredBox(
          color: HealthTone.raised,
          child: Center(
            child: Icon(
              breed.species == 'cat' ? LucideIcons.cat : LucideIcons.dog,
              size: 28,
              color: HealthTone.faint,
            ),
          ),
        ),
      );
}
