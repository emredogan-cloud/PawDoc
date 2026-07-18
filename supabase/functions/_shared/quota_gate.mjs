// Quota gate v3 (evolution Phase 6): FREE = SAFETY, PAID = MEMORY.
//
// TEXT guidance is UNMETERED for everyone — safety advice is never metered,
// counted, or blocked, so "never paywall an emergency" stops being a rule we
// enforce and becomes something the architecture cannot do.
//
// PHOTO logs are a RECORD feature and are metered PRE-AI. Vision is no longer
// an emergency-detection mechanism (the client keyword router + the server
// text override + the offline red button carry that), so blocking a photo up
// front can no longer suppress an emergency — and the v2 trap where an
// out-of-quota photo ran the full paid pipeline "just in case" (BE-01's
// unbounded free-inference path) is gone at the root: no quota'd request ever
// reaches a model.
//
// Pure ESM so Deno (the Edge Function) and Node (the unit tests) share it.

/** Photos are the only metered input. */
export function isMetered(inputType) {
  return inputType === "photo";
}

/**
 * Pre-AI gate: block ONLY a metered (photo) request that is out of quota.
 * Text never blocks. Nothing blocks after the AI — there is no post-AI gate.
 */
export function blockBeforeAi(inputType, quotaExceeded) {
  return isMetered(inputType) && quotaExceeded;
}

/**
 * Counting: only a real, surfaced photo analysis by a free user counts.
 * Degraded answers (tierUsed 0) never count (GAP-E7), and GET_HELP_NOW is
 * never counted — the belt stays even though photos can't be the only route
 * to an emergency anymore.
 */
export function countsAgainstQuota({ isPremium, inputType, action, tierUsed }) {
  if (isPremium) return false;
  if (!isMetered(inputType)) return false;
  if (action === "GET_HELP_NOW") return false;
  return (tierUsed ?? 0) > 0;
}
