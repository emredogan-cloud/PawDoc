// Pure free-tier decision logic. Plain ESM so it runs in BOTH Deno (the Edge
// Function) and Node (the unit test). Includes the monthly reset (Critical
// Review #10) — without it, free users would get their allowance ONCE ever
// instead of monthly.
//
// v3 (evolution Phase 6): the meter applies to PHOTO LOGS only (a record
// feature). Text guidance is unmetered — see quota_gate.mjs.

export const FREE_PHOTO_MONTHLY_LIMIT = 5;
// Back-compat alias for older call sites/tests.
export const FREE_TIER_MONTHLY_LIMIT = FREE_PHOTO_MONTHLY_LIMIT;

/** First instant of the month after `now` (UTC), ISO string. */
export function nextMonthStartISO(now) {
  const d = new Date(now);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1)).toISOString();
}

/**
 * Decide whether an analysis is allowed and compute the new counter state.
 * @returns {{allowed:boolean, newUsed:number, didReset:boolean, resetAt:string}}
 */
export function evaluateFreeTier({
  usedThisMonth,
  resetAt,
  now = new Date().toISOString(),
  isPremium = false,
  limit = FREE_PHOTO_MONTHLY_LIMIT,
}) {
  if (isPremium) {
    return { allowed: true, newUsed: usedThisMonth, didReset: false, resetAt };
  }

  let used = usedThisMonth;
  let didReset = false;
  let effectiveResetAt = resetAt;

  // CR #10: check-on-read monthly reset.
  if (resetAt && new Date(now) >= new Date(resetAt)) {
    used = 0;
    didReset = true;
    effectiveResetAt = nextMonthStartISO(now);
  }

  if (used < limit) {
    return { allowed: true, newUsed: used + 1, didReset, resetAt: effectiveResetAt };
  }
  return { allowed: false, newUsed: used, didReset, resetAt: effectiveResetAt };
}
