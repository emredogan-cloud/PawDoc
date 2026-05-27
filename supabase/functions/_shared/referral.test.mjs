// Referral result-mapping tests. Run: node --test supabase/functions/_shared/referral.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { isFraudStatus, referralResult } from "./referral.mjs";

test("success is ok with a reward message", () => {
  const r = referralResult("success");
  assert.equal(r.ok, true);
  assert.equal(r.status, "success");
  assert.match(r.message, /claimed/i);
});

test("self-referral and double-claim are not ok and preserve status", () => {
  assert.equal(referralResult("self_referral").ok, false);
  assert.equal(referralResult("self_referral").status, "self_referral");
  assert.equal(referralResult("already_claimed").ok, false);
  assert.equal(referralResult("already_claimed").status, "already_claimed");
});

test("invalid code is not ok", () => {
  assert.equal(referralResult("invalid_code").ok, false);
  assert.equal(referralResult("invalid_code").status, "invalid_code");
});

test("unknown status collapses to a safe error", () => {
  const r = referralResult("anything-else");
  assert.equal(r.ok, false);
  assert.equal(r.status, "error");
});

test("isFraudStatus flags self-referral and double-claim only", () => {
  assert.equal(isFraudStatus("self_referral"), true);
  assert.equal(isFraudStatus("already_claimed"), true);
  assert.equal(isFraudStatus("success"), false);
  assert.equal(isFraudStatus("invalid_code"), false);
});
