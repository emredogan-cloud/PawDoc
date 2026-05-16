# Phase 1D — Production Hardening + Monetization Foundation — PLAN

**Project:** PawDoc
**Phase:** 1D
**Date:** 2026-05-16
**Authoritative source:** [`roadmaps/APP_EXECUTION_ROADMAP.md`](../../roadmaps/APP_EXECUTION_ROADMAP.md) §7 (monetization), §9 (security), §10 Phase 1+2
**Predecessors:** Phase 0/1A/1B/1C complete

---

## 1. Scope

Wire RevenueCat, Apple Sign-In, Sentry, and OneSignal into the now-working
analyze flow. Complete the revenuecat-webhook state mapping deferred by
Phase 1B. Harden the production runtime — env validation, app lifecycle
resilience, deployment runbooks. Ship the paywall screen that the 402
`quotaExceeded` failure path needs.

What 1D is **not**: a polished growth funnel, A/B tests, real reminder
campaigns, family-plan UI, referrals UI. Those are roadmap Phase 3+.

## 2. Monetization Architecture

```
                    user taps "Continue with Premium" in paywall
                                       │
                                       ▼
                   purchases_flutter.purchasePackage(...)
                                       │
        ┌──────────────────────────────┴──────────────────────────────┐
        │                                                              │
        ▼                                                              ▼
  App Store / Play                                              RevenueCat
  StoreKit / Billing                                            (eventual)
        │                                                              │
        └───────► RevenueCat ◄─────────────────────────────────────────┘
                       │ webhook
                       ▼
        Supabase Edge Function /revenuecat-webhook
                       │ verified secret + event mapping
                       ▼
        public.users.subscription_status  ← THE SOURCE OF TRUTH
                       │
                       ▼ (every analyze call reads this via the free-tier RPC)
        attempt_consume_free_analysis(user_id)
```

### 2.1 Server is the source of truth

- The mobile **never** trusts a local `Purchases.entitlements.active`
  read for paywall gating.
- The mobile MAY display an entitlement badge from RevenueCat
  optimistically (between purchase and webhook arrival, typically
  3-30 seconds) — but the actual *quota gate* lives at
  `attempt_consume_free_analysis(...)`, which reads `public.users.
  subscription_status`.
- Phase 1A established this: a subscriber's `subscription_status` is
  `'premium'` or `'family'`, which causes the RPC to return `true`
  unconditionally (no quota consumed).

### 2.2 Eventually-consistent recovery

| Scenario | Behavior |
|----------|----------|
| Purchase succeeds, webhook lands in <30s | DB updated → next analyze immediately unlimited |
| Purchase succeeds, webhook is delayed | App shows "Premium" badge from RevenueCat client; user attempts analyze → 402 → paywall (because DB still shows `free` and quota was already exhausted). User taps "Restore purchases" → webhook eventually arrives → DB updates → unblocked |
| Webhook lost (network / RevenueCat outage) | "Restore purchases" forces a server-side reconciliation: the webhook is re-sent by RevenueCat on demand, or the mobile can call a future `/sync-entitlement` edge function (Phase 2) |
| App offline at purchase time | Store APIs queue the receipt; resumes on reconnect |

### 2.3 Pricing per roadmap §7

| Tier | Monthly | Annual | RevenueCat offering |
|------|---------|--------|---------------------|
| Premium | $9.99 | $59.99 (~$5/mo) | `pawdoc_premium` offering, packages `monthly` + `annual` |
| Family | $14.99 | $89.99 (~$7.50/mo) | `pawdoc_family` offering, packages `monthly` + `annual` |

Annual presented FIRST per roadmap §7 ("Annual-first display"). The mobile
default selection is `pawdoc_premium.annual`.

### 2.4 RevenueCat webhook mapping (completing Phase 1B's stub)

| Event type | Target `subscription_status` | Notes |
|------------|------------------------------|-------|
| `INITIAL_PURCHASE` | `premium` or `family` per `product_id` mapping | Set `subscription_tier` to RC's `product_id` |
| `RENEWAL` | same | Idempotent |
| `PRODUCT_CHANGE` | re-derive from new `product_id` | E.g., premium → family upgrade |
| `UNCANCELLATION` | re-derive | User resumed cancelled sub |
| `EXPIRATION` | `free` | Period ended without renewal |
| `BILLING_ISSUE` | `free` | After grace period expires |
| `CANCELLATION` | **no DB change** | User cancelled — sub still active until `expires_date` |
| `NON_RENEWING_PURCHASE` | no change | One-time IAP, not subscription |
| `TRANSFER` | log only | Phase 2: handle account-level transfers |
| `SUBSCRIPTION_PAUSED` | log only | Phase 2 |
| `SUBSCRIPTION_EXTENDED` | log only | Phase 2 |

Product → tier mapping configured via env, NOT hardcoded:

```
REVENUECAT_PRODUCT_PREMIUM_MONTHLY=pawdoc_premium_monthly
REVENUECAT_PRODUCT_PREMIUM_ANNUAL=pawdoc_premium_annual
REVENUECAT_PRODUCT_FAMILY_MONTHLY=pawdoc_family_monthly
REVENUECAT_PRODUCT_FAMILY_ANNUAL=pawdoc_family_annual
```

Allows the App Store / Play product IDs to be renamed without a code
deploy.

## 3. Apple Sign-In

### 3.1 Why now

Per roadmap §10 Phase 1 task list ("Apple Sign In + email auth flows") and
App Store rule 4.8: any app that uses third-party social auth must also
offer Apple Sign-In. We ship email-only in 1C (acceptable for closed
TestFlight); Apple ships in 1D so the public App Store submission can
proceed (Phase 2).

### 3.2 Flow

```
user taps "Continue with Apple"
       │
       ▼
generate cryptographically random nonce
       │
       ▼
sign_in_with_apple.getAppleIDCredential(nonce: sha256(raw_nonce))
       │
       ▼
receive Apple ID token (JWT)
       │
       ▼
supabase.auth.signInWithIdToken(
  provider: OAuthProvider.apple,
  idToken: appleCredential.identityToken,
  nonce: raw_nonce,           // Supabase verifies sha256(raw) matches what Apple signed
)
       │
       ▼
Supabase Auth verifies Apple's signature + nonce → creates session
       │
       ▼
auth state stream emits Authenticated → router redirects
```

### 3.3 Nonce handling

- Generate 32 cryptographically random bytes (`Random.secure()`).
- Base64-encode for the raw nonce.
- SHA-256 the raw nonce; pass the hash to Apple (Apple signs the hash).
- Pass the raw nonce to Supabase; Supabase verifies sha256(raw) == hash.

### 3.4 Account linking

If a user has signed up via email previously and now uses Apple with the
*same* email, Supabase Auth attempts to link automatically (matching by
verified email). If Apple's "Hide my email" relay is used, the link is
not automatic — Supabase treats it as a new account. This is the same
behaviour all major apps have; we document it but don't try to override.

### 3.5 Fallback

Apple Sign-In is iOS-only (Android can use Apple's web flow but it's
janky on a phone). We:
- Show the Apple button only on `Platform.isIOS`.
- Show the email OTP flow as the always-available fallback.
- Hide the Apple button entirely when `APPLE_SIGN_IN_ENABLED=false`
  (e.g., dev builds where the OAuth provider isn't configured in
  Supabase).

## 4. Observability Strategy

### 4.1 Sentry: three projects, three SDKs

| Project | SDK | What's reported |
|---------|-----|-----------------|
| `pawdoc-mobile` | `sentry_flutter` | Flutter uncaught exceptions, native crashes, manual `Sentry.captureException` |
| `pawdoc-ai-service` | `sentry-sdk[fastapi]` | FastAPI unhandled exceptions, AI provider errors logged through `app.core.exceptions` |
| `pawdoc-edge-functions` (Phase 2) | `https://deno.land/x/sentry` | Deferred — Phase 1D scope is mobile + AI; edge functions stay on structlog/console for now |

### 4.2 What gets captured, what doesn't

**Always captured:**
- Crashes / unhandled exceptions
- Edge cases logged via `Sentry.captureMessage` (rare)
- HTTP failures with response status (sanitised body — keys/PII stripped)
- Sentry breadcrumbs for major nav events + API calls

**Never captured:**
- Auth tokens (JWT, refresh, RevenueCat receipts) — stripped via Sentry
  `beforeSend`
- Raw user emails — stripped (we use user.id which is a UUID)
- Raw image bytes — Sentry's default config doesn't capture attachments;
  we don't enable it
- Free-text symptom descriptions — they may contain identifying details
  about the owner; we hash them before adding as a tag

### 4.3 Release tracking

Every Sentry init reads:
- `release`: `pawdoc-mobile@<version>+<build>` (or service-specific)
- `environment`: `prod` | `dev` | `local` (from `APP_ENV`)
- `dist`: build number (mobile only)

The Sentry "Releases" tab then groups errors by build, surfacing regressions
introduced in a specific version.

### 4.4 Request correlation

Phase 1B already wires `X-Request-ID` between edge function and AI service.
Phase 1D adds the request ID as a Sentry tag on every captured event so
errors across services can be joined in the Sentry UI.

### 4.5 PII minimisation hook (every service)

```python
# Python
def before_send(event, hint):
    # Strip request body, auth headers, query strings.
    if 'request' in event and 'data' in event['request']:
        event['request']['data'] = '<scrubbed>'
    return event
```

```dart
// Flutter
options.beforeSend = (event, hint) {
  event = event.copyWith(request: event.request?.copyWith(data: null));
  return event;
};
```

The Sentry SDK already scrubs default secret-pattern keys; this is
defence-in-depth.

## 5. OneSignal Foundation

### 5.1 Scope for 1D

- SDK initialised at app start (or no-op when `ONESIGNAL_APP_ID` empty).
- `OneSignal.login(userId)` on auth success → ties player_id to our user
  ID across reinstalls.
- Player ID persisted to `public.users.one_signal_player_id` via a
  service-role RPC (so the mobile doesn't need an authenticated INSERT
  policy on that column).
- Permission request UX: contextual modal after onboarding pet, before
  the home screen. Roadmap §6 puts this earlier (screen 4); we defer
  to post-onboarding to keep 1D's onboarding flow simple. Phase 2 may
  reorder.

### 5.2 Out of scope for 1D

- 48 h follow-up campaigns
- Vaccination reminder cron
- Seasonal alerts
- Notification preferences UI

These are Phase 3 ([`reports/GROWTH_STRATEGY.md`](../../reports/GROWTH_STRATEGY.md) §retention).

## 6. App Store Compliance Considerations

| Rule | How we comply |
|------|---------------|
| 4.8 (must offer Apple Sign-In if any other social auth) | We ship Apple + email; no Google Sign-In in 1D (Phase 2) |
| 2.3.1 ("accurate metadata") | App Store description: "AI-assisted guidance, not veterinary diagnosis"; same wording every screen footer |
| 1.4.1 (medical apps require accurate health info) | Disclaimer at API level (Phase 1B); cross-verify + confidence floor; EMERGENCY override hardcoded |
| 3.1.1 (in-app purchases for digital content) | All paid features go through RevenueCat → StoreKit; no external payment links from inside the app |
| 3.1.2 (subscription disclosure) | Paywall lists: price, billing period, renewal disclosure, cancel link, restore link, ToS + Privacy links |
| 5.1.1 (privacy + data collection) | Privacy manifest (`PrivacyInfo.xcprivacy`) added in Phase 2 alongside App Store submission. Camera permission used only for the analyze flow |
| 5.1.5 (location services) | We don't request location in 1D |
| 4.2 (minimum functionality) | Real product behind paid tier — analyze + history + multi-pet |

### 6.1 Paywall copy discipline

- **No** scarcity language ("Only X spots!").
- **No** countdown timers.
- **No** dark patterns (pre-checked, hard-to-dismiss).
- Clear price + renewal info, big "Cancel anytime" line.
- Equal visual weight for "Restore purchases" link.
- A visible "Maybe later" button.

Phase 4 will A/B test specific copy variants, but the foundation is
trust-first.

## 7. Production Hardening

### 7.1 Env validation

`AppConfig.fromEnvironment()` already returns a typed config. Phase 1D adds:

```dart
void validate() {
  if (env == AppEnv.prod) {
    if (sentryDsn.isEmpty) {
      // Production builds must have Sentry — otherwise crashes go to
      // dev/null. This is a fatal config error.
      throw StateError('SENTRY_DSN required in prod builds');
    }
    if (revenueCatPublicKey.isEmpty) {
      throw StateError('REVENUECAT_PUBLIC_KEY required in prod builds');
    }
  }
}
```

AI service (`app/core/config.py`) gets the same treatment:
`if app_env == AppEnv.PROD and sentry_dsn is None: raise ValueError(...)`.

### 7.2 App lifecycle resilience

`WidgetsBindingObserver` watches for `AppLifecycleState.resumed`. On
resume after >5 minutes background, we:
- Re-emit `authStreamProvider` (cheap; just reads current session)
- Refresh `petsControllerProvider` (DB re-fetch)

Reasons: a JWT may have rotated, or the user may have changed pet data
from another device.

### 7.3 Retry / fallback review

| Layer | Retry | Fallback |
|-------|-------|----------|
| AI service ↔ Gemini | 1 retry on 5xx (Phase 1B) | Escalate to Tier 3 (Phase 1B) |
| AI service ↔ Claude | 1 retry on 5xx (Phase 1B) | Graceful degradation (Phase 1B) |
| Edge fn ↔ AI service | Phase 1B has the 30s timeout; **Phase 1D adds 1 retry on connection error** (network blip mid-call) | Returns 502 → mobile shows friendly upstream error |
| Mobile ↔ Edge fn | No retry (POSTs are not idempotent — quota is consumed) | User retries manually |
| Mobile ↔ Supabase Storage | `supabase_flutter` retries small reads; uploads do not retry | User retries via UI |

The decision to NOT auto-retry the mobile analyze POST is deliberate: a
retry on transient failure would double-charge the user's quota. The user
explicitly opts in to retry.

### 7.4 Timeout audit

| Call | Timeout | Source |
|------|---------|--------|
| Mobile → Supabase Auth | default (60s) | SDK |
| Mobile → Supabase Storage upload | default | SDK; large uploads acceptable |
| Mobile → Edge function /analyze | 60s | Mobile-side HTTP client |
| Edge fn → Upstash Redis | 5s | Hand-rolled timeout in rate-limit.ts |
| Edge fn → AI service | 30s | `AbortController` in ai-service.ts |
| AI service → Gemini | 20s | `Settings.gemini_timeout_s` |
| AI service → Claude | 30s | `Settings.claude_timeout_s` |

End-to-end ceiling: edge function 30s timeout < mobile 60s timeout < user
abandonment threshold (~30s subjective). Safe.

### 7.5 Upload abuse review

- Bucket size cap: 5 MB (server-enforced; Phase 1C)
- MIME allowlist: jpeg/png/heic/webp (server-enforced; Phase 1C)
- Per-user folder RLS: `<user_id>/<filename>` (Phase 1C)
- Daily rate limit: 10/day per Phase 1B
- Free-tier monthly limit: 3 per Phase 1A
- Auth required: bucket private + service-role-only signed URL gen

A malicious user can at most:
- Upload 3 (free) or 10 (paid) files per day = 50 MB/day max
- Cannot read others' uploads (RLS)
- Cannot consume more than the daily rate of AI calls

This is acceptable. We add no new controls in 1D.

## 8. Operational Logging Improvements

### 8.1 Event-name registry

Existing services already emit structured events. Phase 1D introduces a
**registry** (just a markdown doc — not code) of canonical event names so
they're consistent across services:

```
analyze_request_received          edge function
analyze_completed                 ai-service router
emergency_override_triggered      ai-service orchestrator
tier2_resolved / tier3_resolved   ai-service orchestrator
graceful_degradation              ai-service orchestrator
rate_limit_check                  edge function
free_tier_consume                 edge function
auth_state_changed                mobile
purchase_flow_started             mobile
purchase_completed                mobile
purchase_restored                 mobile
paywall_shown                     mobile
paywall_dismissed                 mobile
```

Lives at `docs/event-catalog.md`. Phase 4 (PostHog A/B testing) will use
this catalog as the canonical event names for funnel + retention analytics.

### 8.2 Sentry breadcrumb wiring

Where the mobile already emits a `_log.info(...)` event for important user
actions, we *additionally* call `Sentry.addBreadcrumb(...)` so an
eventual crash report carries the recent user journey. Implemented as a
wrapper in `shared/services/logger.dart`:

```dart
class AppLogger {
  void breadcrumb(String message, {Map<String, Object?>? data}) {
    Sentry.addBreadcrumb(Breadcrumb(message: message, data: data));
    _logger.info(message);
  }
}
```

## 9. Deployment & Rollback

### 9.1 Activating the Fly.io deploy workflow

Phase 0 shipped `.github/workflows/ai-service-deploy.yml` gated on the
repo variable `AI_SERVICE_DEPLOY_ENABLED == 'true'`. Activation requires:

1. `flyctl auth signup`
2. `flyctl apps create pawdoc-ai-dev --org pawdoc`
3. `flyctl apps create pawdoc-ai-prod --org pawdoc`
4. `flyctl auth token` → copy → set as GH secret `FLY_API_TOKEN`
5. Configure Doppler → Fly.io integration; sync `dev` and `prod` configs
6. Set the GH repo variable `AI_SERVICE_DEPLOY_ENABLED=true`

The deploy workflow then triggers on every push to `main` that touches
`ai-service/**`, running a `flyctl deploy --strategy rolling` followed by
an external `/health` probe.

### 9.2 Staging vs production separation

| Env | Supabase project | Fly.io app | RevenueCat env |
|-----|------------------|------------|----------------|
| `dev` | `pawdoc-dev` | `pawdoc-ai-dev` | RevenueCat sandbox (StoreKit testing) |
| `prod` | `pawdoc-prod` | `pawdoc-ai-prod` | RevenueCat production |

Mobile env files (`env/dev.json`, `env/prod.json`) point at the
corresponding URLs. `--dart-define-from-file=env/prod.json` produces a
binary hard-coded to prod backends; no runtime switching.

### 9.3 Rollback steps

Per service:

**AI service:**
```bash
flyctl releases list --app pawdoc-ai-prod
flyctl releases rollback <prior-version> --app pawdoc-ai-prod
```
Roll-forward is preferred for schema-related issues; rollback is only
safe when the binary change is purely behavioural.

**Supabase edge functions:**
```bash
# Redeploy a prior commit
git checkout <prior-sha>
supabase functions deploy <name> --project-ref <prod-ref>
git checkout main
```
There is no native rollback in Supabase; we redeploy.

**Supabase migrations:**
Forward-only. To revert a problematic migration, author a follow-up
migration. We do not run destructive rollbacks against production data.

**Mobile (TestFlight / Play Internal):**
- TestFlight: invalidate the failing build; users re-download the prior
  build automatically.
- Play Internal: halt rollout in console; previous version remains live.

These are documented in detail in `docs/deployment.md` (extended by this
phase).

## 10. Operational Risks

| Risk | Mitigation in 1D | Phase to fully address |
|------|-------------------|------------------------|
| RevenueCat webhook lost / delayed | "Restore purchases" UX; the server retains the authoritative state once eventual consistency settles | Phase 2 (`/sync-entitlement` endpoint) |
| User signs in via Apple "Hide my email" + later email-OTP with their real address | Duplicate accounts. Phase 1D documents the limitation; Phase 2 ships an in-app "merge accounts" flow if customer support volume justifies | Phase 2 |
| Sentry quota exhausted by a crash loop | We set sample rates: `tracesSampleRate: 0.1`, `profilesSampleRate: 0` — captures errors fully but throttles performance traces | Phase 2 (refine after real traffic) |
| OneSignal player_id desync after reinstall | `OneSignal.login(userId)` re-binds on every app start; idempotent server-side UPSERT | OK |
| Paywall A/B test framework missing | Phase 1D ships one paywall layout; the analytics events fire for Phase 4 A/B testing | Phase 4 |
| Production env without Sentry DSN ships | `AppConfig.validate()` throws at boot for prod builds; CI smoke would catch | OK |
| Apple Sign-In credential leak via logs | Sentry `beforeSend` scrubs `request.data`; the credential payload is short-lived (single use) | OK |
| Inbox spam during email OTP testing | Local Inbucket — never hits real email in dev. Prod uses Supabase SMTP — rate-limited by Supabase | OK |
| AI service env mismatch (e.g., dev token + prod URL) | Phase 1D's stricter `Settings.validate()` checks env consistency | OK |
| Concurrent purchase + analyze race | The free-tier RPC takes `FOR UPDATE` lock; the webhook UPDATE waits its turn. No race | OK |

## 11. Test Plan

### 11.1 Edge function (`revenuecat-webhook`)

| Test | Asserts |
|------|---------|
| INITIAL_PURCHASE → premium | DB row updated with `subscription_status='premium'`, `subscription_tier=<product_id>` |
| INITIAL_PURCHASE with family product → family | maps correctly |
| RENEWAL is idempotent | running twice produces the same final row |
| EXPIRATION → free | downgrades |
| CANCELLATION is a no-op | DB row unchanged |
| TRANSFER is logged but no DB change | safe default |
| Unknown event type is logged and acked 200 | doesn't 500 |
| Missing bearer token → 401 | from Phase 1B |
| Missing `app_user_id` → 422 | from Phase 1B |

### 11.2 Mobile

| Test | Asserts |
|------|---------|
| `AppConfig.validate()` throws in prod with missing Sentry | catches misconfiguration |
| `AppConfig.validate()` no-op in local | doesn't bother dev |
| `RevenueCatService.noOpWhenKeyMissing` | doesn't crash on init in local |
| `AppleSignInService.generateNonce` | nonce is base64 + 32 bytes raw, sha256 matches |
| `PaywallController.purchase` happy path | calls SDK → emits success state |
| `PaywallController.restore` happy path | calls SDK → reads entitlements |
| `OneSignalService.noOpWhenAppIdMissing` | doesn't crash in local |
| `SentryService.noOpWhenDsnMissing` | doesn't init |
| Paywall renders both Premium + Family with annual prices first | tier comparison correct |
| 402 from analyze service → paywall route | mobile routing test |

### 11.3 AI service

| Test | Asserts |
|------|---------|
| Sentry init no-op with empty DSN | `init_sentry(None)` returns without error |
| Sentry init with DSN sets env tag | `init_sentry(...)` configures release + environment |
| Production env without DSN raises ValidationError | enforces prod requirement |

## 12. Files Added / Modified

### Added

```
mobile/lib/shared/services/sentry_service.dart
mobile/lib/shared/services/revenuecat_service.dart
mobile/lib/shared/services/apple_signin_service.dart
mobile/lib/shared/services/onesignal_service.dart
mobile/lib/shared/services/app_lifecycle_observer.dart
mobile/lib/features/paywall/paywall_screen.dart
mobile/lib/features/paywall/paywall_controller.dart
mobile/test/revenuecat_service_test.dart
mobile/test/paywall_controller_test.dart
mobile/test/apple_signin_service_test.dart
mobile/test/onesignal_service_test.dart
mobile/test/app_config_validation_test.dart
ai-service/app/core/sentry.py
ai-service/tests/test_sentry.py
supabase/functions/revenuecat-webhook/_state_map.ts    (extracted from index.ts)
supabase/functions/revenuecat-webhook/state_map.test.ts
docs/reports/phase1d-production-plan.md                (this file)
docs/reports/phase1d-production-implementation.md      (post-impl)
docs/event-catalog.md
docs/rollback-runbook.md
```

### Modified

```
mobile/pubspec.yaml                          + 5 deps (purchases_flutter, sign_in_with_apple, sentry_flutter, onesignal_flutter, crypto)
mobile/lib/app/config.dart                   + revenueCat/oneSignal/apple keys + validate()
mobile/lib/main.dart                         + Sentry, RevenueCat, OneSignal init; runZonedGuarded
mobile/lib/app/router.dart                   + /paywall route
mobile/lib/features/auth/auth_screen.dart    + Apple Sign-In button (iOS only)
mobile/lib/features/auth/auth_controller.dart  + signInWithApple flow
mobile/lib/shared/services/analyze_service.dart  + emit purchase_required event for paywall routing
mobile/lib/shared/services/logger.dart       + breadcrumb wrapper (only when Sentry initialized)
mobile/lib/features/onboarding/welcome_screen.dart  + push permission prompt before /home
mobile/env/dev.json.example                  + new env keys
mobile/env/prod.json.example                 + new env keys
ai-service/pyproject.toml                    + sentry-sdk[fastapi]
ai-service/app/core/config.py                + REVENUECAT_PRODUCT_* (for completeness; webhook reads these)
ai-service/app/main.py                       + Sentry init at lifespan startup
ai-service/.env.example                      + SENTRY_DSN documented
supabase/functions/revenuecat-webhook/index.ts  full state mapping implementation
docs/deployment.md                           + Fly.io activation runbook + RC sandbox setup
docs/environment-setup.md                    + RevenueCat / OneSignal / Apple OAuth steps
```

### Not Touched

Phase 0/1A/1B/1C core artifacts (migrations, schema, RLS policies, AI
orchestrator). Phase 1D is **integration scaffolding** plus the webhook
completion + paywall UI.

## 13. Definition of Done

- `flutter analyze --fatal-infos --fatal-warnings` exits 0
- `flutter test` passes (1C 55 + new 1D tests, all green)
- `make lint && make test` pass (Phase 0/1B/1C gates intact)
- `supabase test db` passes (1A pgTAP 48/48 unchanged)
- `deno fmt/lint/check/test` pass (new revenuecat webhook tests included)
- `pytest` in `ai-service/` passes (≥80% coverage; new Sentry tests)
- Live smoke: app boots without crashing when ALL of the SDK keys are
  empty (graceful degradation across the integrations)
- `phase1d-production-implementation.md` documents the result + readiness

---

*End of Phase 1D plan. Implementation follows.*
