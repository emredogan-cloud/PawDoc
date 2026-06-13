// Storage-key unit tests. Run: node --test supabase/functions/_shared/upload_key.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { buildStorageKey, isOwnUploadKey } from "./upload_key.mjs";

const USER = "11111111-1111-1111-1111-111111111111";
const UUID = "22222222-2222-2222-2222-222222222222";
const OTHER = "33333333-3333-3333-3333-333333333333";

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

// --- GAP-A2: isOwnUploadKey gates inbound storage keys (SSRF defense) ---
test("isOwnUploadKey accepts the caller's own well-formed key", () => {
  assert.equal(isOwnUploadKey(`uploads/${USER}/${UUID}.jpg`, USER), true);
  assert.equal(isOwnUploadKey(`uploads/${USER}/${UUID}.webp`, USER), true);
});

test("isOwnUploadKey rejects a key owned by another user", () => {
  assert.equal(isOwnUploadKey(`uploads/${OTHER}/${UUID}.jpg`, USER), false);
});

test("isOwnUploadKey rejects arbitrary URLs / non-uploads strings (SSRF)", () => {
  assert.equal(isOwnUploadKey("http://169.254.169.254/latest/meta-data", USER), false);
  assert.equal(isOwnUploadKey("https://evil.example/x.jpg", USER), false);
  assert.equal(isOwnUploadKey(`../../${USER}/${UUID}.jpg`, USER), false);
  assert.equal(isOwnUploadKey(`uploads/${USER}/../../etc/passwd`, USER), false);
});

test("isOwnUploadKey rejects bad shapes (uuid / ext / type)", () => {
  assert.equal(isOwnUploadKey(`uploads/${USER}/not-a-uuid.jpg`, USER), false);
  assert.equal(isOwnUploadKey(`uploads/${USER}/${UUID}.exe`, USER), false);
  assert.equal(isOwnUploadKey(null, USER), false);
  assert.equal(isOwnUploadKey(`uploads/${USER}/${UUID}.jpg`, ""), false);
});
