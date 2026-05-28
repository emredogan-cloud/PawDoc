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
export function rateLimitKey(ip) {
  return `anon_checker:${ip}`;
}

/** True once the IP has exceeded `max` requests in the window. */
export function rateLimitExceeded(count, max) {
  return typeof count === "number" && count > max;
}

/** Strip the full AI result down to what an ANONYMOUS web user may see: the
 *  triage level + a short concern. The detailed "what to do" stays app-only
 *  (conversion funnel) and is never sent over the anonymous endpoint. */
export function simplifyResult(full) {
  return {
    triage_level: full?.triage_level ?? "MONITOR",
    primary_concern: full?.primary_concern ?? "",
    disclaimer_required: true,
  };
}
