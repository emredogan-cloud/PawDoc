// Pure free-tier decision logic. Plain ESM so it runs in BOTH Deno (the Edge
// Function) and Node (the unit test). Includes the monthly reset the source
// roadmap omitted (Critical Review #10) — without it, free users get 3 analyses
// EVER instead of 3 per month.

export const FREE_TIER_MONTHLY_LIMIT = 3;

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
  limit = FREE_TIER_MONTHLY_LIMIT,
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

  const allowed = used < limit;
  return {
    allowed,
    newUsed: allowed ? used + 1 : used, // increment only on an allowed analysis
    didReset,
    resetAt: effectiveResetAt,
  };
}
