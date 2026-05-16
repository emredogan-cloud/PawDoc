# Phase 1 — Stabilization Execution Plan

**Audit date:** 2026-05-16
**Source documents:**
- [`phase1-roadmap-gap-analysis.md`](phase1-roadmap-gap-analysis.md)
- [`phase1-full-audit.md`](phase1-full-audit.md)
- [`phase1-technical-debt.md`](phase1-technical-debt.md)
- [`phase1-production-risks.md`](phase1-production-risks.md)

This plan converts the audit findings into a prioritised sequence of
work. The four priority tiers map to launch readiness:

- **P0 launch blockers** — public launch cannot proceed without these
- **P1 production hardening** — required for sustainable operations at
  scale
- **P2 UX / growth improvements** — completes the roadmap's Phase 1
  intent
- **P3 optional optimisations** — defer until evidence justifies

Each item references the audit finding ID it resolves (Cn / Hn / Mn /
Ln / Rn) and gives a complexity estimate. Architecture decisions from
Phases 0-1D are preserved.

---

## P0 — Launch Blockers

These must complete before App Store submission or public marketing.

### P0.1 — Add iOS permission usage descriptions ⭐ (C-1, R-20)

- **File:** `mobile/ios/Runner/Info.plist`
- **Action:** Add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`.
- **Effort:** 30 min.
- **Blocks:** App Store / TestFlight.

### P0.2 — Author iOS PrivacyInfo.xcprivacy ⭐ (C-2, R-19)

- **File:** `mobile/ios/Runner/PrivacyInfo.xcprivacy` (new)
- **Action:** Declare data collection types + required-reason APIs.
  Reference each SDK's own privacy manifest (sentry_flutter,
  purchases_flutter, sign_in_with_apple, onesignal_flutter).
- **Effort:** 2-4 h (research per SDK).
- **Blocks:** App Store.

### P0.3 — Implement free-tier quota refund on AI failure ⭐ (C-3, R-11)

- **Files:**
  - new migration: `supabase/migrations/<ts>_refund_free_tier.sql`
    creating `refund_free_analysis(uuid)` RPC
  - `supabase/functions/analyze/index.ts` — call refund in the catch
    arms around `callAiService` + `persistAnalysis`
- **Action:** Mirror the consume RPC; decrement with `GREATEST(0, ...)`;
  service-role-only EXECUTE. Edge function calls it on AI failure +
  on persistence failure.
- **Effort:** 3-5 h including pgTAP tests.
- **Blocks:** Public-scale launch (acceptable in closed beta).

### P0.4 — Wire ToS + Privacy links in paywall + publish URLs ⭐ (C-6, C-7, R-21)

- **Files:**
  - `mobile/lib/features/paywall/paywall_screen.dart` — two
    `TextButton` linking to URLs via `url_launcher`
  - `mobile/pubspec.yaml` — promote `url_launcher` from transitive to
    direct dependency
  - Static hosting: publish `https://pawdoc.app/terms` + `/privacy`
- **Action:** Engineering: ~30 min. Legal: separate workstream to
  publish the policies.
- **Effort:** 30 min eng; legal varies.
- **Blocks:** App Store. Cannot ship without both the link and the
  page being live.

### P0.5 — Enable Apple Sign-In in prod env (C-1 + H-11, R-24)

- **Files:** `mobile/env/prod.json.example` — already documents the
  requirement. Real `mobile/env/prod.json` (gitignored, populated
  before build) must set `APPLE_SIGN_IN_ENABLED: true`.
- **Action:** Document explicitly in `docs/environment-setup.md` (already
  partially covered). Plus: configure Apple OAuth provider in the
  Supabase Dashboard.
- **Effort:** 1-2 h including Apple Developer console work.
- **Blocks:** App Store (rule 4.8).

### P0.6 — Integrate PostHog SDK + emit Phase 1 events ⭐ (C-4)

- **Files:**
  - `mobile/pubspec.yaml` — add `posthog_flutter: ^4.x`
  - `mobile/lib/main.dart` — initialise after Supabase (no-op when key
    empty)
  - new: `mobile/lib/shared/services/analytics_service.dart` — thin
    wrapper exposing `capture(event, props)`
  - sites that emit events: auth controller, onboarding controller,
    pets controller, analyze controller, paywall controller
- **Action:** Use the canonical event names from
  `docs/event-catalog.md`. Phase 4 will add A/B test flags; Phase 1
  scope is plain event capture + revenue sync via RevenueCat
  integration.
- **Effort:** 6-8 h including ~50 callsites.
- **Blocks:** Data-driven launch (we ship blind without it).

### P0.7 — Audit + lock down medical-claim language (R-22, R-4)

- **Files:** Every user-visible string in mobile + App Store metadata
  (Phase 2 separately)
- **Action:** grep for "diagnos", "cure", "treat", "guaranteed",
  "prescribe" across `mobile/lib/`. Confirm none survive in user-
  facing copy. Pre-submission checklist line.
- **Effort:** 1 h.
- **Blocks:** App Store.

### P0.8 — Verify Anthropic + Google AI provider budget caps (R-12)

- **Files:** N/A (operational)
- **Action:** Set Anthropic spend caps; set Google AI budget alerts.
  Document the values in `docs/environment-setup.md`.
- **Effort:** 30 min.
- **Blocks:** Cost-runaway protection for public launch.

### P0.9 — Verify OneSignal ATT requirement (R-5, R-23)

- **Files:** `mobile/ios/Runner/Info.plist`
- **Action:** Audit `onesignal_flutter` 5.2.7 native code for IDFA
  reads. If yes: add `NSUserTrackingUsageDescription` +
  `AppTrackingTransparency.requestTrackingAuthorization()`. If no:
  document explicit non-use in PrivacyInfo.xcprivacy.
- **Effort:** 2 h.
- **Blocks:** Potential App Store rejection.

---

**P0 total estimate: 16-22 hours of engineering + legal/ops parallel
work.** This is roughly 2-3 focused days for the engineering portion.

---

## P1 — Production Hardening

After P0. These prevent ugly post-launch incidents.

### P1.1 — Fix mobile 401 handling → force sign-out (H-12, R-30)

- **File:** `mobile/lib/features/analysis/analysis_controller.dart` +
  router redirect chain
- **Action:** On 401 from analyze, call `authController.signOut()`.
  Auth stream emits Unauthenticated → router redirects to /auth.
- **Effort:** 30 min.

### P1.2 — Vet finder deep link on EMERGENCY (H-2, audit row)

- **File:** `mobile/lib/features/analysis/analysis_result_screen.dart`
- **Action:** Add primary CTA "Find an emergency vet near me" that
  opens `https://www.google.com/maps/search/?api=1&query=emergency+veterinary+clinic`
  (universal) via `url_launcher`. On iOS prefer `maps://`.
- **Effort:** 1 h.

### P1.3 — Wire Sentry breadcrumbs at significant events (H-10)

- **Files:** auth controller, analyze controller, paywall controller,
  apple-signin service
- **Action:** Call `sentryBreadcrumb('analyze_submitted', ...)` etc.
  at the same points where PostHog events fire (P0.6).
- **Effort:** 2 h.

### P1.4 — Cross-verify disagreement re-applies confidence floor (H-7)

- **File:** `ai-service/app/services/orchestrator.py:146-165`
- **Action:** After downgrade-to-MONITOR on disagreement, if the
  resulting confidence < `insufficient_confidence_floor`, return
  `_graceful_degradation(request)` instead.
- **Effort:** 30 min + 1 unit test.

### P1.5 — Fix CORS regex bug (H-1, R-10)

- **File:** `supabase/functions/_shared/cors.ts:10`
- **Action:** Replace `/^app\.pawdoc\.app$/` with `/^https:\/\/app\.pawdoc\.app$/`
  (or remove if covered by the wildcard).
- **Effort:** 5 min.

### P1.6 — Add AI service env validation in prod (H-9)

- **File:** `ai-service/app/core/config.py`
- **Action:** Pydantic `model_validator` that raises when
  `app_env == AppEnv.PROD` and `internal_api_token is None`. Mirror
  for `anthropic_api_key`, `google_ai_api_key`.
- **Effort:** 30 min + 2 tests.

### P1.7 — Storage lifecycle policy on `pet-uploads` (H-8, roadmap §8)

- **File:** new migration
- **Action:** Add a 90-day archive policy. Phase 1C plan documented
  this as deferred.
- **Effort:** 1 h.

### P1.8 — Reuse uploaded storage key on retry (H-8)

- **File:** `mobile/lib/features/analysis/analysis_controller.dart`
- **Action:** Cache `storageKey` after successful upload; if the
  analyze submit fails, don't re-upload on retry.
- **Effort:** 1 h.

### P1.9 — Free-tier RPC pgTAP test (M-1)

- **File:** `supabase/tests/rls_isolation.test.sql` (extend) OR new
  `supabase/tests/free_tier.test.sql`
- **Action:** Test 4-call rejection, monthly rollover, subscriber
  short-circuit.
- **Effort:** 1.5 h.

### P1.10 — Webhook secret + service-role rotation runbook (R-9)

- **File:** `docs/environment-setup.md` extension
- **Action:** Document the rotation steps for each secret + recommended
  cadence (quarterly).
- **Effort:** 1 h.

### P1.11 — Provision Doppler workspace (R-25)

- **File:** N/A (operational)
- **Action:** Create Doppler project, configs (dev / prod), GH Actions
  integration, Fly.io integration. Documented in
  `docs/environment-setup.md` since Phase 0.
- **Effort:** 2-3 h.

### P1.12 — Wire Sentry crash-rate alert (R-28)

- **File:** N/A (operational — Sentry dashboard)
- **Action:** Configure alert: crash-free-sessions < 99% in any 1-hour
  window → Slack/email.
- **Effort:** 30 min.

### P1.13 — Better Uptime alert routes (R-28)

- **File:** Operational
- **Action:** Wire /health → SMS founder + Slack channel.
- **Effort:** 30 min.

### P1.14 — Tighten `text_description` length (R-7)

- **File:** `supabase/functions/analyze/index.ts` validation step
- **Action:** Enforce `text_description.length <= 2000` in the body
  validator. Currently no upper bound.
- **Effort:** 15 min + 1 test.

### P1.15 — Image compression on isolate (P-1, R-16)

- **File:** `mobile/lib/shared/services/image_service.dart`
- **Action:** Use `compute()` or switch to `compressWithFile` so
  compression doesn't freeze the UI thread on low-end Androids.
- **Effort:** 1-2 h.

---

**P1 total estimate: 14-18 hours of engineering + operational.**

---

## P2 — UX / Growth Improvements

After P1. Complete the roadmap's Phase 1 intent.

### P2.1 — Onboarding screens 3 + 4 + 5 (H-3)

- Trust signal (vet advisor) — needs assets + content
- Push permission opt-in (uses OneSignal service)
- Activation screen (subsume into existing flow)
- **Effort:** 1-2 days including assets.

### P2.2 — Share button on NORMAL results (H-4)

- `share_plus` plugin + watermarked image.
- **Effort:** 4-6 h including a simple watermark.

### P2.3 — Pet edit / soft-delete UI (H-5)

- New `pet_edit_screen.dart`; routes; soft-delete confirm.
- **Effort:** 1 day.

### P2.4 — Home screen: photo + last-check + query counter (H-6)

- Add `petLastCheckProvider`, `userProfileProvider`. Render in card.
- **Effort:** 1 day.

### P2.5 — Pet photo upload during onboarding

- Optional avatar in onboarding pet form. Uses the same image_service
  pipeline; stores to a separate `pet-avatars` bucket or as a column
  on the user's pet folder.
- **Effort:** 1 day.

### P2.6 — Referral code UI + deep link handling

- Table exists. Mobile generates a code, presents shareable link,
  handles inbound app open via deep link.
- **Effort:** 2 days.

### P2.7 — RevenueCat → PostHog revenue sync

- Edge function emits a webhook to PostHog when subscription state
  changes (so cohort revenue is visible).
- **Effort:** 4 h.

### P2.8 — Onboarding draft widget tests (gap row Testing #5)

- Cover the onboarding form widget's validation + submit behaviour.
- **Effort:** 2-3 h.

### P2.9 — RevenueCat webhook idempotency table (M-4)

- `webhook_events(provider, event_id) UNIQUE`. Insert before applying.
- **Effort:** 2 h.

### P2.10 — Auth state machine cleanup (M-3)

- Reset to Idle after successful verify.
- **Effort:** 15 min.

### P2.11 — RC purchase success refreshes user profile (M-7)

- `petsControllerProvider.refresh()` after success.
- **Effort:** 15 min.

### P2.12 — Rate-limit log mode tagging (O-4)

- Tag log entries with `mode: upstash | inmemory | failopen`.
- **Effort:** 30 min.

### P2.13 — AI service per-tier cost telemetry (O-3, R-12)

- Log estimated cost per call (provider tokens × rate).
- **Effort:** 2 h.

### P2.14 — Emergency keyword parity CI test (debt-12)

- CI step that compares Python + TypeScript keyword lists.
- **Effort:** 1 h.

### P2.15 — Open Settings CTA on permission denial (R-32)

- `app_settings` plugin.
- **Effort:** 1 h.

---

**P2 total estimate: 7-10 days of engineering.**

---

## P3 — Optional Optimisations

After P2. Defer until evidence justifies.

### P3.1 — Migrate storage backend to R2 (debt-1)

- Trigger: > $200/month egress.
- **Effort:** 2-3 days (V4 signer + cutover).

### P3.2 — Promote cross-verify to Claude Opus (debt-2)

- Trigger: production EMERGENCY frequency + cross-verify disagreement
  metrics support it.
- **Effort:** Trivial (env change).

### P3.3 — Semantic cache via pgvector (debt-3, roadmap Phase 3)

- Phase 3 scope.

### P3.4 — On-device CoreML/TFLite pre-filter (debt-4, roadmap Tier 1)

- Phase 2-3 scope.

### P3.5 — `Sentry _initialized` state refactor (debt-17, M-6)

- Defer.

### P3.6 — End-to-end CI integration test (debt-20)

- Phase 2 scope.

### P3.7 — Single-source-of-truth enum generation across layers (debt-A1)

- Phase 4 scope.

### P3.8 — Tier-0 content classifier for jailbreak filtering (R-7)

- Phase 2-3 scope.

### P3.9 — MIME magic-byte scanning on storage uploads (R-5)

- Phase 2 scope.

### P3.10 — `RevenueCat` Family-tier UI (paywall)

- Phase 2 — exposes the family SKU.

---

## Recommended Sequencing

Three sprints of ~1 week each:

**Sprint A (P0 — launch blockers): 3-4 days**

Day 1: P0.1, P0.2, P0.4, P0.5, P0.8, P0.9 (config + manifest + env)
Day 2: P0.6 (PostHog integration + emission sites)
Day 3: P0.3 (refund RPC + edge fn integration)
Day 4: P0.7 (audit pass) + buffer

Exit criterion: TestFlight submission accepted.

**Sprint B (P1 — production hardening): 3-4 days**

Day 1: P1.1, P1.2, P1.5, P1.10, P1.14 (quick wins)
Day 2: P1.3, P1.4, P1.6, P1.9 (correctness + tests)
Day 3: P1.7, P1.8, P1.15 (storage + perf)
Day 4: P1.11, P1.12, P1.13 (ops)

Exit criterion: ready for public launch.

**Sprint C (P2 — UX + growth): 7-10 days**

A focused week of UX polish + the analytics + referrals work.

After Sprint C, return to the original Phase 2 roadmap (App Store
submission + E&O insurance + first 50 beta users).

---

## What This Plan Deliberately Does NOT Do

- **Re-architect anything.** The audit found zero architectural bugs.
  Every issue is additive on existing seams.
- **Add new frameworks.** The only net-new dependency in the plan is
  `posthog_flutter`. Everything else uses what's already in pubspec.
- **Touch Phase 0/1A core artifacts.** Migrations, RLS policies, the
  AI orchestrator core, the storage RLS — all stay as-is.
- **Skip operational work** (Doppler, alerting, legal). These are as
  important as engineering for public launch.

---

## P0 Hit List (One Place)

The 9 P0 items above are the only items between us and a defensible
public submission:

1. iOS permission usage descriptions
2. PrivacyInfo.xcprivacy
3. Free-tier quota refund on AI failure
4. ToS + Privacy links on paywall + publish the URLs
5. Apple Sign-In enabled in prod env + configured
6. PostHog SDK + Phase 1 events
7. Medical-claim language audit
8. Provider budget caps
9. ATT requirement verification (OneSignal)

When these are done, we are ready to ship to closed TestFlight beta.
The Phase 2 work (App Store submission, public marketing) then becomes
a sequenced operational deliverable on top of a solid Phase 1 base.

---

*End of Phase 1 stabilization execution plan.*
