/// Pet-count limits per subscription tier (roadmap §3.1; monetization strategy).
///
/// Free, trial and Premium are all capped at **2 pets**; **Family and B2B-Lite
/// (sitter, Phase 5.4)** are unlimited. Pure functions so the tier gate is
/// unit-tested and identical everywhere it is enforced (the home switcher and
/// the "My pets" screen).
library;

/// Tiers that carry no pet-count cap (Family, B2B-Lite sitter).
const _unlimitedPetTiers = {'family', 'b2b_lite'};

/// Maximum number of pets for a tier. `null` means unlimited.
int? petLimitFor(String subscriptionStatus) =>
    _unlimitedPetTiers.contains(subscriptionStatus) ? null : 2;

/// Whether a user on [subscriptionStatus] holding [currentCount] pets may add
/// one more. Unknown/loading statuses are treated as the most restrictive
/// (free) tier, so the gate never over-grants.
bool canAddPet(String subscriptionStatus, int currentCount) {
  final limit = petLimitFor(subscriptionStatus);
  return limit == null || currentCount < limit;
}
