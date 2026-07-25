// The internal-tester grant must unlock premium for exactly one status value
// and nothing else — a typo or a loosened check here would either strand the QA
// account or hand premium to paying-tier logic it was never meant to cover.
import { test } from "node:test";
import assert from "node:assert/strict";

import {
  INTERNAL_TESTER_STATUS,
  isPremiumStatus,
  PREMIUM_STATUSES,
} from "./premium.mjs";

test("paid tiers and the internal grant are premium", () => {
  for (const status of ["premium", "trial", INTERNAL_TESTER_STATUS]) {
    assert.equal(isPremiumStatus(status), true, status);
  }
});

test("everything else is not premium", () => {
  for (const status of [
    "free",
    "",
    null,
    undefined,
    "cancelled",
    "expired",
    "family", // deleted tier — must not silently re-enable
    "b2b_lite", // deleted tier
    "INTERNAL_TESTER", // case matters; no fuzzy matching
    "internal_tester ", // no trimming — an exact value or nothing
    "tester",
    "internal",
  ]) {
    assert.equal(isPremiumStatus(status), false, JSON.stringify(status));
  }
});

test("the grant is a distinct status, not an alias of premium", () => {
  // Support/analytics rely on being able to tell them apart.
  assert.notEqual(INTERNAL_TESTER_STATUS, "premium");
  assert.equal(INTERNAL_TESTER_STATUS, "internal_tester");
});

test("the premium set stays small and explicit", () => {
  assert.deepEqual(
    [...PREMIUM_STATUSES].sort(),
    ["internal_tester", "premium", "trial"],
  );
});

test("assistant-chat re-exports the same definition (no drift)", async () => {
  const assistant = await import("./assistant_chat.mjs");
  assert.equal(assistant.INTERNAL_TESTER_STATUS, INTERNAL_TESTER_STATUS);
  assert.equal(assistant.isPremiumStatus(INTERNAL_TESTER_STATUS), true);
  assert.equal(assistant.isPremiumStatus("free"), false);
  assert.deepEqual([...assistant.PREMIUM_STATUSES].sort(), [...PREMIUM_STATUSES].sort());
});
