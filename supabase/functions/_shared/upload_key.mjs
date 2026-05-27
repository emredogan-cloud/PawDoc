// Pure storage-key logic for R2 uploads. Plain ESM so it runs in Deno (the
// Edge Function) and Node (the unit test). Namespacing keys under the user id
// keeps one user's uploads isolated from another's.

const ALLOWED_EXT = new Set(["jpg", "jpeg", "png", "webp", "mp4", "mov"]);

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
