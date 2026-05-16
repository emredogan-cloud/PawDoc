# Sprint B3 — Operational Resilience + Performance Hardening — Implementation Report

**Status:** Complete. Ready to commit + push.
**Companion plan:** [`sprint-b3-ops-plan.md`](sprint-b3-ops-plan.md)
**Implemented on:** 2026-05-16

---

## Summary

Sprint B3 closes the operational legibility gap before the closed
TestFlight cut. No new SDKs, no new infrastructure — the
deliverable is "when something goes wrong in production, we will
*see it*, *survive it*, and *recover from it* in minutes."

User-visible improvements:

- A reviewer or low-end Android user whose `flutter_image_compress`
  throws (OOM) now sees a friendly "we couldn't shrink that image"
  message instead of a generic "Something went wrong" — same
  `unsupportedImage` UX as Sprint B2's image-hygiene gates.
- The result-screen disclaimer is now pinned by a visibility test
  that fails when the text renders at zero height — App Store
  compliance can't silently regress.
- AI fallback copy ("see a vet within 24 hours" graceful path,
  emergency override headline) lives in one file, exercised by
  tone-invariant tests that fail on "diagnosis", "treatment",
  "cure", "guaranteed", and friends.

Operator-visible improvements:

- AI service refuses to start in prod with missing keys (lists
  every offender in the startup log).
- New `/ready` endpoint distinguishes config-level readiness from
  process liveness — Better Uptime now has a probe that catches
  config drift without making outbound calls.
- Rate-limit logs carry a `mode: upstash | inmemory | upstash_failopen`
  field; dedicated `rate_limit_failopen` event makes alerting on
  Upstash outages a one-line rule.
- Mobile journey breadcrumbs (`analyze_submit`, `analyze_failed`,
  `paywall_shown`, `purchase_complete`, `purchase_restored`,
  `auth_completed`) wired into Sentry — crash reports now carry
  the user's path through the app, not just the final stack trace.
- The operational runbook gained a full provider-outage triage
  section (Anthropic / Gemini / Upstash / Supabase) plus Better
  Uptime + Sentry alert routing recipes and a rollback rehearsal
  procedure.

| Plan item | Status |
|-----------|--------|
| B3.1 Rate-limit mode tagging + fail-open counter | ✅ Shipped |
| B3.2 AI service prod startup validation (H-9) | ✅ Shipped |
| B3.3 AI service `/ready` endpoint | ✅ Shipped |
| B3.4 Centralized AI tone copy | ✅ Shipped |
| B3.5 Mobile Sentry breadcrumbs (H-10) | ✅ Shipped |
| B3.6 Compression OOM-safe wrapper (R-16 partial) | ✅ Shipped |
| B3.7 Provider-degradation chaos tests | ✅ Shipped |
| B3.8 Disclaimer visibility test (R-2) | ✅ Shipped |
| B3.9 Runbook: provider triage + Better Uptime + rollback rehearsal | ✅ Shipped |
| `compute()`-isolate compression rewrite (R-16 full) | Deferred to Phase 2 / `P1.15` |
| Sentry / Better Uptime live wiring (HTTP calls, Slack hooks) | Operational — founder configures in dashboards |

---

## 1. Discovered failure modes → fixes

Cross-references the F-codes in §1 of the plan.

### F-OPS1 — Rate-limit fail-open mode invisible

**Was:** The happy-path `rate_limit_check` log only said
`allowed/remaining`. An operator couldn't grep for "we are
currently soft-cap-disabled" without correlating two separate
warn lines.

**Now:** every `LimiterResult` carries a `mode: 'upstash' |
'inmemory' | 'upstash_failopen'` field. The edge function's
`rate_limit_check` log line now includes the mode. Both Upstash
failure paths (5xx + transport) emit a dedicated
`rate_limit_failopen` WARN event with a `cause` tag — one alert
rule covers both.

Files: `supabase/functions/_shared/rate-limit.ts`,
`supabase/functions/analyze/index.ts`. Tests:
`supabase/functions/_shared/rate-limit.test.ts` (+4 cases).

### F-OPS2 — AI service config drift was silent (H-9)

**Was:** `Settings` fields are `Optional`; prod could boot with
no `INTERNAL_API_TOKEN`. First user request returned 503; the
operator noticed late.

**Now:** Pydantic `@model_validator(mode="after")` raises
`ValueError` when `app_env == PROD` and any of
`INTERNAL_API_TOKEN`, `ANTHROPIC_API_KEY`, `GOOGLE_AI_API_KEY`,
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` is missing. The
message lists every offending key. Uvicorn surfaces it as a hard
startup crash in Fly logs.

Files: `ai-service/app/core/config.py`. Tests:
`ai-service/tests/test_config.py` (+6 cases).

### F-OPS3 — No readiness probe distinct from liveness

**Was:** Fly.io's `/health` doubled as the only health surface.
A Better Uptime probe couldn't say "this process has the config
it needs" without making it look unhealthy from Fly's perspective
(which would cycle the machine on transient provider hiccups).

**Now:** new `/ready` endpoint (`200` ready / `503` degraded)
that inspects in-process config only — no outbound calls.
LOCAL env is intentionally lenient (devs without a full `.env`
still see green); DEV and PROD report `degraded` with the list of
missing keys.

Files: `ai-service/app/routers/health.py`. Tests:
`ai-service/tests/test_health.py` (+5 cases).

### F-OPS4 — AI tone consistency lived in 3 files

**Was:** Emergency override copy in `services/safety.py`;
graceful degradation hard-coded in `services/orchestrator.py`;
Pydantic default disclaimer in `models/schemas.py`. App Store
tone review was a three-grep operation.

**Now:** `ai-service/app/services/copy.py` is the canonical
home for every user-visible string the orchestrator and safety
layer emit. Orchestrator + safety re-import from there.
Tone-invariant test enumerates every exported string and fails
on "diagnosis", "diagnose", "treatment", "treat", "cure",
"guaranteed", "guarantee", "fatal", "dying". The canonical
disclaimer is the explicit exception — it MUST say "not a
veterinary diagnosis" (App Store requirement), pinned by a
positive test.

Files: `ai-service/app/services/copy.py` (new),
`ai-service/app/services/safety.py`,
`ai-service/app/services/orchestrator.py`. Tests:
`ai-service/tests/test_copy.py` (new, 13 cases).

### F-OPS5 — Sentry breadcrumb helper had zero callers (H-10)

**Was:** `sentryBreadcrumb` existed in
`mobile/lib/shared/services/sentry_service.dart` but no caller.
Crash reports landed with the stack trace but no journey
context.

**Now:** breadcrumbs wired at every high-value checkpoint:
- `analyze_submit` (controller entry, with `input_type`,
  `attempt_id`)
- `analyze_failed` (each failure branch, with `kind`)
- `paywall_shown` (with `offering_id`)
- `purchase_complete` / `purchase_restored`
- `auth_completed` (with `method`)

Payloads are privacy-safe — typed enum names, IDs, durations,
no email / no symptom text / no pet name.

Files: `analysis_controller.dart`, `paywall_controller.dart`,
`auth_controller.dart`. No new tests — `sentryBreadcrumb` is a
no-op when Sentry isn't initialised (the test default), and
asserting on a no-op call adds nothing.

### F-OPS6 — Compression OOM was unhandled (R-16 partial)

**Was:** `flutter_image_compress.compressWithList` running on
the main isolate could throw / return empty on 256 MB Android.
The exception bubbled up as `AnalyzeFailureKind.unknown`
("Something went wrong").

**Now:** each call is wrapped in `try/catch`; empty-byte results
are also caught. Both paths throw a typed
`ImagePickFailure(compressionFailed)` which the controller maps
to `AnalyzeFailureKind.unsupportedImage` ("That image isn't
something we can analyze. Try a clear photo of your pet.").

The full `compute()`-isolate rewrite stays deferred to Phase 2
(`P1.15`) — moving compression off the UI thread is feature-
shaped (UI rewiring, progress reporting, isolate lifetime
management). This sprint ships the safety net for the existing
main-isolate path.

Files: `mobile/lib/shared/services/image_service.dart`,
`mobile/lib/features/analysis/analysis_controller.dart`. Tests:
`mobile/test/image_service_test.dart` (enum-stability case +
existing magic-byte coverage covers the wrapper paths).

### F-OPS7 — Provider-degradation tests were thin

**Was:** the orchestrator's degradation behaviour was documented
but not pinned by tests. A refactor that broke "Tier 3 fails →
graceful degradation" wouldn't fail CI.

**Now:** four new chaos tests in `test_orchestrator.py`:
1. Both providers fail → graceful degradation
2. Graceful degradation uses centralised copy (verifies F-OPS4
   discipline, regression guard)
3. Cross-verify fails with first call EMERGENCY → keeps
   EMERGENCY with `cross_verify_disagreement=False` (pins H-7's
   fail-safe-to-emergency behaviour)
4. Emergency override uses centralised copy

Files: `ai-service/tests/test_orchestrator.py` (+4 cases).

### F-OPS8 — Disclaimer-visibility test was too lax (R-2)

**Was:** the test used `find.textContaining`. A future UI bug
that wraps the disclaimer in `Visibility(visible: false)` or a
zero-height `SizedBox` would still pass.

**Now:** for every triage variant (EMERGENCY, MONITOR, NORMAL)
the test additionally asserts `tester.getSize(finder).height > 0`
and `.width > 0`.

Files: `mobile/test/result_screen_widget_test.dart` (+3 cases).

### F-OPS9 — Operational runbook missing provider-outage triage

**Was:** runbook covered spend caps + orphan cleanup; no
provider-outage playbook.

**Now:** four new sections in `docs/operational-runbook.md`:
- §7 Provider outage triage (Anthropic / Gemini / Upstash /
  Supabase) — each subsection lists the log signature, the
  external status page, and the mitigation step
- §8 Healthchecks + Better Uptime configuration (probes,
  expected codes, Sentry alert routing)
- §9 Production startup validation reference (what the new
  validator does + how to recover from a startup crash)
- §10 Rollback rehearsal procedure (quarterly cadence,
  90-second target)

### Test pollution discovered + fixed (incidental)

While running the full ai-service suite, two pre-existing tests
that wrote to `os.environ` directly (instead of via `monkeypatch.setenv`)
leaked the `INTERNAL_API_TOKEN` env var across test runs, breaking
the new B3 startup-validator + readiness probe tests. Converted
`test_analyze_router.py::app_with_fake` fixture +
`test_orchestrator_dependency_constructs` to use `monkeypatch.setenv`.
Two pre-existing tests (`test_configure_logging_prod_is_json`,
`test_docs_disabled_in_prod`) that constructed prod Settings without
the required keys had stub secrets added.

---

## 2. Performance findings

This sprint deliberately did **not** run a profiling pass — the
brief warns against speculative micro-optimization. The
performance-shaped items shipped this sprint are:

- **Compression safety net (F-OPS6)** — limits the blast radius
  of the existing main-isolate compression path on low-end
  Android. No latency improvement; bounded failure mode.
- **No cold-start tuning** — `min_machines_running = 1` in
  `fly.toml` already mitigates the documented 3-5s cold start.
  Cold-start frequency monitoring requires production traffic to
  size meaningfully; deferred.
- **No `tracesSampleRate` adjustment** — kept at 0.1 mobile-side;
  needs prod traffic to calibrate.

### Documented levers (operational, not engineering)

| Lever | Where | When to use |
|-------|-------|-------------|
| `min_machines_running` | `ai-service/fly.toml` | Bump to 2 only if cold-start latency shows in real user data |
| `gemini_timeout_s` / `claude_timeout_s` | `app/core/config.py` | Default 20s/30s; reduce in prod if real p99 < these |
| `DAILY_LIMIT` env | edge function | Tighten temporarily on Upstash outage to protect spend caps |
| `tier2_confidence_floor` | `app/core/config.py` | Raise to push more traffic to Tier 3 if Tier 2 quality slips |
| Sentry `tracesSampleRate` | mobile + AI service | Reduce on Sentry quota burn (per `R-26`) |

---

## 3. Degradation strategy

After Sprint B3, the degradation ladder for any single failure
mode is:

| Failure | What user sees | What operator sees |
|---------|----------------|--------------------|
| Tier 2 (Gemini) down | (transparent — Tier 3 covers it) | `tier2_failed_escalating_to_tier3` in logs |
| Tier 3 (Claude) down | "Limited analysis" callout + MONITOR / "see a vet within 24h" | `tier3_failed_graceful` |
| Both providers down | "Limited analysis" callout + MONITOR / "see a vet within 24h" | Same as above, both events |
| Upstash down | (transparent — soft cap disabled, hard cap remains) | `rate_limit_failopen` counter |
| Supabase Storage transient | "Connection was lost while uploading. Try again." | `upload_failed` 5xx |
| Mobile network drop mid-analyze | "That took longer than expected. Try again." | (analyze timeout client-side) |
| Mobile offline pre-flight | "You're offline. Reconnect to Wi-Fi or mobile data and try again." | (no request made) |
| App backgrounded > 5 min mid-upload | "Connection was lost while uploading. Try again — we kept your photo." | `analysis_recovered_from_background` |
| Low-end Android OOM in compression | "We couldn't shrink that image. Try a different one." | `image_compress_failed` |
| Prod env missing keys | (process never starts; users see "AI service unavailable" from edge) | `Production startup refused: missing required environment variables: …` |

The common pattern: **users always see calm, action-oriented
copy that names a vet**; operators always see a structured event
they can alert on.

---

## 4. Monitoring architecture

| Surface | Mechanism | Sprint |
|---------|-----------|--------|
| Mobile crashes | Sentry SDK + `sentryCapture` | Phase 1D |
| Mobile journey breadcrumbs | `sentryBreadcrumb` calls at submit / failed / paywall / auth | **B3 (F-OPS5)** |
| AI service errors | Sentry Python SDK | Phase 1D |
| AI service prod liveness | Fly.io HTTP service check on `/health` | Phase 1B |
| AI service config readiness | `/ready` for Better Uptime | **B3 (F-OPS3)** |
| AI service startup config drift | Pydantic prod validator → uvicorn crash log | **B3 (F-OPS2)** |
| Rate-limit fail-open frequency | `rate_limit_failopen` event + mode tag | **B3 (F-OPS1)** |
| Free-tier consume / refund | DB-backed counter + `analysis_refunds` audit | A2 |
| Orphan storage rows | `cleanup_orphan_pet_uploads()` + `pg_cron` | B1 |
| Mobile analytics funnel | PostHog typed event hierarchy | A2 |
| Suspicious input patterns | `suspicious_input_pattern` warning | B2 |
| Better Uptime synthetic checks | External HTTP probes on `/health`, `/ready`, Supabase REST | **B3 runbook §8** |
| Sentry alert routing | Sentry dashboard rules | **B3 runbook §8.3** |

---

## 5. Operational recovery posture

The runbook now answers, for each likely incident, *what does the
operator do in the first 5 minutes*:

- **§7.1 Anthropic outage** — confirm via status page, watch the
  graceful-degradation counter; bump spend cap if Tier 3 carries
  all traffic for > 1h.
- **§7.2 Gemini outage** — same, cost-aware.
- **§7.3 Upstash outage** — confirm via dashboard; the system
  already handles this via `upstash_failopen`. If sustained,
  tighten `DAILY_LIMIT` env temporarily.
- **§7.4 Supabase Storage transient** — confirm via storage tab;
  Sprint B1's storage-key cache means user retries cost nothing.
- **§7.5 Supabase Database** — confirm via Studio logs; rollback
  the last migration if RLS or query plan changed.
- **§9 Startup validator crash** — fix Doppler secret, redeploy.
- **§10 Rollback rehearsal** — quarterly `flyctl releases rollback`
  drill; target < 90 s.

---

## 6. Remaining scale risks

Listed in the plan §3; recap with current status:

| Item | Target |
|------|--------|
| `compute()`-isolate compression rewrite | Phase 2 / `P1.15` |
| Sentry / Better Uptime live wiring (HTTP probes + Slack hooks) | Operational — founder configures in dashboards |
| `tracesSampleRate` per-route tuning | Phase 2, needs real traffic |
| Edge function E2E integration test | Phase 2 / `L-5` |
| Sentry quota alert | Operational |
| Provider org-level budget caps (R-12) | Operational, A2 runbook §1 |
| `webhook_events` idempotency table (M-4) | Phase 2 / `P2.9` |
| Word-boundary refinement on emergency keywords (R-3) | Phase 2 / `P2.6` |
| OneSignal ATT verification (R-23) | Operational manual testing |
| Cold-start frequency monitoring | Phase 2 |
| Vision-content moderation (NSFW/non-pet) | Phase 2 when vision lands |
| HEIC dimension parse | Phase 2 |

None are launch blockers for the closed TestFlight beta.

---

## 7. TestFlight readiness assessment

After Sprint B3, the closed-beta gate is **mechanically green**
on every engineering surface. Remaining gates are operational +
manual:

**Engineering posture — green**
- Mobile: 144/144 tests, `flutter analyze` clean.
- AI service: 156/156 tests, 93.71% coverage.
- pgTAP: 76/76, edge-function `deno check` clean,
  `deno test rate-limit.test.ts` 9/9.
- All Phase 1 P0 / P1 launch blockers from `phase1-stabilization-plan.md`
  closed.
- Sprint A2 + B1 + B2 + B3 implementation reports each enumerate
  their F-codes with test coverage.

**Manual gates the operator still owns**
- [ ] Apple Developer Program enrollment complete +
      bundle ID `com.pawdoc.pawdoc` registered (per
      `docs/environment-setup.md` §14)
- [ ] Anthropic + Google AI spend caps configured per
      `docs/operational-runbook.md` §1
- [ ] Doppler `prod` config populated; `flyctl secrets import`
      executed; `/ready` returns 200 against prod
- [ ] Better Uptime monitors live per `docs/operational-runbook.md`
      §8.2
- [ ] Sentry alert rules wired per §8.3
- [ ] PrivacyInfo.xcprivacy manifest committed (audit C-2)
- [ ] iOS Info.plist usage descriptions present (audit C-1)
- [ ] App Store metadata copy reviewed for medical-claim language
      (Sprint A1)
- [ ] Screenshots captured at the four required device sizes
- [ ] TestFlight build uploaded + invitation list assembled

The engineering side of those checklist items is shipped — they
are operator gates because they need a human with Apple, Doppler,
Fly, Better Uptime, and Sentry credentials.

---

## 8. Validation results

| Surface | Tool | Result |
|---------|------|--------|
| Mobile static analysis | `flutter analyze` | ✅ no issues |
| Mobile tests | `flutter test` | ✅ 144/144 pass |
| AI service tests | `uv run pytest` | ✅ 156/156 pass · 93.71% coverage |
| pgTAP database tests | `supabase test db --local` | ✅ 76/76 (regression — no SQL changes) |
| Edge function tests | `deno test --allow-env --allow-net _shared/rate-limit.test.ts` | ✅ 9/9 pass |
| Edge function TypeScript | `deno check analyze/index.ts` | ✅ pass |
