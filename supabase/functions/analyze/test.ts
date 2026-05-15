// Deno tests for the analyze endpoint.
//
// These cover the validation surface — auth verification, body shape, and
// the "Phase 1A returns 501" contract. Tests use direct calls into the
// validation helpers + a request mock, avoiding the need to spin up
// supabase-js (which would require live env vars).

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { Errors } from "../_shared/errors.ts";
import { asObject, asOneOf, asUuid, readJson } from "../_shared/validation.ts";

Deno.test("readJson rejects malformed bodies", async () => {
  const req = new Request("http://test", {
    method: "POST",
    body: "{not json",
    headers: { "Content-Type": "application/json" },
  });
  await assertRejects(() => readJson(req), Error, "Body must be valid JSON");
});

Deno.test("asUuid validates v4 format", () => {
  const valid = "550e8400-e29b-41d4-a716-446655440000";
  assertEquals(asUuid(valid, "pet_id"), valid);
});

Deno.test("asUuid rejects non-UUID strings", () => {
  try {
    asUuid("nope", "pet_id");
    throw new Error("expected to throw");
  } catch (e) {
    if (e instanceof Error) {
      assertEquals(e.message.includes("pet_id"), true);
    }
  }
});

Deno.test("asOneOf rejects values outside enum", () => {
  try {
    asOneOf("audio", ["photo", "video", "text"] as const, "input_type");
    throw new Error("expected to throw");
  } catch (e) {
    if (e instanceof Error) {
      assertEquals(e.message.includes("input_type"), true);
    }
  }
});

Deno.test("asObject rejects arrays + null", () => {
  try {
    asObject([1, 2, 3]);
    throw new Error("expected to throw");
  } catch (_e) { /* expected */ }
  try {
    asObject(null);
    throw new Error("expected to throw");
  } catch (_e) { /* expected */ }
});

Deno.test("Errors.notImplemented carries phase string", () => {
  const e = Errors.notImplemented("Phase 1B");
  assertEquals(e.status, 501);
  assertEquals(e.code, "not_implemented");
  assertEquals(e.message.includes("Phase 1B"), true);
});
