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

test("rateLimitKey hashes the ip (F6: no raw IP in storage)", async () => {
  const k = await rateLimitKey("1.2.3.4", "salt");
  assert.match(k, /^anon_checker:[0-9a-f]{32}$/);
  assert.ok(!k.includes("1.2.3.4"));
  // Deterministic per (salt, ip); different ips diverge.
  assert.equal(k, await rateLimitKey("1.2.3.4", "salt"));
  assert.notEqual(k, await rateLimitKey("5.6.7.8", "salt"));
});

test("simplifyResult exposes only action + observation (no 'what to do')", () => {
  const full = {
    action: "WATCH_AND_RECHECK",
    observation: "Possible mild GI upset",
    recommended_actions: ["secret step 1", "secret step 2"],
    differential: ["x", "y"],
    visible_symptoms: ["a"],
  };
  const s = simplifyResult(full);
  assert.deepEqual(Object.keys(s).sort(), ["action", "disclaimer_required", "observation"]);
  assert.equal(s.action, "WATCH_AND_RECHECK");
  assert.equal(s.observation, "Possible mild GI upset");
  assert.equal("recommended_actions" in s, false); // detail withheld from anon web
});
