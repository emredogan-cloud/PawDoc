// Pure storage-key logic for R2 uploads. Plain ESM so it runs in Deno (the
// Edge Function) and Node (the unit test). Namespacing keys under the user id
// keeps one user's uploads isolated from another's.

const ALLOWED_EXT = new Set(["jpg", "jpeg", "png", "webp"]);

/** `uploads/<userId>/<uuid>.<ext>`, with validation/sanitization. Throws on bad input. */
export function buildStorageKey(userId, ext, uuid) {
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
  return `uploads/${userId}/${uuid}.${clean}`;
}

/**
 * GAP-A2: true iff `key` is a well-formed `uploads/<userId>/<uuid>.<ext>` owned
 * by `userId`. /analyze uses this to reject any client-supplied storage key
 * outside the caller's own namespace before presigning a GET URL — closing the
 * blind-SSRF vector where the client could hand the server an arbitrary URL/key.
 * No path traversal; extension must be on the allowlist.
 */
export function isOwnUploadKey(key, userId) {
  if (typeof key !== "string" || !userId) return false;
  if (key.includes("..") || key.includes("\\")) return false;
  const m = /^uploads\/([0-9a-fA-F-]{36})\/([0-9a-fA-F-]{36})\.([a-z0-9]+)$/.exec(key);
  if (!m) return false;
  if (m[1] !== userId) return false;
  return ALLOWED_EXT.has(m[3]);
}
