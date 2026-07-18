// Free-tier unit tests (roadmap-required: 3 allowed, 4th blocked) + CR #10 reset.
// Run with:  node --test supabase/functions/_shared/free_tier.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { evaluateFreeTier, nextMonthStartISO } from "./free_tier.mjs";

const FUTURE = "2999-01-01T00:00:00.000Z"; // reset not yet due
const NOW = "2026-05-27T00:00:00.000Z";

test("five photo logs are allowed, the sixth is blocked (v3: photos-only meter)", () => {
  for (let used = 0; used < 5; used++) {
    assert.equal(evaluateFreeTier({ usedThisMonth: used, resetAt: FUTURE, now: NOW }).allowed, true);
  }
  const sixth = evaluateFreeTier({ usedThisMonth: 5, resetAt: FUTURE, now: NOW });
  assert.equal(sixth.allowed, false);
  assert.equal(sixth.newUsed, 5); // not incremented when blocked
});

test("an allowed analysis increments the counter", () => {
  assert.equal(evaluateFreeTier({ usedThisMonth: 0, resetAt: FUTURE, now: NOW }).newUsed, 1);
});

test("CR #10: counter resets when the period has rolled over", () => {
  const past = "2026-05-01T00:00:00.000Z";
  const r = evaluateFreeTier({ usedThisMonth: 5, resetAt: past, now: NOW });
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

