/// Display formatting for user-entered pet names.
///
/// PawDoc personalizes copy with the pet's name ("Ready to check on {name}?").
/// Real test data exposed two failure modes the screenshots captured:
///   * a lowercase name reads broken inside a sentence  → "check on ker"
///   * an empty / whitespace name renders nonsense       → "in 's health"
///
/// [petDisplayName] hardens both: it trims, falls back to a neutral "your pet"
/// when blank, and capitalizes the first letter for display.
///
/// Display-only — the stored name is never mutated. Editing the pet, the AI
/// prompt, and PDF/file naming all keep the raw value.
String petDisplayName(String? raw) {
  final name = raw?.trim() ?? '';
  if (name.isEmpty) return 'your pet';
  return name[0].toUpperCase() + name.substring(1);
}

/// Possessive form for copy like "in {name}'s health".
/// Uses a typographic apostrophe (’) to match the existing onboarding copy.
String petDisplayPossessive(String? raw) => '${petDisplayName(raw)}’s';
