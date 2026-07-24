// Pure storage-key logic for R2 uploads. Plain ESM so it runs in Deno (the
// Edge Function) and Node (the unit test). Namespacing keys under the user id
// keeps one user's uploads isolated from another's.

const ALLOWED_EXT = new Set(["jpg", "jpeg", "png", "webp"]);

// Next Evolution Phase 2: keys are scoped by purpose. `uploads/` feeds the
// analysis pipeline (never re-displayed), `memories/` is the pet journal,
// `chat/` is assistant attachments. Scopes keep the analysis SSRF gate
// (`isOwnUploadKey`) untouched while letting display surfaces sign GETs for
// their own media only.
export const MEDIA_SCOPES = Object.freeze(["uploads", "memories", "chat"]);
// Scopes whose objects may be re-displayed to their owner via signed GET URLs.
// `uploads/` is deliberately absent: analysis images stay non-displayable.
export const DISPLAY_SCOPES = Object.freeze(["memories", "chat"]);
// Scopes whose objects the owner may delete directly (journal media).
export const DELETABLE_SCOPES = Object.freeze(["memories"]);

/** `<scope>/<userId>/<uuid>.<ext>`, with validation/sanitization. Throws on bad input. */
export function buildStorageKey(userId, ext, uuid, scope = "uploads") {
  if (!MEDIA_SCOPES.includes(scope)) {
    throw new Error(`disallowed scope: ${scope}`);
  }
  if (!userId || !/^[0-9a-fA-F-]{36}$/.test(userId)) {
    throw new Error("invalid user id");
  }
  if (!uuid || !/^[0-9a-fA-F-]{36}$/.test(uuid)) {
    throw new Error("invalid uuid");
  }
  const clean = String(ext ?? "jpg").toLowerCase().replace(/[^a-z0-9]/g, "");
  if (!ALLOWED_EXT.has(clean)) {
    throw new Error(`disallowed extension: ${ext}`);
  }
  return `${scope}/${userId}/${uuid}.${clean}`;
}

/**
 * Parse a storage key into its parts, or null when it is not a well-formed
 * `<scope>/<uuid-user>/<uuid>.<ext>` key. Shared shape guard for every
 * key-accepting Edge Function (no traversal, allowlisted scope + extension).
 */
export function parseMediaKey(key) {
  if (typeof key !== "string") return null;
  if (key.includes("..") || key.includes("\\")) return null;
  const m = /^([a-z]+)\/([0-9a-fA-F-]{36})\/([0-9a-fA-F-]{36})\.([a-z0-9]+)$/.exec(key);
  if (!m) return null;
  if (!MEDIA_SCOPES.includes(m[1])) return null;
  if (!ALLOWED_EXT.has(m[4])) return null;
  return { scope: m[1], userId: m[2], uuid: m[3], ext: m[4] };
}

/**
 * GAP-A2: true iff `key` is a well-formed `uploads/<userId>/<uuid>.<ext>` owned
 * by `userId`. /analyze uses this to reject any client-supplied storage key
 * outside the caller's own namespace before presigning a GET URL — closing the
 * blind-SSRF vector where the client could hand the server an arbitrary URL/key.
 * No path traversal; extension must be on the allowlist.
 */
export function isOwnUploadKey(key, userId) {
  const parsed = parseMediaKey(key);
  return !!parsed && parsed.scope === "uploads" && !!userId && parsed.userId === userId;
}

/**
 * True iff `key` is a well-formed key owned by `userId` in one of `scopes`.
 * Used by sign-media-url (DISPLAY_SCOPES) and delete-media (DELETABLE_SCOPES).
 */
export function isOwnMediaKey(key, userId, scopes = DISPLAY_SCOPES) {
  const parsed = parseMediaKey(key);
  return !!parsed && scopes.includes(parsed.scope) && !!userId && parsed.userId === userId;
}

/**
 * Sanitize a client-supplied key batch for signing: must be an array, each key
 * must pass isOwnMediaKey, dedupe, cap at `max`. Returns the clean list (order
 * preserved) — invalid keys are dropped, never signed.
 */
export function sanitizeKeyBatch(keys, userId, scopes = DISPLAY_SCOPES, max = 24) {
  if (!Array.isArray(keys)) return [];
  const seen = new Set();
  const out = [];
  for (const key of keys) {
    if (out.length >= max) break;
    if (seen.has(key)) continue;
    if (!isOwnMediaKey(key, userId, scopes)) continue;
    seen.add(key);
    out.push(key);
  }
  return out;
}
