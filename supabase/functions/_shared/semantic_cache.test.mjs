// Semantic-cache helper tests. Run: node --test supabase/functions/_shared/semantic_cache.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { formatVector, isCacheEligible, selectCacheHit } from "./semantic_cache.mjs";

test("formatVector renders a pgvector literal", () => {
  assert.equal(formatVector([1, 2, 3]), "[1,2,3]");
  assert.equal(formatVector([0.5, -0.25]), "[0.5,-0.25]");
});

test("formatVector rejects empty / non-numeric input", () => {
  assert.equal(formatVector([]), null);
  assert.equal(formatVector(null), null);
  assert.equal(formatVector([1, "x", 3]), null);
  assert.equal(formatVector([1, NaN]), null);
});

test("selectCacheHit returns the best row at/above threshold", () => {
  const hit = selectCacheHit([{ similarity: 0.95, full_response: { triage_level: "NORMAL" } }], 0.9);
  assert.ok(hit);
  assert.equal(hit.full_response.triage_level, "NORMAL");
});

test("selectCacheHit rejects below-threshold or empty / missing payload", () => {
  assert.equal(selectCacheHit([], 0.9), null);
  assert.equal(selectCacheHit(null, 0.9), null);
  assert.equal(selectCacheHit([{ similarity: 0.8, full_response: {} }], 0.9), null);
  assert.equal(selectCacheHit([{ similarity: 0.99, full_response: null }], 0.9), null);
});

test("isCacheEligible: only text, non-emergency, enabled", () => {
  assert.equal(isCacheEligible("text", false, true), true);
  assert.equal(isCacheEligible("photo", false, true), false); // image is the signal + moderation
  assert.equal(isCacheEligible("video", false, true), false);
  assert.equal(isCacheEligible("text", true, true), false); // emergency must re-run the override
  assert.equal(isCacheEligible("text", false, false), false); // cache disabled
});
