# Sprint A2 — Reliability + Analytics + Monetization Hardening — PLAN

**Sprint:** A2 (second of three sprints in the Phase 1 stabilization plan)
**Date:** 2026-05-16
**Reference audit:** [`phase1-stabilization-plan.md`](phase1-stabilization-plan.md) §P0
**Scope:** Closes the 5 remaining P0 launch-blockers after Sprint A1:
P0.3 (quota refund), P0.4 (paywall legal URLs), P0.5 (Apple Sign-In
prod readiness), P0.6 (PostHog), P0.8 (provider budget caps)

After this sprint, all 9 P0 launch-blockers should be closed and the
app should be feasible to submit to closed-TestFlight beta.

This is a **reliability / observability / monetization-hardening**
sprint. No feature expansion. No architectural redesign. Every change
plugs into seams that Phases 0-1D already established.

---

## 1. P0.3 — Free-Tier Quota Refund

### 1.1 Problem (recap from audit)

The edge function `/analyze` consumes a free-tier quota slot BEFORE
the AI service call. If anything between that consume and the user
seeing a result fails (AI timeout, AI 5xx after retries, persistence
error, Fly.io worker restart), the slot is irrevocably gone. Free-tier
users lose paid-for analyses on transient failures.

### 1.2 Solution architecture

A small append-only audit table + an atomic SQL RPC, called from the
edge function's catch arms.

```
Edge function /analyze flow with refund:

  1. CORS preflight / method gate / JWT / body validate / ownership
     check / emergency keyword scan         (unchanged)
  2. If NOT emergency: consume free-tier RPC  (Phase 1A)
  3. Load pet context (service-role read)
  4. try {
       result = await callAiService(...)
     } catch (err) {
       if (!emergency.matched) await refund(user.id, requestId, 'ai_failure')
       throw err
     }
  5. try {
       analysisId = await persistAnalysis(result)
     } catch (err) {
       if (!emergency.matched) await refund(user.id, requestId, 'persist_failure')
       throw err
     }
  6. Return success.
```

EMERGENCY paths don't consume quota in the first place (the keyword
match short-circuits both rate-limit and quota gates), so no refund
is ever needed for them.

### 1.3 Schema

New migration `<ts>_analysis_refunds.sql`:

```sql
CREATE TABLE analysis_refunds (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  request_id   text NOT NULL UNIQUE,            -- idempotency key
  reason       text NOT NULL,                   -- ai_failure | persist_failure | timeout | admin
  refunded_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT analysis_refunds_reason_check
    CHECK (reason IN ('ai_failure', 'persist_failure', 'timeout', 'admin'))
);

CREATE INDEX idx_analysis_refunds_user_created ON analysis_refunds(user_id, refunded_at DESC);
ALTER TABLE analysis_refunds ENABLE ROW LEVEL SECURITY;

-- Users cannot read or write. Service role bypasses RLS.
CREATE POLICY analysis_refunds_select_deny ON analysis_refunds FOR SELECT TO authenticated USING (false);
CREATE POLICY analysis_refunds_insert_deny ON analysis_refunds FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY analysis_refunds_update_deny ON analysis_refunds FOR UPDATE TO authenticated USING (false);
CREATE POLICY analysis_refunds_delete_deny ON analysis_refunds FOR DELETE TO authenticated USING (false);
```

The RPC:

```sql
CREATE OR REPLACE FUNCTION refund_free_analysis(
  p_user_id    uuid,
  p_request_id text,
  p_reason     text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status text;
  v_used   int;
BEGIN
  -- Audit insert (UNIQUE on request_id provides idempotency).
  BEGIN
    INSERT INTO analysis_refunds (user_id, request_id, reason)
    VALUES (p_user_id, p_request_id, p_reason);
  EXCEPTION WHEN unique_violation THEN
    -- Already refunded this request; idempotent no-op.
    RETURN false;
  END;

  -- Lock the user row + decrement only if there's something to refund.
  SELECT subscription_status, free_analyses_used_this_month
    INTO v_status, v_used
    FROM users
   WHERE id = p_user_id
     FOR UPDATE;
  IF NOT FOUND THEN
    RETURN false;  -- defensive; user should always exist
  END IF;

  -- Subscribers never consumed quota in the first place — no refund needed.
  -- Free users with v_used = 0 also have nothing to refund.
  IF v_status = 'free' AND v_used > 0 THEN
    UPDATE users
       SET free_analyses_used_this_month = v_used - 1
     WHERE id = p_user_id;
  END IF;
  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION refund_free_analysis(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION refund_free_analysis(uuid, text, text) FROM anon;
REVOKE ALL ON FUNCTION refund_free_analysis(uuid, text, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION refund_free_analysis(uuid, text, text) TO service_role;
```

Key properties:
- **Atomic** — `FOR UPDATE` lock prevents concurrent refunds racing on
  the same user row.
- **Idempotent** — the `request_id` UNIQUE constraint means even if the
  edge function's catch arm runs twice on the same request, the
  counter only decrements once.
- **Append-only audit** — `analysis_refunds` is RLS-denied to users;
  service role only. No way for a malicious user to insert/delete a
  refund record.
- **No double refund** — even if both the AI-failure catch AND
  persist-failure catch somehow run for the same request_id, the
  second's INSERT fails with unique_violation and returns false.
- **No client authority** — the function is service-role only; the
  mobile cannot call it directly.

### 1.4 Edge function integration

`supabase/functions/analyze/index.ts`:

```typescript
// helper
async function refundIfQuotaConsumed(
  userId: string,
  requestId: string,
  reason: 'ai_failure' | 'persist_failure' | 'timeout',
  emergencyMatched: boolean,
): Promise<void> {
  if (emergencyMatched) return;
  try {
    await supabaseAdmin().rpc('refund_free_analysis', {
      p_user_id: userId,
      p_request_id: requestId,
      p_reason: reason,
    });
    log.info('quota_refunded', { request_id: requestId, reason });
  } catch (err) {
    // Best-effort refund. Don't let a refund failure mask the
    // original error.
    log.error('refund_failed', {
      request_id: requestId,
      reason,
      error: (err as Error).message,
    });
  }
}
```

Wrap the AI call + persist call:

```typescript
let result: AiServiceResult;
try {
  result = await callAiService(aiRequest);
} catch (err) {
  await refundIfQuotaConsumed(user.id, requestId, 'ai_failure', emergency.matched);
  throw err;
}

let analysisId: string;
try {
  analysisId = await persistAnalysis({...});
} catch (err) {
  await refundIfQuotaConsumed(user.id, requestId, 'persist_failure', emergency.matched);
  throw err;
}
```

### 1.5 Tests

- **pgTAP** — new `supabase/tests/refund.test.sql`:
  - Refund decrements the counter
  - Double-call with same request_id is a no-op (returns false)
  - Subscriber call returns true but doesn't decrement
  - Refund at counter=0 doesn't go negative
  - RLS: authenticated user cannot SELECT/INSERT/UPDATE/DELETE
- **Edge function** — Deno tests for the new helper's behaviour with a
  mocked Supabase admin client

### 1.6 What we deliberately do NOT do

- **No client-side trigger.** Mobile never calls refund directly.
- **No batch refund.** Each refund is per-request; no admin endpoint
  to mass-refund.
- **No refund on successful analyses.** Edge function only calls
  refund in catch arms.
- **No refund history shown in app.** That's Phase 3 health-history
  scope; for now it's pure audit infrastructure.

---

## 2. P0.4 — Paywall Legal URLs

### 2.1 Problem (recap)

App Store Guideline 3.1.2 requires that subscription paywalls expose
direct links to the app's Terms of Service and Privacy Policy. Our
paywall mentions both as plain text in the footer, but no links are
clickable. Submission would be rejected.

### 2.2 Solution

Two `TextButton.onPressed` widgets at the bottom of the paywall, each
calling `launchUrl(Uri.parse(...))`. URLs are configured via env so we
can change the destination without a rebuild.

### 2.3 Env knobs

```dart
final String tosUrl;          // defaults to 'https://pawdoc.app/terms'
final String privacyUrl;      // defaults to 'https://pawdoc.app/privacy'
```

Both have sensible defaults so dev builds don't hit empty URLs. The
defaults point at the canonical domain we're going to publish at
(operational deliverable; A2 doesn't publish the static pages, but the
URLs are wired so when they go live, the app picks them up).

### 2.4 url_launcher status

`url_launcher` is in `pubspec.lock` as a transitive dep but not in
`pubspec.yaml`. Sprint A2 promotes it to a direct dependency.

### 2.5 Graceful failures

`launchUrl` can fail if (a) the URL is malformed, (b) no browser is
installed (rare on iOS, possible on Android lite), (c) the URL is
unreachable (DNS issue). The mobile catches the failure, logs it, and
shows a SnackBar with the URL as text so the user can copy + paste.

### 2.6 Disclosure copy review

Current paywall footer (Phase 1D):
> "Your subscription renews automatically and can be cancelled in your
> App Store / Play Store settings. Privacy Policy and Terms of Service
> are available at pawdoc.app."

Updated copy:
> "Your subscription renews automatically and can be cancelled in your
> Apple ID / Google Play subscription settings."
>
> [Terms of Service]  [Privacy Policy]

The "available at pawdoc.app" filler is replaced by the two real
links. Cancellation phrasing matches the canonical store wording
("Apple ID subscription settings", "Google Play subscription
settings") rather than the looser "App Store / Play Store settings."

### 2.7 RevenueCat restore flow review

`Restore purchases` already on the paywall; copy unchanged. Restore
wording is Apple-acceptable as-is.

---

## 3. P0.5 — Apple Sign-In Production Readiness

### 3.1 Problem (recap)

Sprint A1 left the Apple Sign-In button gated behind
`APPLE_SIGN_IN_ENABLED` (defaults false in dev). For prod:
- Must set the env to true
- Must configure the OAuth provider in Supabase Auth dashboard
- Must add Apple Developer "Sign In with Apple" capability

The mobile binary's behaviour when any of these is missing should
fail gracefully — not crash, not block other auth paths.

### 3.2 Solution

#### 3.2.1 Stronger startup warnings

`AppConfig.validate()` already warns in prod when `appleSignInEnabled
== false`. Sprint A2 adds:
- When `appleSignInEnabled == true` in prod, also log a startup info
  message acknowledging the contract: "Apple Sign-In enabled; Supabase
  provider must be configured."

#### 3.2.2 Friendly runtime fallback

`AppleSignInError.notConfigured` already exists. Sprint A2 expands its
trigger surface:
- If `signInWithIdToken` returns 400 from Supabase (typical when
  provider not configured server-side), map to `notConfigured`.
- User sees: "Apple Sign-In is not configured for this build. Please
  use email instead." (existing copy).

#### 3.2.3 Operational documentation

`docs/environment-setup.md` extension: a step-by-step "Apple Sign-In
configuration" runbook covering:
1. Apple Developer Console → Certificates / Identifiers → enable Sign
   In with Apple capability for the app id
2. Create a Services ID + private key
3. Supabase Dashboard → Authentication → Providers → Apple → paste
   the Services ID, Team ID, Key ID, and private key
4. Add Apple's authorised redirect URI to the Supabase Auth Site URL
5. Set `APPLE_SIGN_IN_ENABLED=true` in Doppler prod config
6. Verify with a sandbox iOS device

### 3.3 What we deliberately do NOT do

- Build a Supabase Auth provider health-check endpoint (out of scope;
  Supabase doesn't expose this in their public API).
- Auto-flip the button visibility based on a server check (would add
  a network call on every screen mount — wasteful).

---

## 4. P0.6 — PostHog Integration

### 4.1 Problem (recap)

Roadmap §10 Phase 1 lists nine PostHog events that should fire from
the mobile. Today, `posthogApiKey` exists in `AppConfig` but the SDK
is not installed and no event emission code exists. Launching without
analytics means flying blind on funnel + retention.

### 4.2 Solution architecture

```
                            ┌─────────────────────┐
       analytics events ──→ │ AnalyticsService    │ ──→ PostHog SDK
       from controllers     │ (interface)         │ ──→ NoopAnalyticsService (when DSN empty)
                            └─────────────────────┘
```

Two key disciplines:
1. **All event emission lives in controllers, never in widgets.**
   Widgets render state; controllers represent user intent. The
   analytics events represent intent.
2. **PII is stripped at the service boundary.** Never send email, raw
   pet image bytes, raw text_description, or any other PII to
   PostHog.

### 4.3 SDK choice

`posthog_flutter` v4.x. Industry-standard PostHog client. Has its
own privacy manifest. Wraps both iOS + Android natively.

### 4.4 Type-safe event registry

A sealed-class hierarchy in `mobile/lib/shared/services/analytics_events.dart`:

```dart
sealed class AnalyticsEvent {
  const AnalyticsEvent();
  String get name;
  Map<String, Object?> get properties => const {};
}

class AuthCompletedEvent extends AnalyticsEvent {
  const AuthCompletedEvent({required this.method});
  final String method;  // 'email_otp' | 'apple'
  @override String get name => 'auth_completed';
  @override Map<String, Object?> get properties => {'method': method};
}

class OnboardingStartedEvent extends AnalyticsEvent { ... }
class OnboardingCompletedEvent extends AnalyticsEvent { ... }
class PetCreatedEvent extends AnalyticsEvent { ... }
class UploadStartedEvent extends AnalyticsEvent { ... }
class UploadCompletedEvent extends AnalyticsEvent { ... }
class AnalysisRequestedEvent extends AnalyticsEvent { ... }
class AnalysisCompletedEvent extends AnalyticsEvent { ... }
class AnalysisFailedEvent extends AnalyticsEvent { ... }
class EmergencyResultSeenEvent extends AnalyticsEvent { ... }
class PaywallSeenEvent extends AnalyticsEvent { ... }
class SubscriptionStartedEvent extends AnalyticsEvent { ... }
class RestorePurchaseEvent extends AnalyticsEvent { ... }
```

Benefits:
- IDE autocomplete for every event
- Compile-time safety against typos in event names
- Single place to audit "do these properties leak PII"
- Easy unit tests for property contracts

### 4.5 Privacy contract

Each event's `properties` map MUST contain only:
- Enumerated values (`triage_level`, `tier_used`, `purchase_outcome`)
- Counts or durations (`ai_latency_ms`, `attempts`)
- Boolean flags
- Free-text only when it represents a category, never a user-supplied
  string (e.g., breed is a category-like string; we'll include it.
  Pet name is a user-supplied string; we will NOT include it.)

Strictly excluded:
- Email
- Pet name
- Raw text_description / symptom text
- Raw image bytes
- Raw error messages from upstream providers
- Storage keys (could leak file path information)

A unit test enumerates every event type and asserts no property name
matches a PII-flag list (`['email', 'text_description', 'image',
'storage_key', 'name']`).

### 4.6 Service interface

```dart
abstract class AnalyticsService {
  Future<void> initialize();
  Future<void> identify(String userId);
  Future<void> resetIdentity();
  Future<void> track(AnalyticsEvent event);
}
```

Implementations:
- `PostHogAnalyticsService` — wraps `Posthog()` SDK
- `NoopAnalyticsService` — used when `posthogApiKey.isEmpty` or in
  unit tests
- `RecordingAnalyticsService` (test-only) — captures events for
  assertion

### 4.7 Lifecycle

```
main.dart:
  - construct AnalyticsService based on config.hasPosthog
  - await analytics.initialize()
  - exposed via Riverpod
auth controller:
  - on successful sign-in → analytics.identify(user.id) +
    track(AuthCompletedEvent(method: 'email_otp' | 'apple'))
  - on sign-out → analytics.resetIdentity()
```

### 4.8 Event call-site map

| Event | Emitter | When |
|-------|---------|------|
| `auth_completed` | AuthController.verifyOtp + apple sign-in path | On successful sign-in |
| `onboarding_started` | OnboardingController on first `update()` | Heuristic — saved to a one-shot flag |
| `onboarding_completed` | OnboardingController on `clear()` after successful submit | After save success |
| `pet_created` | PetsController.create | After insert success |
| `upload_started` | AnalysisController.submit | At Uploading state |
| `upload_completed` | AnalysisController.submit | After upload success |
| `analysis_requested` | AnalysisController.submit | At Analysing state |
| `analysis_completed` | AnalysisController.submit | After AnalysisSuccess |
| `analysis_failed` | AnalysisController.submit | After AnalysisFailedState |
| `emergency_result_seen` | AnalysisController.submit | After AnalysisSuccess with EMERGENCY triage_level |
| `paywall_seen` | PaywallController._load | On PaywallReady state |
| `subscription_started` | PaywallController.purchase | On PaywallSucceeded |
| `restore_purchase` | PaywallController.restore | On PaywallSucceeded |

### 4.9 Failure handling

Analytics calls must never block the UX:
- `track(...)` is fire-and-forget — `unawaited(analytics.track(...))`
- The PostHog SDK already swallows network errors and queues
  in-memory. Even if the call fails inside the SDK, the user
  experience is unaffected.
- A `try/catch` around the SDK init protects the boot path. If init
  throws, we log to Sentry and continue with NoopAnalyticsService.

### 4.10 Environment-aware disable

- `kDebugMode` → keep PostHog initialised but use the local dev
  config (or disable). Default: initialise normally.
- Empty `POSTHOG_API_KEY` → use `NoopAnalyticsService`. Local dev
  flow.
- In CI / unit tests → override the provider with
  `NoopAnalyticsService` or `RecordingAnalyticsService`.

---

## 5. P0.8 — AI Provider Budget Safeguards

### 5.1 Problem (recap)

The audit found no operational budget caps on Anthropic + Google AI
spend. A compromised account or runaway loop could spike the bill
before we notice.

### 5.2 Solution

**Operational, not engineering.** The plan ships:
- A new `docs/operational-runbook.md` documenting:
  - Anthropic Console → Settings → Spend Limits configuration
  - Google AI Studio → API Keys → budget alerts
  - OpenAI Console → Usage → budget alerts (Phase 3 semantic cache)
  - Recommended thresholds:
    - Anthropic monthly: $50 soft / $200 hard during Phase 1
    - Google AI monthly: $50 soft
    - Daily-call anomaly threshold: 10× the rolling 7-day average
  - Manual monthly review cadence
- Update `docs/environment-setup.md` with a pre-launch checklist
  including the budget caps as a P0 step (already alluded to; this
  sprint formalises it)

### 5.3 Lightweight engineering safeguard

The Phase 1B audit flagged "AI cost telemetry absent" as O-3.
Sprint A2 adds **token-count logging** in the orchestrator's
`analyze_completed` log line:
- Both Gemini and Claude API responses include token usage
- The provider clients can return this; the orchestrator logs it
- A future Sentry/PostHog dashboard can sum it for cost estimation

For Sprint A2 scope discipline, this is optional and gated on time —
the full implementation is captured in
[`phase1-technical-debt.md`](phase1-technical-debt.md) as deferred to
Phase 2.

---

## 6. Files Added / Modified

### Added

```
supabase/migrations/<ts>_analysis_refunds.sql            new table + RPC
supabase/tests/refund.test.sql                            pgTAP coverage
mobile/lib/shared/services/analytics_service.dart         interface + impls
mobile/lib/shared/services/analytics_events.dart          typed event hierarchy
mobile/test/analytics_service_test.dart                   service + privacy contract
mobile/test/analytics_events_test.dart                    event property privacy
docs/operational-runbook.md                               budget + alert runbook
docs/reports/sprint-a2-hardening-plan.md                  (this file)
docs/reports/sprint-a2-hardening-implementation.md        (post-impl)
```

### Modified

```
mobile/pubspec.yaml                                       + posthog_flutter, url_launcher (promote)
mobile/lib/app/config.dart                                + tosUrl, privacyUrl
mobile/lib/main.dart                                      + analytics init
mobile/lib/features/paywall/paywall_screen.dart           ToS + Privacy URL links
mobile/lib/features/paywall/paywall_controller.dart       emit paywall_seen + subscription_started + restore_purchase
mobile/lib/features/auth/auth_controller.dart             emit auth_completed
mobile/lib/features/onboarding/onboarding_controller.dart emit onboarding_started + onboarding_completed
mobile/lib/features/pets/pets_controller.dart             emit pet_created
mobile/lib/features/analysis/analysis_controller.dart     emit upload/analysis events
mobile/lib/shared/services/apple_signin_service.dart      improve notConfigured detection
mobile/env/dev.json.example                               + TOS_URL, PRIVACY_URL
mobile/env/prod.json.example                              + TOS_URL, PRIVACY_URL
supabase/functions/analyze/index.ts                       call refund on AI/persist failure
docs/environment-setup.md                                 + Apple Sign-In + budget runbook lines
```

### Not Touched

Phase 0/1A/1B/1C/1D core artifacts: existing migrations, RLS policies,
orchestrator routing logic, schema, edge function auth, AI provider
clients.

---

## 7. Validation Plan

| Check | Target |
|-------|--------|
| `flutter analyze --fatal-infos --fatal-warnings` | 0 issues |
| `flutter test` | new analytics tests + all existing pass |
| `make lint && make test` | Phase 0/1A/1B/1C/1D gates intact |
| `supabase test db` | 48 prior pgTAP tests + new refund tests |
| `deno fmt/lint/check/test` in `supabase/functions/` | all green |
| ai-service `pytest` | 110/110 unchanged |
| End-to-end refund: simulate AI failure in edge function tests → verify counter decremented |
| Idempotency: same request_id refunds once, not twice |
| Subscriber refund: returns true, counter unchanged |
| Analytics no-op when `posthogApiKey.isEmpty` |
| Analytics events strip PII (unit-tested) |
| Paywall URLs launch (manually verified; widget test asserts buttons present) |

---

## 8. Production-Readiness Impact

After Sprint A2 ships, the launch readiness checklist looks like:

| P0 item | Status |
|---------|--------|
| P0.1 iOS permission strings | ✅ Sprint A1 |
| P0.2 PrivacyInfo.xcprivacy | ✅ Sprint A1 |
| P0.3 Free-tier quota refund | ✅ Sprint A2 |
| P0.4 Paywall ToS/Privacy links | ✅ Sprint A2 (URLs need to go live) |
| P0.5 Apple Sign-In prod readiness | ✅ Sprint A2 (engineering); operational follow-up |
| P0.6 PostHog | ✅ Sprint A2 |
| P0.7 Medical-claim audit | ✅ Sprint A1 |
| P0.8 Provider budget caps | ⚠️ Documented in Sprint A2; **operational deliverable** (cannot be done from code) |
| P0.9 ATT requirement audit | ✅ Sprint A1 |

The remaining operational steps before submission:
1. Publish ToS + Privacy at `pawdoc.app/terms` and `/privacy`
2. Configure Supabase Auth Apple OAuth provider
3. Set `APPLE_SIGN_IN_ENABLED=true` in prod Doppler config
4. Set Anthropic + Google AI budget caps
5. Provision Doppler workspace (Phase 0 deliverable still open)
6. Set up Sentry crash-rate alert → Slack
7. App Store Connect submission (Phase 2)

The engineering side is **done after Sprint A2**.

---

## 9. Definition of Done

- All P0 audit findings closed (engineering work) OR documented as
  operational (P0.8 budget caps + parts of P0.4/P0.5)
- Refund flow handles AI failure, persist failure, idempotency, and
  subscriber short-circuit
- PostHog SDK initialises gracefully (no-op when key absent)
- Every Phase 1 funnel event has a typed class + emission point
- PII contract tested
- Paywall renders both legal URL links
- Apple Sign-In behaviour reviewed; documented for prod operators
- Provider budget runbook committed
- Plan + implementation reports committed

---

*End of Sprint A2 plan. Implementation follows.*
