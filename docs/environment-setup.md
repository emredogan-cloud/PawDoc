# Cloud Environment Setup Runbook

This is a step-by-step checklist for going from "zero accounts" to "all
Phase 0 infrastructure provisioned." The founder must execute these — they
involve billing, 2FA, and verified identity, none of which an automated agent
can do safely.

**Estimated time:** 4-8 hours active + 24-48h Apple enrollment wait.

---

## Day 1 — Start the Slow Things

These have multi-day lead times. Start them first.

### 1. Apple Developer Program

- Cost: $99/year
- Sign up: https://developer.apple.com/programs/enroll/
- Wait: 24-48h verification
- **Required for:** TestFlight builds, App Store submission (Phase 2)

### 2. Google Play Console

- Cost: $25 one-time
- Sign up: https://play.google.com/console
- Wait: typically same-day approval
- **Required for:** internal-testing track (Phase 1+), production publish (Phase 2)

### 3. Domain — pawdoc.app

- Register at any registrar (recommendation: Cloudflare Registrar — at-cost pricing)
- Point nameservers at Cloudflare
- **Required for:** ToS / Privacy URLs (Phase 2), web symptom checker (Phase 4)

---

## Day 1 — Provision What You Can

### 4. Doppler (Secrets Hub)

This is the source of truth for all real secret values. Set this up first so
every subsequent service's keys land in Doppler immediately.

```bash
brew install dopplerhq/cli/doppler   # or: curl -Ls https://cli.doppler.com/install.sh | sh
doppler login
doppler setup
```

Create the project + configs:
- **Project:** `pawdoc`
- **Configs:** `dev`, `prod`
- Optionally: `dev_local` for personal dev overrides

Connect Doppler integrations later (after the services below exist):
- Doppler ↔ GitHub Actions: settings → Integrations → GitHub
- Doppler ↔ Fly.io: settings → Integrations → Fly.io

### 5. Supabase

Create two projects in the [Supabase Dashboard](https://supabase.com/dashboard):

| Project | Tier | Region |
|---------|------|--------|
| `pawdoc-dev` | Free | choose nearest to founder |
| `pawdoc-prod` | Pro ($25/mo) — once Phase 1 starts | choose nearest to user base; **EU project for GDPR users (Phase 5+)** |

For each project:
1. Database → Extensions: enable `pgvector` and `uuid-ossp`
2. Authentication → Providers: enable Email + Apple + Google (configure providers when keys arrive)
3. Authentication → URL Configuration: add `io.pawdoc.app://callback` to redirect URLs
4. Project Settings → API: copy `URL`, `anon` key, `service_role` key → store in Doppler:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`

### 6. Cloudflare R2

In Cloudflare Dashboard → R2:
1. Create buckets `pawdoc-uploads-dev` and `pawdoc-uploads-prod`
2. Configure CORS (Bucket → Settings → CORS):
   ```json
   [{
     "AllowedOrigins": ["https://pawdoc.app", "https://*.pawdoc.app", "io.pawdoc.app://*"],
     "AllowedMethods": ["GET", "PUT", "POST"],
     "AllowedHeaders": ["*"],
     "MaxAgeSeconds": 3600
   }]
   ```
3. Create an R2 API token (read+write on both buckets); store in Doppler:
   - `R2_ACCOUNT_ID`
   - `R2_ACCESS_KEY_ID`
   - `R2_SECRET_ACCESS_KEY`
   - `R2_BUCKET`
4. Create public custom domain `uploads.pawdoc.app` mapping to the prod bucket (Phase 1+)

### 7. Fly.io

```bash
brew install flyctl
flyctl auth signup    # or `flyctl auth login` if you already have an account
```

Create both AI service apps (these match `ai-service/fly.toml`):

```bash
cd ai-service
flyctl apps create pawdoc-ai-dev  --org pawdoc
flyctl apps create pawdoc-ai-prod --org pawdoc
```

Generate a deploy token for CI:

```bash
flyctl auth token         # copy this → store in Doppler as FLY_API_TOKEN
```

### 8. Anthropic + Google AI

- Anthropic: https://console.anthropic.com → API Keys → create → `ANTHROPIC_API_KEY` in Doppler
- Google AI Studio: https://aistudio.google.com → API Keys → create → `GOOGLE_AI_API_KEY` in Doppler
- OpenAI (for embedding only, Phase 3+): https://platform.openai.com → API keys → `OPENAI_API_KEY` in Doppler

Set a hard budget on Anthropic + Google AI (Anthropic Console → Settings → Spend Limits). The operational runbook ([`operational-runbook.md`](operational-runbook.md) §1) lists the per-phase thresholds and the alert wiring; the short version for Phase 1:
- Anthropic: **$50/month soft, $200/month hard**.
- Google AI: **$50/month soft, $150/month hard** (set via Cloud Billing budget on the linked project, with "Cap spending at limit" enabled).

### 9. Sentry

Create org + projects at https://sentry.io:
- Project `pawdoc-mobile` (platform: Flutter)
- Project `pawdoc-ai-service` (platform: Python / FastAPI)

Copy DSNs → Doppler:
- `SENTRY_DSN_MOBILE`
- `SENTRY_DSN_AI_SERVICE`

### 10. PostHog

Two options:
- **Cloud (easy):** https://posthog.com → EU region → create project. Copy project API key → `POSTHOG_API_KEY`.
- **Self-hosted (recommended at scale, roadmap §3):** Deploy via the [`posthog/posthog`](https://github.com/PostHog/posthog) Fly.io recipe. Phase 0 can defer this to Phase 4 (cost: ~$30/mo Cloud free-tier supplement).

### 11. RevenueCat

- Create app at https://app.revenuecat.com
- Configure iOS Bundle ID `com.pawdoc.pawdoc`
- Configure Android Package Name `com.pawdoc.pawdoc`
- API keys → Doppler:
  - `REVENUECAT_PUBLIC_KEY_IOS`
  - `REVENUECAT_PUBLIC_KEY_ANDROID`
  - Webhook secret: generate → `REVENUECAT_WEBHOOK_AUTH_TOKEN`

### 12. OneSignal

- Create app at https://onesignal.com (one app, both platforms)
- iOS + Android push credentials configured Phase 2
- App ID + REST API key → Doppler:
  - `ONESIGNAL_APP_ID`
  - `ONESIGNAL_REST_API_KEY`

### 13. Better Uptime

- Create monitors at https://betteruptime.com → free tier covers Phase 0-2
- Add HTTP checks for:
  - `https://pawdoc-ai-dev.fly.dev/health`
  - `https://pawdoc-ai-prod.fly.dev/health` (Phase 1+)
  - `https://<project-ref>.supabase.co/rest/v1/` (basic 200 on root)
- Configure Slack / SMS alerts

---

## Wiring It All Up

### Doppler → GitHub Actions

In Doppler Dashboard → Integrations → GitHub:
1. Connect this repo
2. Map configs: `dev` → branch `develop`, `prod` → branch `main`
3. Enable auto-sync — Doppler now pushes env vars as GitHub Secrets

Required GitHub Actions secrets after sync:
- `FLY_API_TOKEN` (for `ai-service-deploy.yml`)
- `SUPABASE_ACCESS_TOKEN` (Phase 1+, for migration deploy)
- App Store + Play Console secrets (Phase 2)

### Doppler → Fly.io

```bash
doppler secrets download --config prod --no-file --format docker \
  | flyctl secrets import --app pawdoc-ai-prod

doppler secrets download --config dev --no-file --format docker \
  | flyctl secrets import --app pawdoc-ai-dev
```

Re-run whenever secrets change. Doppler's Fly.io integration also offers webhook-based sync.

### Enable Branch Protection

In GitHub repo → Settings → Branches → Add rule for `main`:
- Require pull request before merging
- Require status checks to pass: `mobile-ci/Format + Analyze + Test`, `ai-service-ci/Format + Lint + Type + Test`, `ai-service-ci/Docker image builds`, `secret-scan/Gitleaks`
- Require branches to be up to date
- Restrict who can push to matching branches: founder only

### Enable Deploy Workflows

Once Fly.io apps exist + `FLY_API_TOKEN` is synced:

```bash
gh variable set AI_SERVICE_DEPLOY_ENABLED --body true
```

(Or set via GitHub UI: Settings → Secrets and variables → Actions → Variables.)

---

## 14. Apple Sign-In (Production Wiring)

The mobile app supports two auth paths — email OTP (always on) and
Apple Sign-In (gated by `APPLE_SIGN_IN_ENABLED`). Before flipping the
prod build's flag to `true`, the four pieces below must all be in
place. If any are missing, the app handles it gracefully (the user
sees "Apple Sign-In is not configured for this build" and falls back
to email) — but App Store review will reject a binary that ships an
Apple Sign-In button that does nothing.

### 14.1 Apple Developer Console — enable the capability

1. Go to https://developer.apple.com/account → Certificates, IDs &
   Profiles.
2. Identifiers → select `com.pawdoc.pawdoc` (the iOS app ID).
3. Tick **Sign In with Apple**. Save.
4. (Optional, for the Android web fallback) Create a **Services ID**:
   Identifiers → + → Services IDs → `com.pawdoc.web`.
   - Enable **Sign In with Apple**, configure the primary App ID
     above, add the Supabase callback under "Return URLs":
     `https://<project-ref>.supabase.co/auth/v1/callback`.
5. Keys → + → tick **Sign In with Apple** → register and **download**
   the `.p8` private key. The key file is shown **once** — store the
   contents in Doppler as `APPLE_SIGN_IN_PRIVATE_KEY` (multi-line PEM
   block).

### 14.2 Supabase Dashboard — configure the OAuth provider

1. Project Settings → Authentication → Providers → **Apple**.
2. Toggle "Enable Apple provider" on.
3. Fill in:
   - **Services ID** = `com.pawdoc.web` (the one from 14.1.4)
   - **Team ID** = your Apple Developer Team ID (top-right of the
     Apple Developer site)
   - **Key ID** = the 10-character ID of the `.p8` key created in
     14.1.5
   - **Private key** = paste the **contents** of the `.p8` file
4. Site URL — confirm `io.pawdoc.app://callback` is listed under
   "Redirect URLs" in Authentication → URL Configuration.

### 14.3 Doppler — flip the flag

In Doppler's `prod` config, set:
```
APPLE_SIGN_IN_ENABLED=true
```
(Do **not** set this in `dev` until you've also done 14.1 + 14.2 for
the dev Supabase project. It's safe to leave dev as `false`.)

### 14.4 Verify

On a sandbox iOS device or simulator with `flutter run`:
1. Sign-out, then tap **Continue with Apple** on the auth screen.
2. Complete the Face ID / Touch ID confirmation.
3. The app should land on the home screen with the new Apple-linked
   session.

If it errors out with "Apple Sign-In is not configured for this
build" *despite* 14.1-14.3 being done, check the Supabase project's
**Logs → Auth Logs** — the most common failure is a malformed private
key (missing `\n` between header and body, accidentally pasting the
`-----BEGIN PRIVATE KEY-----` lines twice, etc.).

### 14.5 What the binary does when this isn't wired

| Missing piece | Symptom | App behaviour |
|---|---|---|
| `APPLE_SIGN_IN_ENABLED=false` | (dev default) | Button hidden entirely |
| Capability not on Apple Developer | iOS shows Apple sheet → error | Maps to `unknown` → "Something went wrong" |
| Provider disabled in Supabase | iOS sheet succeeds, Supabase returns 400 | Maps to `notConfigured` → "Apple Sign-In is not configured for this build" |
| `.p8` private key invalid | Same as above (400 from Supabase) | `notConfigured` → fallback copy |

The mobile error mapping lives in
`mobile/lib/shared/services/apple_signin_service.dart`. Test coverage
in `mobile/test/apple_signin_service_test.dart` exercises the
status-code → user-message translation for each of these.

---

## Verification Checklist

When all the above is done:

- [ ] `make ai-dev` works locally
- [ ] `curl https://pawdoc-ai-dev.fly.dev/health` returns 200 (after first deploy)
- [ ] `supabase link --project-ref <dev-ref>` succeeds
- [ ] All secrets exist in Doppler `dev` and `prod` configs
- [ ] GitHub branch protection on `main` is on
- [ ] Gitleaks workflow runs and passes on the latest commit
- [ ] Better Uptime monitors are configured
- [ ] Apple Sign-In configured (§14) before flipping the prod flag
