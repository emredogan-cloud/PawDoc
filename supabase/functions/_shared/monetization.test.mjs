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

// --- Phase 5.4: B2B-Lite (sitter) + Family entitlement mapping --------------
test("RevenueCat entitlement_id 'b2b_lite' maps to b2b_lite status", () => {
  assert.equal(
    entitlementStatusFromEvent({ type: "INITIAL_PURCHASE", entitlement_ids: ["b2b_lite"] }),
    "b2b_lite",
  );
  // Also accepts the singular form some webhook payloads use.
  assert.equal(
    entitlementStatusFromEvent({ type: "RENEWAL", entitlement_id: "b2b_lite" }),
    "b2b_lite",
  );
});

test("RevenueCat entitlement 'family' maps to family", () => {
  assert.equal(
    entitlementStatusFromEvent({ type: "INITIAL_PURCHASE", entitlement_ids: ["family"] }),
    "family",
  );
});

test("Unknown / missing entitlement falls back to legacy 'premium'", () => {
  // Preserves existing customers (no entitlement_id field on older events).
  assert.equal(entitlementStatusFromEvent({ type: "RENEWAL", entitlement_ids: ["pro"] }), "premium");
  assert.equal(entitlementStatusFromEvent({ type: "INITIAL_PURCHASE", entitlement_ids: [] }), "premium");
});

test("Trial period beats entitlement-id (RC reports period_type=TRIAL)", () => {
  assert.equal(
    entitlementStatusFromEvent({
      type: "INITIAL_PURCHASE",
      period_type: "TRIAL",
      entitlement_ids: ["b2b_lite"],
    }),
    "trial",
  );
});

// --- Phase 6.3: PDF Health Report add-on (consumable) -----------------------
import { ADDON_PRODUCTS, addonCreditsFromEvent } from "./revenuecat.mjs";

test("PDF Health Report addon is registered with a +1 credit grant", () => {
  assert.deepEqual(
    ADDON_PRODUCTS.pdf_report_addon,
    { column: "pdf_reports_remaining", delta: 1 },
  );
});

test("NON_RENEWING_PURCHASE of pdf_report_addon grants 1 credit", () => {
  const credit = addonCreditsFromEvent({
    type: "NON_RENEWING_PURCHASE",
    product_id: "pdf_report_addon",
    app_user_id: "u1",
  });
  assert.equal(credit?.column, "pdf_reports_remaining");
  assert.equal(credit?.delta, 1);
  assert.equal(credit?.productId, "pdf_report_addon");
});

test("INITIAL_PURCHASE of pdf_report_addon also grants a credit (non-consumable case)", () => {
  // Some projects ship the addon as a non-consumable; we recognize both.
  const credit = addonCreditsFromEvent({
    type: "INITIAL_PURCHASE",
    product_identifier: "pdf_report_addon",
  });
  assert.equal(credit?.delta, 1);
});

test("Unknown product or unrelated event yields no credit", () => {
  assert.equal(
    addonCreditsFromEvent({ type: "NON_RENEWING_PURCHASE", product_id: "some_other" }),
    null,
  );
  assert.equal(
    addonCreditsFromEvent({ type: "RENEWAL", product_id: "pdf_report_addon" }),
    null,
  );
  assert.equal(addonCreditsFromEvent({}), null);
  assert.equal(addonCreditsFromEvent(null), null);
});
