# Sprint B3 — Operational Resilience + Performance Hardening — Plan

**Status:** Plan. Implementation tracked in
[`sprint-b3-ops-implementation.md`](sprint-b3-ops-implementation.md)
once shipped.
**Owner:** Founder.
**Companion audits:**
- [`phase1-full-audit.md`](phase1-full-audit.md) H-9, H-10, M-10, O-1, O-3, O-4, R-12, R-13, R-14, R-15, R-16, R-26, R-28
- [`phase1-production-risks.md`](phase1-production-risks.md) R-2, R-3, R-4, R-22, R-27
- [`sprint-b1-reliability-implementation.md`](sprint-b1-reliability-implementation.md) §5
- [`sprint-b2-abuse-implementation.md`](sprint-b2-abuse-implementation.md) §5

---

## 0. Charter

Sprint B3 readies PawDoc for **real TestFlight users on real
networks with real provider hiccups**. It is the last sprint
before the closed-beta cut. The objective is operational
**legibility** — when something goes wrong in production, we
should:

1. **See it** (structured logs, alert-friendly event names).
2. **Survive it** (graceful degradation, calm UX, no wedged
   spinners).
3. **Recover from it** (startup validation, rollback rehearsal,
   runbook coverage).

**Non-goals**:

- Speculative scaling systems (autoscaling tuning, Redis sharding,
  multi-region failover).
- New ML systems / vision moderators (Phase 2).
- Compression isolate rewrite — `compute()`-based offload of
  `flutter_image_compress` is explicitly deferred to Phase 2
  (`P1.15`). We do ship a small OOM-safe wrapper today that maps
  a compression crash to a friendly failure kind.
- New monitoring SaaS. Sentry + Better Uptime + provider
  dashboards are the stack; we make them work properly.

---

## 1. Discovered operational risks → fixes

Each item carries an F-code for the implementation report.

### F-OPS1 — Rate-limit fail-open mode is invisible in dashboards

**Source:** audit O-4.

`getDailyLimiter()` chooses Upstash or in-memory based on env. On
an Upstash 5xx / network error, the Upstash path falls open and
emits a `rate_limit_upstash_error` / `rate_limit_upstash_5xx`
warn — but the **happy-path** `rate_limit_check` log doesn't
distinguish between Upstash-allowed, in-memory-allowed, or
fail-open-allowed. The operator can't easily count "we are
running with the soft cap disabled."

**Fix (B3.1):** add a `mode: 'upstash' | 'inmemory' |
'upstash_failopen'` field to the limiter result + the
`rate_limit_check` log. Emit a dedicated WARN-level
`rate_limit_failopen` event so a single Sentry alert rule covers
both Upstash error modes.

### F-OPS2 — AI service config drift is silent (H-9)

**Source:** audit H-9.

`Settings` fields are all `Optional` so the process boots even
without `INTERNAL_API_TOKEN`, `ANTHROPIC_API_KEY`, `GOOGLE_AI_API_KEY`,
or the Supabase keys. Today the first request returns 503 or
401; the operator finds out late.

**Fix (B3.2):** Pydantic `@model_validator(mode="after")` that
raises `ValueError` when `app_env == PROD` and any of the
required-for-prod secrets is unset. The process refuses to start
with a clear log line listing every missing key.

### F-OPS3 — No readiness probe distinct from liveness (R-13/R-28)

**Source:** new (inferred from R-13 + R-28 commentary).

`/health` is wired as Fly.io's liveness probe — and **must stay
that way** (no upstream dependency in liveness, or a transient
Anthropic outage takes the service "unhealthy"). But there's no
endpoint for Better Uptime / synthetic monitors to distinguish "is
this process configured well enough to serve" from "is it alive."

**Fix (B3.3):** new `/ready` endpoint that returns:
- `200` with `{status: "ready", checks: {...}}` when every
  configured-for-this-env secret is present
- `503` with `{status: "degraded", missing: [...]}` when one or
  more are missing

No outbound calls — the endpoint only inspects in-process config.
External monitors can poll without contributing to provider
spend.

### F-OPS4 — AI tone consistency lives in 3 files (R-2/R-4/R-22)

**Source:** audit R-2, R-4, R-22 + Sprint A1 compliance posture.

User-facing copy from the AI service is scattered:

- `services/safety.py` — emergency override copy
- `services/orchestrator.py` — graceful degradation hard-coded
- `models/schemas.py` — Pydantic default disclaimer

This makes a single App Store review pass harder than it should
be. Also: no test asserts the tone invariants (no
"diagnosis" / "treatment" / "cure" / "guaranteed" in any user-
visible string).

**Fix (B3.4):** new `ai-service/app/services/copy.py` exports
typed constants + factory functions. The orchestrator and safety
layer import from there. A new test enumerates every exported
copy string and asserts the tone invariants. Two App Store
review failures away from launch becomes one grep away.

### F-OPS5 — Sentry breadcrumb helper has zero callers (H-10 / O-1)

**Source:** audit H-10, O-1.

`sentryBreadcrumb(...)` exists in
`mobile/lib/shared/services/sentry_service.dart` but no production
code calls it. When a crash actually ships, Sentry sees the stack
trace but no journey-level breadcrumbs to explain "what was the
user doing."

**Fix (B3.5):** wire breadcrumbs at the high-value checkpoints
listed in the audit:
- `analyze_submit` (`AnalysisController.submit` entry)
- `analyze_failed` (each failure branch)
- `paywall_shown` (paywall controller transitions to Ready)
- `purchase_complete` (paywall purchase success / restore success)
- `auth_completed` (auth controller / Apple Sign-In)

Payloads are privacy-safe (typed `kind` enums, durations, IDs —
no email, no symptom text, no pet name).

### F-OPS6 — Compression OOM is unhandled (R-16 partial)

**Source:** audit R-16, P-1.

`flutter_image_compress.compressWithList` can throw / return
empty on 256 MB Android. Today the iterative downscale loop runs
`compressWithList` inside an unguarded `await`. An `OutOfMemoryError`
or a sentinel empty-bytes result bubbles up as a generic
exception, mapping to `AnalyzeFailureKind.unknown` (= "Something
went wrong").

**Fix (B3.6):** wrap each `compressWithList` call in `try/catch`;
on either exception or empty-byte result, throw a typed
`ImagePickFailure(unsupportedFormat | compressionFailed)`. The
full `compute()`-isolate rewrite stays deferred to Phase 2; this
is the safety net for the existing main-isolate path.

### F-OPS7 — Provider-degradation tests are thin (L-5, B1 §5)

**Source:** audit L-5.

The orchestrator's degradation behaviour is documented in the
plan but not pinned by tests. A future refactor that breaks "Tier
3 fails → graceful degradation" wouldn't fail CI.

**Fix (B3.7):** add chaos-style tests to
`tests/test_orchestrator.py`:
- Tier 2 transport fail → falls through to Tier 3
- Tier 3 transport fail → returns graceful degradation
- Both fail → graceful degradation
- Cross-verify fail with first call EMERGENCY → keeps EMERGENCY
  with `cross_verify_disagreement=False` (audit-flagged behaviour
  H-7)
- Below `insufficient_confidence_floor` → graceful degradation

### F-OPS8 — Disclaimer-visibility test is too lax (R-2)

**Source:** production-risks R-2.

`result_screen_widget_test::disclaimer text always renders` uses
`find.textContaining`. A future UI change that wraps the
disclaimer in a `SizedBox(height: 0)` or a collapsed `Visibility`
widget would still pass.

**Fix (B3.8):** tighten the assertion to also verify the rendered
size of the disclaimer text is non-zero on every triage variant.

### F-OPS9 — Operational runbook missing provider-outage triage

**Source:** new (Sprint B1/B2 added cost-cap + cleanup sections;
provider-outage triage is the missing page).

When the operator sees `tier2_failed_escalating_to_tier3` flood
the logs, what do they do? When Upstash returns 503 for an hour,
what do they check? The current runbook covers spend caps + orphan
cleanup; no playbook for "Anthropic returns 529 for 10 min."

**Fix (B3.9):** new section in `docs/operational-runbook.md`:
- Per-provider outage triage steps (Anthropic, Google AI,
  Upstash, Supabase Storage)
- `/ready` semantics for Better Uptime
- Sentry alert routing recipe
- Rollback rehearsal command

---

## 2. Out of scope (named landing zones)

| Item | Deferred to | Reason |
|------|-------------|--------|
| `compute()`-isolate compression rewrite | Phase 2 / `P1.15` | Feature-shaped (UI rewiring); B3 ships the OOM-safe wrapper |
| Better Uptime / Sentry alert wiring (the live HTTP calls + Slack hooks) | Operational, runbook-only | Founder configures in the dashboards; no engineering deliverable |
| Sentry `tracesSampleRate` per-route tuning | Phase 2 | Needs production traffic to size; B3 only documents the lever |
| Edge function E2E integration test | Phase 2 / `L-5` | Needs a Deno test runner; outside this sprint's scope |
| Sentry quota alert | Operational | Configured in Sentry dashboard, not code |
| Provider org-level budget caps (R-12) | Operational, A2 runbook | Already documented |
| Webhook idempotency table (M-4) | Phase 2 / `P2.9` | Already deferred |
| Word-boundary refinement on emergency keywords (R-3) | Phase 2 / `P2.6` | Cross-mirror with edge function emergency.ts adds complexity; substring match is acceptable for safety direction |
| OneSignal ATT verification (R-23) | Operational | Manual device testing |
| Cold-start frequency monitoring | Phase 2 | Needs prod traffic + a dashboard |

---

## 3. Files added / modified

### Added

```
ai-service/app/services/copy.py                            new — centralised user-facing strings
docs/reports/sprint-b3-ops-plan.md                         (this file)
docs/reports/sprint-b3-ops-implementation.md               (post-impl)
```

### Modified

```
ai-service/app/core/config.py                              + prod startup validator
ai-service/app/routers/health.py                           + /ready endpoint
ai-service/app/services/safety.py                          read copy from copy.py
ai-service/app/services/orchestrator.py                    read copy from copy.py
ai-service/tests/test_orchestrator.py                      + chaos tests
ai-service/tests/test_health.py                            + /ready tests
ai-service/tests/test_config.py                            + startup validator tests
ai-service/tests/test_safety.py                            tone-invariants tests
mobile/lib/shared/services/image_service.dart              + OOM-safe wrapper + compressionFailed kind
mobile/lib/features/analysis/analysis_controller.dart      breadcrumb wires
mobile/lib/features/auth/auth_controller.dart              breadcrumb on auth_completed
mobile/lib/features/auth/auth_screen.dart                  breadcrumb on apple_signin
mobile/lib/features/paywall/paywall_controller.dart        breadcrumbs at paywall_shown / purchase_complete
mobile/test/result_screen_widget_test.dart                 disclaimer non-zero-height assertion
mobile/test/image_service_test.dart                        compressionFailed coverage
supabase/functions/_shared/rate-limit.ts                   + mode tagging + failopen event
supabase/functions/_shared/rate-limit.test.ts              mode-tagging tests
docs/operational-runbook.md                                + provider outage triage + Better Uptime
```

---

## 4. Validation checklist

Before commit:

- [ ] `flutter analyze` clean
- [ ] `flutter test` 100% pass (existing 141 + new B3 cases)
- [ ] `supabase test db --local` 100% pass (no SQL change; regression sanity)
- [ ] `cd supabase/functions && deno test _shared/rate-limit.test.ts` (where present)
- [ ] `deno check analyze/index.ts` clean
- [ ] `cd ai-service && uv run pytest` 100% pass + ≥ 90% coverage
- [ ] Manual smoke: start the AI service with no env → process refuses
      to boot with a clear "missing required keys" log
- [ ] Manual smoke: `/health` returns 200; `/ready` returns 200 in
      local (all keys present) and 503 when an env var is unset

---

## 5. Definition of done

- Every F-code in §1 has a corresponding implementation +
  test(s) + a one-line summary in the report.
- The operational runbook contains a provider-outage triage
  section that lists the exact log signatures to look for and
  the exact mitigation step for each.
- App Store tone-invariant tests fail when "diagnosis",
  "treatment", "cure", or "guaranteed" appears in any centralised
  copy string.
- A clean `make test` / `flutter test` / `pytest` / `deno check`
  pass on a fresh checkout.
- The TestFlight readiness section of the implementation report
  honestly enumerates the remaining manual gates (App Store
  metadata, screenshots, Apple Sign-In dashboard, RevenueCat
  sandbox verification) — nothing handwaved as done that isn't.
