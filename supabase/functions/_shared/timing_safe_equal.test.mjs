import { test } from "node:test";
import assert from "node:assert/strict";
import { timingSafeEqual } from "./timing_safe_equal.mjs";

test("identical strings match", () => {
  assert.equal(timingSafeEqual("rc-secret-abc123", "rc-secret-abc123"), true);
});

test("strings differing in one byte do not match", () => {
  assert.equal(timingSafeEqual("rc-secret-abc123", "rc-secret-abc124"), false);
});

test("different lengths do not match (no prefix match)", () => {
  assert.equal(timingSafeEqual("rc-secret", "rc-secret-and-more"), false);
});

test("empty vs non-empty does not match", () => {
  assert.equal(timingSafeEqual("", "x"), false);
});

test("two empty strings match", () => {
  assert.equal(timingSafeEqual("", ""), true);
});

test("null/undefined are coerced and do not throw", () => {
  assert.equal(timingSafeEqual(null, undefined), true); // both -> ""
  assert.equal(timingSafeEqual(null, "x"), false);
});
