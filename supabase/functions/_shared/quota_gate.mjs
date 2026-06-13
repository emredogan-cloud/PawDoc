// GAP-A3: pure free-tier quota-gate decisions, shared so the safety-critical
// branching is unit-tested in Node and used verbatim by the Deno /analyze
// function. The non-negotiable: EMERGENCY is NEVER paywalled — including the
// VISUAL half. A photo/video emergency (pale gums, bloat) can't be detected
// from text, so an out-of-quota visual request must run the AI and only be
// blocked AFTER, and only when the verdict is not EMERGENCY.

/**
 * Block BEFORE the AI runs?
 * Text out-of-quota is blocked up front (cheap; no visual emergency to miss).
 * A visual out-of-quota request is NOT blocked here — it must run so an image
 * emergency can surface.
 */
export function blockBeforeAi(quotaExceeded, isVisual) {
  return quotaExceeded && !isVisual;
}

/**
 * Block AFTER the AI runs?
 * An out-of-quota visual is blocked only when the verdict is NOT EMERGENCY.
 * An EMERGENCY is always returned in full, free.
 */
export function blockAfterAi(quotaExceeded, triageLevel) {
  return quotaExceeded && triageLevel !== "EMERGENCY";
}

/**
 * Count this analysis against the free quota?
 * Never for emergencies (text-keyword OR AI-detected), never for out-of-quota
 * requests, never for premium, never for degraded answers (tier_used === 0).
 */
export function countsAgainstQuota(
  { isPremium, isEmergencyText, quotaExceeded, triageLevel, tierUsed },
) {
  if (isPremium || isEmergencyText || quotaExceeded) return false;
  if (triageLevel === "EMERGENCY") return false;
  return (tierUsed ?? 0) > 0;
}
