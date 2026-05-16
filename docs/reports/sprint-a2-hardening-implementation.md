# Sprint A2 — Reliability + Analytics + Monetization Hardening — Implementation Report

**Status:** Complete. Ready to commit + push.
**Companion plan:** [`sprint-a2-hardening-plan.md`](sprint-a2-hardening-plan.md)
**Implemented on:** 2026-05-16

---

## Summary

Sprint A2 closes the remaining five P0 launch blockers identified in
the Phase 1 audit (`phase1-stabilization-plan.md`). Every change is a
hardening change — no new features, no architectural restructuring,
no new SDKs beyond the two listed in the plan.

| P0 | Item | Status |
|----|------|--------|
| P0.3 | Free-tier quota refund on AI failure | ✅ Shipped |
| P0.4 | Paywall ToS + Privacy URL handling | ✅ Shipped |
| P0.5 | Apple Sign-In production readiness | ✅ Shipped |
| P0.6 | PostHog integration + Phase 1 events | ✅ Shipped |
| P0.8 | AI provider budget operational safeguards | ✅ Documented (operational) |

After this sprint **all 9 P0 launch blockers from Phase 1 are
closed.** The app is feasible to submit to closed TestFlight beta.

---

## 1. P0.3 — Free-Tier Quota Refund

### What shipped

- **Migration** `supabase/migrations/20260516020000_analysis_refunds.sql`:
  - Append-only `analysis_refunds` audit table with RLS deny-all for
    `authenticated` (service-role-only audit storage)
  - `refund_free_analysis(p_user_id, p_request_id, p_reason)`
    `SECURITY DEFINER` RPC
  - Idempotency via `UNIQUE` constraint on `request_id`
  - Race-safety via `FOR UPDATE` lock on `users`
  - Counter clamped at 0 — refund at zero is a no-op decrement
  - Subscribers short-circuit (true return, no decrement)
  - `REVOKE … FROM PUBLIC/anon/authenticated; GRANT EXECUTE TO
    service_role`
- **pgTAP** `supabase/tests/refund_rpc.test.sql` — 21 assertions
  covering happy path, idempotency, distinct request_ids, counter
  clamp, subscriber short-circuit, reason CHECK violation, missing
  user, RLS denial, service-role-only EXECUTE
- **Edge function** `supabase/functions/analyze/index.ts`:
  - New `refundIfQuotaConsumed(userId, requestId, reason,
    emergencyMatched)` helper
  - `callAiService` wrapped in `try/catch` → refund with
    `'ai_failure'` on throw
  - `persistAnalysis` wrapped in `try/catch` → refund with
    `'persist_failure'` on throw
  - Emergency-override path short-circuits refund (no quota was
    consumed)
  - Refund failures never mask the original error
- **Regenerated** `supabase/functions/_shared/types/db.ts` so the
  `rpc('refund_free_analysis', …)` call compiles

### Why the design

`request_id` is the only stable handle that spans the consume-call →
refund-attempt. Putting `UNIQUE` on it gives us *exactly once*
semantics: retries (whether from the edge function's own catch arms
or from a future client-retry feature) never double-refund.

The audit row insert happens *before* the decrement to ensure that a
crash between the two leaves a refund record (operator-visible).

The subscriber short-circuit returns true (not false) so callers
treat "no quota was consumed" the same as "quota was refunded"; both
are "the slot is back".

---

## 2. P0.4 — Paywall ToS + Privacy URL Handling

### What shipped

- **`mobile/pubspec.yaml`** — promoted `url_launcher` from transitive
  to explicit (`^6.3.1`)
- **`mobile/lib/app/config.dart`** — `tosUrl` + `privacyUrl` fields
  with sensible defaults (`https://pawdoc.app/terms`,
  `https://pawdoc.app/privacy`), populated from `TOS_URL` +
  `PRIVACY_URL` dart-defines
- **`mobile/env/{dev,prod}.json.example`** — both URL keys added
- **`mobile/lib/features/paywall/paywall_screen.dart`** — new
  `_LegalLinks` widget with two `TextButton`s that call
  `launchUrl(uri, mode: LaunchMode.externalApplication)`; replaces
  the prior plain-text disclaimer line

Apple Guideline 3.1.2 + Google Play subscription disclosure both
require the ToS + Privacy Policy to be one tap from the paywall.
Before this change the paywall only mentioned them in body copy —
not link-tappable. Now it is.

---

## 3. P0.5 — Apple Sign-In Production Readiness

### What shipped

- **`mobile/lib/shared/services/apple_signin_service.dart`**:
  - Routed the `enabled` flag through `AppConfig.appleSignInEnabled`
    instead of reading `bool.fromEnvironment` inside the provider,
    so tests can override via `appConfigProvider`
  - New `_mapAuthException(AuthException)` helper that maps Supabase
    400-with-"provider … not enabled" to
    `AppleSignInError.notConfigured` (operator misconfiguration,
    not a user error). Other 4xx → `invalidResponse`; 5xx →
    `network`
  - `debugMapAuthException` exposed `@visibleForTesting` so the
    mapping has unit coverage
- **`mobile/lib/main.dart`** — info log at boot when
  `isProduction && appleSignInEnabled` confirming the Supabase OAuth
  provider must be configured (operator contract)
- **`mobile/test/apple_signin_service_test.dart`** — 5 new tests
  exercising the status-code/message → typed-error mapping
- **`docs/environment-setup.md` §14** — new step-by-step runbook
  covering Apple Developer Console capability, Services ID + private
  key creation, Supabase dashboard config, Doppler flag flip, and a
  "what the binary does when this isn't wired" failure-mode table

### What we deliberately did NOT do

- Build a Supabase Auth provider health-check endpoint (Supabase
  doesn't expose this in their public API)
- Auto-flip the button visibility based on a server check (would add
  a network call on every screen mount — wasteful)

These are explicitly listed as out-of-scope in the plan §3.3.

---

## 4. P0.6 — PostHog Integration + Phase 1 Events

### What shipped

- **`mobile/pubspec.yaml`** — `posthog_flutter ^4.10.1` added as a
  direct dependency
- **`mobile/lib/shared/services/analytics_events.dart`** — sealed
  `AnalyticsEvent` hierarchy with 13 concrete events covering the
  Phase 1 funnel:
  - `AuthCompletedEvent` (with `AuthMethod` enum: `email_otp` |
    `apple`)
  - `OnboardingStarted` / `OnboardingCompletedEvent`
  - `PetCreatedEvent`
  - `UploadStarted` / `UploadCompletedEvent`
  - `AnalysisRequested` / `AnalysisCompleted` / `AnalysisFailedEvent`
  - `EmergencyResultSeenEvent`
  - `PaywallSeenEvent`
  - `SubscriptionStartedEvent`
  - `RestorePurchaseEvent`
  - Exported `kAllAnalyticsEventSamples` for test enumeration
- **`mobile/lib/shared/services/analytics_service.dart`** —
  `AnalyticsService` interface with three implementations:
  - `PostHogAnalyticsService` — wraps the SDK; all failures silent
  - `NoopAnalyticsService` — used when `posthogApiKey.isEmpty` or
    after a failed initialise
  - `RecordingAnalyticsService` — `@visibleForTesting`, captures
    events in-memory for controller tests
  - `analyticsServiceProvider` falls back to Noop when no key
- **`mobile/lib/main.dart`** — analytics initialise during the
  bootstrapper's `addPostFrameCallback`; `identify(userId)` /
  `resetIdentity()` driven off the same auth-state listener that
  already manages RevenueCat + OneSignal
- **Controller wiring** — analytics emitted from controllers, never
  from widgets:
  - `auth_controller.dart` → `auth_completed` on OTP verify; new
    `notifyAuthCompleted(AuthMethod)` for the Apple Sign-In screen
    to call without coupling
  - `onboarding_controller.dart` → `onboarding_started` on first
    non-empty update, `onboarding_completed` on `clear()`. New
    `OnboardingDraft.isEmpty` getter to drive the "fire exactly
    once per draft" heuristic
  - `pets_controller.dart` → `pet_created` with `species` (a fixed
    enum, safe category)
  - `analysis_controller.dart` → `upload_started`,
    `upload_completed` (with duration), `analysis_requested`,
    `analysis_completed` (with triage_level, tier_used, latency_ms),
    `emergency_result_seen` (when triage is EMERGENCY), and
    `analysis_failed` (with kind) on every failure path
  - `paywall_controller.dart` → `paywall_seen` (with offering_id),
    `subscription_started` (with package_id) on purchase success,
    `restore_purchase` on restore success
- **`mobile/test/analytics_events_test.dart`** — privacy-contract
  tests: every event name is snake_case + unique; no property key
  matches a PII tabu word; property values are primitives or short
  category strings
- **`mobile/test/analytics_service_test.dart`** — Noop is silent,
  Recording captures everything in order, the provider falls back
  to Noop without a key and to PostHog with one

### Privacy contract

The `analytics_events_test.dart::privacy contract` group enumerates
every concrete event via `kAllAnalyticsEventSamples` and asserts no
property key contains any of:

```
email, phone, address, text_description, symptom, image, photo_data,
storage_key, pet_name, first_name, last_name, user_name, password,
token
```

Property values are restricted to primitives and category strings ≤
64 chars. Pet name is excluded (user-supplied). Species is included
(fixed enum). Email is excluded (PII). Pet age is excluded (could be
joined back to a user by inspection).

This guards against future regressions where a contributor might
casually add `email` or `text_description` to an event's properties.

---

## 5. P0.8 — AI Provider Budget Operational Safeguards

### What shipped

- **`docs/operational-runbook.md`** (new) — covers:
  - Anthropic Console spend-limit configuration ($50 soft / $200
    hard for Phase 1, $200/$1000 for Phase 2)
  - Google AI Studio + Cloud Billing budget configuration ($50 soft
    / $150 hard for Phase 1, with "Cap spending at limit" on the
    Cloud project)
  - OpenAI Phase 3 configuration (deferred until semantic cache
    lands)
  - 10× daily-spike anomaly threshold
  - Monthly verification checklist
  - Incident response playbook for a tripped hard cap
  - Pre-launch operational gate (all-boxes-ticked check)
- **`docs/environment-setup.md` §8** — short-form pointer into the
  runbook with the Phase 1 thresholds inline

This is an **operational deliverable** — the founder must actually
log in to Anthropic / Google AI dashboards and configure the caps.
The documentation gives a step-by-step + a verification cadence so
the configuration doesn't drift.

### Engineering side (deferred)

Token-usage telemetry in the orchestrator's `analyze_completed` log
is captured in `phase1-technical-debt.md` for Phase 2. Sprint A2's
scope discipline excluded it.

---

## 6. Validation Results

| Surface | Tool | Result |
|---------|------|--------|
| Edge function TypeScript | `deno check analyze/index.ts` | ✅ pass |
| Mobile static analysis | `flutter analyze` | ✅ no issues |
| Mobile tests | `flutter test` | ✅ 106/106 pass |
| pgTAP database tests | `supabase test db --local` | ✅ 69/69 pass (across 2 files) |

The 69 pgTAP tests include the 21 new ones in `refund_rpc.test.sql`.

---

## 7. What's Next

With Sprint A2 closed, the Phase 1 launch blocker list is empty.
Next priorities are:

1. **Operational (founder)** — actually configure the spend caps per
   the runbook before the first TestFlight build
2. **Pre-submission** — work through `app-store-metadata.md`'s
   compliance checklist; capture screenshots
3. **Phase 2** — the work captured in
   [`phase1-technical-debt.md`](phase1-technical-debt.md), starting
   with token-usage telemetry now that PostHog + budgets are in place
