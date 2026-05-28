# PawDoc — Environment Variables & Secrets

> **Single source of truth for every secret the app uses.**
> Maintained per the execution contract — updated on **every** SUB-PR.
> All values live in **Doppler** (`pawdoc` project, `dev` + `prod` configs). **Never** hardcode a secret or commit it to git. The `.gitignore` blocks the common offenders, but Doppler is the authority.
>
> **How values flow:** Doppler → injected at runtime (`doppler run -- <cmd>`) or synced to the platform (Fly.io, Supabase, GitHub Actions) via Doppler integrations. Local `.env.example` files describe shape only and contain **no real values**.

**Status legend:** ✅ slot live in Doppler · ⏳ slot created with placeholder, real value minted later · 🔒 server-only (never reaches the mobile/web client).

---

## Phase 0.1 backbone (created now, as placeholders)

These slots are created in Doppler in Phase 0.1; real values are minted in 0.2/0.3 as the services come online.

### Supabase — database, auth, storage metadata
*Provisioned in Phase 0.2. Dashboard: https://supabase.com/dashboard → your project.*

| Variable | Purpose | Req | Client-safe | How to obtain |
|---|---|---|---|---|
| `SUPABASE_URL` | Project REST/Realtime base URL | Yes | ✅ public | Project Settings → **API** → *Project URL* (e.g. `https://abcd.supabase.co`) |
| `SUPABASE_ANON_KEY` | Public anon key for client auth (RLS-guarded) | Yes | ✅ public | Project Settings → **API** → *Project API keys* → **anon / public** |
| `SUPABASE_SERVICE_ROLE_KEY` 🔒 | Bypasses RLS; server/Edge-Function/AI-service only | Yes | ❌ NEVER | Project Settings → **API** → *Project API keys* → **service_role** (click reveal) |
| `SUPABASE_JWT_SECRET` 🔒 | Verify Supabase JWTs in the AI service | Yes | ❌ | Project Settings → **API** → *JWT Settings* → **JWT Secret** |
| `SUPABASE_DB_URL` 🔒 | Postgres connection string (migrations, psql) | Yes | ❌ | Project Settings → **Database** → *Connection string* → **URI** (insert DB password) |

> **EU project (GDPR future-proofing)** is created in Phase 0.2; it adds `SUPABASE_EU_URL`, `SUPABASE_EU_ANON_KEY`, `SUPABASE_EU_SERVICE_ROLE_KEY` 🔒. Documented here now so the slots aren't a surprise.

### Anthropic — Tier 3 analysis (Claude Sonnet)
| Variable | Purpose | Req | Client-safe | How to obtain |
|---|---|---|---|---|
| `ANTHROPIC_API_KEY` 🔒 | Claude `claude-sonnet-4-6` calls from the AI service | Yes | ❌ | https://console.anthropic.com → **Settings → API Keys** → *Create Key*. Starts `sk-ant-`. Shown once — copy immediately. |

### Google AI — Tier 2 analysis (Gemini)
| Variable | Purpose | Req | Client-safe | How to obtain |
|---|---|---|---|---|
| `GOOGLE_AI_API_KEY` 🔒 | Gemini 2.0 Flash calls (Tier 2) | Yes | ❌ | https://aistudio.google.com/app/apikey → **Create API key**. |

### Cloudflare R2 — image/video object storage
*Buckets provisioned in Phase 0.2. Dashboard: Cloudflare → **R2**.*

| Variable | Purpose | Req | Client-safe | How to obtain |
|---|---|---|---|---|
| `R2_ACCOUNT_ID` | Cloudflare account ID for the R2 endpoint | Yes | ❌ | Cloudflare dashboard → **R2** → *Account ID* (right-hand panel) |
| `R2_ACCESS_KEY_ID` 🔒 | S3-compatible access key (server-side signing) | Yes | ❌ | R2 → **Manage R2 API Tokens** → *Create API token* → **Access Key ID** |
| `R2_SECRET_ACCESS_KEY` 🔒 | S3-compatible secret (shown once) | Yes | ❌ | Same token-creation screen → **Secret Access Key** |
| `R2_ENDPOINT` | S3 endpoint `https://<account_id>.r2.cloudflarestorage.com` | Yes | ❌ | Derived from `R2_ACCOUNT_ID` |
| `R2_BUCKET_DEV` | Dev bucket name | Yes | ❌ | Chosen at bucket creation (0.2), e.g. `pawdoc-uploads-dev` |
| `R2_BUCKET_PROD` | Prod bucket name | Yes | ❌ | e.g. `pawdoc-uploads-prod` |

> **Client uploads never use these keys.** Per Critical Review #6, the client receives short-lived **presigned PUT URLs** minted by an Edge Function (built in Phase 1.2). R2 write credentials stay server-side.

---

## Tooling / CI credentials (Phase 0.1–0.2)

| Variable | Purpose | Req | Where it lives | How to obtain |
|---|---|---|---|---|
| `DOPPLER_TOKEN` 🔒 | Service token so CI/Fly read secrets non-interactively | Yes (CI) | GitHub Actions / Fly secrets | Doppler → project `pawdoc` → config → **Access** → *Service Tokens* → generate (read-only) |
| `GH_TOKEN` 🔒 | Apply branch protection + secret scanning via API | Optional (one-time) | local shell only | https://github.com/settings/tokens → *Fine-grained token* scoped to `emredogan-cloud/PawDoc` with **Administration: Read/Write** |
| `SUPABASE_ACCESS_TOKEN` 🔒 | Supabase Management API / CLI (create projects, enable extensions) | Yes (0.2) | local shell + Doppler | https://supabase.com/dashboard/account/tokens → *Generate new token* (`sbp_…`) |

---

## Phase 0.2 additions

### Supabase auth provider secrets
Referenced by `supabase/config.toml` via `env(...)`. Set once the Apple Developer account (runbook 01) is approved and a Google OAuth client exists. Full steps in runbook 06 §4.

| Variable | Purpose | Req | How to obtain |
|---|---|---|---|
| `SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID` | Apple **Services ID** (acts as the OAuth client id) | Yes | Apple Developer → Identifiers → Services ID |
| `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET` 🔒 | Apple client secret (JWT signed with the Sign in with Apple `.p8` key) | Yes | Generated from the Apple key |
| `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` | Google OAuth 2.0 client id | Yes | Google Cloud Console → Credentials |
| `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` 🔒 | Google OAuth client secret | Yes | Same screen |

### Supabase EU project (GDPR residency, region eu-central-1)
| Variable | Purpose | Req | Client-safe |
|---|---|---|---|
| `SUPABASE_EU_URL` | EU project REST/Realtime URL | Yes | ✅ |
| `SUPABASE_EU_ANON_KEY` | EU anon key | Yes | ✅ |
| `SUPABASE_EU_SERVICE_ROLE_KEY` 🔒 | EU service role (RLS bypass; server only) | Yes | ❌ |

### R2 bucket names (finalized this phase)
`R2_BUCKET_DEV` = `pawdoc-uploads-dev`, `R2_BUCKET_PROD` = `pawdoc-uploads-prod`. Private buckets; access only via presigned URLs (Phase 1.2). CORS policy: `infra/r2-cors.json`.

---

## Phase 0.3 additions

### Fly.io (AI service compute)
| Variable | Purpose | Req | How to obtain |
|---|---|---|---|
| `FLY_API_TOKEN` 🔒 | Non-interactive deploy from CI (Phase 0.4) | Yes (CI) | `fly tokens create deploy` → store in Doppler `prd` + GitHub Actions |

### RevenueCat (subscription backend skeleton)
Project + app identifiers only this phase; products/entitlements come in Phase 1.4.

| Variable | Purpose | Req | Client-safe | How to obtain |
|---|---|---|---|---|
| `REVENUECAT_API_KEY` 🔒 | Server-side RevenueCat REST calls | Yes (1.4) | ❌ | RevenueCat → API keys → secret key |
| `REVENUECAT_WEBHOOK_SECRET` 🔒 | Verify `/revenuecat-webhook` auth header (CR #21) | Yes (1.4) | ❌ | RevenueCat → webhook auth header value you set |
| `REVENUECAT_PUBLIC_SDK_KEY_IOS` | RevenueCat SDK key (iOS client) | Yes (1.4) | ✅ public | RevenueCat → API keys → public SDK key (iOS) |
| `REVENUECAT_PUBLIC_SDK_KEY_ANDROID` | RevenueCat SDK key (Android client) | Yes (1.4) | ✅ public | RevenueCat → API keys → public SDK key (Android) |

**Canonical app identifier:** `app.pawdoc` (iOS bundle id + Android package; used by Flutter in 1.1 and the RevenueCat apps).

---

## Phase 0.4 additions

### Observability (runtime — stored in Doppler)
| Variable | Purpose | Req | Client-safe | How to obtain |
|---|---|---|---|---|
| `SENTRY_DSN` | Crash/error reporting (Flutter + AI service) | Yes | ✅ (DSN is publishable) | sentry.io → project → Settings → Client Keys (DSN) |
| `POSTHOG_API_KEY` | Product analytics ingest key | Yes | ✅ | PostHog → Project settings → API key |
| `POSTHOG_HOST` | PostHog instance URL | Yes | ✅ | `https://us.i.posthog.com` (cloud) or self-hosted URL — CR #18 |
| `BETTER_UPTIME_API_TOKEN` 🔒 | Programmatic monitor mgmt (optional) | No | ❌ | Better Uptime → API tokens |

### CI/CD + release signing (GitHub Actions repo secrets — build-time, NOT Doppler)
| Variable | Purpose | Req | How to obtain |
|---|---|---|---|
| `FLY_API_TOKEN` 🔒 | `deploy.yml` → flyctl deploy | Yes | `fly tokens create deploy` (runbook 08/10) |
| `MATCH_PASSWORD` 🔒 | Decrypt iOS signing repo | Yes (release) | chosen at `fastlane match` (runbook 11) |
| `MATCH_GIT_URL`, `MATCH_GIT_BASIC_AUTHORIZATION` 🔒 | Read the private certs repo in CI | Yes (release) | runbook 11 |
| `APP_STORE_CONNECT_API_KEY_KEY_ID`, `_ISSUER_ID`, `_KEY` 🔒 | TestFlight upload auth | Yes (release) | App Store Connect API key (runbook 11) |
| `GOOGLE_PLAY_JSON_KEY_FILE` 🔒 | Play internal-track upload | Yes (release) | Play service account JSON (runbook 11) |
| `FASTLANE_APPLE_ID`, `APPLE_DEVELOPER_TEAM_ID` | Fastlane Appfile identity | Yes (release) | Apple Developer (runbook 01) |

> Release/CI secrets live in **GitHub → Settings → Secrets and variables → Actions**, not Doppler — they are build-time, not app runtime.

---

## Phase 1.1 additions

| Variable | Purpose | Req | Client-safe | How to obtain |
|---|---|---|---|---|
| `SUPABASE_AUTH_WEBHOOK_SECRET` 🔒 | Verify the `/auth-webhook` signature before provisioning a `users` row (CR #21) | Yes | ❌ | Supabase → Authentication → Hooks → signing secret (`v1,whsec_…`); also `supabase secrets set` for the function (runbook 13) |

**Mobile build-time config (`--dart-define`, sourced from Doppler — not new secrets):**
`SUPABASE_URL`, `SUPABASE_ANON_KEY` (public, RLS-guarded) and `SENTRY_DSN` are compiled into the Flutter app at build time, e.g.:

```bash
flutter run \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=SENTRY_DSN=$SENTRY_DSN
```

---

## Phase 1.3 additions

### Upstash Redis (AI result cache + dynamic kill-switch flag, CR #19)
| Variable | Purpose | Req | Client-safe | How to obtain |
|---|---|---|---|---|
| `UPSTASH_REDIS_REST_URL` 🔒 | Result cache + kill-switch flag store | Optional | ❌ | Upstash console → Redis DB → REST URL |
| `UPSTASH_REDIS_REST_TOKEN` 🔒 | Upstash REST auth token | Optional | ❌ | Same screen → REST token |

### AI service / Edge Function wiring (config; set via Fly env + `supabase secrets set`)
| Variable | Purpose | Req | Where |
|---|---|---|---|
| `AI_SERVICE_URL` | Edge Function `/analyze` → Python service base URL | Yes | Supabase function secret (e.g. `https://pawdoc-ai.fly.dev`) |
| `AI_KILL_SWITCH` | Static kill-switch fallback (`1`/`true`) (CR #19) | Optional | Fly env on the AI service |
| `GEMINI_MODEL` / `CLAUDE_MODEL` | Override pinned model IDs (CR #17 defaults `gemini-2.0-flash` / `claude-sonnet-4-6`) | Optional | Fly env |
| `GEMINI_VIDEO_MODEL` | Pinned video model (CR #17, default `gemini-2.0-flash`) — Phase 3.2 | Optional | Fly env |
| `GEMINI_EMBEDDING_MODEL` | Pinned semantic-cache embedding model (CR #17, default `gemini-embedding-001`, requested at 1536 dims) — Phase 3.2 | Optional | Fly env |
| `SEMANTIC_CACHE_ENABLED` | Toggle the semantic cache (`0`/`false` to disable; default on) — Phase 3.2 | Optional | Fly env (AI service) **and** `supabase secrets set` (Edge Function) |
| `CRON_SECRET` 🔒 | Auth for `/process-reminders` (the `x-cron-secret` header). Fails CLOSED if unset — Phase 3.3 P2 | Yes (push) | `supabase secrets set` (Edge) **and** Supabase Vault `cron_secret` (same value) |
| `ONESIGNAL_APP_ID` | OneSignal app id for server-side push (`app_id` in the REST body) — Phase 3.3 P2 | Yes (push) | `supabase secrets set` on `process-reminders` |
| `ONESIGNAL_REST_API_KEY` 🔒 | OneSignal REST key for server push (reminders + re-engagement) — Phase 3.3 P2 | Yes (push) | `supabase secrets set` on `process-reminders` |
| `PLACES_API_KEY` 🔒 | Google Places (New) key for the `/find-vets` proxy. **Server-only** — never in the client — Phase 3.4 | Yes (vet finder) | `supabase secrets set` on `find-vets` |
| `TURNSTILE_SECRET_KEY` 🔒 | Cloudflare Turnstile **secret** for `/analyze-anonymous` (bot block). **Server-only** — Phase 5.2 | Yes (web checker) | `supabase secrets set` on `analyze-anonymous` |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase URL the web `/check` page calls | Yes (web) | Cloudflare Pages env (build-time, public) |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anon (publishable) key for the web checker | Yes (web) | Cloudflare Pages env (build-time, public) |
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | Cloudflare Turnstile **site** key (public, in the browser) — Phase 5.2 | Yes (web) | Cloudflare Pages env (build-time, public) |
| `OPENAI_API_KEY` 🔒 | OpenAI key for the weekly AI Health Journal (GPT-4o family) — Phase 5.3 | Yes (journal) | Fly env on the AI service |
| `OPENAI_MODEL` | Pinned journal model (CR #17, default `gpt-4o-mini` — cheap) — Phase 5.3 | Optional | Fly env |
| `AIRVET_AFFILIATE_URL` | Embedded telehealth deep-link target (Airvet-style partner). The button SELF-HIDES if empty — Phase 5.4 | Optional (revenue share) | `--dart-define=AIRVET_AFFILIATE_URL=…` on `flutter build` |

> `ANTHROPIC_API_KEY` + `GOOGLE_AI_API_KEY` (Phase 0.1 backbone) are consumed by the AI service (Tier 3 / Tier 2). Set them as Fly secrets on `pawdoc-ai`. The **dynamic** kill-switch (no redeploy) is the Redis key `pawdoc:ai_kill_switch` = `1`.
>
> **Phase 5.3 (AI Health Journal):** the weekly cron `generate-journals` reuses the **existing** `CRON_SECRET` (3.3 P2) + Vault `project_url`/`cron_secret`; the new secret is `OPENAI_API_KEY` on the AI service. The journal pipeline FAILS-SAFE: any OpenAI error (no key, timeout, SDK error) returns `{narrative: null}` and the cron logs + skips that pet — no DB write, no system crash (CR #5). Set a billing alarm on the OpenAI key; the default `gpt-4o-mini` keeps weekly-per-pet spend small.
>
> **Phase 5.4 (Localization, Telehealth, B2B-Lite):** no new server secrets. **CR #11 (safety-critical)** is fully wired — the English + German emergency-keyword maps live in both `ai-service/app/safety.py` and `supabase/functions/_shared/emergency_keywords.mjs`; the Edge `/analyze` Function reads `users.preferred_locale` and forwards it to the AI service so the pre-AI override matches the user's language (an unknown locale safely falls back to English). The new `AIRVET_AFFILIATE_URL` build-define enables the embedded telehealth CTA (button self-hides if empty). The `b2b_lite` ($19.99/mo sitter) subscription status is recognized by `users.subscription_status`, the Edge `PREMIUM_STATUSES`, `paywall_policy`, `pets_pending_journal`, and the RevenueCat webhook (entitlement-id mapped via `_shared/revenuecat.mjs`).
>
> **Phase 5.2 (anonymous web checker):** `/analyze-anonymous` is the ONLY anonymous AI path and **fails closed (503)** unless BOTH `TURNSTILE_SECRET_KEY` and the existing `UPSTASH_REDIS_REST_URL`/`_TOKEN` are set (it enforces a 3/IP/24h Upstash rate limit + Turnstile). The `NEXT_PUBLIC_*` values are public/build-time (set in Cloudflare Pages); the Turnstile **secret** stays server-side on the Edge Function. Set a **global AI spend alarm** (CR #5/#13) — anonymous AI is a cost-abuse magnet. See `docs/runbooks/21-web-checker.md`.
>
> **Phase 3.4 (vet finder):** `PLACES_API_KEY` lives ONLY in the `find-vets` Edge Function; the Flutter client sends a lat/lng (or zip/city) and gets back a clean vet list — the key never reaches the device. `find-vets` is `verify_jwt = true` (signed-in users only) so the Places quota can't be drained anonymously. Set a **billing budget alert** on the key (CR #12). Restrict the key to the Places API and (where possible) to the server.
>
> **Phase 3.2:** no new *secrets*. The semantic cache reuses `GOOGLE_AI_API_KEY` (embeddings) and the existing `SUPABASE_SERVICE_ROLE_KEY` (the Edge Function calls the `match_analyses` RPC, which is locked to `service_role`). Embeddings degrade gracefully when the key is absent (cache simply skipped).
>
> **Phase 3.3 Part 2 (push/cron):** the hourly `pg_cron` job calls `/process-reminders` via `pg_net`, reading the **project URL** + **cron secret** from **Supabase Vault** (`vault.create_secret(...)` for `project_url` and `cron_secret`) — so nothing is committed to git. `CRON_SECRET` on the Edge Function MUST equal the Vault `cron_secret`. The schedule migration (`20260527040001`) is applied on the managed project (`supabase db push`), where `pg_cron`/`pg_net`/Vault exist — it is not run by the local Docker tests.

---

## Phase 1.2 additions

### R2 upload (`generate-upload-url` Edge Function)
| Variable | Purpose | Req | Where |
|---|---|---|---|
| `R2_BUCKET` 🔒 | Bucket the presigned PUT targets (`pawdoc-uploads-dev`/`-prod`) | Yes | Supabase function secret |

> `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` (Phase 0.2) are consumed by `generate-upload-url` to sign URLs. **R2 write keys live ONLY in the function (CR #6) — never in the client.**

**Mobile analytics (`--dart-define`):** `POSTHOG_API_KEY` (publishable project key) + `POSTHOG_HOST` are compiled into the app for the onboarding events. Example:
`flutter run --dart-define=POSTHOG_API_KEY=phc_… --dart-define=POSTHOG_HOST=https://us.i.posthog.com`

---

## Phase 1.4 additions

**Mobile (`--dart-define`):** `REVENUECAT_PUBLIC_SDK_KEY` (publishable; pass the iOS public key for iOS builds and the Android public key for Android builds — both from Phase 0.3 RevenueCat setup).

### RevenueCat webhook (server)
| Variable | Purpose | Req | Where |
|---|---|---|---|
| `REVENUECAT_WEBHOOK_SECRET` 🔒 | Authorization secret `/revenuecat-webhook` verifies (CR #21) | Yes | Supabase function secret — set the SAME value as the RevenueCat webhook's Authorization header |

> The app calls `Purchases.logIn(<supabase uid>)`, so RevenueCat's `app_user_id` equals the Supabase user id; the webhook updates `users` by that id. The `analyze` Edge Function now also presigns a GET URL from R2 (Phase 0.2 R2 keys) for the uploaded image.

---

## Phase 2.1 additions

**Mobile (`--dart-define`):** `ONESIGNAL_APP_ID` (publishable) — push. The permission prompt fires on onboarding Screen 4; the player id is synced to `users.one_signal_player_id`.

> No new server secrets this phase: account deletion (`/delete-account`, CR #9) uses the existing `SUPABASE_SERVICE_ROLE_KEY`; image moderation (CR #8) uses the existing `GOOGLE_AI_API_KEY` + R2 keys (delete-on-reject). OneSignal APNs/FCM credentials are configured in the OneSignal dashboard (runbook 17).

---

## Reserved for later phases (slots NOT created yet)

Documented so the roadmap's full secret surface is visible. Each is added to Doppler **in the phase that provisions it**, with full acquisition steps appended here at that time.

| Variable | Service | Introduced | Notes |
|---|---|---|---|
| `ONESIGNAL_REST_API_KEY` 🔒 | OneSignal | 3.3 | Server-side push sending (reminders/follow-ups) |
| `GOOGLE_PLACES_API_KEY` 🔒 | Google Places | 3.4 | Vet finder (proxied; never client-side) |
| `OPENAI_API_KEY` 🔒 | OpenAI | 5.3 | AI Health Journal (GPT-4o) |
| `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` 🔒 | Stripe | 7.3 | B2B usage billing |

---

## Doppler quick reference

```bash
# one-time: authenticate this machine (interactive — run it yourself)
doppler login

# create project + dev/prod configs + all Phase 0.1 slots (idempotent)
./scripts/doppler-bootstrap.sh

# inspect (placeholders are expected in 0.1)
doppler secrets --project pawdoc --config dev
doppler secrets --project pawdoc --config prod

# run any command with secrets injected as env vars
doppler run --project pawdoc --config dev -- <your-command>
```
