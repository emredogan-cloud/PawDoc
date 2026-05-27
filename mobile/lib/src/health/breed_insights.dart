/// Static breed-health reference data + the rotating-card selection logic.
///
/// This is general, informational wellness content for the most common breeds —
/// NOT medical advice and NEVER a diagnosis. Every insight points the owner back
/// to their vet, consistent with PawDoc's safety posture. Scoped to top breeds
/// first (roadmap §3.1 execution-risk note); species-level fallbacks cover the
/// rest. Kept client-side (a static config, per the deliverable) rather than a
/// Supabase table — see the sub-PR report for the rationale/deferral.
library;

class BreedInsight {
  const BreedInsight(this.title, this.body);
  final String title;
  final String body;
}

/// Breed-specific insights, keyed by a normalized (lowercase) breed name.
const Map<String, List<BreedInsight>> _breedData = {
  'labrador retriever': [
    BreedInsight('Watch the waistline',
        'Labs love food and gain weight easily. Keep an eye on body condition and ask your vet about an ideal target weight.'),
    BreedInsight('Joints & hips',
        'This breed is prone to hip and elbow issues. Mention any limping or stiffness to your vet early.'),
    BreedInsight('Ears after swimming',
        'Floppy ears trap moisture. Dry them after baths or swims and watch for head-shaking or odor.'),
  ],
  'german shepherd': [
    BreedInsight('Hips & mobility',
        'German Shepherds are prone to hip dysplasia. Note any difficulty rising or reluctance to climb stairs.'),
    BreedInsight('Sensitive stomachs',
        'Digestive upset is common. Sudden food changes can trigger it — transition diets gradually.'),
  ],
  'golden retriever': [
    BreedInsight('Skin & coat',
        'Goldens are prone to skin allergies and ear issues. Watch for excessive scratching or licking.'),
    BreedInsight('Weight & joints',
        'Keep them lean to protect their joints, and ask your vet about hip health as they age.'),
  ],
  'french bulldog': [
    BreedInsight('Breathing & heat',
        'Flat-faced breeds overheat easily and can struggle to breathe in hot weather. Keep exercise gentle and avoid heat.'),
    BreedInsight('Skin folds',
        'Clean facial folds to prevent irritation, and watch for redness or odor.'),
  ],
  'bulldog': [
    BreedInsight('Breathing & heat',
        'Bulldogs are heat-sensitive and prone to breathing trouble. Avoid strenuous activity in warm weather.'),
    BreedInsight('Skin folds',
        'Keep wrinkles clean and dry to prevent skin infections.'),
  ],
  'poodle': [
    BreedInsight('Coat & ears',
        'Poodles need regular grooming, and their ears benefit from routine cleaning to avoid infection.'),
    BreedInsight('Eyes',
        'Tear staining and eye irritation are common — mention persistent discharge to your vet.'),
  ],
  'beagle': [
    BreedInsight('Watch the weight',
        'Beagles are food-motivated and prone to obesity. Measure meals and limit treats.'),
    BreedInsight('Ears',
        'Long ears trap moisture; check weekly for redness, odor, or head-shaking.'),
  ],
  'dachshund': [
    BreedInsight('Protect the back',
        'Their long spine is prone to disc problems. Discourage jumping from heights and support the back when lifting.'),
    BreedInsight('Weight matters',
        'Extra weight strains the spine — keeping them lean is one of the best things you can do.'),
  ],
  'yorkshire terrier': [
    BreedInsight('Dental care',
        'Small breeds are prone to dental disease. Ask your vet about brushing and dental checks.'),
    BreedInsight('Watch for chills',
        'Tiny dogs lose heat fast. Keep them warm in cold weather.'),
  ],
  'chihuahua': [
    BreedInsight('Dental care',
        'Prone to dental crowding and disease — regular dental care really helps.'),
    BreedInsight('Handle gently',
        'Fragile frames mean falls and rough handling can injure them; supervise around larger pets.'),
  ],
  'persian': [
    BreedInsight('Eyes & face',
        'Flat faces cause tearing — gently wipe the eye area daily and watch for redness.'),
    BreedInsight('Coat care',
        'Long coats mat quickly; daily brushing prevents painful tangles and hairballs.'),
  ],
  'maine coon': [
    BreedInsight('Heart health',
        'This breed can be prone to a heart condition (HCM). Ask your vet about screening as they mature.'),
    BreedInsight('Big-cat joints',
        'Their size can stress hips and joints — keep them active and lean.'),
  ],
  'siamese': [
    BreedInsight('Dental & respiratory',
        'Siamese can be prone to dental and respiratory issues — note any persistent sneezing or bad breath.'),
    BreedInsight('Very vocal',
        'Sudden changes in vocalization or appetite are worth mentioning to your vet.'),
  ],
  'ragdoll': [
    BreedInsight('Heart screening',
        'Like several large breeds, Ragdolls can be prone to HCM. Ask your vet about heart checks.'),
    BreedInsight('Gentle indoor life',
        'They are docile and best kept indoors; watch weight with a less active lifestyle.'),
  ],
  'british shorthair': [
    BreedInsight('Watch the weight',
        'This laid-back breed gains weight easily. Measure food and encourage play.'),
    BreedInsight('Heart health',
        'Ask your vet whether heart screening is appropriate as they age.'),
  ],
};

/// Species-level fallbacks when the breed is unknown or not in the table.
const Map<String, List<BreedInsight>> _speciesData = {
  'dog': [
    BreedInsight('Routine matters',
        'Annual vet checkups, dental care, and a healthy weight prevent most common issues.'),
    BreedInsight('Know your baseline',
        'Logging weight and behavior helps you (and your vet) spot changes early.'),
  ],
  'cat': [
    BreedInsight('Hydration & litter',
        'Changes in drinking, urination, or litter-box habits are early warning signs worth noting.'),
    BreedInsight('Indoor enrichment',
        'Play and climbing keep indoor cats at a healthy weight and reduce stress.'),
  ],
  'rabbit': [
    BreedInsight('Gut never stops',
        'Rabbits must keep eating. If a rabbit stops eating or passing droppings, contact a vet promptly.'),
    BreedInsight('Teeth & hay',
        'Unlimited hay wears down constantly-growing teeth and keeps the gut moving.'),
  ],
  'bird': [
    BreedInsight('Birds hide illness',
        'Birds mask symptoms well. Any fluffed posture, appetite change, or lethargy deserves quick attention.'),
    BreedInsight('Air quality',
        'Keep away from fumes (non-stick cookware, smoke, aerosols) — their lungs are very sensitive.'),
  ],
  'reptile': [
    BreedInsight('Heat & light',
        'Most issues trace back to temperature, UVB, or humidity. Verify the habitat against your species’ needs.'),
    BreedInsight('Appetite & sheds',
        'Track feeding and shedding; irregularities are often the first sign something is off.'),
  ],
  'other': [
    BreedInsight('Know your baseline',
        'Logging weight, appetite, and behavior helps you and your vet catch changes early.'),
  ],
};

/// All insights applicable to a pet: its breed's list, else the species
/// fallback, else a generic list. Never empty.
List<BreedInsight> insightsForPet({String? breed, required String species}) {
  if (breed != null && breed.trim().isNotEmpty) {
    final key = breed.trim().toLowerCase();
    final exact = _breedData[key];
    if (exact != null) return exact;
    for (final entry in _breedData.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) return entry.value;
    }
  }
  return _speciesData[species.toLowerCase()] ?? _speciesData['other']!;
}

/// The insight to show right now. Rotates **daily** (deterministic, so it is
/// testable and stable within a day); [offset] lets the card advance on tap.
BreedInsight rotatingInsight({
  String? breed,
  required String species,
  DateTime? now,
  int offset = 0,
}) {
  final list = insightsForPet(breed: breed, species: species);
  final dayIndex = (now ?? DateTime.now()).difference(DateTime(2020)).inDays;
  return list[(dayIndex + offset) % list.length];
}
