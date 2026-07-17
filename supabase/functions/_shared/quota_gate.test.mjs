// GAP-A3 quota-gate tests. Run: node --test supabase/functions/_shared/quota_gate.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { blockAfterAi, blockBeforeAi, countsAgainstQuota } from "./quota_gate.mjs";

// The four quadrants the gap analysis demanded: in/out quota × emergency/normal
// × text/visual. GET_HELP_NOW must never be blocked for any input type.

test("in-quota requests are never blocked (any type)", () => {
  for (const visual of [true, false]) {
    assert.equal(blockBeforeAi(false, visual), false);
    assert.equal(blockAfterAi(false, "WATCH_AND_RECHECK"), false);
    assert.equal(blockAfterAi(false, "GET_HELP_NOW"), false);
  }
});

test("out-of-quota TEXT is blocked up front", () => {
  assert.equal(blockBeforeAi(true, /* isVisual */ false), true);
});

test("out-of-quota VISUAL is NOT blocked up front (must run the AI)", () => {
  assert.equal(blockBeforeAi(true, /* isVisual */ true), false);
});

test("out-of-quota visual: GET_HELP_NOW is returned (never blocked after AI)", () => {
  assert.equal(blockAfterAi(true, "GET_HELP_NOW"), false);
});

test("out-of-quota visual: non-emergency is blocked after AI (upgrade)", () => {
  assert.equal(blockAfterAi(true, "WATCH_AND_RECHECK"), true);
  assert.equal(blockAfterAi(true, "WATCH_AND_RECHECK"), true);
});

test("counting: emergencies (text or AI) never count; degraded never counts", () => {
  // AI-detected emergency on a free, in-quota check → free.
  assert.equal(
    countsAgainstQuota({ isPremium: false, isEmergencyText: false, quotaExceeded: false, action: "GET_HELP_NOW", tierUsed: 3 }),
    false,
  );
  // text-keyword emergency → free.
  assert.equal(
    countsAgainstQuota({ isPremium: false, isEmergencyText: true, quotaExceeded: false, action: "WATCH_AND_RECHECK", tierUsed: 2 }),
    false,
  );
  // degraded (tier 0) → not counted (GAP-E7).
  assert.equal(
    countsAgainstQuota({ isPremium: false, isEmergencyText: false, quotaExceeded: false, action: "WATCH_AND_RECHECK", tierUsed: 0 }),
    false,
  );
  // out-of-quota request → never counts (already out).
  assert.equal(
    countsAgainstQuota({ isPremium: false, isEmergencyText: false, quotaExceeded: true, action: "WATCH_AND_RECHECK", tierUsed: 2 }),
    false,
  );
});

test("counting: a real free non-emergency analysis DOES count", () => {
  assert.equal(
    countsAgainstQuota({ isPremium: false, isEmergencyText: false, quotaExceeded: false, action: "WATCH_AND_RECHECK", tierUsed: 2 }),
    true,
  );
});

test("counting: premium never counts", () => {
  assert.equal(
    countsAgainstQuota({ isPremium: true, isEmergencyText: false, quotaExceeded: false, action: "WATCH_AND_RECHECK", tierUsed: 2 }),
    false,
  );
});
