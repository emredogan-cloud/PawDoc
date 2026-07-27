// Storage-key unit tests. Run: node --test supabase/functions/_shared/upload_key.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import {
  buildStorageKey,
  DELETABLE_SCOPES,
  DISPLAY_SCOPES,
  isOwnMediaKey,
  isOwnUploadKey,
  parseMediaKey,
  sanitizeKeyBatch,
} from "./upload_key.mjs";

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

// --- Next Evolution Phase 2: scoped keys (memories / chat) ---
test("builds scoped keys and rejects unknown scopes", () => {
  assert.equal(
    buildStorageKey(USER, "jpg", UUID, "memories"),
    `memories/${USER}/${UUID}.jpg`,
  );
  assert.equal(
    buildStorageKey(USER, "webp", UUID, "chat"),
    `chat/${USER}/${UUID}.webp`,
  );
  assert.throws(() => buildStorageKey(USER, "jpg", UUID, "evil"), /disallowed scope/);
  assert.throws(() => buildStorageKey(USER, "jpg", UUID, "UPLOADS"), /disallowed scope/);
});

test("isOwnUploadKey stays uploads-only (analysis gate unchanged)", () => {
  assert.equal(isOwnUploadKey(`memories/${USER}/${UUID}.jpg`, USER), false);
  assert.equal(isOwnUploadKey(`chat/${USER}/${UUID}.jpg`, USER), false);
});

test("parseMediaKey extracts parts and rejects malformed keys", () => {
  assert.deepEqual(parseMediaKey(`memories/${USER}/${UUID}.jpg`), {
    scope: "memories",
    userId: USER,
    uuid: UUID,
    ext: "jpg",
  });
  assert.equal(parseMediaKey(`secrets/${USER}/${UUID}.jpg`), null);
  assert.equal(parseMediaKey(`memories/${USER}/${UUID}.exe`), null);
  assert.equal(parseMediaKey(`memories/${USER}/../${UUID}.jpg`), null);
  assert.equal(parseMediaKey(42), null);
});

test("isOwnMediaKey honors ownership and the scope allowlist", () => {
  assert.equal(isOwnMediaKey(`memories/${USER}/${UUID}.jpg`, USER), true);
  assert.equal(isOwnMediaKey(`chat/${USER}/${UUID}.jpg`, USER), true);
  // Display scopes exclude uploads/ — analysis images are never re-displayed.
  assert.equal(isOwnMediaKey(`uploads/${USER}/${UUID}.jpg`, USER), false);
  assert.equal(isOwnMediaKey(`memories/${OTHER}/${UUID}.jpg`, USER), false);
  // Deletable scopes are memories-only (chat/analysis objects can't be nuked).
  assert.equal(isOwnMediaKey(`memories/${USER}/${UUID}.jpg`, USER, DELETABLE_SCOPES), true);
  assert.equal(isOwnMediaKey(`chat/${USER}/${UUID}.jpg`, USER, DELETABLE_SCOPES), false);
});

test("sanitizeKeyBatch drops foreign/invalid keys, dedupes, and caps", () => {
  const mine = `memories/${USER}/${UUID}.jpg`;
  const theirs = `memories/${OTHER}/${UUID}.jpg`;
  assert.deepEqual(
    sanitizeKeyBatch([mine, theirs, mine, "junk", null], USER),
    [mine],
  );
  assert.deepEqual(sanitizeKeyBatch("not-an-array", USER), []);
  const many = Array.from({ length: 30 }, (_, i) =>
    buildStorageKey(USER, "jpg", `${String(i).padStart(8, "0")}-2222-2222-2222-222222222222`, "memories"));
  assert.equal(sanitizeKeyBatch(many, USER, DISPLAY_SCOPES, 24).length, 24);
});

// ── Pet profile photos (post-beta polish) ────────────────────────────────────
// The `pets/` scope is displayable AND owner-deletable — replacing a photo must
// not strand the old object — while `uploads/` stays neither.
test("pets scope: displayable and deletable, uploads still neither", () => {
  assert.ok(DISPLAY_SCOPES.includes("pets"));
  assert.ok(DELETABLE_SCOPES.includes("pets"));
  assert.ok(!DISPLAY_SCOPES.includes("uploads"));
  assert.ok(!DELETABLE_SCOPES.includes("uploads"));
});

test("pets keys build and parse", () => {
  const uid = "11111111-1111-4111-8111-111111111111";
  const obj = "22222222-2222-4222-8222-222222222222";
  const key = buildStorageKey(uid, "jpg", obj, "pets");
  assert.equal(key, `pets/${uid}/${obj}.jpg`);
  assert.deepEqual(parseMediaKey(key), {
    scope: "pets",
    userId: uid,
    uuid: obj,
    ext: "jpg",
  });
});

test("a pet photo key belonging to someone else is not mine", () => {
  const mine = "11111111-1111-4111-8111-111111111111";
  const theirs = "33333333-3333-4333-8333-333333333333";
  const obj = "22222222-2222-4222-8222-222222222222";
  assert.equal(isOwnMediaKey(`pets/${mine}/${obj}.jpg`, mine, DISPLAY_SCOPES), true);
  assert.equal(isOwnMediaKey(`pets/${theirs}/${obj}.jpg`, mine, DISPLAY_SCOPES), false);
});

test("a pet photo key is never accepted by the analysis SSRF gate", () => {
  // /analyze presigns only `uploads/`; a display-scope key must not slip in.
  const uid = "11111111-1111-4111-8111-111111111111";
  const obj = "22222222-2222-4222-8222-222222222222";
  assert.equal(isOwnUploadKey(`pets/${uid}/${obj}.jpg`, uid), false);
});
