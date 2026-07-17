// Quota gate v3 tests: free = safety (text unmetered), paid = memory (photos
// metered PRE-AI). GET_HELP_NOW is never counted; nothing blocks after the AI.
// Run: node --test supabase/functions/_shared/quota_gate.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { blockBeforeAi, countsAgainstQuota, isMetered } from "./quota_gate.mjs";

test("text is never metered and never blocked — in or out of quota", () => {
  assert.equal(isMetered("text"), false);
  assert.equal(blockBeforeAi("text", false), false);
  assert.equal(blockBeforeAi("text", true), false);
});

test("photos are metered: out-of-quota photos block BEFORE any AI call", () => {
  assert.equal(isMetered("photo"), true);
  assert.equal(blockBeforeAi("photo", false), false);
  assert.equal(blockBeforeAi("photo", true), true); // BE-01 dead: no model runs
});

test("counting: only a real, surfaced free photo analysis counts", () => {
  assert.equal(
    countsAgainstQuota({ isPremium: false, inputType: "photo", action: "WATCH_AND_RECHECK", tierUsed: 2 }),
    true,
  );
  // Text never counts (unmetered).
  assert.equal(
    countsAgainstQuota({ isPremium: false, inputType: "text", action: "WATCH_AND_RECHECK", tierUsed: 2 }),
    false,
  );
  // Premium never counts.
  assert.equal(
    countsAgainstQuota({ isPremium: true, inputType: "photo", action: "WATCH_AND_RECHECK", tierUsed: 2 }),
    false,
  );
  // GET_HELP_NOW never counts (belt).
  assert.equal(
    countsAgainstQuota({ isPremium: false, inputType: "photo", action: "GET_HELP_NOW", tierUsed: 3 }),
    false,
  );
  // Degraded answers never count (GAP-E7).
  assert.equal(
    countsAgainstQuota({ isPremium: false, inputType: "photo", action: "WATCH_AND_RECHECK", tierUsed: 0 }),
    false,
  );
});
