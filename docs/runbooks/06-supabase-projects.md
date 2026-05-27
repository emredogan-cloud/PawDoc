# 06 — Supabase projects (dev + prod + EU)

Provisions the database/auth spine. Three projects are created so production data, development, and EU-resident data are isolated from day one (retrofitting data residency later is a migration).

**Dashboard:** <https://supabase.com/dashboard>

## 1. Personal access token (for CLI + scripts)

<https://supabase.com/dashboard/account/tokens> → **Generate new token**.
```bash
export SUPABASE_ACCESS_TOKEN=sbp_xxxxx
```
Also store it in Doppler (`SUPABASE_ACCESS_TOKEN`) for CI later.

## 2. Create the three projects

For each, click **New project**, pick the org, set a **strong DB password** (save it — it's part of `SUPABASE_DB_URL`).

| Project name | Region | Purpose |
|---|---|---|
| `pawdoc-dev` | closest to you | development |
| `pawdoc-prod` | closest to your users (e.g. `us-east-1`) | production |
| `pawdoc-eu` | **`eu-central-1` (Frankfurt)** | GDPR / EU residency |

The **project ref** is the 20-char id in the dashboard URL (`https://supabase.com/dashboard/project/<ref>`). You'll need all three.

## 3. Enable extensions (uuid-ossp + vector)

Pick one:
- **Script (fastest):** `./scripts/supabase-enable-extensions.sh <dev-ref> <prod-ref> <eu-ref>`
- **CLI:** `supabase link --project-ref <ref>` then `supabase db push` (applies the canonical migration `supabase/migrations/*_enable_extensions.sql`).
- **Dashboard:** SQL Editor → run `create extension if not exists "uuid-ossp" with schema extensions; create extension if not exists vector with schema extensions;`

## 4. Configure auth providers

**Email** — on by default (Authentication → Providers → Email). Leave confirmations per product choice.

**Apple Sign In** *(requires the Apple Developer account from runbook 01 to be approved)*:
1. Apple Developer → Certificates, IDs & Profiles → **Identifiers** → create a **Services ID** (this becomes the Apple *Client ID*). Enable "Sign in with Apple"; set the return URL to `https://<ref>.supabase.co/auth/v1/callback`.
2. Create a **Sign in with Apple key** (`.p8`); note the Key ID + your Team ID.
3. Supabase → Authentication → Providers → **Apple** → enter the Services ID (client id) and the generated client secret (JWT from the key).
4. Store in Doppler: `SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID`, `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET`.

**Google**:
1. Google Cloud Console → APIs & Services → Credentials → **OAuth client ID** (Web application). Authorized redirect URI: `https://<ref>.supabase.co/auth/v1/callback`.
2. Supabase → Authentication → Providers → **Google** → paste client id + secret.
3. Store in Doppler: `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID`, `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET`.

> These provider toggles are also declared as code in `supabase/config.toml` (used by local `supabase start`); the dashboard config governs the hosted projects.

## 5. Site URL + redirect allow-list (each hosted project)

Authentication → URL Configuration:
- **Site URL:** `https://pawdoc.app`
- **Redirect URLs:** add `pawdoc://login-callback` (mobile) and any local dev URL.

## 6. Copy keys into Doppler

From each project's **Settings → API** and **Settings → Database**:
```bash
# dev
doppler secrets set SUPABASE_URL="https://<dev-ref>.supabase.co"        --project pawdoc --config dev
doppler secrets set SUPABASE_ANON_KEY="<anon>"                          --project pawdoc --config dev
doppler secrets set SUPABASE_SERVICE_ROLE_KEY="<service_role>"          --project pawdoc --config dev
doppler secrets set SUPABASE_JWT_SECRET="<jwt secret>"                  --project pawdoc --config dev
doppler secrets set SUPABASE_DB_URL="postgresql://...:<pw>@...:5432/postgres" --project pawdoc --config dev
# prod → --config prd (use the prod project's values)
# EU   → --config prd as SUPABASE_EU_URL / SUPABASE_EU_ANON_KEY / SUPABASE_EU_SERVICE_ROLE_KEY
```

## 7. Verify

```bash
export SUPABASE_PROJECT_REFS="<dev-ref> <prod-ref> <eu-ref>"
./scripts/verify-phase-0.2.sh
```

## Proposed (owner decision — NOT auto-applied): backups / PITR

Critical Review #22 recommends enabling **Point-in-Time Recovery** + a restore drill at Phase 0.2 for an app storing "permanent legal records." PITR needs Supabase **Pro**. Decide whether to enable now or defer; this is surfaced, not silently implemented.
