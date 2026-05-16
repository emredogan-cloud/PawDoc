// Tests for the RevenueCat → users.subscription_status mapping.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { deriveUpdate, productTier } from "./state_map.ts";

function setProductEnv() {
  Deno.env.set("REVENUECAT_PRODUCT_PREMIUM_MONTHLY", "pawdoc_premium_monthly");
  Deno.env.set("REVENUECAT_PRODUCT_PREMIUM_ANNUAL", "pawdoc_premium_annual");
  Deno.env.set("REVENUECAT_PRODUCT_FAMILY_MONTHLY", "pawdoc_family_monthly");
  Deno.env.set("REVENUECAT_PRODUCT_FAMILY_ANNUAL", "pawdoc_family_annual");
}

function clearProductEnv() {
  Deno.env.delete("REVENUECAT_PRODUCT_PREMIUM_MONTHLY");
  Deno.env.delete("REVENUECAT_PRODUCT_PREMIUM_ANNUAL");
  Deno.env.delete("REVENUECAT_PRODUCT_FAMILY_MONTHLY");
  Deno.env.delete("REVENUECAT_PRODUCT_FAMILY_ANNUAL");
}

Deno.test("productTier maps premium products → premium status", () => {
  setProductEnv();
  try {
    assertEquals(
      productTier("pawdoc_premium_monthly"),
      { status: "premium", tier: "pawdoc_premium_monthly" },
    );
    assertEquals(
      productTier("pawdoc_premium_annual"),
      { status: "premium", tier: "pawdoc_premium_annual" },
    );
  } finally {
    clearProductEnv();
  }
});

Deno.test("productTier maps family products → family status", () => {
  setProductEnv();
  try {
    assertEquals(
      productTier("pawdoc_family_monthly"),
      { status: "family", tier: "pawdoc_family_monthly" },
    );
    assertEquals(
      productTier("pawdoc_family_annual"),
      { status: "family", tier: "pawdoc_family_annual" },
    );
  } finally {
    clearProductEnv();
  }
});

Deno.test("productTier defaults unknown products to premium (fail-safe)", () => {
  setProductEnv();
  try {
    const r = productTier("some_new_product_we_havent_mapped");
    assertEquals(r.status, "premium");
    assertEquals(r.tier, "some_new_product_we_havent_mapped");
  } finally {
    clearProductEnv();
  }
});

Deno.test("productTier maps null product to unknown/premium safe default", () => {
  clearProductEnv();
  const r = productTier(null);
  assertEquals(r.status, "premium");
  assertEquals(r.tier, "unknown");
});

Deno.test("INITIAL_PURCHASE produces an upgrade", () => {
  setProductEnv();
  try {
    const d = deriveUpdate({ type: "INITIAL_PURCHASE", productId: "pawdoc_premium_annual" });
    assertEquals(d, { status: "premium", tier: "pawdoc_premium_annual" });
  } finally {
    clearProductEnv();
  }
});

Deno.test("RENEWAL with a family product upgrades to family", () => {
  setProductEnv();
  try {
    const d = deriveUpdate({ type: "RENEWAL", productId: "pawdoc_family_monthly" });
    assertEquals(d, { status: "family", tier: "pawdoc_family_monthly" });
  } finally {
    clearProductEnv();
  }
});

Deno.test("PRODUCT_CHANGE re-derives from the new product id", () => {
  setProductEnv();
  try {
    const d = deriveUpdate({ type: "PRODUCT_CHANGE", productId: "pawdoc_family_annual" });
    assertEquals(d, { status: "family", tier: "pawdoc_family_annual" });
  } finally {
    clearProductEnv();
  }
});

Deno.test("EXPIRATION downgrades to free", () => {
  const d = deriveUpdate({ type: "EXPIRATION", productId: "pawdoc_premium_annual" });
  assertEquals(d, { status: "free", tier: "" });
});

Deno.test("BILLING_ISSUE downgrades to free", () => {
  const d = deriveUpdate({ type: "BILLING_ISSUE", productId: null });
  assertEquals(d, { status: "free", tier: "" });
});

Deno.test("CANCELLATION is a no-op (entitlement still active)", () => {
  const d = deriveUpdate({ type: "CANCELLATION", productId: "pawdoc_premium_annual" });
  assertEquals(d.status, null);
});

Deno.test("UNCANCELLATION re-derives subscription state", () => {
  setProductEnv();
  try {
    const d = deriveUpdate({ type: "UNCANCELLATION", productId: "pawdoc_premium_monthly" });
    assertEquals(d, { status: "premium", tier: "pawdoc_premium_monthly" });
  } finally {
    clearProductEnv();
  }
});

Deno.test("TRANSFER is logged but not applied", () => {
  const d = deriveUpdate({ type: "TRANSFER", productId: null });
  assertEquals(d.status, null);
});

Deno.test("TEST events from the dashboard are no-ops", () => {
  const d = deriveUpdate({ type: "TEST", productId: null });
  assertEquals(d.status, null);
});

Deno.test("NON_RENEWING_PURCHASE is a no-op", () => {
  const d = deriveUpdate({ type: "NON_RENEWING_PURCHASE", productId: null });
  assertEquals(d.status, null);
});

Deno.test("SUBSCRIPTION_PAUSED is a no-op (treat as still entitled)", () => {
  const d = deriveUpdate({ type: "SUBSCRIPTION_PAUSED", productId: null });
  assertEquals(d.status, null);
});

Deno.test("Unknown event types ack but do not mutate", () => {
  const d = deriveUpdate({ type: "INVENTED_FUTURE_EVENT", productId: null });
  assertEquals(d.status, null);
});

Deno.test("Idempotency: re-applying the same renewal produces same decision", () => {
  setProductEnv();
  try {
    const e = { type: "RENEWAL", productId: "pawdoc_premium_annual" };
    const a = deriveUpdate(e);
    const b = deriveUpdate(e);
    assertEquals(a, b);
  } finally {
    clearProductEnv();
  }
});
