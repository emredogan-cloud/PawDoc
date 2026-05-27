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
 * `bonus` is a one-time credit POOL (Phase 3.3 referral reward): the monthly
 * allowance is spent first, and only once it is exhausted does an analysis
 * consume a bonus credit — so a +3 referral reward is 3 extra checks total, not
 * 3 extra every month.
 * @returns {{allowed:boolean, newUsed:number, newBonus:number, usedBonus:boolean, didReset:boolean, resetAt:string}}
 */
export function evaluateFreeTier({
  usedThisMonth,
  resetAt,
  now = new Date().toISOString(),
  isPremium = false,
  limit = FREE_TIER_MONTHLY_LIMIT,
  bonus = 0,
}) {
  if (isPremium) {
    return { allowed: true, newUsed: usedThisMonth, newBonus: bonus, usedBonus: false, didReset: false, resetAt };
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

  // Monthly allowance first.
  if (used < limit) {
    return { allowed: true, newUsed: used + 1, newBonus: bonus, usedBonus: false, didReset, resetAt: effectiveResetAt };
  }
  // Then the one-time bonus pool.
  if (bonus > 0) {
    return { allowed: true, newUsed: used, newBonus: bonus - 1, usedBonus: true, didReset, resetAt: effectiveResetAt };
  }
  // Exhausted.
  return { allowed: false, newUsed: used, newBonus: bonus, usedBonus: false, didReset, resetAt: effectiveResetAt };
}
