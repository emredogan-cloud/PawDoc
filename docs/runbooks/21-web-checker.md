# 21 — Web Symptom Checker (Phase 5.2)

> The free, no-account checker at `pawdoc.app/check` is the ONLY anonymous AI
> path. Anonymous AI is a cost-abuse magnet, so it is gated by **two**
> non-negotiable controls and **fails closed** if either is missing (CR #5/#13).

## 1. Cloudflare Turnstile (bot block)
1. Cloudflare dashboard → **Turnstile** → **Add site**. Domain: `pawdoc.app`. Widget mode: **Managed** (or Invisible).
2. Copy the two keys:
   - **Site key** (public) → set as `NEXT_PUBLIC_TURNSTILE_SITE_KEY` (Cloudflare Pages env).
   - **Secret key** (private) → set on the Edge Function only:
     `supabase secrets set TURNSTILE_SECRET_KEY=... --project-ref <ref>`
3. The web page renders the widget with the site key; the Edge Function verifies
   the returned token server-side against `siteverify`. No valid token → **403**.

## 2. Upstash rate limit (IP cap) — reuses the existing Redis
The Edge Function uses the **existing** `UPSTASH_REDIS_REST_URL` / `UPSTASH_REDIS_REST_TOKEN`
(Phase 0.x) to enforce **3 analyses per IP per 24h** (fixed window: `INCR` +
`EXPIRE 86400`). Over the limit → clean **429**. If Upstash isn't configured, the
function returns **503** (never serves unprotected anonymous AI). Make sure both
secrets are set on the `analyze-anonymous` function:
```
supabase secrets set UPSTASH_REDIS_REST_URL=... UPSTASH_REDIS_REST_TOKEN=... --project-ref <ref>
```

## 3. Deploy
- Edge Function: `supabase functions deploy analyze-anonymous --project-ref <ref>`
  (it is `verify_jwt = false` in `config.toml`; the controls above are the gate).
- Web page: it's part of the static `web/` site — set the Pages env vars
  (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`,
  `NEXT_PUBLIC_TURNSTILE_SITE_KEY`) and redeploy (runbook on `web/README.md`).

## 4. Cost guardrails (do this)
- Set a **global AI spend alarm** (Anthropic + Google AI billing alerts) and a Fly
  budget alert — the anonymous path adds uncapped-by-user demand.
- Keep the per-IP cap conservative (3/day). Lower it if abuse appears.
- The endpoint returns only a **simplified** result (triage + short concern); the
  detailed guidance is app-only (conversion funnel), which also limits scraping value.

## 5. Verify (founder)
- Hit `pawdoc.app/check`, submit a symptom → get a triage result with no signup.
- Submit 4× from one IP → the 4th returns **429** ("daily free limit").
- Disable JS / send no Turnstile token → **403**.
- Confirm `web → install` is tracked (UTM on the store links / PostHog).
