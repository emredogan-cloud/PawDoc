// Anonymous web-checker helper tests. Run: node --test supabase/functions/_shared/web_checker.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { clientIp, rateLimitExceeded, rateLimitKey, simplifyResult } from "./web_checker.mjs";

const hdrs = (obj) => new Map(Object.entries(obj));

test("clientIp prefers cf-connecting-ip, then x-forwarded-for first hop", () => {
  assert.equal(clientIp(hdrs({ "cf-connecting-ip": "1.2.3.4" })), "1.2.3.4");
  assert.equal(clientIp(hdrs({ "x-forwarded-for": "9.9.9.9, 10.0.0.1" })), "9.9.9.9");
  assert.equal(clientIp(hdrs({})), ""); // unknown -> caller fails closed
});

test("rateLimitExceeded fires strictly above max (3/day)", () => {
  assert.equal(rateLimitExceeded(1, 3), false);
  assert.equal(rateLimitExceeded(3, 3), false); // 3rd allowed
  assert.equal(rateLimitExceeded(4, 3), true); // 4th blocked
});

test("rateLimitKey namespaces by ip", () => {
  assert.equal(rateLimitKey("1.2.3.4"), "anon_checker:1.2.3.4");
});

test("simplifyResult exposes only triage + concern (no 'what to do')", () => {
  const full = {
    triage_level: "MONITOR",
    primary_concern: "Possible mild GI upset",
    recommended_actions: ["secret step 1", "secret step 2"],
    differential: ["x", "y"],
    visible_symptoms: ["a"],
  };
  const s = simplifyResult(full);
  assert.deepEqual(Object.keys(s).sort(), ["disclaimer_required", "primary_concern", "triage_level"]);
  assert.equal(s.triage_level, "MONITOR");
  assert.equal(s.primary_concern, "Possible mild GI upset");
  assert.equal("recommended_actions" in s, false); // detail withheld from anon web
});
