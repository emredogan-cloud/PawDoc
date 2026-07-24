/// Breed Encyclopedia models (Next Evolution Phase 3).
///
/// Content is data, not code: `assets/breeds/breeds_v1.json` (versioned
/// schema) + per-image attribution in `assets/breeds/credits.json`. The model
/// validates on decode so a malformed catalog fails loudly in tests, never
/// silently in the UI. Health notes are educational only — the catalog is
/// authored hedged ("can be prone to…"), never diagnostic, and the UI always
/// closes with a talk-to-your-vet line.
class Breed {
  const Breed({
    required this.id,
    required this.species,
    required this.name,
    required this.image,
    required this.origin,
    required this.countries,
    required this.lifeExpectancyYears,
    required this.sizeClass,
    required this.weightKg,
    required this.coat,
    required this.temperament,
    required this.personality,
    required this.exerciseLevel,
    required this.exerciseNote,
    required this.groomingLevel,
    required this.groomingNote,
    required this.healthNotes,
    required this.funFacts,
  });

  final String id;
  final String species; // 'dog' | 'cat'
  final String name;
  final String image; // bundled asset path
  final String origin;
  final List<String> countries;
  final (int, int) lifeExpectancyYears;
  final String sizeClass;
  final (double, double) weightKg;
  final String coat;
  final List<String> temperament;
  final String personality;
  final int exerciseLevel; // 1–5
  final String exerciseNote;
  final int groomingLevel; // 1–5
  final String groomingNote;
  final List<String> healthNotes;
  final List<String> funFacts;

  factory Breed.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        ((json[key] as List?) ?? const []).cast<String>();
    (num, num) pair(String key) {
      final list = (json[key] as List).cast<num>();
      if (list.length != 2 || list[0] > list[1]) {
        throw FormatException('breed ${json['id']}: bad range for $key');
      }
      return (list[0], list[1]);
    }

    int level(String key) {
      final v = json[key] as int;
      if (v < 1 || v > 5) {
        throw FormatException('breed ${json['id']}: $key out of 1..5');
      }
      return v;
    }

    final species = json['species'] as String;
    if (species != 'dog' && species != 'cat') {
      throw FormatException('breed ${json['id']}: unknown species $species');
    }
    final life = pair('life_expectancy_years');
    final weight = pair('weight_kg');
    return Breed(
      id: json['id'] as String,
      species: species,
      name: json['name'] as String,
      image: json['image'] as String,
      origin: json['origin'] as String,
      countries: strings('countries'),
      lifeExpectancyYears: (life.$1.toInt(), life.$2.toInt()),
      sizeClass: json['size_class'] as String,
      weightKg: (weight.$1.toDouble(), weight.$2.toDouble()),
      coat: json['coat'] as String,
      temperament: strings('temperament'),
      personality: json['personality'] as String,
      exerciseLevel: level('exercise_level'),
      exerciseNote: json['exercise_note'] as String,
      groomingLevel: level('grooming_level'),
      groomingNote: json['grooming_note'] as String,
      healthNotes: strings('health_notes'),
      funFacts: strings('fun_facts'),
    );
  }

  String get lifeExpectancyLabel =>
      '${lifeExpectancyYears.$1}–${lifeExpectancyYears.$2} yrs';

  String get weightLabel {
    String n(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return '${n(weightKg.$1)}–${n(weightKg.$2)} kg';
  }

  String get sizeLabel =>
      sizeClass[0].toUpperCase() + sizeClass.substring(1);
}

/// Attribution for one bundled breed photo (Wikimedia Commons).
class BreedCredit {
  const BreedCredit({
    required this.slug,
    required this.author,
    required this.license,
    this.licenseUrl,
    required this.sourceUrl,
  });

  final String slug;
  final String author;
  final String license;
  final String? licenseUrl;
  final String sourceUrl;

  factory BreedCredit.fromJson(Map<String, dynamic> json) => BreedCredit(
        slug: json['slug'] as String,
        author: json['author'] as String,
        license: json['license'] as String,
        licenseUrl: json['license_url'] as String?,
        sourceUrl: json['source_url'] as String,
      );
}

/// The loaded catalog: breeds + photo credits, id-addressed.
class BreedCatalog {
  const BreedCatalog({required this.breeds, required this.credits});

  final List<Breed> breeds;
  final Map<String, BreedCredit> credits;

  List<Breed> bySpecies(String species) =>
      breeds.where((b) => b.species == species).toList(growable: false);

  BreedCredit? creditFor(String breedId) => credits[breedId];
}

/// Case-insensitive search over name, origin, and temperament. Pure.
List<Breed> searchBreeds(List<Breed> breeds, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return breeds;
  return breeds
      .where((b) =>
          b.name.toLowerCase().contains(q) ||
          b.origin.toLowerCase().contains(q) ||
          b.temperament.any((t) => t.toLowerCase().contains(q)))
      .toList(growable: false);
}
