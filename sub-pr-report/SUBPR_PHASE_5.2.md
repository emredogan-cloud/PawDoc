# SUB-PR Report — Phase 5.2: Web Symptom Checker

**Status:** Complete and verified (node helpers, a real static `next build`, shellcheck). A free, no-account web checker at `pawdoc.app/check` backed by a hard-gated anonymous Edge Function (Turnstile + IP rate limit, fail-closed), with an app-install conversion funnel.
**Branch:** `phase-5.2-web-checker` (from `origin/main` = `f12933c`, contains 0.1→5.1)
**Date:** 2026-05-28

---

## 1. Files created / modified

**Anonymous AI path (Edge):**
```
supabase/functions/_shared/web_checker.mjs (+ .test.mjs)  pure: clientIp / rateLimitKey /
                                                          rateLimitExceeded / simplifyResult
supabase/functions/analyze-anonymous/index.ts             the only anon AI endpoint (gated)
supabase/config.toml                          (mod)        [functions.analyze-anonymous] verify_jwt=false
```
**Web (`web/`, static export):**
```
web/app/check/page.tsx              server component (SEO metadata) wrapping the client form
web/app/check/symptom-checker.tsx   "use client" form + fetch + conversion funnel
web/app/page.tsx          (mod)      landing links to /check
web/.env.example                    NEXT_PUBLIC_SUPABASE_URL / _ANON_KEY / _TURNSTILE_SITE_KEY
```
**Docs / scripts:**
```
docs/runbooks/21-web-checker.md     Turnstile keys, Upstash, deploy, spend alarm
scripts/verify-phase-5.2.sh         phase verifier (structural + node + real web build)
ENVIRONMENT_VARS.md       (mod)      TURNSTILE_SECRET_KEY (Edge) + NEXT_PUBLIC_* (web)
sub-pr-report/SUBPR_PHASE_5.2.md     this report
```
**No `ai-service` change** (reuses `/analyze`, so the web checker gets the full safety pipeline incl. the Phase 5.1 species-specific overrides). New secret: `TURNSTILE_SECRET_KEY` (server-only) + public `NEXT_PUBLIC_*`; reuses the existing Upstash + `AI_SERVICE_URL`.

## 2. How the abuse controls protect AI cost (CR #5 / #13)

`/analyze-anonymous` is the **only** anonymous AI path (the main `/analyze` stays `verify_jwt=true`). It applies, in order, before ever calling the paid AI:

1. **Cloudflare Turnstile (bot block).** The web page renders the Turnstile widget (`NEXT_PUBLIC_TURNSTILE_SITE_KEY`) and sends the token. The Edge Function verifies it server-side against Cloudflare `siteverify` using `TURNSTILE_SECRET_KEY` (server-only) — `success !== true` → **403**.
2. **Upstash IP rate limit.** The Edge derives the client IP (`cf-connecting-ip`, else first hop of `x-forwarded-for`), then `INCR anon_checker:<ip>` over Upstash REST; on the first hit it `EXPIRE`s the key to a **24h** window. `count > 3` → clean **429** (`{"error":"rate_limit"}`). The `INCR` is the gate and is counted *before* the AI call, so even successful analyses spend the quota.
3. **FAIL CLOSED.** If `TURNSTILE_SECRET_KEY` or the Upstash creds are **not configured** (or the limiter errors), the function returns **503** and never calls the AI — we never serve unprotected anonymous AI ("zero cost bleed").
4. **Minimized payload.** Only the **simplified** result (`triage_level` + short `primary_concern`) is returned — the detailed "what to do" stays app-only, which also reduces scraping value.

Runbook 21 also instructs the founder to set a **global AI spend alarm**.

## 3. How the static-export constraint was honored

`web/` is built with `output: 'export'` (Phase 4.3), so there is **no server** — Next API routes (`app/api/...`) are impossible. The `/check` page is therefore split:
- **`page.tsx` — server component** (so it can export SEO `metadata`: title, description, canonical). It prerenders to static HTML and renders the client child.
- **`symptom-checker.tsx` — `"use client"`** Client Component that, **at runtime in the browser**, `fetch`es the Supabase Edge Function directly:
  `POST ${NEXT_PUBLIC_SUPABASE_URL}/functions/v1/analyze-anonymous` (with the public anon `apikey`).

No `app/api` route exists (verifier asserts the directory is absent). Public config is inlined at build via `NEXT_PUBLIC_*`. **Proven by a real build:** `next build` exports `/check` as static (`○`), `out/check/index.html` carries the canonical link, and `Exporting (2/2)` succeeds.

## 4. Conversion funnel + emergency safety

The result shows the **triage badge + primary concern**; the "What to do next" steps are rendered as a **blurred teaser** with an overlay CTA + App Store / Google Play badges driving the app install (and the detailed steps aren't even sent over the wire). **Safety exception:** when the triage is **EMERGENCY**, a clear "this may be an emergency — contact a vet now" message is shown **un-gated** (we never bury an emergency behind a paywall/funnel — consistent with the EMERGENCY trust rule).

## 5. Tests executed & results

| Test | Result |
|------|--------|
| `node --test _shared/web_checker.test.mjs` | **4 pass** (IP extraction, rate-limit boundary, key, simplifier withholds detail) |
| `node --test _shared/*.mjs` (full) | **46 pass** |
| `npm run build` (web, `output: 'export'`) | **✓ Exporting** — `/check` is static `○`; canonical in `out/check/index.html` |
| `./scripts/verify-phase-5.2.sh` | **exit 0** — gating + static-export + funnel checks; 3 MANUAL |
| `shellcheck` (verifier) | **clean** |

(Mobile/AI/pytest untouched this phase.)

## 6. MANUAL (founder)

- Set `TURNSTILE_SECRET_KEY` + `UPSTASH_REDIS_REST_URL`/`_TOKEN` on `analyze-anonymous`; deploy it; set the `NEXT_PUBLIC_*` in Cloudflare Pages; redeploy web (runbook 21).
- Set a **global AI spend alarm**. Verify: a 4th request from one IP → 429; a request with no Turnstile token → 403; an anonymous user gets a triage with no signup; web→install tracked.
- Deno typecheck of `analyze-anonymous` runs in Supabase CI (deno not installed here); its `_shared` logic is node-tested.

## 7. Git branch / commit / push

- Branch: `phase-5.2-web-checker`
- Implementation commit (deliverables): `f98a759cfc7b1f9057d3b7679ad66639e52dab5f`
- Push: pushed to `origin/phase-5.2-web-checker`; open PR at https://github.com/emredogan-cloud/PawDoc/pull/new/phase-5.2-web-checker

## 8. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Anonymous checker at /check, no account | ✅ DONE | `/check` page + `/analyze-anonymous`; build green |
| Dedicated anon endpoint (main /analyze NOT exposed) | ✅ DONE | new fn; `/analyze` stays verify_jwt=true |
| Simplified result only | ✅ DONE | `simplifyResult`; node test |
| IP rate limit (3/IP/24h) via Upstash → 429 | ✅ DONE | `INCR`+`EXPIRE`; fail-closed 503 |
| Turnstile/reCAPTCHA bot block | ✅ DONE | server-side `siteverify`; 403 |
| Text-only client form | ✅ DONE | `symptom-checker.tsx` (textarea + species) |
| Static-export-safe (no API route) | ✅ DONE | server+client split; no `app/api`; build green |
| Conversion funnel (blur + app CTA) | ✅ DONE | blurred steps + store badges; EMERGENCY un-gated |
| Live keys + spend alarm + deploy | ⏳ MANUAL | runbook 21 |

**Verified now:** the anonymous endpoint is hard-gated (Turnstile + Upstash IP limit, fail-closed, simplified output), and the `/check` page statically exports while fetching the Edge Function directly (no API route) — confirmed by a real `next build`. Stopping for approval.
