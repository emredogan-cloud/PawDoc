// Free-tier unit tests (roadmap-required: 3 allowed, 4th blocked) + CR #10 reset.
// Run with:  node --test supabase/functions/_shared/free_tier.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { evaluateFreeTier, nextMonthStartISO } from "./free_tier.mjs";

const FUTURE = "2999-01-01T00:00:00.000Z"; // reset not yet due
const NOW = "2026-05-27T00:00:00.000Z";

test("first three analyses are allowed, the fourth is blocked", () => {
  assert.equal(evaluateFreeTier({ usedThisMonth: 0, resetAt: FUTURE, now: NOW }).allowed, true);
  assert.equal(evaluateFreeTier({ usedThisMonth: 1, resetAt: FUTURE, now: NOW }).allowed, true);
  assert.equal(evaluateFreeTier({ usedThisMonth: 2, resetAt: FUTURE, now: NOW }).allowed, true);

  const fourth = evaluateFreeTier({ usedThisMonth: 3, resetAt: FUTURE, now: NOW });
  assert.equal(fourth.allowed, false);
  assert.equal(fourth.newUsed, 3); // not incremented when blocked
});

test("an allowed analysis increments the counter", () => {
  assert.equal(evaluateFreeTier({ usedThisMonth: 0, resetAt: FUTURE, now: NOW }).newUsed, 1);
});

test("CR #10: counter resets when the period has rolled over", () => {
  const past = "2026-05-01T00:00:00.000Z";
  const r = evaluateFreeTier({ usedThisMonth: 3, resetAt: past, now: NOW });
  assert.equal(r.didReset, true);
  assert.equal(r.allowed, true); // reset to 0, so allowed again
  assert.equal(r.newUsed, 1);
  assert.equal(r.resetAt, "2026-06-01T00:00:00.000Z");
});

test("premium is unlimited", () => {
  const r = evaluateFreeTier({ usedThisMonth: 99, resetAt: FUTURE, now: NOW, isPremium: true });
  assert.equal(r.allowed, true);
});

test("nextMonthStartISO rolls to the first of next month (UTC)", () => {
  assert.equal(nextMonthStartISO("2026-05-27T12:00:00.000Z"), "2026-06-01T00:00:00.000Z");
  assert.equal(nextMonthStartISO("2026-12-15T00:00:00.000Z"), "2027-01-01T00:00:00.000Z");
});

// --- Phase 3.3 referral bonus pool ------------------------------------------
test("bonus pool is consumed only AFTER the monthly allowance is exhausted", () => {
  // Under the monthly limit -> spend monthly, leave the bonus untouched.
  const monthly = evaluateFreeTier({ usedThisMonth: 1, resetAt: FUTURE, now: NOW, bonus: 3 });
  assert.equal(monthly.allowed, true);
  assert.equal(monthly.usedBonus, false);
  assert.equal(monthly.newUsed, 2);
  assert.equal(monthly.newBonus, 3);

  // At the monthly limit -> dip into the bonus (monthly counter unchanged).
  const fromBonus = evaluateFreeTier({ usedThisMonth: 3, resetAt: FUTURE, now: NOW, bonus: 3 });
  assert.equal(fromBonus.allowed, true);
  assert.equal(fromBonus.usedBonus, true);
  assert.equal(fromBonus.newUsed, 3);
  assert.equal(fromBonus.newBonus, 2);
});

test("with the monthly limit hit and no bonus, the analysis is blocked", () => {
  const r = evaluateFreeTier({ usedThisMonth: 3, resetAt: FUTURE, now: NOW, bonus: 0 });
  assert.equal(r.allowed, false);
  assert.equal(r.newBonus, 0);
});

test("a +3 referral bonus is a one-time pool (not 3 every month)", () => {
  // Spend all 3 bonus credits at the limit; the 4th over-limit call is blocked.
  let bonus = 3;
  for (let i = 0; i < 3; i++) {
    const r = evaluateFreeTier({ usedThisMonth: 3, resetAt: FUTURE, now: NOW, bonus });
    assert.equal(r.allowed, true);
    assert.equal(r.usedBonus, true);
    bonus = r.newBonus;
  }
  assert.equal(bonus, 0);
  assert.equal(evaluateFreeTier({ usedThisMonth: 3, resetAt: FUTURE, now: NOW, bonus }).allowed, false);
});
