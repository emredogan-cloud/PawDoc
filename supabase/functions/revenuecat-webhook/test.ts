// Deno tests for revenuecat-webhook validation.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { asObject, asString } from "../_shared/validation.ts";

Deno.test("revenuecat event parsing — happy path shape", () => {
  const raw = {
    event: {
      type: "INITIAL_PURCHASE",
      app_user_id: "user_abc",
      product_id: "pawdoc_premium_monthly",
      environment: "PRODUCTION",
    },
  };
  const obj = asObject(raw);
  const evt = asObject(obj.event, "event");
  assertEquals(asString(evt.type, "event.type"), "INITIAL_PURCHASE");
  assertEquals(asString(evt.app_user_id, "event.app_user_id"), "user_abc");
});

Deno.test("revenuecat event parsing — missing event throws", () => {
  try {
    asObject({}).event as unknown;
    asObject(undefined, "event");
    throw new Error("expected to throw");
  } catch (e) {
    if (e instanceof Error) {
      assertEquals(e.message.includes("event"), true);
    }
  }
});
