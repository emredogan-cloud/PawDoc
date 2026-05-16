# Phase 1D — Production Hardening + Monetization Foundation — IMPLEMENTATION

**Project:** PawDoc
**Phase:** 1D
**Date:** 2026-05-16
**Plan reference:** [`phase1d-production-plan.md`](phase1d-production-plan.md)
**Predecessors:** Phase 0 / 1A / 1B / 1C complete

---

## 1. Summary

Phase 1D wires monetisation + observability + push foundations into the
running app, completes the Phase 1B revenuecat-webhook stub, and tightens
production env validation. The mobile boots cleanly with all SDKs absent
(local dev) and with all configured (production-ready).

Phase 0 / 1A / 1B / 1C architecture preserved entirely.

### Verification (all run locally)

| Command | Result |
|---------|--------|
| `flutter analyze --fatal-infos --fatal-warnings` | ✅ No issues |
| `flutter test` | ✅ **84/84** mobile tests |
| `make lint && make test` | ✅ Phase 0/1A/1B/1C gates intact |
| `supabase test db` (1A pgTAP RLS) | ✅ **48/48** |
| Deno (`fmt --check && lint && check && test`) | ✅ **44/44** edge function tests (17 new state_map + 27 prior) |
| `pytest` in `ai-service/` | ✅ **110/110** at **91.8% coverage** |

---

## 2. Implemented Systems

### 2.1 RevenueCat — subscription state mapping (server side)

`supabase/functions/revenuecat-webhook/index.ts` now applies the inbound
event to `public.users` via service-role UPDATE. The mapping rules live
in `state_map.ts` for unit testability.

| Event | Action |
|-------|--------|
| `INITIAL_PURCHASE`, `RENEWAL`, `PRODUCT_CHANGE`, `UNCANCELLATION`, `SUBSCRIPTION_EXTENDED` | Upgrade — derive tier from `product_id` env mapping |
| `EXPIRATION`, `BILLING_ISSUE` | Downgrade to `free` |
| `CANCELLATION` | No DB change (entitlement still active until expires_date) |
| `NON_RENEWING_PURCHASE`, `SUBSCRIPTION_PAUSED`, `TRANSFER`, `TEST` | Log only |
| Unknown event type | Log and ack 200 |

Product → tier mapping is configured via env (not hardcoded):

```
REVENUECAT_PRODUCT_PREMIUM_MONTHLY=...
REVENUECAT_PRODUCT_PREMIUM_ANNUAL=...
REVENUECAT_PRODUCT_FAMILY_MONTHLY=...
REVENUECAT_PRODUCT_FAMILY_ANNUAL=...
```

Unknown SKUs default to `premium` (fail-safe — never downgrades a
real subscriber due to a typo'd env).

**17 new pgTAP-style tests** (`state_map.test.ts`) cover every mapping
branch + idempotency.

### 2.2 RevenueCat — mobile (client side)

`shared/services/revenuecat_service.dart`:
- `RevenueCatServiceImpl` wraps `Purchases.configure / logIn /
  purchasePackage / restorePurchases / logOut`.
- `NoopRevenueCatService` returns `notSupported` for every call — used
  when no public key is configured (local dev).
- The provider switches on `Platform.isIOS` to pick the right key
  (`REVENUECAT_PUBLIC_KEY_IOS` vs `_ANDROID`).

`features/paywall/`:
- `PaywallController` loads offerings, prefers `pawdoc_premium`, exposes
  `purchase(package)` + `restore()`.
- `PaywallScreen` shows: tier comparison bullet points, the annual
  package selected by default, "Maybe later" button, and a "Restore
  purchases" link. No scarcity language, no countdowns.

When `/analyze` returns 402, the capture screen routes the user to
`/paywall` (the mobile error mapping is in `AnalyzeFailureKind`). On a
successful purchase the paywall navigates back to `/home` and trusts
the next analyze call to pick up the new entitlement once the webhook
lands.

### 2.3 Apple Sign-In

`shared/services/apple_signin_service.dart`:
- Generates a 32-byte cryptographically random nonce, SHA-256s it, sends
  the hash to Apple, forwards the *raw* nonce + Apple's ID token to
  `client.auth.signInWithIdToken(provider: OAuthProvider.apple, ...)`.
- `isSupported` returns true only when `APPLE_SIGN_IN_ENABLED=true` AND
  `Platform.isIOS`. The button is hidden when `!isSupported`.
- Typed `AppleSignInError` enum maps the SDK's exception codes to user-
  visible copy with **no backend identifier leakage** (tested in
  `apple_signin_service_test.dart`).

### 2.4 Sentry — three SDKs, one discipline

**AI service** (`app/core/sentry.py`):
- `init_sentry(settings)` configures the SDK with FastAPI + Starlette +
  HTTPX integrations. No-op when DSN is missing.
- `_scrub_event` strips request body, query string, sensitive headers,
  and user email/IP before any event leaves the process.
- 5 unit tests cover init-without-DSN, idempotency, the scrub function.

**Mobile** (`shared/services/sentry_service.dart`):
- `runWithSentry(config, () => runApp(...))` initialises only when DSN
  present. `FlutterError.onError` forwards uncaught widget errors.
- `_scrub` strips request body + sensitive headers + user PII (email/IP)
  via a fresh `SentryRequest` (copyWith doesn't differentiate "leave
  unchanged" from "clear").

**Common discipline** (both):
- Release tag: `pawdoc-mobile@<version>+<build>` / `pawdoc-ai-service@<version>`
- Environment tag: matches `APP_ENV`
- `tracesSampleRate: 0.1` (10% performance traces — conservative)
- `profilesSampleRate: 0.0` (off by default; expensive)
- `sendDefaultPii: false`
- No screenshot/view-hierarchy attachment on mobile (pet image leakage
  risk)

### 2.5 OneSignal

`shared/services/onesignal_service.dart`:
- `OneSignalServiceImpl.initialize(...)` configures the SDK when an app
  id is present.
- `linkUser(userId)` calls `OneSignal.login(userId)` and persists the
  resulting `player_id` to `public.users.one_signal_player_id` via the
  column-level GRANT (Phase 1A) — the mobile already has UPDATE rights
  on that column under its JWT.
- `requestPermission()` triggers the OS prompt.
- `logout()` clears the binding on sign-out.
- `NoopOneSignalService` for local dev / un-keyed builds.

Phase 1D ships **registration only**. Campaigns (48 h follow-ups,
reminder schedules) are Phase 3 per roadmap §6.

### 2.6 Production hardening

**Env validation** (`AppConfig.validate()`):
- In **prod**, throws `StateError` if `SENTRY_DSN` is empty.
- Returns warnings for missing RevenueCat / OneSignal / Apple-disabled.
- In **local/dev**, never throws or warns (developer convenience).

**App lifecycle** (`shared/services/app_lifecycle_observer.dart`):
- Watches `AppLifecycleState`. On resume after >5 min idle:
  - Refreshes `petsControllerProvider`.
  - Re-identifies with RevenueCat + OneSignal.
- Wired in `main.dart` as a top-level wrapper of `PawDocApp`.

**Auth-state sync** (in `main.dart::_Bootstrapper`):
- On every `authStateProvider` change:
  - `Authenticated` → `rc.identify(userId)` + `os.linkUser(userId)`
  - `Unauthenticated` → `rc.logOut()` + `os.logout()`
- Subscription is closed when the app shuts down.

**Edge function retry** (`_shared/ai-service.ts`):
- One retry on **transport-only** failures (DNS, ECONNRESET, etc.) with
  a 250 ms backoff. **No retry** on HTTP responses (5xx is the AI
  service's responsibility) or on timeouts (a retry would just
  re-timeout). Quota is consumed once before the call; transport-retry
  preserves the quota→result contract.

---

## 3. App Store Readiness Status

| Requirement | Status |
|-------------|--------|
| Apple Sign-In wired | ✅ (gated on `APPLE_SIGN_IN_ENABLED=true` until Apple Developer enrollment completes) |
| RevenueCat subscriptions | ✅ Server source-of-truth via webhook; mobile UX complete |
| Crash reporting (Sentry) | ✅ Mobile + AI service both wired |
| Camera permission flow | ✅ (Phase 1C) |
| Privacy disclaimer at API level | ✅ (Phase 1B) |
| Disclaimer visible on every result | ✅ (Phase 1C) |
| EMERGENCY acknowledgement gate | ✅ (Phase 1C) |
| Restore purchases | ✅ |
| Paywall: clear price, renewal, cancel disclosure | ✅ Hardcoded footer text |
| No scarcity language / countdown timers | ✅ Verified in `paywall_screen.dart` |
| No medical "diagnosis" wording in metadata | TBD — App Store Connect submission step (Phase 2) |
| `PrivacyInfo.xcprivacy` manifest | TBD — Phase 2 |
| Push permission contextual prompt | Service exists; the UX placement is Phase 2 (post-onboarding nudge) |
| Apple Developer enrollment | **External** — must complete before public submission |

**Verdict:** the codebase is **ready for App Store closed-TestFlight
distribution** once the cloud accounts in `docs/environment-setup.md`
are provisioned. Public submission requires the metadata + privacy
manifest work catalogued in Phase 2.

---

## 4. Known Production Risks

| Risk | Severity | Mitigation in 1D |
|------|----------|-------------------|
| RevenueCat webhook lost / delayed | Medium | "Restore purchases" forces re-sync; the server is the entitlement authority once the webhook lands |
| User signs in via Apple Hide-My-Email + later email-OTP → two accounts | Low | Documented in plan §10; manual support flow until Phase 2 merge UI |
| Sentry quota spike from a crash loop | Low | `tracesSampleRate: 0.1`; `profilesSampleRate: 0`. Tune after real traffic |
| OneSignal player_id desync after reinstall | Low | `linkUser(userId)` is idempotent; called on every auth change |
| Paywall A/B testing framework absent | Acceptable | Phase 4 ships PostHog feature flags; 1D delivers the events catalog |
| App boots into invalid prod env (Sentry missing) | **Fatal** by design | `AppConfig.validate()` throws at startup; CI smoke catches |
| Apple Sign-In credential leaked via Sentry | Low | `beforeSend` scrubs request body + sensitive headers; the credential is one-time use anyway |
| Free-tier counter race during a purchase | Low | Free-tier RPC uses `FOR UPDATE`; webhook write waits its turn |
| Webhook delivery during DB outage | Low | Webhook handler returns 502; RevenueCat retries automatically |
| Cancellation → unexpected downgrade | Mitigated | `CANCELLATION` is intentionally a no-op; `EXPIRATION` is the downgrade signal |

---

## 5. Files Added / Modified

### Added — mobile

```
mobile/lib/shared/services/sentry_service.dart
mobile/lib/shared/services/revenuecat_service.dart
mobile/lib/shared/services/apple_signin_service.dart
mobile/lib/shared/services/onesignal_service.dart
mobile/lib/shared/services/app_lifecycle_observer.dart
mobile/lib/features/paywall/paywall_controller.dart
mobile/lib/features/paywall/paywall_screen.dart
mobile/test/app_config_validation_test.dart
mobile/test/apple_signin_service_test.dart
mobile/test/revenuecat_service_test.dart
mobile/test/onesignal_service_test.dart
mobile/test/sentry_service_test.dart
```

### Added — ai-service

```
ai-service/app/core/sentry.py
ai-service/tests/test_sentry.py
```

### Added — supabase

```
supabase/functions/revenuecat-webhook/state_map.ts
supabase/functions/revenuecat-webhook/state_map.test.ts
```

### Added — docs

```
docs/event-catalog.md
docs/rollback-runbook.md
docs/reports/phase1d-production-plan.md
docs/reports/phase1d-production-implementation.md   (this file)
```

### Modified

```
mobile/pubspec.yaml                                  + purchases_flutter, sign_in_with_apple,
                                                       sentry_flutter, onesignal_flutter, crypto
mobile/lib/app/config.dart                           + revenueCat/oneSignal/apple keys + validate()
mobile/lib/main.dart                                 + Sentry wrap + RC + OneSignal + auth sub
mobile/lib/app/router.dart                           + /paywall route
mobile/lib/features/auth/auth_screen.dart            + Apple Sign-In button (iOS only)
mobile/lib/features/analysis/analysis_capture_screen.dart + 402 → /paywall routing
mobile/env/dev.json.example                          + new env keys
mobile/env/prod.json.example                         + new env keys
ai-service/pyproject.toml                            + sentry-sdk[fastapi]
ai-service/app/main.py                               + Sentry init in lifespan
supabase/functions/revenuecat-webhook/index.ts       full state mapping implementation
supabase/functions/_shared/ai-service.ts             + transport-error retry
```

### Not Touched

Phase 1A migrations / RLS, Phase 1B AI orchestrator + provider clients,
Phase 1C onboarding + analyze flows. The integrations are bolted onto
existing seams, not refactored into them.

---

## 6. Operational Notes

### Activating each integration

| Service | Configure |
|---------|-----------|
| Sentry | Set `SENTRY_DSN` (mobile env + ai-service env). Required in prod |
| RevenueCat | Set `REVENUECAT_PUBLIC_KEY_IOS` + `REVENUECAT_PUBLIC_KEY_ANDROID` (mobile env). `REVENUECAT_WEBHOOK_AUTH_TOKEN` + `REVENUECAT_PRODUCT_*` (edge function env via `supabase secrets set`) |
| OneSignal | Set `ONESIGNAL_APP_ID` (mobile env) |
| Apple Sign-In | Set `APPLE_SIGN_IN_ENABLED=true` (mobile env); configure Apple OAuth provider in Supabase Auth |

`docs/environment-setup.md` already has the setup steps from Phase 0;
Phase 2 will refresh it with explicit Phase 1D activation lines.

### Smoke order for a fresh release

1. Deploy ai-service (Fly.io)
2. Deploy edge functions (`supabase functions deploy`)
3. Deploy mobile (TestFlight / Play Internal)
4. Verify in TestFlight: sign in → onboard → analyze (text-only emergency) → see EMERGENCY
5. Verify paywall: spam analyze until 402 → tap upgrade → buy a sandbox sub → verify subscription_status in DB

The rollback steps for each layer are in [`docs/rollback-runbook.md`](../rollback-runbook.md).

---

## 7. Phase 2 Recommendations

In priority order — each is a single PR-sized scope.

1. **Apple Developer Program enrollment + Match config.** Required for
   any public TestFlight build. Lead time 24-48 h.

2. **`PrivacyInfo.xcprivacy` manifest.** Required for App Store Connect
   submission. Lists every API access (camera, network) + reasons.

3. **App Store metadata.** Title, subtitle, keywords, screenshots,
   review notes ("AI-assisted information tool, not veterinary
   service. All results include clear disclaimers.")

4. **E&O insurance ($100K minimum, pre-public launch).** Roadmap §9.
   Operational, not engineering.

5. **Family-plan picker + multi-pet UX.** Surfaces `pawdoc_family` SKU.

6. **Push permission UX placement.** Currently the service requests on
   demand; Phase 2 should add a contextual prompt at a natural moment
   (e.g., after the first successful MONITOR analysis).

7. **`/sync-entitlement` edge function.** A manual force-sync endpoint
   the mobile can hit if RevenueCat webhook is delayed (the user taps
   "Restore" → we hit the new endpoint → it queries RC directly).

8. **Sentry source-map upload.** Surfaces release-mode crash symbols.
   `sentry-cli` integration into the mobile-release workflow.

9. **PostHog event ingestion.** The event catalog (`docs/event-catalog.md`)
   is ready; Phase 4 wires it.

10. **Family-tier mapping in revenuecat-webhook.** Already implemented;
    Phase 2 just needs to activate the family SKU in App Store Connect.

---

## 8. Definition of Done — Verified

- ✅ `flutter analyze --fatal-infos --fatal-warnings` exits 0
- ✅ `flutter test` passes (84/84)
- ✅ `make lint && make test` pass (Phase 0/1B/1C gates intact)
- ✅ `supabase test db` passes (1A pgTAP 48/48)
- ✅ `deno fmt/lint/check/test` pass (44/44 edge function tests)
- ✅ `pytest` in `ai-service/` passes (110/110, 91.8% coverage)
- ✅ Sentry init no-ops gracefully without DSN
- ✅ RevenueCat init no-ops gracefully without keys
- ✅ OneSignal init no-ops gracefully without app id
- ✅ Apple Sign-In button hidden when disabled
- ✅ Paywall renders + supports restore
- ✅ Webhook state mapping covers every event the RC dashboard sends
- ✅ Plan + implementation reports documented

---

*End of Phase 1D implementation report.*
