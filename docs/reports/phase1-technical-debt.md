# Phase 1 — Technical Debt Register

**Audit date:** 2026-05-16
**Scope:** deliberate trade-offs the implementation accepted (not bugs)

Each entry is a conscious decision Phase 1 made to defer or simplify
something. The decision is sound for Phase 1; the cost is documented
here so a future maintainer can choose to repay it when the trigger
arrives.

For each:
- **What:** the simplification
- **Why (Phase 1):** the rationale
- **Cost:** what we accepted
- **Trigger to repay:** the metric or milestone that should prompt
  re-investment
- **Repay complexity:** rough effort

---

## 1. Storage backend: Supabase Storage instead of R2

- **What:** Phase 1C ships images via Supabase Storage with per-user RLS.
  Roadmap §3 + TECH_DECISIONS §5 specify Cloudflare R2 (zero-egress).
- **Why (Phase 1):** R2 requires AWS Signature V4 in Deno edge functions —
  a new hand-rolled signing layer or an external SDK. Supabase Storage
  is native to the stack we already run.
- **Cost:** Egress bills (Supabase Storage charges ~$0.09/GB; R2 zero).
  At 100K MAU × 3 analyses × 1.5 MB = ~450 GB/month → ~$40/month at
  Supabase Storage vs $0 at R2. Annual: ~$500/year.
- **Trigger to repay:** > $200/month egress OR public launch.
- **Repay complexity:** Medium — write an S3 V4 signer in `_shared/r2.ts`
  (~150 lines), swap `storage_service.dart` to point at R2 endpoint, add
  a presigned-URL edge function. Schema unchanged.
- **Status:** Documented in [`phase1c-mobile-plan.md`](phase1c-mobile-plan.md) §5.3.

---

## 2. Cross-verify uses Claude Sonnet, not Opus

- **What:** Roadmap §3 Tier 4 = Claude Opus for EMERGENCY verification.
  Phase 1B/1D uses Claude Sonnet for both Tier 3 + cross-verify.
- **Why (Phase 1):** Opus is ~5× more expensive ($15/M input tokens vs
  $3/M Sonnet). We have no production EMERGENCY frequency data yet, so
  paying for Opus on every EMERGENCY is premature optimisation.
- **Cost:** Slightly higher false-positive rate on EMERGENCY
  classifications. Slightly weaker reasoning on edge cases.
- **Trigger to repay:** When real production data shows EMERGENCY rate
  ≥ 5% AND cross-verify disagreement rate < 10% (i.e., we trust the
  cross-verify enough to warrant the Opus upgrade).
- **Repay complexity:** Trivial — change one env var + redeploy.
- **Status:** Documented in [`phase1b-ai-plan.md`](phase1b-ai-plan.md) §3.

---

## 3. Semantic cache deferred

- **What:** Roadmap §3/§8 calls for pgvector similarity caching of
  analyses (90% similarity → reuse cached result). Phase 1 does not
  populate the `analyses.embedding` column.
- **Why (Phase 1):** Adds an embedding-generation step (OpenAI
  `text-embedding-3-small`) to every analyze call, increasing cost and
  latency before we know if cache hit rate justifies it.
- **Cost:** 10-15% higher API cost at 100K+ MAU. Documented
  $500-750/month at full scale.
- **Trigger to repay:** Phase 3 per roadmap §10.
- **Repay complexity:** Medium — add embedding service, schema is ready
  (column + ivfflat index already exist).

---

## 4. On-device pre-filter (CoreML/TFLite) deferred

- **What:** Roadmap §3 Tier 1 = on-device animal-detection + image-quality
  classifier. Phase 1 has the `lib/platform/{ios,android}/` directories
  as `.gitkeep` placeholders.
- **Why (Phase 1):** Each platform needs a separately-trained model + a
  Method-Channel bridge. Mature deliverable but adds 2 weeks to Phase 1.
- **Cost:** 15-20% wasted API calls on non-animal / blurry images that
  the pre-filter would have rejected. Documented $50-100/month at 100K
  MAU.
- **Trigger to repay:** Phase 2 (image-quality UX improvements).
- **Repay complexity:** Medium-High — model training + native code.

---

## 5. Onboarding compressed from 5 screens to 2

- **What:** Roadmap §6 onboarding flow has 5 screens (welcome → pet
  setup → trust signal → push permission → activation). Phase 1C ships
  welcome + pet setup only.
- **Why (Phase 1):** Trust-signal screen needs real vet advisor
  credentials + photos (legal + asset deliverable). Push permission
  needs OneSignal integration (now landed in 1D but UX placement is a
  Phase 1.5 effort). Activation screen subsumed into home.
- **Cost:** ~10% lower trial conversion than the roadmap forecast,
  per industry benchmarks. Lower push opt-in rate (~30% vs 55%+).
- **Trigger to repay:** Phase 1.5 (post-1D polish) or first A/B test.
- **Repay complexity:** Medium (assets + content + 3 screens).

---

## 6. Pet profile is create-only

- **What:** Mobile creates pets in onboarding. No edit / soft-delete /
  view-detail screens.
- **Why (Phase 1):** The data model supports CRUD. Building the screens
  costs 2-3 days. Phase 1's critical path is analyze; pet CRUD is
  necessary but not gating.
- **Cost:** Support load on "how do I change my pet's weight."
- **Trigger to repay:** First production support ticket on the topic OR
  Phase 1.5.
- **Repay complexity:** Medium (~150-200 mobile lines + a test).

---

## 7. Home screen elements stripped down

- **What:** Roadmap §10 Phase 1 home card lists pet photo + last-check
  summary + query counter. Phase 1C ships species emoji + name + breed
  + age + "Check" CTA.
- **Why (Phase 1):** The missing elements require (a) loading from
  analyses + users tables, (b) photo upload UX which is also missing.
- **Cost:** Lower visual engagement; users surprised by paywall hit.
- **Trigger to repay:** Phase 1.5.
- **Repay complexity:** Medium.

---

## 8. PostHog SDK not integrated

- **What:** Roadmap §10 Phase 1 lists 9 PostHog events to track. Phase 1
  catalogued them in `docs/event-catalog.md` but did NOT install the SDK.
- **Why (Phase 1):** PostHog self-hosted requires an extra Fly.io app +
  ~$30/month managed. The team prioritised the analyze flow over
  observability.
- **Cost:** **High and accumulating.** Without PostHog, we cannot:
  - Measure onboarding completion
  - Measure paywall conversion
  - Run A/B tests
  - Track retention (D1/D7/D30)
  - Decide which screens drop users
- **Trigger to repay:** Pre-launch — we should not run a public launch
  blind. **This is the highest-ROI debt item to repay.**
- **Repay complexity:** Medium (~150 mobile lines + a few hundred event
  call-sites + cost ceiling for hosting).
- **Severity uplift:** This started as debt; the audit elevates it to a
  **Critical-7** finding because launching blind violates the data-driven
  premise of roadmap §13 Post-Launch Strategy.

---

## 9. Share button on NORMAL results not implemented

- **What:** Roadmap §10 Phase 1 + §6 "Viral mechanics."
- **Why (Phase 1):** Each viral component (Share + Referrals UI + ASO)
  is multi-day work; the team prioritised the analyze flow.
- **Cost:** Zero viral coefficient → 100% paid acquisition.
- **Trigger to repay:** Pre-launch.
- **Repay complexity:** Low (~50 lines + watermark asset).

---

## 10. Vet finder deep link not implemented

- **What:** Roadmap §10 Phase 1 EMERGENCY UX requirement.
- **Why (Phase 1):** A real vet-finder UX is Phase 3 (Google Places API
  + filter). A simple deep link to Google Maps query was viable in
  Phase 1 but didn't ship.
- **Cost:** EMERGENCY result screen is incomplete on the most
  consequential code path.
- **Trigger to repay:** Pre-public-launch (Phase 1.5).
- **Repay complexity:** Low (~30 lines + `url_launcher` already a
  transitive dep).

---

## 11. AI cost telemetry absent

- **What:** We log `tier_used`, latency, triage. We do not log estimated
  cost per call (tokens × per-token rate).
- **Why (Phase 1):** Token counts come from provider responses; we don't
  surface them today.
- **Cost:** No real-time cost dashboard; we'd discover a cost runaway
  only via the AWS/Anthropic/Google billing alerts.
- **Trigger to repay:** Pre-public-launch or first $50/day spend on
  providers.
- **Repay complexity:** Low — add `usage` field to provider client
  responses, log to stdout, tag in Sentry.

---

## 12. No automated parity test for emergency keyword lists

- **What:** `ai-service/app/services/safety.py` and
  `supabase/functions/_shared/emergency.ts` carry the same list. They
  could drift.
- **Why (Phase 1):** Defence-in-depth design, intentional duplication.
- **Cost:** Drift would manifest as a quota mismatch (edge function
  thinks not-emergency, AI service classifies as EMERGENCY). Safety
  preserved either way (AI service is authoritative); revenue/quota
  consistency degrades.
- **Trigger to repay:** First time someone modifies the Python list and
  forgets the TS file.
- **Repay complexity:** Low — add a CI step that parses both files and
  diffs the lists.

---

## 13. Free-tier RPC not unit-tested

- **What:** `attempt_consume_free_analysis(uuid, int)` SQL function
  shipped without an explicit test in the pgTAP suite.
- **Why (Phase 1):** The function is tiny and exercised by manual
  smoke. pgTAP focus was RLS isolation.
- **Cost:** A bug in the rollover or counter logic could ship undetected.
- **Trigger to repay:** Before any future change to the function.
- **Repay complexity:** Low (~50 lines pgTAP).

---

## 14. Edge function rate limiter fails open

- **What:** When Upstash is unreachable, the daily rate limiter allows
  the call and logs a warning. The DB-backed free-tier counter is the
  harder limit.
- **Why (Phase 1):** Documented as deliberate in
  [`phase1b-ai-plan.md`](phase1b-ai-plan.md) §7. User experience
  preserved during transient Upstash outages.
- **Cost:** During an Upstash outage, the 10/day rate cap is not
  enforced. A determined attacker could abuse this window. Bounded by:
  free-tier counter (3/month/free user), provider rate caps, and
  log-based detection.
- **Trigger to repay:** If we ever see a coordinated abuse window
  exploit fail-open.
- **Repay complexity:** Medium — secondary in-DB rate counter as
  fallback.

---

## 15. RevenueCat webhook idempotency relies on UPDATE-only semantics

- **What:** The webhook UPDATEs the user row. Two simultaneous
  identical events produce the same final state (idempotent for
  RENEWAL → premium → premium). No `webhook_events` table with
  unique constraint.
- **Why (Phase 1):** Adding a webhook-events log is straightforward but
  not required for correctness on the events we handle today.
- **Cost:** A future non-idempotent event type (e.g., crediting a
  one-time bonus) would race. Currently no such event.
- **Trigger to repay:** When we add a non-idempotent event handler.
- **Repay complexity:** Low (~30 lines + 1 migration).

---

## 16. AI service env validation diverges between mobile and AI service

- **What:** `AppConfig.validate()` (mobile, Phase 1D) throws in prod
  without Sentry. `Settings` (ai-service) does NOT throw without an
  `INTERNAL_API_TOKEN` in prod.
- **Why (Phase 1):** Inconsistent oversight — the mobile-side hardening
  was a Phase 1D task; the ai-service-side equivalent wasn't.
- **Cost:** Misconfigured prod ai-service deploy serves 401s but boots
  successfully. Symptom-only failure mode.
- **Trigger to repay:** Phase 1.5.
- **Repay complexity:** Trivial.

---

## 17. Sentry `_initialized` module-global

- **What:** `ai-service/app/core/sentry.py` uses a module-level `_initialized`
  bool + `global` statement + `# noqa: PLW0603`. Tests reset it directly.
- **Why (Phase 1):** Pragmatic — wrapping in a dataclass or class-level
  attribute added complexity without proportional safety.
- **Cost:** Subtle coupling between test setup and module internals.
- **Trigger to repay:** Optional; refactor when this file changes for
  another reason.
- **Repay complexity:** Trivial.

---

## 18. No App Lifecycle hardening on lower-power Android

- **What:** `AppLifecycleObserver` only listens for `paused`/`resumed`.
  Android can also emit `inactive` and `detached` and OEM-specific
  states (Doze, Battery Optimization).
- **Why (Phase 1):** Standard `WidgetsBindingObserver` covers the 90%
  case.
- **Cost:** On very-low-power Androids, the app may resume to a stale
  state if Android killed the process mid-background.
- **Trigger to repay:** When real device testing surfaces a regression.
- **Repay complexity:** Medium.

---

## 19. iOS native code untouched (default Flutter scaffolding)

- **What:** `mobile/ios/Runner/AppDelegate.swift` is the default
  Flutter template. No custom platform code shipped (e.g., no Sentry
  native init, no special Apple Sign-In capability handling).
- **Why (Phase 1):** The plugins we use handle their own platform
  registration via `flutter_plugin_registrant`. No custom hooks
  required for 1D.
- **Cost:** When we eventually need native code (e.g., Tier-1 CoreML
  classifier, custom camera overlay), we'll add it then.
- **Trigger to repay:** Phase 2 or whenever native code is needed.

---

## 20. No CI integration test for the end-to-end analyze flow

- **What:** The mobile uses Riverpod overrides to inject fakes; the
  edge function tests cover validation; the AI service has unit tests
  with mocked providers; the pgTAP suite covers RLS. **There is no
  single test that exercises mobile → edge function → ai-service → DB
  in a hermetic CI environment.**
- **Why (Phase 1):** The cost of such a test is high (Supabase + AI
  service container + fake AI providers). Manual smoke is documented
  in `mobile/SMOKE.md`.
- **Cost:** Regressions across layer boundaries (e.g., schema change
  + mobile not updated) can ship.
- **Trigger to repay:** First production cross-layer regression.
- **Repay complexity:** Medium-High.

---

## Summary of Debt by Cost Trajectory

| Item | Linear / sub-linear cost | Cost at 100K MAU |
|------|--------------------------|------------------|
| Supabase Storage vs R2 | linear in users | ~$40/month |
| Cross-verify Sonnet vs Opus | linear in EMERGENCY rate | bounded by EMERGENCY count |
| No semantic cache | linear in queries | ~$500-750/month |
| No on-device pre-filter | linear in queries | ~$50-100/month |
| No PostHog | constant (information loss compounds) | priceless |
| No share button | inverse (constrains organic growth) | high CAC |
| No vet finder | constant (UX gap) | trust loss |
| Onboarding 2-screen vs 5 | constant (lower conversion) | ~10% conversion gap |

**Highest-ROI debt to repay before launch:**
1. PostHog
2. Vet-finder deep link
3. Share button on NORMAL results
4. Pet edit/delete UI
5. Home screen polish (photo + last-check + counter)

These are the items the audit elevates from "debt" to "Phase 1.5
hardening pass."

---

*End of technical debt register.*
