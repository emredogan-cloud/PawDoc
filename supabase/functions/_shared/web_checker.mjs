// Pure helpers for the anonymous web symptom checker (Phase 5.2). Plain ESM so
// it runs in Deno (the Edge Function) and Node (the unit test).

/** Best-effort client IP for rate limiting: Cloudflare's header first, then the
 *  first hop of x-forwarded-for. Returns "" when unknown (caller fails closed). */
export function clientIp(headers) {
  const get = (name) =>
    typeof headers?.get === "function" ? headers.get(name) : headers?.[name];
  const cf = get("cf-connecting-ip");
  if (cf) return String(cf).trim();
  const xff = get("x-forwarded-for");
  if (xff) return String(xff).split(",")[0].trim();
  const real = get("x-real-ip");
  return real ? String(real).trim() : "";
}

/** Fixed-window rate-limit key (one 24h window per IP). */
/** F6 (evolution): the raw IP never lands in storage — an unkeyed SHA-256 of
 *  (salt + ip) namespaces the counter instead. The salt is an env secret so
 *  stored keys can't be reversed by rainbow-tabling IPv4 space. */
export async function rateLimitKey(ip, salt = "") {
  const data = new TextEncoder().encode(`${salt}:${ip}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  const hex = Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `anon_checker:${hex.slice(0, 32)}`;
}

/** True once the IP has exceeded `max` requests in the window. */
export function rateLimitExceeded(count, max) {
  return typeof count === "number" && count > max;
}

/** Strip the full AI result down to what an ANONYMOUS web user may see: the
 *  action + a short observation. The detailed "what to do" stays app-only
 *  (conversion funnel) and is never sent over the anonymous endpoint. */
export function simplifyResult(full) {
  return {
    action: full?.action ?? "WATCH_AND_RECHECK",
    observation: full?.observation ?? "",
    disclaimer_required: true,
  };
}
