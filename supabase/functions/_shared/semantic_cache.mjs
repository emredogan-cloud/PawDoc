// Pure helpers for the semantic cache (Phase 3.2). Plain ESM so it runs in Deno
// (the Edge Function) and Node (the unit test). The hard safety guarantees
// (same user, same species, threshold, NULL handling) live in the SQL function
// `match_analyses`; these helpers add a defense-in-depth check and the
// eligibility rule.

/** Format a numeric embedding array as a pgvector text literal: "[1,2,3]".
 *  Returns null for anything not a non-empty numeric array. */
export function formatVector(arr) {
  if (!Array.isArray(arr) || arr.length === 0) return null;
  for (const x of arr) {
    if (typeof x !== "number" || Number.isNaN(x)) return null;
  }
  return "[" + arr.join(",") + "]";
}

/** Pick the best cache hit from match_analyses() rows (already ordered
 *  closest-first and pre-filtered by the RPC). Defense-in-depth: re-check the
 *  similarity threshold and require a stored full_response. Returns the row or
 *  null. */
export function selectCacheHit(rows, threshold) {
  if (!Array.isArray(rows) || rows.length === 0) return null;
  const best = rows[0];
  if (typeof best.similarity === "number" && best.similarity < threshold) return null;
  if (!best.full_response) return null;
  return best;
}

/** The cache applies ONLY to text inputs and never to emergencies:
 *  - text: the symptom text is the whole signal, so a near-duplicate is safe.
 *  - photo/video: the IMAGE is the signal (not captured by the text embedding),
 *    and serving a cached result would also skip image moderation — so never
 *    cache them; always run a fresh analysis.
 *  - emergency text: must hit the hardcoded override every time.
 */
export function isCacheEligible(inputType, isEmergencyText, enabled) {
  return enabled === true && inputType === "text" && isEmergencyText !== true;
}
