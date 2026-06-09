import { test } from "node:test";
import assert from "node:assert/strict";

import { aiServiceHeaders } from "./ai_service.mjs";

test("attaches a bearer credential when the token is configured (prod)", () => {
  const h = aiServiceHeaders("rid-123", "s3cret-token");
  assert.equal(h["authorization"], "Bearer s3cret-token");
  assert.equal(h["x-request-id"], "rid-123");
  assert.equal(h["content-type"], "application/json");
});

test("omits the authorization header when the token is empty (dev)", () => {
  const h = aiServiceHeaders("rid-456", "");
  assert.equal(h["authorization"], undefined);
  assert.equal(h["x-request-id"], "rid-456");
  assert.equal(h["content-type"], "application/json");
});

test("treats a missing token argument as no-auth (does not throw)", () => {
  const h = aiServiceHeaders("rid-789", undefined);
  assert.equal(h["authorization"], undefined);
  assert.equal(h["x-request-id"], "rid-789");
});
