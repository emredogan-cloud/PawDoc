// Tests for ai-service.ts — response validation + error mapping.
//
// Network paths are exercised by mocking globalThis.fetch. The validator
// is exercised with hand-crafted payloads.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { callAiService } from "./ai-service.ts";

function setEnv(): void {
  Deno.env.set("AI_SERVICE_URL", "https://ai.test");
  Deno.env.set("INTERNAL_API_TOKEN", "secret");
}

function validAiResponse(): Record<string, unknown> {
  return {
    triage_level: "MONITOR",
    confidence: 0.82,
    primary_concern: "Plausible mild GI upset.",
    visible_symptoms: ["loose stool"],
    differential: ["dietary indiscretion"],
    recommended_actions: ["Bland diet for 24h."],
    urgency_timeframe: "Within 24 hours.",
    disclaimer_required: true,
    disclaimer_text: "PawDoc provides triage guidance...",
    model_used: "claude-sonnet-test",
    tier_used: 3,
    emergency_override_applied: false,
    cross_verify_disagreement: false,
    ai_latency_ms: 1234,
    request_id: "req_test",
  };
}

Deno.test("callAiService returns parsed result on 200", async () => {
  setEnv();
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(JSON.stringify(validAiResponse()), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    )) as typeof fetch;

  try {
    const result = await callAiService({
      request_id: "req_test",
      pet: { pet_id: "p1", name: "Luna", species: "dog" },
      input_type: "text",
      text_description: "limping",
    });
    assertEquals(result.triage_level, "MONITOR");
    assertEquals(result.tier_used, 3);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("callAiService maps 5xx to upstream_error", async () => {
  setEnv();
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (() => Promise.resolve(new Response("", { status: 502 }))) as typeof fetch;

  try {
    await assertRejects(
      () =>
        callAiService({
          request_id: "req_test",
          pet: { pet_id: "p1", name: "Luna", species: "dog" },
          input_type: "text",
          text_description: "limping",
        }),
      Error,
      "AI service returned HTTP",
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("callAiService rejects response missing required string field", async () => {
  setEnv();
  const bad = validAiResponse();
  delete bad.primary_concern;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(JSON.stringify(bad), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    )) as typeof fetch;

  try {
    await assertRejects(
      () =>
        callAiService({
          request_id: "req_test",
          pet: { pet_id: "p1", name: "Luna", species: "dog" },
          input_type: "text",
          text_description: "x",
        }),
      Error,
      "primary_concern",
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("callAiService rejects bad triage_level", async () => {
  setEnv();
  const bad = validAiResponse();
  bad.triage_level = "URGENT";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(JSON.stringify(bad), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    )) as typeof fetch;

  try {
    await assertRejects(
      () =>
        callAiService({
          request_id: "req_test",
          pet: { pet_id: "p1", name: "Luna", species: "dog" },
          input_type: "text",
          text_description: "x",
        }),
      Error,
      "triage_level",
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});
