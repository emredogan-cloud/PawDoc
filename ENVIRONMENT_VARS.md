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

## Tooling / CI credentials (Phase 0.1)

| Variable | Purpose | Req | Where it lives | How to obtain |
|---|---|---|---|---|
| `DOPPLER_TOKEN` 🔒 | Service token so CI/Fly read secrets non-interactively | Yes (CI) | GitHub Actions / Fly secrets | Doppler → project `pawdoc` → config → **Access** → *Service Tokens* → generate (read-only) |
| `GH_TOKEN` 🔒 | Apply branch protection + secret scanning via API | Optional (one-time) | local shell only | https://github.com/settings/tokens → *Fine-grained token* scoped to `emredogan-cloud/PawDoc` with **Administration: Read/Write** |

---

## Reserved for later phases (slots NOT created yet)

Documented so the roadmap's full secret surface is visible. Each is added to Doppler **in the phase that provisions it**, with full acquisition steps appended here at that time.

| Variable | Service | Introduced | Notes |
|---|---|---|---|
| `FLY_API_TOKEN` 🔒 | Fly.io | 0.3 | `fly tokens create deploy` |
| `REVENUECAT_API_KEY`, `REVENUECAT_WEBHOOK_SECRET` 🔒 | RevenueCat | 0.3 / 1.4 | Webhook secret used to verify `/revenuecat-webhook` (Critical Review #21) |
| `SENTRY_DSN` | Sentry | 0.4 / 1.1 | Crash reporting |
| `POSTHOG_API_KEY`, `POSTHOG_HOST` | PostHog | 0.4 | Product analytics (see Critical Review #18 re self-host vs cloud) |
| `BETTER_UPTIME_*` | Better Uptime | 0.4 | Monitoring |
| `APP_STORE_CONNECT_API_KEY_ID`, `_ISSUER_ID`, `_KEY` (.p8) 🔒 | Apple | 0.4 | Fastlane TestFlight lane |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` 🔒 | Google Play | 0.4 | Fastlane Play lane |
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
