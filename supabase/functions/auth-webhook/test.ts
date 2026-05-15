// Deno tests for auth-webhook validation + signature verification.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { verifyWebhookSecret } from "../_shared/auth.ts";

Deno.test("verifyWebhookSecret rejects missing header", () => {
  Deno.env.set("SUPABASE_AUTH_WEBHOOK_SECRET", "secret123");
  const req = new Request("http://test", { method: "POST" });
  try {
    verifyWebhookSecret(req, "SUPABASE_AUTH_WEBHOOK_SECRET");
    throw new Error("expected to throw");
  } catch (e) {
    if (e instanceof Error) {
      assertEquals(e.message.includes("Authorization"), true);
    }
  }
});

Deno.test("verifyWebhookSecret rejects mismatched secret", () => {
  Deno.env.set("SUPABASE_AUTH_WEBHOOK_SECRET", "secret123");
  const req = new Request("http://test", {
    method: "POST",
    headers: { Authorization: "Bearer wrong" },
  });
  try {
    verifyWebhookSecret(req, "SUPABASE_AUTH_WEBHOOK_SECRET");
    throw new Error("expected to throw");
  } catch (e) {
    if (e instanceof Error) {
      assertEquals(e.message.includes("Invalid webhook signature"), true);
    }
  }
});

Deno.test("verifyWebhookSecret accepts matching secret", () => {
  Deno.env.set("SUPABASE_AUTH_WEBHOOK_SECRET", "secret123");
  const req = new Request("http://test", {
    method: "POST",
    headers: { Authorization: "Bearer secret123" },
  });
  // Should not throw.
  verifyWebhookSecret(req, "SUPABASE_AUTH_WEBHOOK_SECRET");
});

Deno.test("verifyWebhookSecret rejects when env unset", async () => {
  Deno.env.delete("SUPABASE_AUTH_WEBHOOK_SECRET");
  const req = new Request("http://test", {
    method: "POST",
    headers: { Authorization: "Bearer anything" },
  });
  await assertRejects(
    () => Promise.resolve().then(() => verifyWebhookSecret(req, "SUPABASE_AUTH_WEBHOOK_SECRET")),
    Error,
    "Webhook not configured",
  );
});
