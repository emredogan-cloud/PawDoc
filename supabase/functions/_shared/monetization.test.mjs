// Run: node --test supabase/functions/_shared/monetization.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { EMERGENCY_KEYWORDS, containsEmergencyKeyword } from "./emergency_keywords.mjs";
import { entitlementStatusFromEvent } from "./revenuecat.mjs";

test("emergency keyword list mirrors the AI service (23, no dupes)", () => {
  assert.equal(EMERGENCY_KEYWORDS.length, 23);
  assert.equal(new Set(EMERGENCY_KEYWORDS).size, 23);
});

test("emergency keyword detection is case-insensitive", () => {
  assert.equal(containsEmergencyKeyword("My dog had a SEIZURE"), true);
  assert.equal(containsEmergencyKeyword("ate something toxic last night"), true);
  assert.equal(containsEmergencyKeyword("happy and eating well"), false);
  assert.equal(containsEmergencyKeyword(null), false);
});

test("RevenueCat events map to subscription_status", () => {
  assert.equal(entitlementStatusFromEvent({ type: "INITIAL_PURCHASE" }), "premium");
  assert.equal(entitlementStatusFromEvent({ type: "INITIAL_PURCHASE", period_type: "TRIAL" }), "trial");
  assert.equal(entitlementStatusFromEvent({ type: "RENEWAL" }), "premium");
  assert.equal(entitlementStatusFromEvent({ type: "EXPIRATION" }), "free");
  assert.equal(entitlementStatusFromEvent({ type: "CANCELLATION" }), null);
  assert.equal(entitlementStatusFromEvent({ type: "BILLING_ISSUE" }), null);
});
