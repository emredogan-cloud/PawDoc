// Phase 5.2 — /analyze-anonymous
// The ONLY anonymous AI path (the main /analyze stays authenticated). Built for
// the free web symptom checker. Anonymous AI is a cost-abuse magnet, so this is
// protected by TWO non-negotiable controls (CR #5 / #13):
//   1. Cloudflare Turnstile (bot block) — token verified server-side.
//   2. Upstash IP rate limit — max 3 analyses per IP per 24h, clean 429 when hit.
// It FAILS CLOSED (503) if either control isn't configured, so we never serve
// unprotected anonymous AI ("zero cost bleed"). It returns ONLY a simplified
// result (triage level + short concern); the detailed guidance stays app-only.
//
// verify_jwt = false (no user); the controls above are the gate.
import {
  clientIp,
  rateLimitExceeded,
  rateLimitKey,
  // deno-lint-ignore no-import-assertions
  simplifyResult,
} from "../_shared/web_checker.mjs";
// deno-lint-ignore no-import-assertions
import { aiServiceHeaders } from "../_shared/ai_service.mjs";

const AI_SERVICE_URL = Deno.env.get("AI_SERVICE_URL") ?? "https://pawdoc-ai.fly.dev";
// Phase A — trust-boundary credential presented to the internal AI service.
const AI_SERVICE_TOKEN = Deno.env.get("AI_SERVICE_TOKEN") ?? "";
const MAX_PER_DAY = 3;
const WINDOW_SECONDS = 86400;

const CORS = {
  "Access-Control-Allow-Origin": "*", // public endpoint; no cookies/credentials
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

async function verifyTurnstile(secret: string, token: string | undefined, ip: string): Promise<boolean> {
  try {
    const form = new URLSearchParams();
    form.set("secret", secret);
    form.set("response", token ?? "");
    if (ip) form.set("remoteip", ip);
    const resp = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      body: form,
    });
    const data = await resp.json().catch(() => ({}));
    return data?.success === true;
  } catch {
    return false; // verification error -> treat as not human (fail closed)
  }
}

async function upstash(url: string, token: string, ...cmd: string[]): Promise<number> {
  const resp = await fetch(`${url}/${cmd.map(encodeURIComponent).join("/")}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!resp.ok) throw new Error(`upstash ${resp.status}`);
  const data = await resp.json();
  return Number(data?.result ?? 0);
}

Deno.serve(async (req: Request) => {
  const requestId = req.headers.get("x-request-id") ?? crypto.randomUUID();
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "x-request-id": requestId, ...CORS },
    });

  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const turnstileSecret = Deno.env.get("TURNSTILE_SECRET_KEY") ?? "";
  const upstashUrl = Deno.env.get("UPSTASH_REDIS_REST_URL") ?? "";
  const upstashToken = Deno.env.get("UPSTASH_REDIS_REST_TOKEN") ?? "";

  // FAIL CLOSED: never serve anonymous AI without both abuse controls configured.
  if (!turnstileSecret || !upstashUrl || !upstashToken) {
    console.error("analyze-anonymous: abuse controls not configured", requestId);
    return json({ error: "temporarily_unavailable" }, 503);
  }

  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }
  const text = typeof body?.text_description === "string" ? body.text_description.trim() : "";
  if (!text) return json({ error: "text_description is required" }, 400);
  const species = typeof body?.species === "string" && body.species.trim() ? body.species.trim() : "dog";
  // CR #11 (Phase 5.4): allow the web client to pass its locale so the AI
  // service applies the right pre-AI emergency-keyword set. Defaults to 'en'.
  const locale = typeof body?.locale === "string" && body.locale.trim() ? body.locale.trim() : "en";

  const ip = clientIp(req.headers);
  if (!ip) return json({ error: "rate_limit" }, 429); // can't identify -> can't rate limit -> deny

  // 1. Bot block.
  if (!(await verifyTurnstile(turnstileSecret, body?.token, ip))) {
    return json({ error: "verification_failed" }, 403);
  }

  // 2. IP rate limit (fixed 24h window). INCR is the gate.
  try {
    const key = await rateLimitKey(ip, Deno.env.get("ANON_IP_SALT") ?? "");
    const count = await upstash(upstashUrl, upstashToken, "incr", key);
    if (count === 1) await upstash(upstashUrl, upstashToken, "expire", key, String(WINDOW_SECONDS));
    if (rateLimitExceeded(count, MAX_PER_DAY)) {
      return json({ error: "rate_limit", message: "Daily free limit reached. Download the app for more." }, 429);
    }
  } catch (err) {
    console.error("analyze-anonymous: rate limiter error", requestId, String(err));
    return json({ error: "temporarily_unavailable" }, 503); // limiter down -> fail closed
  }

  // 3. Call the AI service (full safety pipeline incl. species-specific override).
  try {
    const resp = await fetch(`${AI_SERVICE_URL}/analyze`, {
      method: "POST",
      headers: aiServiceHeaders(requestId, AI_SERVICE_TOKEN),
      body: JSON.stringify({
        input_type: "text",
        text_description: text,
        image_url: null,
        frame_urls: [],
        low_input_quality: false,
        pet: { species, breed: null, age_years: null, sex: null, weight_kg: null, prior_history: [] },
        locale,
      }),
    });
    if (!resp.ok) throw new Error(`AI service ${resp.status}`);
    const ai = await resp.json();
    // Return ONLY the simplified result — the detailed guidance is app-only.
    return json({ result: simplifyResult(ai.result), request_id: requestId });
  } catch (err) {
    console.error("analyze-anonymous: AI call failed", requestId, String(err));
    return json({ error: "analysis_unavailable" }, 503);
  }
});
