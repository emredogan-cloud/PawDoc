// Storage-key unit tests. Run: node --test supabase/functions/_shared/upload_key.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { buildStorageKey } from "./upload_key.mjs";

const USER = "11111111-1111-1111-1111-111111111111";
const UUID = "22222222-2222-2222-2222-222222222222";

test("builds a user-namespaced key", () => {
  assert.equal(buildStorageKey(USER, "jpg", UUID), `uploads/${USER}/${UUID}.jpg`);
});

test("sanitizes the extension (no path traversal / junk)", () => {
  assert.equal(buildStorageKey(USER, "../JPG", UUID), `uploads/${USER}/${UUID}.jpg`);
});

test("rejects a disallowed extension", () => {
  assert.throws(() => buildStorageKey(USER, "exe", UUID), /disallowed extension/);
});

test("rejects a bad user id (prevents cross-user key forging)", () => {
  assert.throws(() => buildStorageKey("not-a-uuid", "jpg", UUID), /invalid user id/);
});
