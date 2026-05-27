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

## Reserved for later phases (slots NOT created yet)

Documented so the roadmap's full secret surface is visible. Each is added to Doppler **in the phase that provisions it**, with full acquisition steps appended here at that time.

| Variable | Service | Introduced | Notes |
|---|---|---|---|
| `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN` 🔒 | Upstash | 1.3 | Result caching |
| `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY` 🔒 | OneSignal | 2.1 | Push |
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
