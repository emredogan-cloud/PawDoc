# PawDoc Execution Roadmap — Decomposed Version
**Companion to `APP_EXECUTION_ROADMAP.md` v1.0 | Decomposition v1 | May 2026 | Solo Founder Edition**

> This document does **not** replace the original roadmap. It preserves its vision, architecture, product strategy, safety assumptions, monetization logic, and phase ordering **verbatim in intent**, and re-expresses each Phase as 2–4 sequential, independently-testable **SUB-PHASES (SUB-PRs)** optimized for AI-coding-agent execution. All strategic decisions are unchanged. Every proposed change is quarantined in the **Critical Review** section and clearly marked — nothing new has been silently folded into the phase tasks.

---

## Executive Summary

### How the phases were decomposed
The 9 original phases (0–8) are broken into **33 sub-phases** (4+4+3+4+3+4+3+4+4). Each sub-phase is a single mergeable PR with: a bounded scope, explicit inputs, explicit outputs (deliverables), a validation checklist, and a binary Definition of Done. Tasks were **lifted directly from the original roadmap** and reassigned to the sub-phase where they belong in dependency order — no task was added, removed, or reworded in intent. The only net-new fields are *Validation Checklist*, *Definition of Done*, *Why this comes first*, and *Execution Risks*, all of which are execution scaffolding derived from the roadmap's own Success Metrics, Critical Considerations, and Risk Analysis.

### Decomposition philosophy
1. **Secure & testable before wide.** Data layer + security (RLS, auth) and the safety core (emergency override, structured output) land before UX breadth.
2. **Vertical slices that compile.** Each sub-phase leaves the system in a runnable, demoable state — never a half-wired build that needs the next PR to compile.
3. **Foundations down the dependency tree first.** Within a phase, the sub-phase that the most other work depends on (schema, AI contract, infra) goes first.
4. **Parallelizable seams are explicit.** Where two sub-phases touch disjoint code (e.g., Flutter capture vs. Python AI), they are marked parallelizable and meet at a defined contract.
5. **Safety is a gate, not a task.** Emergency override, disclaimer injection, and the "EMERGENCY never paywalled" rule are Definition-of-Done gates, not checklist line items that can be quietly skipped.

### Major observations
- **The roadmap is structurally strong and is preserved in full.** Phase ordering, the 4-tier AI architecture, freemium-with-never-paywalled-emergencies, the false-negative-is-the-#1-risk framing, and the acquisition endgame are all intact.
- **~25 execution-level issues were found** and are documented transparently in the Critical Review. The most consequential, in priority order: (1) the **on-device Tier 1 model is architecturally load-bearing but sequenced into zero phases**; (2) the **RLS policies as written are non-functional** (no `WITH CHECK`, no INSERT policy, no policy at all on two tables); (3) **NSFW/content moderation is marked "done" but exists in no task list**; (4) the AI pipeline **double-checks EMERGENCY but never NORMAL**, which is backwards given that the stated #1 business risk is a false-negative; (5) there is **no AI regression/golden-set eval**; (6) **GDPR "right to deletion" directly contradicts "every analysis stored permanently,"** and account deletion is sequenced nowhere.
- **Effort estimates were redistributed, not inflated.** Each phase's sub-phase hours sum exactly to the original phase budget (Phase 0 = 40h, Phase 1 = 120h, … Phase 8 = 480h; total 1,900h).

### Overall feasibility
- **Phases 0–2 (MVP):** High feasibility, but the 120h/3-week Phase 1 budget is optimistic *if* the on-device Tier 1 model is actually built (the original tasks silently omit it — see Critical Review #1). With Tier 1 deferred or replaced by heuristics, the budget is realistic.
- **Phases 3–4 (V1):** Medium. Android parity and content marketing are the real drains, exactly as the original notes.
- **Phases 5–6 (V2):** Low-Medium; content competes with engineering.
- **Phases 7–8 (V3):** Not solo-feasible — matches the roadmap's own assessment. Requires a second engineer (ML/B2B) by Month 8–10.

---

# Phase 0 — Foundation & Infrastructure

**Original Goal (preserved):** *All infrastructure deployed and verified before writing a single line of app code. Eliminate deployment unknowns early. Engineering time is worth more when the deployment pipeline works reliably from day one. Zero infrastructure surprises during development.* (Days 1–7, 40h, Confidence: High)

---

## Phase 0.1 — Accounts, Domains & Secrets Backbone

**Title:** Long-lead accounts, domain, and the secrets spine everything else plugs into.

**Objective:** Stand up every account with a human-approval or propagation delay, register the domain, and centralize secrets in Doppler so no later sub-phase is ever blocked waiting on enrollment or hunting for a key.

**Why this comes first:** Apple Developer enrollment takes 24–48h and gates TestFlight; domain DNS propagation takes hours; Doppler is the single source every other service reads from. These are the critical-path, can't-parallelize-away items — start them on Day 1.

**Dependencies:** None.

**Deliverables:**
- Apple Developer account ($99/yr) enrollment **initiated Day 1**.
- Google Play Developer account ($25) created.
- `pawdoc.app` registered; Cloudflare DNS configured and resolving.
- Doppler project with dev + prod configs holding: Supabase keys, Anthropic API key, Google AI key, R2 credentials (placeholders until 0.2/0.3 mint real values).
- GitHub repo created with branch protection (require PR review for `main`).

**Tasks:**
- [ ] Initiate Apple Developer Program enrollment (Day 1 — do not wait).
- [ ] Create Google Play Developer account.
- [ ] Register `pawdoc.app`; configure Cloudflare DNS.
- [ ] Create Doppler project; define dev + prod configs; add secret slots for all providers (values filled as services come online).
- [ ] Initialize GitHub repo; configure branch protection (require PR review for `main`); enable automated secret scanning.

**Validation Checklist:**
- [ ] `dig pawdoc.app` resolves through Cloudflare.
- [ ] Doppler `dev` and `prod` configs exist; `doppler secrets` lists all expected keys (placeholders allowed).
- [ ] A test PR cannot merge to `main` without a review.
- [ ] Apple enrollment confirmation email received (or in-progress with case number logged).

**Definition of Done:** Domain resolves, Doppler is the authoritative secret store, `main` is protected, and both store accounts exist (Apple may still be "in review" — that's acceptable for DoD as long as it was initiated Day 1).

**Estimated Effort:** 10h.

**Execution Risks:** Apple enrollment can stall on D-U-N-S / identity verification — if it slips past 48h, escalate via Apple Developer Support rather than waiting passively. Putting real secrets in git before Doppler is wired is the classic Day-1 mistake; enable secret scanning *before* the first push.

---

## Phase 0.2 — Core Data & Storage Platform

**Title:** Supabase (dev + prod + EU) and Cloudflare R2 — the stateful spine.

**Objective:** Provision the persistent data and object-storage layer with the extensions, auth providers, and CORS the app will need, so the data layer in Phase 1.1 has somewhere to migrate into.

**Why this comes first (within Phase 0):** Stateful services are slow to reprovision and carry GDPR/data-residency decisions that are painful to retrofit. The roadmap explicitly says to create the EU project *immediately* for future compliance — doing it now is free; doing it later is a migration.

**Dependencies:** 0.1 (Doppler to receive the minted keys).

**Deliverables:**
- Supabase **dev + prod** projects, plus an **EU** project provisioned (per the roadmap's "create Supabase EU project immediately" directive).
- Extensions enabled: `pgvector`, `uuid-ossp`.
- Supabase Auth providers configured: email, Apple Sign In, Google.
- Cloudflare R2 buckets (dev + prod) with CORS policy allowing Flutter app origins.
- All minted keys written back into Doppler.

**Tasks:**
- [ ] Create Supabase projects (dev + prod); enable `pgvector`, `uuid-ossp` extensions.
- [ ] Create the Supabase EU project (GDPR future-proofing).
- [ ] Configure Supabase Auth providers: email, Apple Sign In, Google.
- [ ] Create Cloudflare R2 buckets (dev + prod) with CORS policy (allow Flutter app origins).
- [ ] Store Supabase + R2 credentials in Doppler.

**Validation Checklist:**
- [ ] `select * from pg_extension` shows `vector` and `uuid-ossp` on dev and prod.
- [ ] A test upload to the dev R2 bucket succeeds; CORS preflight from a browser origin returns the allow headers.
- [ ] Auth provider config screens show email/Apple/Google enabled.
- [ ] Doppler now holds real (non-placeholder) Supabase + R2 values.

**Definition of Done:** Both primary Supabase projects and the EU project are live with extensions on; R2 buckets accept CORS-valid uploads; all credentials flow from Doppler.

**Estimated Effort:** 10h.

**Execution Risks:** R2 CORS misconfiguration is the most common direct-upload failure later — validate it now with a real browser-origin preflight, not just a `curl`. Apple Sign In requires a Services ID + key pair; configure it now so 1.1 auth isn't blocked.

---

## Phase 0.3 — AI Service Shell & Compute

**Title:** Fly.io FastAPI placeholder + RevenueCat project skeleton.

**Objective:** Get a deployable, always-warm compute target and the subscription backend's identifiers in place, so Phase 1.3 (AI orchestration) and Phase 1.4 (paywall) have a home to deploy into.

**Why this comes first (within Phase 0):** The AI service is the one bespoke compute surface; proving a `min_machines_running = 1` deploy works (no cold starts) de-risks the entire AI pipeline before any real logic exists.

**Dependencies:** 0.1 (Doppler), 0.2 (so the service can later reach Supabase/R2).

**Deliverables:**
- Fly.io account + Dockerized FastAPI placeholder deployed, exposing `GET /health` only, with `min_machines_running = 1`.
- RevenueCat project created; iOS + Android app identifiers configured.

**Tasks:**
- [ ] Deploy Fly.io placeholder FastAPI service (`GET /health` only); Docker container; set `min_machines_running = 1` (no cold starts).
- [ ] Create RevenueCat project; configure iOS + Android app identifiers.

**Validation Checklist:**
- [ ] `curl https://<fly-app>/health` returns 200 from a cold start with no spin-up delay (machine already running).
- [ ] `fly status` shows exactly one always-on machine.
- [ ] RevenueCat dashboard shows both app identifiers registered.

**Definition of Done:** The AI service answers `/health` with zero cold-start latency, and RevenueCat is ready to receive product configuration in Phase 1.4.

**Estimated Effort:** 8h.

**Execution Risks:** Forgetting `min_machines_running = 1` reintroduces cold starts that will later blow the P95 < 10s latency budget. RevenueCat product/entitlement setup (vs. just app identifiers) is intentionally deferred to 1.4 where the paywall is built — don't over-build here.

---

## Phase 0.4 — CI/CD, Observability & Verification

**Title:** Pipelines, monitoring, and the green-board sign-off that closes Phase 0.

**Objective:** Wire continuous integration/deployment, error/uptime/product observability, and run the end-to-end verification that proves the foundation is trustworthy before any app code is written.

**Why this comes last (within Phase 0):** CI/CD and monitoring need the targets from 0.1–0.3 to exist (repo, Fly app, Supabase, store accounts) before they can deploy to or watch them.

**Dependencies:** 0.1, 0.2, 0.3.

**Deliverables:**
- GitHub Actions: Flutter `analyze` + `test` on every PR; Fly.io deploy on merge to `main`.
- Fastlane: Matchfile (iOS cert management); TestFlight upload lane (git-tag triggered); Google Play internal-testing lane.
- PostHog (self-hosted) deployed on Fly.io.
- Sentry project created; Flutter DSN configured.
- Better Uptime monitoring on all endpoints.

**Tasks:**
- [ ] GitHub Actions: Flutter analyze + test on every PR.
- [ ] GitHub Actions: Fly.io deploy on merge to `main`.
- [ ] Install Fastlane; configure Matchfile for iOS certificate management.
- [ ] Fastlane lane: TestFlight upload triggered by git tag.
- [ ] Fastlane lane: Google Play internal testing upload.
- [ ] Deploy PostHog (self-hosted) on Fly.io.
- [ ] Create Sentry project; configure Flutter DSN.
- [ ] Set up Better Uptime monitoring for all endpoints.

**Validation Checklist (this is also the Phase 0 exit gate):**
- [ ] All services deployed and passing health checks.
- [ ] CI pipeline completes in **under 5 minutes**.
- [ ] A tagged commit produces a TestFlight build **within 24 hours**.
- [ ] **Zero secrets in git history** (automated secret scanning green).
- [ ] Better Uptime shows all monitors green; Sentry receives a test event; PostHog receives a test event.

**Definition of Done:** Every original Phase 0 Success Metric passes: services healthy, CI < 5 min, TestFlight build < 24h, zero secrets in history. The foundation is verified end-to-end.

**Estimated Effort:** 12h.

**Execution Risks:** Fastlane Match certificate setup is the single most time-consuming task here and routinely overruns — treat it as the long pole. Self-hosting PostHog (ClickHouse-backed) is operationally heavy for a solo founder (see Critical Review #18 for a lighter alternative, kept out of the task list per the transparency rule).

---

# Phase 1 — MVP Core Product

**Original Goal (preserved):** *Working Flutter app — photo + pet context → AI triage result — with auth and paywall. Prove the core value proposition works technically and experientially. A product that creates a genuine "wow" moment for a beta user.* (Weeks 2–4, 120h, Confidence: High)

> The original phase's "Execution Prompt (FOR AI AGENT)", "Architecture Constraints", "Coding Standards", "Security/Performance/Anti-Hallucination" blocks apply to **all** Phase 1 sub-phases and are reproduced once in the **AI-Agent Execution Guidance** section so each sub-phase PR can reference them.

---

## Phase 1.1 — App Skeleton, Auth & Data Layer

**Title:** Compilable Flutter shell + Supabase auth + migrated, RLS-secured schema.

**Objective:** Establish the app skeleton (Riverpod, go_router, Material 3), working authentication, and the full database schema with security policies — the substrate every other Phase 1 sub-phase writes against.

**Why this comes first:** Capture/upload (1.2), AI orchestration (1.3), and result/paywall (1.4) all read and write through this schema and auth context. Building it first lets 1.2 and 1.3 proceed in parallel against a stable contract. RLS must be proven with real user JWTs here, not bolted on later.

**Dependencies:** Phase 0 complete (Supabase, Doppler, CI/CD, Sentry).

**Deliverables:**
- Flutter project configured: Riverpod 2.x, go_router, Material 3 theme (teal `#00897B` / amber `#FFB300`).
- Supabase Flutter client + auth-state Riverpod provider.
- Apple Sign In + email auth flows.
- Supabase migration v1: **all tables** with indexes and RLS policies (per Section 5 schema).
- Edge Function `/auth-webhook`: create `users` row on new Supabase Auth signup.
- Sentry crash reporting initialized (early, to capture dev-time crashes).
- **Agreed shared `AnalysisResult` contract** documented as the source of truth for 1.3/1.4 (definition lands in code in 1.3, but the field list is frozen here to unblock parallel work).

**Tasks:**
- [ ] Flutter project: Riverpod, go_router, Material 3 theme (teal `#00897B` / amber `#FFB300`).
- [ ] Supabase Flutter client; auth state Riverpod provider.
- [ ] Apple Sign In + email auth flows.
- [ ] Supabase migration v1: all tables with indexes and RLS policies.
- [ ] Edge Function `/auth-webhook`: create `users` row on new Supabase Auth signup.
- [ ] Sentry crash reporting initialization.

**Validation Checklist:**
- [ ] App compiles and runs to a signed-in state on iOS simulator + Android emulator.
- [ ] Email + Apple sign-in both create a `users` row via `/auth-webhook`.
- [ ] **RLS verified with two real user JWTs:** user A cannot read or write user B's rows (test `pets`, `analyses`, `health_events`, `reminders`).
- [ ] All Section-5 indexes exist (`\di` lists them).
- [ ] Sentry receives a deliberately-thrown test exception.

**Definition of Done:** A user can sign in two ways, a `users` row is auto-provisioned, the full schema is migrated, and cross-user access is provably impossible under authenticated JWTs.

**Estimated Effort:** 30h.

**Execution Risks:** **The RLS policies as written in the source roadmap are non-functional** (no `WITH CHECK`, no INSERT policy, no policy at all on `health_events`/`reminders`/`analysis_feedback`/`referrals`) — this sub-phase will fail its own validation checklist until those are fixed. See Critical Review #2 for the exact correction; it is *not* silently applied here. The shared `AnalysisResult` schema lives in three languages (Dart/TS/Python) — agree the field list now to avoid drift (Critical Review #16).

---

## Phase 1.2 — Capture & Upload Pipeline

**Title:** Onboarding, pet setup, in-app camera, compression, and R2 upload — up to "we have an input + pet context."

**Objective:** Deliver everything needed to *produce an analysis input* — the 5-screen onboarding, pet CRUD, the quality-guided camera, client-side compression, R2 upload, and text input — with no AI yet. Output is a stored R2 key (or text) plus a pet profile.

**Why this comes second / parallel to 1.3:** This is pure client + storage work that depends only on auth + schema (1.1). It shares no code with the Python AI service (1.3), so the two can be built concurrently and meet at 1.4.

**Dependencies:** 1.1 (auth, `pets` table, R2 from Phase 0).

**Deliverables:**
- Onboarding 5-screen wizard with pet setup (name, species grid 🐶🐱🐰🦜🦎, breed typeahead, age picker, optional photo). *Screen 4 (push permission) is built as UI only here; OneSignal is wired in 2.1.*
- Pet profile CRUD screen.
- In-app camera module with real-time quality overlay (blur, lighting, framing hints).
- Image capture → compress to **<2MB** → upload to R2 → return storage key.
- Text symptom input screen with character guidance.
- PostHog `onboarding_step_completed`, `onboarding_completed` events.

**Tasks:**
- [ ] Onboarding 5-screen wizard with pet setup (name, species grid, breed typeahead, age picker, optional photo).
- [ ] Pet profile CRUD screen.
- [ ] In-app camera module: real-time quality overlay (blur, lighting, framing hints).
- [ ] Image capture: compress to <2MB → upload to R2 → return storage key.
- [ ] Text symptom input screen with character guidance.
- [ ] PostHog events on onboarding steps + completion.

**Validation Checklist:**
- [ ] A new user completes onboarding in **< 2 minutes** to the camera screen (per the design target).
- [ ] Captured image is verifiably **< 2MB** after compression before upload.
- [ ] Upload returns a valid R2 storage key; the object is retrievable with proper credentials.
- [ ] Pet CRUD round-trips (create/edit/delete) under RLS.
- [ ] Image upload to R2 completes in **< 2s on 4G** (per performance target).

**Definition of Done:** A user can onboard, create a pet, and produce either a compressed image in R2 (returning a key) or a text description — with PostHog tracking each onboarding step. No AI is invoked yet.

**Estimated Effort:** 30h.

**Execution Risks:** Camera permission flows differ on iOS vs. Android — test both on physical devices early (per original Risk Analysis). The **mechanism by which the client is authorized to upload to R2 is unspecified in the roadmap** (presigned PUT URLs vs. embedded credentials) — see Critical Review #6; do not ship embedded R2 write credentials. EXIF/GPS stripping on upload is a privacy gap (Critical Review #7).

---

## Phase 1.3 — AI Orchestration & Safety Core

**Title:** FastAPI `/analyze`, emergency override, Tier 2/3 routing, structured output, and the Edge Function that drives it.

**Objective:** Build the brain: the Python AI service (Gemini Flash Tier 2 → Claude Sonnet Tier 3, with hardcoded emergency override, confidence gating, cross-verification, prompt caching, structured output) and the Supabase Edge Function `/analyze` that validates input, loads pet context, enforces the free tier, calls the service, and stores the result.

**Why this comes third / parallel to 1.2:** It depends only on the schema + contract from 1.1 and shares no code with the Flutter capture work, so it runs concurrently with 1.2. It is the highest-effort, highest-risk sub-phase — isolating it keeps its blast radius contained and its tests focused.

**Dependencies:** 1.1 (schema, `AnalysisResult` contract, Fly placeholder from 0.3).

**Deliverables:**
- FastAPI app with `/analyze` endpoint; Pydantic request/response models.
- **Emergency keyword detection (hardcoded list, runs BEFORE any API call).**
- Gemini 2.0 Flash integration with JSON-schema enforcement (Tier 2).
- Claude Sonnet (`claude-sonnet-4-6`) integration with structured output via tool_use (Tier 3).
- Tier routing: confidence > 0.85 → Tier 2 result; else → Tier 3.
- EMERGENCY cross-verification: a second Claude Sonnet call confirms any EMERGENCY.
- Confidence gating: < 0.60 → "insufficient information" graceful response.
- System prompt v1 (species, breed, age, prior history, tone, anti-hallucination guards).
- Structured output schema `AnalysisResult` `{triage_level, confidence, primary_concern, visible_symptoms[], differential[], recommended_actions[], urgency_timeframe, disclaimer_required}`.
- Anthropic prompt caching on the system prompt.
- Upstash Redis basic result caching.
- Retry logic (1 retry on timeout) + graceful degradation on repeated failure.
- Structured JSON logging (mask API keys).
- Edge Function `/analyze`: validate input, load pet profile, check free-tier limit, call AI service, store result.
- Free-tier enforcement: check `free_analyses_used_this_month` before AI call; increment after.

**Tasks:**
- [ ] FastAPI app with `/analyze`; Pydantic request/response models.
- [ ] Emergency keyword detection (hardcoded, pre-AI).
- [ ] Gemini 2.0 Flash integration with JSON schema enforcement.
- [ ] Claude Sonnet integration with structured output (tool_use JSON pattern).
- [ ] Tier routing: confidence > 0.85 → Tier 2; else → Tier 3.
- [ ] EMERGENCY cross-verification (second Claude Sonnet call).
- [ ] Confidence gating < 0.60 → "insufficient information".
- [ ] System prompt v1 with anti-hallucination guards.
- [ ] `AnalysisResult` structured output schema.
- [ ] Anthropic prompt caching on system prompt.
- [ ] Upstash Redis basic result caching.
- [ ] Retry logic + graceful degradation.
- [ ] Structured JSON logging (mask API keys).
- [ ] Edge Function `/analyze`: validate, load pet profile, free-tier check, call AI, store result.
- [ ] Free-tier enforcement: check counter before, increment after.
- [ ] **Unit tests:** AI output parser (valid, invalid, malformed JSON); emergency override (all 14 hardcoded keywords); free-tier rate limiting (3 allowed, 4th blocked).

**Validation Checklist:**
- [ ] Emergency override catches **all 14 hardcoded trigger scenarios** and runs *before* any AI call.
- [ ] Temperature is **0.1** on every health-analysis call.
- [ ] Confidence < 0.60 returns "insufficient information" — never a fabricated answer.
- [ ] Every EMERGENCY classification triggers a cross-verification call.
- [ ] Off-schema AI responses are rejected and logged (parser unit tests green).
- [ ] 4th free analysis is blocked server-side; logs contain no PII / unmasked keys.
- [ ] Tier 2 P50 < 3s; Tier 3 P50 < 6s (per performance targets).

**Definition of Done:** Given a pet context + input, the service returns a schema-valid triage result through the correct tier, with emergency override and cross-verification provably active, free-tier enforced server-side, and all three unit-test suites green.

**Estimated Effort:** 40h.

**Execution Risks:** Claude JSON mode occasionally emits malformed output — the parser + retry path is mandatory, not optional (original Risk Analysis). Gemini self-reported confidence is **uncalibrated**; the 0.85 gate that lets 60% of queries skip the stronger model is a false-negative vector (Critical Review #4 and #5). **The semantic-cache step shown in the MVP data-flow diagram is not actually built until Phase 3, and nothing here populates the `embedding` column** (Critical Review #3). The model display name "Claude 3.5 Sonnet" in the source is stale relative to its own ID `claude-sonnet-4-6` — standardize on IDs (Critical Review #17).

---

## Phase 1.4 — Result UX, Monetization & End-to-End QA

**Title:** The screens that close the loop + RevenueCat paywall + the full QA pass that makes Phase 1 demoable.

**Objective:** Join 1.2 (input) and 1.3 (analysis) into a complete experience: loading → triage result → (EMERGENCY path with acknowledgment gate) → home screen, plus the RevenueCat paywall, growth hooks, full analytics, and the integration/widget/manual QA that proves the end-to-end flow on physical devices.

**Why this comes last:** It is the integration layer — it cannot start until both the input pipeline (1.2) and the analysis brain (1.3) exist. It is deliberately the smallest budget because it wires existing pieces rather than building new subsystems.

**Dependencies:** 1.2 and 1.3 both complete.

**Deliverables:**
- Analysis loading screen (animated, 4 rotating contextual messages).
- Result screen: color-coded triage badge (green/amber/red), "what we noticed" list, numbered "what to do" list, escalation triggers, disclaimer.
- EMERGENCY result screen: warm red, urgent copy, vet-finder deep link, **acknowledgment gate before dismissal**.
- Home screen: pet card (photo, name, last-check summary), "Check [Pet]" primary CTA, query counter.
- RevenueCat paywall: shown **after first successful analysis**; annual-first layout. (Free: 3/month; Premium: unlimited.)
- Edge Function `/revenuecat-webhook`: update `subscription_status` on entitlement change.
- Share button on LIKELY NORMAL results (copy + PawDoc watermark image).
- Referral code field + referral deep-link generation.
- PostHog events: `analysis_submitted`, `analysis_completed`, `result_viewed`, `emergency_triggered`, `paywall_shown`, `trial_started`, `subscription_converted`; RevenueCat → PostHog revenue sync.

**Tasks:**
- [ ] Analysis loading screen with 4 rotating messages.
- [ ] Result screen: triage badge, what-we-noticed, what-to-do, escalation triggers, disclaimer.
- [ ] EMERGENCY result screen: warm red, urgent copy, vet finder deep link, acknowledgment gate.
- [ ] Home screen: pet card, "Check [Pet]" CTA, query counter.
- [ ] RevenueCat paywall: post-first-analysis, annual-first.
- [ ] Edge Function `/revenuecat-webhook`: update `subscription_status`.
- [ ] Share button on LIKELY NORMAL results.
- [ ] Referral code field + deep link generation.
- [ ] PostHog key-action events + RevenueCat → PostHog revenue sync.
- [ ] **Integration tests:** full analysis flow with mocked AI responses.
- [ ] **Widget tests:** onboarding flow; result screen for all three triage levels.
- [ ] **Manual QA:** happy path on physical iPhone + Android; EMERGENCY flow (acknowledgment gate, vet-finder CTA); paywall (3 free, 4th blocked, RevenueCat flow).

**Validation Checklist:**
- [ ] End-to-end analysis works on **physical** iOS + Android devices.
- [ ] **EMERGENCY analyses are never blocked by the paywall** — explicit check confirmed in the Edge Function.
- [ ] Disclaimers are injected at the **API level** and present on every result (not removable by UI changes).
- [ ] Paywall appears only after the first successful analysis, never during onboarding or emergency flow, and never more than once/day.
- [ ] P95 latency **< 10s on WiFi**; all three triage result screens render correctly.
- [ ] App cold start **< 2s** on iPhone 12 / Pixel 6.

**Definition of Done:** A first-time user can go camera → AI → result on a real device, hit the paywall after their first analysis, and convert — with emergency flows un-paywalled, disclaimers API-injected, and integration/widget/manual QA all green. This is the "wow-moment" build for beta.

**Estimated Effort:** 20h.

**Execution Risks:** The "EMERGENCY never paywalled" rule is a trust-critical gate — make it an explicit, tested Edge Function check, not an implicit UI behavior. The push-permission Onboarding Screen 4 has no OneSignal behind it until 2.1, so don't let QA flag it as broken here. NSFW/content moderation is *claimed done* in the roadmap's validation table but exists in no Phase 1 task — it is genuinely absent (Critical Review #8).

---

# Phase 2 — MVP Polish & App Store Launch

**Original Goal (preserved):** *App Store approved, production-quality UX, first public users. First paying users. Establish App Store presence. Collect real user feedback for V1 iteration.* (Weeks 5–6, 80h, Confidence: Medium)

---

## Phase 2.1 — Production Polish & Hardening

**Title:** Every state handled, push wired, accessible, dark-mode, and within performance budget.

**Objective:** Take the functional Phase 1 build to production quality — all loading/error/empty/offline states, OneSignal integration behind the onboarding push screen, accessibility, dark mode, final icon/splash, deep links, and verified performance budgets.

**Why this comes first (within Phase 2):** Beta testers (2.3) must receive a polished, accessible, crash-resistant build; submitting an unpolished build wastes scarce App Store review cycles.

**Dependencies:** Phase 1 complete.

**Deliverables:**
- Final design polish on all loading, error, and empty states.
- Offline graceful-degradation messaging.
- OneSignal SDK integrated; permission request wired to Onboarding Screen 4.
- App icon (all required iOS + Android sizes) + splash screen.
- Deep link handling: referral codes; result share links.
- Accessibility: minimum contrast ratios, VoiceOver labels, dynamic type.
- Dark mode (follows system setting).
- Performance profiling: cold start < 2s; analysis memory < 150MB.

**Tasks:**
- [ ] Final design polish: all loading, error, empty states.
- [ ] Offline graceful degradation messaging.
- [ ] OneSignal SDK integration + permission request on Onboarding Screen 4.
- [ ] App icon (all sizes) + splash screen.
- [ ] Deep link handling: referral codes; result share links.
- [ ] Accessibility: contrast, VoiceOver labels, dynamic type.
- [ ] Dark mode (system setting).
- [ ] Performance profiling: cold start < 2s; analysis memory < 150MB.

**Validation Checklist:**
- [ ] No screen shows a raw spinner or blank state; every async path has a designed loading/error/empty state.
- [ ] Push permission prompt fires from Screen 4 and registers a OneSignal player ID.
- [ ] VoiceOver reads every interactive element; dynamic type scales without clipping; contrast passes WCAG AA.
- [ ] Dark mode renders all screens correctly.
- [ ] Cold start < 2s and analysis memory < 150MB on reference devices.

**Definition of Done:** The app is visually and functionally production-grade, accessible, push-capable, and inside its performance budget — ready to hand to beta testers.

**Estimated Effort:** 35h.

**Execution Risks:** OneSignal player-ID capture must reconcile with the `one_signal_player_id` column on `users`; verify the write path. Accessibility is easy to defer and hard to retrofit — do it here.

---

## Phase 2.2 — Legal, Compliance & Trust Gate

**Title:** E&O insurance, ToS, Privacy Policy, and disclaimer verification — the hard gate before any public release.

**Objective:** Put every legal safeguard in place *before* the product is exposed to the public, per the roadmap's explicit sequencing ("purchase E&O before public launch").

**Why this is a gate (and can run parallel to 2.1):** The legal work has no code dependency on polish, so it parallelizes with 2.1 — but it is a **hard blocker** on 2.3: no public submission proceeds until E&O is bound and ToS/Privacy are live.

**Dependencies:** Phase 1 complete (disclaimer injection to verify). Parallelizable with 2.1.

**Deliverables:**
- E&O insurance policy, **≥ $100K coverage**, purchased before public launch.
- Terms of Service live at `pawdoc.app/terms` (GDPR-compliant, affirmatively accepted).
- Privacy Policy live at `pawdoc.app/privacy` (covers US + EU users).
- Customer support email: `support@pawdoc.app`.
- Verification that disclaimers are injected at the API level on every result.

**Tasks:**
- [ ] E&O Insurance policy: $100K minimum coverage; purchase before public launch.
- [ ] Terms of Service: live at `pawdoc.app/terms`; GDPR-compliant.
- [ ] Privacy Policy: live at `pawdoc.app/privacy`; covers US + EU.
- [ ] Stand up `support@pawdoc.app`.

**Validation Checklist:**
- [ ] E&O certificate of insurance on file; coverage ≥ $100K; effective date precedes the planned public-launch date.
- [ ] `pawdoc.app/terms` and `pawdoc.app/privacy` resolve and are linked from the app + App Store listing.
- [ ] ToS requires affirmative acceptance at signup.
- [ ] Disclaimer text appears on a sampled set of live results, sourced from the API payload.
- [ ] `support@pawdoc.app` receives and routes test mail.

**Definition of Done:** Insurance is bound, both legal documents are live and linked, ToS is affirmatively gated, disclaimers are confirmed API-level, and support email works. The legal gate to public launch is open.

**Estimated Effort:** 15h.

**Execution Risks:** E&O underwriting for an AI health-adjacent product can take longer than expected and may probe the "not veterinary diagnosis" framing — start the application at the *beginning* of Phase 2, not the end. The roadmap's "store every analysis permanently for legal record" conflicts with its own GDPR "right to deletion / 30-day purge" promise (Critical Review #9) — resolve the legal-hold-vs-erasure policy before ToS goes live.

---

## Phase 2.3 — Beta, Store Submission & Public Launch

**Title:** 50-user TestFlight beta, App Store + Play submission, and the rating gate to public release.

**Objective:** Validate with a real beta cohort, submit to both stores with carefully framed review notes and ASO metadata, clear the ≥ 4.0 rating gate, and go public.

**Why this comes last:** It requires both a polished build (2.1) and the legal gate (2.2). It also carries the longest external dependency (Apple health-app review), so it is isolated to absorb review churn without blocking other work.

**Dependencies:** 2.1 (polished build) + 2.2 (legal gate). Original gate: "Phase 1 complete + beta tested on 20+ users."

**Deliverables:**
- iOS App Store submission: binary + metadata (title `PawDoc: AI Pet Health`, subtitle `Know When to Call the Vet`, description, optimized keywords, 10 screenshots, preview video if possible).
- App Store review notes: "AI-assisted information tool, not veterinary service. All results include clear disclaimers."
- Google Play submission: AAB bundle + store listing.
- Soft launch: 50 beta users via TestFlight; ≥ 4.0 average rating before public.
- Production infrastructure verified.

**Tasks:**
- [ ] iOS App Store: binary + metadata (title, subtitle, description, keywords, 10 screenshots, preview video if possible).
- [ ] App Store review notes (AI-assisted info tool framing).
- [ ] Google Play: AAB bundle + store listing.
- [ ] Soft launch: 50 beta users via TestFlight; minimum 4.0 avg rating before public.

**ASO Keywords (Apple, ≤100 chars) — preserved:** `symptom,checker,dog,cat,sick,emergency,vet,triage,diagnosis,rabbit,puppy,monitor`

**Screenshot order — preserved:** (1) "Know exactly what your pet needs." + result; (2) How it works: camera → AI → result; (3) "No more 2am anxiety spirals." + NORMAL result; (4) Trust: "Reviewed by veterinary experts"; (5) Feature breadth: multi-pet, history, reminders.

**Validation Checklist:**
- [ ] App Store approval **without a P0 rejection**.
- [ ] 50 beta users with **average rating > 4.0**.
- [ ] Analysis flow **P95 < 10s on 4G**.
- [ ] **Zero P0 bugs** in beta.

**Definition of Done:** Both stores have approved the app, the beta cohort rates it ≥ 4.0 with no P0 bugs, and the app is publicly available.

**Estimated Effort:** 30h.

**Execution Risks:** Apple health-app review takes 2–3 weeks and often requires 2–3 rejections — avoid all "diagnosis" language in metadata; lean on the review notes. Google Play is faster but also scrutinizes health apps. Budget 4–6 weeks of calendar time even though the build effort is 30h. App Store now mandates in-app account deletion (guideline 5.1.1(v)) — which the roadmap never sequences (Critical Review #9); this can itself trigger a rejection.

---

# Phase 3 — V1 Core Growth Features

**Original Goal (preserved):** *Video analysis, multi-pet management, health history, vet finder, referral program. Reach $5K MRR. Build the retention features that create stickiness beyond the acute symptom event.* (Weeks 7–12, 180h, Confidence: Medium)

---

## Phase 3.1 — Health History & Multi-Pet Foundation

**Title:** The retention substrate — timeline, manual events, multi-pet switching, breed insight cards.

**Objective:** Build the data-ownership features that make the app sticky between symptom events: a health-history timeline, manual health-event logging, a multi-pet switcher, and breed-specific insight cards on the home screen.

**Why this comes first (within Phase 3):** These are pure data + UI features (no new external APIs) that establish the "emotional ownership" retention loop the roadmap relies on, and they create the surfaces (history, multi-pet) that later sub-phases (notifications, video) attach to.

**Dependencies:** Phase 2 launched; 100+ active users providing real data.

**Deliverables:**
- Health history timeline (analyses + manual health events).
- Manual health-event quick-add (type, date, notes).
- Multi-pet switcher on the home screen (up to 2 pets Premium, unlimited Family).
- Breed data table (static breed health characteristics, cached in Supabase) + rotating breed insight cards on home.
- Analytics: `health_event_logged`, `multi_pet_added`.

**Tasks:**
- [ ] Health history screen: timeline view; analyses + manual events.
- [ ] Manual health event quick-add: type, date, notes.
- [ ] Multi-pet switcher: pet selector on home screen.
- [ ] Breed data table: static breed health characteristics; cached in Supabase.
- [ ] Breed insight cards: rotating contextual content on home.
- [ ] Analytics: `health_event_logged`, `multi_pet_added`.

**Validation Checklist:**
- [ ] Timeline correctly interleaves analyses and manual events in chronological order, scoped by RLS.
- [ ] Manual event add round-trips and appears immediately in the timeline.
- [ ] Multi-pet switcher enforces tier limits (2 Premium / unlimited Family) and switches all home context.
- [ ] Breed cards render for the pet's breed and rotate.
- [ ] Both analytics events fire.

**Definition of Done:** A user with multiple pets can switch between them, view a combined health timeline, log manual events, and see breed-relevant cards — all tier-gated and tracked.

**Estimated Effort:** 40h.

**Execution Risks:** The `health_events`/`reminders` tables still need working RLS INSERT policies (Critical Review #2) — if 1.1 didn't fix them, manual event logging fails here. Breed data sourcing/accuracy is a content task that can balloon; scope to top breeds first.

---

## Phase 3.2 — Video Analysis Pipeline

**Title:** Video capture → keyframe extraction → Gemini video path, plus the semantic cache the architecture already promised.

**Objective:** Extend the analysis pipeline to video (in-app capture, client-side keyframe extraction, Edge Function video path to the Gemini video API) and implement the semantic-cache logic that the MVP architecture diagram referenced but that was deferred to Phase 3 by the roadmap's own "issues found" table.

**Why this is sequenced here:** Video reuses the analysis plumbing from Phase 1 and is the most engineering-heavy V1 feature; the semantic cache belongs with it because both touch the AI service and the `embedding` column, and caching becomes valuable once analysis volume grows.

**Dependencies:** Phase 1.3 (AI service + `/analyze`), Phase 3.1 (history surfaces to display results in).

**Deliverables:**
- In-app video capture (max 30s, quality guidance).
- Client-side keyframe extraction (`flutter_ffmpeg`): 4–6 frames per video.
- Edge Function video path → Gemini video API.
- Semantic-cache logic: generate the `embedding` per analysis, pgvector similarity lookup (>90% → cache hit).
- Analytics: `video_analysis_submitted`.

**Tasks:**
- [ ] Video capture: in-app camera video mode (max 30s); quality guidance.
- [ ] Client-side keyframe extraction (`flutter_ffmpeg`): 4–6 frames from video.
- [ ] Video analysis path: Edge Function handles video input; sends to Gemini video API.
- [ ] Semantic cache logic (pgvector similarity matching; populate + query `embedding`).
- [ ] Analytics: `video_analysis_submitted`.

**Validation Checklist:**
- [ ] A 30s video yields 4–6 keyframes client-side and a valid triage result.
- [ ] **Video analysis P95 latency < 15s.**
- [ ] Embeddings are written for new analyses; a near-duplicate query returns a cache hit at >90% similarity.
- [ ] `video_analysis_submitted` fires.

**Definition of Done:** Users can submit a video and receive a triage result within the latency budget, and the semantic cache demonstrably serves near-duplicate queries from pgvector.

**Estimated Effort:** 50h.

**Execution Risks:** `flutter_ffmpeg` is heavy and has had maintenance/licensing churn — confirm a supported package before committing. **Nothing in Phase 1 populated `embedding`, and the MVP data-flow diagram implied caching that didn't exist** (Critical Review #3) — this sub-phase is where that debt is paid; budget for backfilling embeddings on historical rows. The video model is referenced inconsistently in the source ("Gemini video API" / "Gemini 1.5 Pro" / "Gemini 2.0 Flash") — pin one version (Critical Review #17).

---

## Phase 3.3 — Engagement & Notification Systems

**Title:** Reminders, follow-ups, seasonal alerts, and the live referral program — the push-driven return loops.

**Objective:** Build the notification and referral machinery that drives D2/D7/D30 returns: vaccination/medication reminders via cron, the 48h MONITOR follow-up, seasonal alerts, Android notification channels, and the live referral program with RevenueCat entitlement extension.

**Why this comes here:** It depends on the history/pet data from 3.1 (to know what to remind about) and OneSignal from 2.1, and it operationalizes the roadmap's retention-loop design.

**Dependencies:** 3.1 (pets/events to remind on), 2.1 (OneSignal).

**Deliverables:**
- Reminder cron (daily Edge Function; reminders due in 7 days; push via OneSignal).
- Vaccination reminder setup (species-based schedule pre-fill; custom additions).
- 48h follow-up system (if last analysis = MONITOR, push after 48h).
- Seasonal alert system (monthly cron; breed-specific seasonal content to relevant segments).
- Android notification channels (health alerts, reminders, follow-ups).
- Referral program live (personal links, conversion tracking, RevenueCat entitlement extension).
- Review request v2 (after 3rd health-history event logged).
- Analytics: `reminder_set`.

**Tasks:**
- [ ] Reminder cron job: daily Edge Function; check reminders due in 7 days; push via OneSignal.
- [ ] Vaccination reminder setup: species-based schedule pre-fill; custom additions.
- [ ] 48h follow-up system: if last analysis = MONITOR, send follow-up push after 48h.
- [ ] Seasonal alert system: monthly cron; breed-specific seasonal content to segments.
- [ ] Android notification channels: health alerts, reminders, follow-ups.
- [ ] Referral program live: personal links, conversion tracking, RevenueCat entitlement extension.
- [ ] Review request v2: after 3rd health history event logged.
- [ ] Analytics: `reminder_set`.

**Validation Checklist:**
- [ ] A reminder due in 7 days triggers exactly one OneSignal push; `is_sent`/`notification_sent_at` update.
- [ ] A MONITOR analysis produces a follow-up push at ~48h.
- [ ] Android channels are individually toggleable in system settings.
- [ ] A referred friend who subscribes grants the referrer a 1-month entitlement extension; conversion is tracked.
- [ ] Review prompt appears after the 3rd logged event.

**Definition of Done:** Reminders, follow-ups, and seasonal alerts fire correctly via cron + OneSignal, Android channels are in place, and the referral loop pays out on real conversions.

**Estimated Effort:** 45h.

**Execution Risks:** **No monthly job resets `free_analyses_used_this_month`** anywhere in the roadmap (Critical Review #10) — the daily reminder cron is the natural place to add a monthly reset, but it is *not* in the original tasks; flag, don't silently add. Referral payout abuse (fake-email farming of the 3 bonus analyses) needs fraud controls (Critical Review #14). OneSignal + APNs/FCM credential setup is fiddly across both platforms.

---

## Phase 3.4 — Vet Finder, Widgets & Android Parity

**Title:** Vet finder + Airvet deep links, home-screen widgets, full Android parity, and the first SEO articles.

**Objective:** Ship the location-based vet finder (via a key-hiding Google Places proxy), Airvet referral deep links on EMERGENCY/low-confidence results, iOS + Android widgets, a full Android feature-parity sweep, and the first 5 SEO articles.

**Why this comes last (within Phase 3):** Widgets and Android parity validate the *whole* feature set built in 3.1–3.3, so they belong at the end; the vet finder + Airvet links open the Phase-3 referral revenue stream.

**Dependencies:** 3.1–3.3 (parity sweep needs the full feature set; Airvet links attach to the result screen).

**Deliverables:**
- Vet finder (Google Places via Edge Function proxy that hides the API key; nearest 5; emergency filter; call + directions CTA).
- Airvet deep link on EMERGENCY result + low-confidence result.
- iOS Widget (WidgetKit): pet name, last-check status, "Check [Pet]" button.
- Android Widget (AppWidgetProvider): equivalent to iOS.
- Full Android parity (camera, video, widgets, notifications matched to iOS).
- First 5 SEO articles published at `pawdoc.app/blog`.
- Analytics: `vet_finder_opened`, `airvet_clicked`, `widget_installed`; D7/D30 cohort retention by feature usage; Airvet referral tracking via UTM.

**Tasks:**
- [ ] Vet finder: location-based Google Places results; emergency filter; call + directions CTA.
- [ ] Google Places proxy: Edge Function proxies queries (hides API key).
- [ ] Airvet deep link: shown on EMERGENCY result + low-confidence result.
- [ ] iOS Widget (WidgetKit): pet name, last check status, "Check [Pet]" button.
- [ ] Android Widget (AppWidgetProvider): equivalent.
- [ ] Full Android parity sweep.
- [ ] First 5 SEO articles at `pawdoc.app/blog`.
- [ ] Analytics: `vet_finder_opened`, `airvet_clicked`, `widget_installed`; D7/D30 cohort retention by feature; Airvet UTM tracking.

**Validation Checklist:**
- [ ] Vet finder returns the nearest 5 vets with working call + directions; the Places API key never reaches the client.
- [ ] Airvet deep link appears on EMERGENCY and low-confidence results and tracks via UTM.
- [ ] Both widgets render live pet status and deep-link into a check.
- [ ] Android feature set matches iOS (camera, video, widget, notifications) on a physical device.
- [ ] 5 SEO articles live with proper metadata.

**Definition of Done (Phase 3 exit gate):** Vet finder + Airvet links live, widgets shipped on both platforms, Android at parity, first SEO articles published — and the Phase-3 Success Metrics are trackable: $5K MRR, D7 ≥ 32%, 25% of Premium using history, first $500 Airvet revenue, video P95 < 15s.

**Estimated Effort:** 45h.

**Execution Risks:** Android parity is platform-specific and routinely runs ~30% over (original bottleneck note) — protect this budget. WidgetKit and AppWidgetProvider share no code; treat them as two builds. Google Places billing can surprise — set a budget alert (Critical Review #12).

---

# Phase 4 — V1 Monetization & Retention Optimization

**Original Goal (preserved):** *$10K MRR. A/B test the conversion funnel. Launch paid acquisition. Achieve LTV:CAC > 3:1 on paid acquisition. Establish content/SEO flywheel.* (Weeks 13–16, 120h, Confidence: Medium)

---

## Phase 4.1 — Experimentation Infrastructure

**Title:** Feature-flag variant assignment, A/B dashboards, and in-app feedback capture.

**Objective:** Build the measurement backbone — PostHog feature-flag variant assignment, A/B dashboards, in-app thumbs-up/down feedback, and the 72h "was this helpful?" follow-up — *before* running any experiment.

**Why this comes first:** You cannot trust experiment results (4.2) without correct variant assignment and dashboards first. The feedback widgets also seed the outcome data the roadmap later turns into a training signal.

**Dependencies:** Phase 3 complete; real retention data from 500+ users.

**Deliverables:**
- PostHog feature flags for A/B variant assignment.
- A/B test dashboards (variant completion + conversion rates).
- In-app feedback: thumbs up/down on the result screen; optional comment.
- 72h follow-up prompt: "Was this assessment helpful?"

**Tasks:**
- [ ] PostHog feature flags for A/B variant assignment.
- [ ] A/B test dashboards: variant completion + conversion rates.
- [ ] In-app feedback: thumbs up/down on result screen; optional comment.
- [ ] Analysis follow-up: 72h prompt "Was this assessment helpful?"

**Validation Checklist:**
- [ ] Users are deterministically and stably bucketed into variants (same user → same variant across sessions).
- [ ] Dashboards show per-variant completion + conversion with sample-size counts.
- [ ] Thumbs up/down + comment persist (to `analysis_feedback`) and are queryable.
- [ ] 72h follow-up fires once per eligible analysis.

**Definition of Done:** Variant assignment is stable and observable, dashboards report per-variant funnels, and result feedback + 72h follow-up are capturing data.

**Estimated Effort:** 35h.

**Execution Risks:** `analysis_feedback` has no RLS in the source schema (Critical Review #2) — fix before writing user outcomes to it. Flag-bucketing bugs silently corrupt every downstream experiment; test stability explicitly.

---

## Phase 4.2 — Onboarding & Paywall Experiments

**Title:** Run the onboarding and paywall variants; pick winners on real conversion data.

**Objective:** Implement and run the roadmap's onboarding variants (B: paywall on Screen 2; C: late paywall) and paywall variants (B: monthly-featured; C: testimonial + vet photo), and identify statistically valid winners.

**Why this comes second:** It depends entirely on the experimentation infra from 4.1, and the minimum-sample requirement (500/variant) means it needs the user volume that 4.1's prerequisite provides.

**Dependencies:** 4.1 (flags + dashboards).

**Deliverables:**
- Onboarding Variant B (paywall on Screen 2 — aggressive).
- Onboarding Variant C (no paywall in onboarding — late paywall).
- Paywall Variant B (monthly price featured; annual as "best value" badge).
- Paywall Variant C (testimonial + vet advisor photo on paywall).
- Identified winning onboarding + paywall variants.

**Tasks:**
- [ ] Onboarding Variant B: paywall on Screen 2 (aggressive).
- [ ] Onboarding Variant C: no paywall in onboarding (late paywall).
- [ ] Paywall Variant B: monthly featured, annual "best value" badge.
- [ ] Paywall Variant C: add testimonial + vet advisor photo to paywall.

**Validation Checklist:**
- [ ] Each variant reaches ≥ 500 users (per the 80%-power minimum) before a decision.
- [ ] Trial-start and trial-to-paid rates are reported per variant with confidence intervals.
- [ ] Winners are documented and rolled out to 100%.

**Definition of Done:** All four variants ran to adequate sample size, winners are chosen on conversion data, and the winning variants are live for all users.

**Estimated Effort:** 40h.

**Execution Risks:** Calling winners before 500/variant is the classic A/B mistake — enforce the sample gate. The "annual-first" strategic default must remain the control, not be A/B'd away on a noisy read.

---

## Phase 4.3 — Web Presence & Paid Acquisition

**Title:** Landing page, SEO content engine, and the first paid channels.

**Objective:** Stand up the Next.js landing page + blog, publish 10 SEO articles, wire Search Console, and launch the first paid campaigns (Apple Search Ads + a TikTok test) with ROI dashboards.

**Why this comes last:** Paid acquisition should point at a funnel with a *winning* onboarding/paywall (4.2), and the SEO flywheel and landing page are the organic complement to paid spend.

**Dependencies:** 4.2 (winning funnel to send paid traffic into).

**Deliverables:**
- Next.js landing page on Cloudflare Pages (value prop above fold, screenshots, App Store badges, social proof).
- Blog infrastructure (MDX articles with SEO metadata).
- 10 SEO articles live.
- Google Search Console integration.
- First paid campaigns: Apple Search Ads (5 exact-match keywords) + TikTok ($500 test).
- Paid-acquisition ROI dashboards (cost per install/trial/subscriber by channel).

**Tasks:**
- [ ] Landing page: value prop above fold; screenshots; App Store badges; social proof.
- [ ] Blog infrastructure: MDX articles with SEO metadata.
- [ ] 10 SEO articles (target keywords per Growth Strategy report).
- [ ] Google Search Console integration.
- [ ] Apple Search Ads (5 exact-match keywords) + TikTok ($500 test).
- [ ] Paid ROI dashboards: cost per install/trial/subscriber by channel.

**Validation Checklist:**
- [ ] Landing page is live on `pawdoc.app`, scores well on Core Web Vitals, and links to both stores.
- [ ] 10 articles indexed; Search Console verified and receiving impressions.
- [ ] Paid campaigns spending with per-channel CPI/trial/subscriber attribution flowing to the dashboard.

**Definition of Done (Phase 4 exit gate):** Web + content engine live, paid channels running with measured ROI, and Phase-4 Success Metrics trackable: $10K MRR, winning variants identified, paid CAC < $15, 5 articles in top-20, D30 ≥ 25%.

**Estimated Effort:** 45h.

**Execution Risks:** The roadmap's blended CAC of $5–12 and 10% free-to-paid are optimistic for consumer health apps (Critical Review #15) — treat the first campaigns as price discovery, not scale. SEO writing competes with engineering time for a solo founder (original bottleneck) — consider a freelance vet writer.

---

# Phase 5 — V2 Platform Expansion

**Original Goal (preserved):** *Exotic species, web symptom checker, AI health journal, embedded telehealth. $25K MRR. Open exotic species niche (40–60% higher WTP). Content-driven organic growth.* (Months 5–7, 240h, Confidence: Low-Medium)

---

## Phase 5.1 — Exotic Species Expansion

**Title:** Rabbits, guinea pigs, birds, reptiles — species-specific prompts and safety.

**Objective:** Open the high-WTP exotic niche by adding rabbits, guinea pigs, birds, and reptiles with dedicated AI prompts per species (and species-specific emergency considerations).

**Why this comes first (within Phase 5):** It reuses the existing analysis pipeline with new prompts — the lowest-integration, highest-WTP lever — and the onboarding species grid already includes exotic icons (🐰🦜🦎), so the surface exists.

**Dependencies:** Phase 4 complete; stable $10K+ MRR; 4.5+ App Store rating.

**Deliverables:**
- Exotic species supported: rabbits, guinea pigs, birds, reptiles.
- Separate AI prompts per species.
- Species-specific emergency-keyword sets and safety handling.

**Tasks:**
- [ ] Add exotic species to species model + onboarding grid wiring.
- [ ] Author separate AI system prompts per species (rabbit, guinea pig, bird, reptile).
- [ ] Per-species emergency-keyword handling.
- [ ] Per-species QA on representative cases.

**Validation Checklist:**
- [ ] Each new species routes to its dedicated prompt and returns species-appropriate triage.
- [ ] Species-specific emergencies (e.g., avian/reptile red flags) trigger correctly.
- [ ] Onboarding lets users create exotic pets end-to-end.

**Definition of Done:** All four exotic species are selectable, analyzed with species-specific prompts, and safety-checked — toward the "5% of users are exotic" metric.

**Estimated Effort:** 60h.

**Execution Risks:** Exotic-species clinical accuracy requires real domain expertise — vet-advisor review of these prompts is strongly advisable. The hardcoded emergency keyword list is English-only and substring-matched (Critical Review #11), which is even riskier for low-data exotic species.

---

## Phase 5.2 — Web Symptom Checker

**Title:** Free, no-account web checker at `pawdoc.app/check` as a top-of-funnel growth loop.

**Objective:** Ship a free, no-account-required symptom checker on the web that reuses the AI service and converts anonymous users into app installs.

**Why this comes here:** It is a distinct surface (web) that reuses the AI backend; it powers content-driven organic growth, the stated Phase-5 business goal.

**Dependencies:** Phase 1.3 AI service; Phase 4.3 web infrastructure (Next.js/Cloudflare Pages).

**Deliverables:**
- Free web symptom checker at `pawdoc.app/check`, no account required.
- Abuse controls for anonymous traffic (IP rate limiting / captcha).
- Conversion funnel from web result → app install.

**Tasks:**
- [ ] Build `pawdoc.app/check` calling the AI service (anonymous path).
- [ ] Anonymous abuse controls: IP-based rate limiting / captcha.
- [ ] App-install conversion funnel + tracking.

**Validation Checklist:**
- [ ] Anonymous user gets a triage result with no signup.
- [ ] Abuse controls cap anonymous usage and block obvious automation.
- [ ] Web → install conversion is tracked; target 5K unique uses/month is measurable.

**Definition of Done:** The web checker serves anonymous triage with abuse protection and a tracked path to install.

**Estimated Effort:** 55h.

**Execution Risks:** Anonymous traffic has no per-user identity, so the existing per-user rate limit doesn't protect it — IP/captcha controls and a global AI spend alarm are essential (Critical Review #5, #13). Free anonymous AI is a cost-abuse magnet; cap aggressively.

---

## Phase 5.3 — AI Health Journal

**Title:** Weekly GPT-4o-synthesized health narrative per pet.

**Objective:** Add an opt-in weekly health journal that synthesizes each pet's recent analyses and events into a readable narrative using GPT-4o.

**Why this comes here:** It is a retention/engagement layer that depends on accumulated history (Phase 3.1) and adds a new provider (OpenAI) to the stack — isolating it contains that integration.

**Dependencies:** Phase 3.1 (history data), Phase 1.3 (AI service patterns).

**Deliverables:**
- Weekly GPT-4o-synthesized health narrative per pet (cron-generated, opt-in).
- In-app surface for the journal.

**Tasks:**
- [ ] GPT-4o integration for narrative synthesis.
- [ ] Weekly cron to generate per-pet narratives (opt-in only).
- [ ] In-app journal display.

**Validation Checklist:**
- [ ] Weekly narrative generates for opted-in pets and reads coherently from their real history.
- [ ] Opt-out suppresses generation.
- [ ] Narrative carries the same disclaimer guarantees as analyses.

**Definition of Done:** Opted-in users receive an accurate weekly narrative synthesized from their pet's history.

**Estimated Effort:** 50h.

**Execution Risks:** Adding a third AI provider (OpenAI) widens the provider-outage surface with no failover described (Critical Review #5). Narratives can hallucinate trends across sparse history — bound them with anti-hallucination guards consistent with the analysis pipeline.

---

## Phase 5.4 — Embedded Telehealth, Localization & B2B Lite

**Title:** In-app Airvet consults, German launch, and the dog-walker/sitter plan.

**Objective:** Deepen monetization and reach: embed Airvet video consultations (revenue share), localize to German with an App Store submission, and launch a B2B-lite multi-client plan for pet sitters/walkers ($19.99/mo with sitter mode).

**Why this comes last (within Phase 5):** These are three larger, more external-dependency-heavy initiatives (partner integration, localization review, new plan/billing) best tackled after the lighter expansion levers land.

**Dependencies:** 3.4 (Airvet deep-link relationship), 4.x (paywall/RevenueCat for the new plan).

**Deliverables:**
- Embedded Airvet in-app video consultations (revenue share).
- German localization + German App Store submission.
- B2B-lite dog walker / pet sitter multi-client plan ($19.99/month) + sitter mode.

**Tasks:**
- [ ] Embedded Airvet: in-app video consultations (revenue share).
- [ ] German localization (strings, ASO) + App Store submission.
- [ ] B2B-lite multi-client plan ($19.99/mo) + sitter mode.

**Validation Checklist:**
- [ ] An in-app Airvet consult can be initiated and revenue-share is attributed.
- [ ] German build passes localization QA and is submitted.
- [ ] Sitter plan supports multiple clients under one account with correct entitlement.

**Definition of Done (Phase 5 exit gate):** Embedded telehealth, German localization, and the B2B-lite plan are live — toward Phase-5 metrics: $25K MRR, 5% exotic users, 5K web-checker uses/month, $2K/month Airvet revenue.

**Estimated Effort:** 75h.

**Execution Risks:** German launch makes the **English-only emergency keyword override a live safety hole for German users** (Critical Review #11) — localize the safety net *before* the German submission, not after. Embedded telehealth may pull the app into stricter App Store medical-service review.

---

# Phase 6 — V2 Revenue Optimization

**Original Goal (preserved):** *$50K MRR. Personalization engine. Insurance affiliates. Data moat begins.* (Months 7–9, 240h, Confidence: Low-Medium)

---

## Phase 6.1 — Personalization Engine

**Title:** Breed + age + history injected into every analysis prompt.

**Objective:** Deepen analysis quality (and the data moat) by injecting breed, age, and longitudinal history into every analysis prompt.

**Why this comes first (within Phase 6):** It upgrades the core analysis the rest of the product depends on, and it is the foundation of the "data moat begins" theme — better personalization both improves results and generates richer signal.

**Dependencies:** Phase 3.1 (history), Phase 1.3 (prompt pipeline).

**Deliverables:**
- Personalization engine: breed + age + history injected into every analysis prompt.

**Tasks:**
- [ ] Build the context-assembly layer that injects breed + age + prior history into each prompt.
- [ ] Regression-check that personalization improves (or holds) result quality.

**Validation Checklist:**
- [ ] Every analysis prompt includes the pet's breed, age, and relevant history.
- [ ] Personalized results measurably differ from generic on test cases without regressing safety.

**Definition of Done:** All analyses run through the personalization layer with breed/age/history context.

**Estimated Effort:** 80h.

**Execution Risks:** Without a golden-set eval (Critical Review #4), there's no way to prove personalization didn't regress safety — this is the strongest argument for building that eval harness before/with this sub-phase. Larger prompts raise token cost; lean on prompt caching.

---

## Phase 6.2 — Outcome Feedback Loop & Data Foundation

**Title:** "What happened?" 72h follow-up → the proprietary training dataset begins.

**Objective:** Close the outcome loop with a "What happened?" 72h follow-up writing structured outcomes to `analysis_feedback`, and begin accumulating the labeled dataset that underpins the long-term model moat.

**Why this comes here:** It is the moat seed the whole V3 fine-tuning plan depends on — the earlier it runs, the more data compounds. It builds on the feedback widgets from 4.1.

**Dependencies:** 4.1 (feedback capture), 6.1 (richer per-analysis context to label).

**Deliverables:**
- Outcome feedback loop: "What happened?" 72h follow-up (model-accuracy signal).
- Accumulating outcome dataset (toward 10K+ data points).

**Tasks:**
- [ ] "What happened?" 72h follow-up capturing structured outcomes to `analysis_feedback`.
- [ ] Outcome dashboards (model accuracy signal: false-negative/false-positive proxies).

**Validation Checklist:**
- [ ] Follow-up captures outcome categories (`resolved_on_own`, `vet_confirmed`, `vet_said_nothing`, `still_monitoring`, `other`) + rating.
- [ ] Outcomes are queryable and dashboards surface accuracy proxies.
- [ ] Toward 10K+ outcome data points (tracked).

**Definition of Done:** Outcome feedback flows into `analysis_feedback`, and accuracy-signal dashboards exist — the training dataset is accumulating.

**Estimated Effort:** 70h.

**Execution Risks:** This is the only systematic mechanism for detecting the **false negatives that are the stated #1 business risk** — its value depends on response rates, so design the follow-up for high engagement. `analysis_feedback` RLS must be correct (Critical Review #2).

---

## Phase 6.3 — Revenue Add-ons

**Title:** Insurance affiliates, exportable PDF health reports, and family sharing.

**Objective:** Add three monetization/retention levers: pet-insurance affiliate links with attribution, exportable branded PDF health reports ($4.99 add-on), and family sharing.

**Why this comes last (within Phase 6):** These are revenue-surface features that benefit from the richer personalized data (6.1) and the outcome signal (6.2), and they are independent enough to ship after the data foundation.

**Dependencies:** 6.1, 6.2; Phase 3.1 (history to export); RevenueCat (add-on purchase).

**Deliverables:**
- Pet insurance affiliate: Trupanion + Healthy Paws deep links with attribution.
- Branded health reports: exportable PDF for vet visits ($4.99 add-on).
- Family sharing: invite family members to shared pet access.

**Tasks:**
- [ ] Pet insurance affiliate: Trupanion + Healthy Paws deep links with attribution.
- [ ] Branded health reports: exportable PDF ($4.99 add-on).
- [ ] Family sharing: invite family members to shared pet access.

**Validation Checklist:**
- [ ] Affiliate clicks are attributed to Trupanion/Healthy Paws.
- [ ] PDF report exports a pet's history in a vet-presentable format; $4.99 purchase flows through RevenueCat.
- [ ] Invited family members get correctly-scoped shared access under RLS.

**Definition of Done (Phase 6 exit gate):** Insurance affiliates, PDF reports, and family sharing are live — toward Phase-6 metrics: $50K MRR, $3K/month insurance, 500+ reports/month, 10K+ outcome data points.

**Estimated Effort:** 90h.

**Execution Risks:** Family sharing changes the RLS model from "one user owns rows" to "a group can access rows" — this is a non-trivial security redesign, not a UI feature; budget for it and re-test cross-user isolation. PDF generation of health data is a new PII-export surface — log/secure it.

---

# Phase 7 — V3 Infrastructure & B2B Foundation

**Original Goal (preserved):** *100K+ MAU infrastructure hardening. B2B API v1. Community features. $75K MRR; 99.9%+ uptime.* (Months 10–14, 400h, Confidence: Low — explicitly "not solo-friendly.")

---

## Phase 7.1 — Infrastructure Hardening & Scale

**Title:** Read replicas, pgBouncer, autoscaling, partitioning, blob offload — the 100K-MAU substrate.

**Objective:** Realize the Section-5 "Scaling Concerns" table: read replicas, pgBouncer connection pooling, Fly.io autoscaling, monthly partitioning of `analyses`, and moving large JSONB AI responses to R2 blobs.

**Why this comes first (within Phase 7):** Everything else in V3 (B2B API load, community, model serving) assumes the platform can take 100K+ MAU without falling over; harden the substrate before piling load on it.

**Dependencies:** Phase 6 complete; sustained high MAU.

**Deliverables:**
- Read replicas; analytics queries routed to replica.
- pgBouncer enabled (Supabase Pro).
- Fly.io autoscaling for the AI service.
- DB partitioning: `analyses` by `created_at` (monthly).
- JSONB AI responses moved to R2 blobs (pointer stored in DB).

**Tasks:**
- [ ] Enable read replicas; route analytics to replica.
- [ ] Enable pgBouncer (Supabase Pro).
- [ ] Configure Fly.io autoscaling.
- [ ] Partition `analyses` by `created_at` (monthly).
- [ ] Move AI responses to R2 blobs; store pointer in DB.

**Validation Checklist:**
- [ ] Analytics load hits the replica, not primary.
- [ ] Connection count stays healthy under 200+ concurrent users (pgBouncer active).
- [ ] AI service scales out under load and back down after.
- [ ] New `analyses` rows land in the correct monthly partition.
- [ ] **System uptime 99.9%+ over a rolling 30 days.**

**Definition of Done:** The platform sustains 100K+ MAU patterns with replicas, pooling, autoscaling, partitioning, and blob offload — at 99.9%+ uptime.

**Estimated Effort:** 120h.

**Execution Risks:** Until autoscaling lands here, the AI service is a **single Fly machine — a single point of failure for all triage** (Critical Review #5) since launch; a viral spike before Phase 7 could take the whole product down. Partitioning a live `analyses` table requires a careful migration; rehearse on a copy.

---

## Phase 7.2 — Longitudinal Monitoring

**Title:** AI baseline detection for chronic-condition drift.

**Objective:** Use accumulated per-pet history to detect drift from a baseline, surfacing chronic-condition signals over time.

**Why this comes here:** It depends on a meaningful history corpus (Phases 3.1/6.x) and on the hardened data layer (7.1) to query history at scale.

**Dependencies:** 7.1 (scaled data layer), 6.x (history depth).

**Deliverables:**
- Longitudinal monitoring: AI baseline detection for chronic-condition drift.

**Tasks:**
- [ ] Per-pet baseline modeling from historical analyses/events.
- [ ] Drift detection + surfacing of chronic-condition signals.

**Validation Checklist:**
- [ ] A pet with a degrading trend across history triggers a drift signal.
- [ ] False-positive rate on stable pets is acceptable on a labeled sample.

**Definition of Done:** Baseline drift detection runs over pet history and surfaces chronic-condition signals.

**Estimated Effort:** 80h.

**Execution Risks:** Drift detection is a quasi-diagnostic claim — keep it framed as "monitoring signal," not diagnosis, to stay inside the legal posture (Critical Review #10). Needs the eval harness to validate.

---

## Phase 7.3 — B2B API v1

**Title:** Public REST API with keys, usage billing, and self-service signup.

**Objective:** Ship the B2B API: authenticated REST endpoints, API-key management, Stripe usage billing, and self-service signup — opening the B2B revenue line.

**Why this comes here:** It needs the hardened, autoscaling backend (7.1) to safely expose triage to external load, and it is the largest new surface in V3.

**Dependencies:** 7.1 (scaled, multi-tenant-safe backend).

**Deliverables:**
- B2B API v1: REST API with API keys, usage billing (Stripe), self-service signup.

**Tasks:**
- [ ] REST API with API-key auth + per-key rate limiting/quotas.
- [ ] Stripe usage-based billing.
- [ ] Self-service signup + API docs.

**Validation Checklist:**
- [ ] An external customer can self-serve a key, call the API, and be metered/billed via Stripe.
- [ ] Per-key quotas and rate limits enforce correctly.
- [ ] API isolation: B2B traffic cannot reach consumer user data.

**Definition of Done:** External developers can sign up, get a key, call the triage API, and be billed — toward 3+ paying customers at $500–2K/month.

**Estimated Effort:** 130h.

**Execution Risks:** B2B sales cycles are 3–6 months (original bottleneck) and **not solo-feasible** — this sub-phase likely requires the second hire. Exposing triage publicly raises the liability and abuse surface; reuse the same safety core, never a stripped-down path.

---

## Phase 7.4 — Community & Proprietary Dataset

**Title:** Breed Q&A with vet-verified answers + the labeled dataset for fine-tuning.

**Objective:** Launch community features (breed-specific Q&A, vet-verified answers) and assemble the proprietary dataset v1 (50K+ labeled analyses) that Phase 8 fine-tunes on.

**Why this comes last (within Phase 7):** Community is additive and can absorb spare capacity; the dataset assembly is the explicit bridge into Phase 8's model work.

**Dependencies:** 6.2 (outcome labels), 7.1 (data at scale).

**Deliverables:**
- Community features: breed-specific Q&A; vet-verified answers.
- Proprietary dataset v1: 50K+ labeled analyses prepared for fine-tuning.

**Tasks:**
- [ ] Breed-specific Q&A with vet-verified answers.
- [ ] Assemble + label proprietary dataset v1 (50K+ analyses) for fine-tuning.

**Validation Checklist:**
- [ ] Q&A supports posting, answering, and a vet-verified badge.
- [ ] Dataset reaches 50K+ labeled analyses in a training-ready format with held-out eval split.

**Definition of Done (Phase 7 exit gate):** Community Q&A is live and a 50K+ labeled, training-ready dataset exists — toward Phase-7 metrics: $75K MRR, 3+ B2B customers, 99.9%+ uptime.

**Estimated Effort:** 70h.

**Execution Risks:** Community introduces user-generated content → moderation + liability obligations not otherwise in the roadmap. Dataset labeling quality determines Phase-8 model quality; vet-verified labels are the gold standard but expensive.

---

# Phase 8 — V3 Proprietary AI & Acquisition Readiness

**Original Goal (preserved):** *Fine-tuned proprietary model. $100K MRR. Acquisition conversations begin.* (Months 15–18, 480h, Confidence: Low.)

---

## Phase 8.1 — Model Training Pipeline

**Title:** Fine-tuned vision model v1 + offline eval harness, gated on Claude-baseline parity.

**Objective:** Train the proprietary fine-tuned vision model v1 on PawDoc's dataset and build an offline evaluation harness that gates release on accuracy ≥ the Claude Sonnet baseline.

**Why this comes first (within Phase 8):** No routing, FNOL, or rollout can happen until a model exists and is proven at least as accurate/safe as the incumbent.

**Dependencies:** 7.4 (50K+ labeled dataset).

**Deliverables:**
- Fine-tuned vision model v1 trained on PawDoc's pet-health dataset.
- Offline eval harness with a held-out, emergency-weighted test set.

**Tasks:**
- [ ] Train fine-tuned vision model v1 on the proprietary dataset.
- [ ] Build offline eval harness; benchmark against Claude Sonnet baseline.

**Validation Checklist:**
- [ ] **Proprietary model accuracy ≥ Claude Sonnet baseline** on the held-out set.
- [ ] **False-negative rate on emergency cases ≤ baseline** (hard safety gate).
- [ ] Eval harness is reproducible and version-pinned.

**Definition of Done:** A fine-tuned model exists and meets-or-beats the Claude baseline on accuracy and emergency false-negatives in offline eval.

**Estimated Effort:** 160h.

**Execution Risks:** **Not solo-feasible** — requires ML engineering (the second hire). This is the first place a formal eval harness is unavoidable; if one wasn't built earlier (Critical Review #4), it must be built now and there's no historical regression baseline to compare prompt changes against.

---

## Phase 8.2 — Model A/B Routing & Shadow Deployment

**Title:** Shadow-mode the proprietary model, then gradually route live traffic with safety monitoring.

**Objective:** Build traffic-routing infrastructure to run the proprietary model in shadow mode first, then ramp live traffic gradually under continuous safety monitoring.

**Why this comes here:** It is the safe-rollout layer between a trained model (8.1) and trusting it in production; shadow-first prevents a model regression from reaching users.

**Dependencies:** 8.1 (a model that passed the gate).

**Deliverables:**
- Model A/B test infrastructure: traffic routing to the proprietary model.
- Shadow-mode comparison → gradual rollout with safety monitoring.

**Tasks:**
- [ ] Traffic-routing infra for model A/B (incl. shadow mode).
- [ ] Shadow comparison vs. production; then staged live ramp with monitoring + rollback.

**Validation Checklist:**
- [ ] Shadow mode logs proprietary-vs-production disagreements without affecting users.
- [ ] Live ramp is gradual (small % first) with an automatic rollback trigger on safety-metric regression.
- [ ] EMERGENCY handling is identical or stricter on the new model path.

**Definition of Done:** The proprietary model can be shadow-tested and ramped safely with monitoring and instant rollback.

**Estimated Effort:** 120h.

**Execution Risks:** Routing must preserve the hardcoded emergency override and cross-verification regardless of which model serves (Critical Review #4). A model kill-switch/rollback is mandatory here (Critical Review #19).

---

## Phase 8.3 — Insurance FNOL & International Expansion

**Title:** Emergency-triggered insurance FNOL + German and Australian App Store launches.

**Objective:** Integrate pet-insurance First Notice of Loss (emergency analyses notify the insurance partner) and launch in the German and Australian App Stores.

**Why this comes here:** FNOL is a high-value B2B2C revenue surface that depends on a trustworthy emergency path (8.1/8.2); international launches extend the proven product to new markets.

**Dependencies:** 8.2 (trusted emergency path), 5.4 (German localization base).

**Deliverables:**
- Pet insurance FNOL integration: emergency analyses notify insurance partner.
- German + Australian App Store launches.

**Tasks:**
- [ ] FNOL integration: notify insurance partner on emergency analyses (with consent).
- [ ] German + Australian App Store launches (localization, ASO, compliance).

**Validation Checklist:**
- [ ] An emergency analysis (with user consent) triggers a partner FNOL notification.
- [ ] German + Australian builds pass store review and are live.
- [ ] Emergency keyword override is localized for German (safety) before German FNOL is active.

**Definition of Done:** FNOL fires on consented emergencies and both new markets are live — toward "first FNOL revenue."

**Estimated Effort:** 120h.

**Execution Risks:** FNOL ties a possibly-wrong AI emergency call to a financial/insurance action — the false-positive and false-negative blast radius both grow; consent and human review are essential. Australian launch adds another locale to the English-only safety-net problem (Critical Review #11).

---

## Phase 8.4 — Acquisition Readiness

**Title:** Data room, metrics deck, and initiating strategic buyer conversations.

**Objective:** Assemble acquisition materials (data room, metrics deck) and initiate conversations with strategic buyers.

**Why this comes last:** It packages the fully-realized business (revenue, data moat, proprietary model, international) for the most-likely exit pathway.

**Dependencies:** 8.1–8.3; sustained metrics.

**Deliverables:**
- Acquisition readiness materials: data room, metrics deck.
- 2+ strategic buyer conversations initiated.

**Tasks:**
- [ ] Build the data room (financials, metrics, security, legal, data assets).
- [ ] Build the metrics/strategy deck.
- [ ] Initiate conversations with 2+ strategic buyers (Chewy / Trupanion / Mars Petcare).

**Validation Checklist:**
- [ ] Data room is complete, organized, and access-controlled.
- [ ] Metrics deck reflects current, verifiable numbers.
- [ ] 2+ buyer conversations underway.

**Definition of Done (Phase 8 / program exit gate):** Acquisition materials are ready and 2+ strategic conversations are live — toward Phase-8 metrics: $100K MRR, proprietary model ≥ baseline, first FNOL revenue, 2+ buyer conversations.

**Estimated Effort:** 80h.

**Execution Risks:** A clean data room requires that earlier compliance gaps (account deletion, GDPR erasure-vs-retention, data lineage) were actually closed — diligence will surface them (Critical Review #9). Acquisition timing is market-dependent and outside execution control.

---

# Critical Review & Improvements

> Per the transparency requirement, **none** of the items below were folded into the phase tasks above. Each is a finding against the original roadmap, marked as either a **[RISK / INCONSISTENCY FOUND]** or a **[PROPOSED ADDITION]**, with placement guidance. They are ordered roughly by severity.

## A. Safety & AI Correctness (highest priority for a triage product)

**[RISK / INCONSISTENCY FOUND] #1 — The on-device Tier 1 model is load-bearing but sequenced into zero phases.**
**Issue:** Tier 1 (CoreML/TFLite: "is this an animal?", species classification, image-quality check) appears in the AI Tier Architecture (§3), the system diagram (§4), the data-flow ("On-device pre-filter"), the folder structure (`platform/ios` CoreML, `platform/android` TFLite), and the cost model ("saves ~15–20% of API calls"). It appears in **no phase's task list**. Phase 1.2's "real-time quality overlay" is heuristic, not the ML pre-filter.
**Why it matters:** It's credited with 15–20% cost savings and is the first quality/safety gate. Either the cost model is wrong or ~15–20% of cost is unaccounted for, and the architecture diagram describes a component that won't exist.
**Suggested adjustment:** Decide explicitly: (a) build it — add a sub-phase (suggest **Phase 1.5** or fold into 1.2) to train/integrate the CoreML + TFLite models; or (b) defer it — strike it from the MVP architecture/cost model and mark it a Phase 3+ optimization. Do not leave it implied-but-unbuilt.

**[RISK / INCONSISTENCY FOUND] #4 — Verification asymmetry contradicts the stated #1 risk.**
**Issue:** The pipeline cross-verifies **EMERGENCY** classifications (a second Claude call) but never re-checks **NORMAL** results. The stated #1 business risk is a viral false-negative ("pet dies after 'likely normal'"). Cross-verifying EMERGENCY reduces *false alarms*; it does nothing for the *false negatives* that are the actual existential risk.
**Why it matters:** The most dangerous failure mode (NORMAL when it should be EMERGENCY/MONITOR) is the least-defended path. Reliance on Gemini's uncalibrated self-confidence (>0.85 → skip the stronger model on 60% of queries) compounds this.
**Suggested adjustment:** Add a "borderline NORMAL" re-check: when a result is NORMAL but any risk signal is present (symptom keywords, low input quality, sensitive species/age), escalate to Tier 3 or bias to MONITOR. Place in **Phase 1.3** (core safety) or, at latest, fast-follow before public launch (Phase 2).

**[PROPOSED ADDITION] #2-eval — Golden-set AI regression eval in CI.**
Reason: There is no fixed, labeled evaluation set run on every prompt/model change. For an AI triage product, a silent prompt regression can kill someone's pet.
Impact: Catches safety regressions before they ship; becomes the objective gate for personalization (6.1), longitudinal monitoring (7.2), and the fine-tuned model (8.1) — all of which currently have no regression baseline.
Recommended Placement: Build a minimal version in **Phase 1.3** (emergency cases especially); formalize into CI in **Phase 2**; it becomes mandatory by Phase 6.1/8.1.

**[RISK / INCONSISTENCY FOUND] #11 — Emergency keyword override is English-only and substring-matched; breaks under localization.**
**Issue:** `EMERGENCY_KEYWORDS` is English and uses naive `in` substring matching. The schema has `preferred_locale`; Phase 5.4 ships German; Phase 8.3 ships Australian. Substring matching also misfires ("grapes" inside "no grapes eaten" → false EMERGENCY).
**Why it matters:** For non-English users the hardcoded safety net — explicitly designed to be the AI-independent backstop — **does not fire at all**. This is a direct safety regression introduced by localization.
**Suggested adjustment:** Localize the keyword sets per supported locale and add light negation handling; gate German/Australian launches on a localized override. Place the localization work *inside* **Phase 5.4** and **8.3** as a hard prerequisite.

**[PROPOSED ADDITION] #19 — AI pipeline kill-switch / maintenance mode.**
Reason: The incident protocol says "pause affected path," but no mechanism exists to do so. Mobile releases can't be rolled back instantly.
Impact: Lets you instantly stop or reroute a misbehaving AI path (e.g., fall back to "we can't analyze right now — if this seems urgent, contact a vet") without an App Store release.
Recommended Placement: **Phase 1.3** (server-side flag in the Edge Function / AI service); reused by Phase 8.2 model rollout.

## B. Data Model & Security

**[RISK / INCONSISTENCY FOUND] #2 — RLS policies as written are non-functional.**
**Issue:** (a) Policies for `pets`/`analyses` use only `USING (auth.uid() = user_id)` with **no `WITH CHECK`** and **no INSERT policy** → with RLS enabled, authenticated users **cannot insert their own pets/analyses**. (b) `health_events` and `reminders` have RLS **enabled but no policy defined** → all access denied (deny-by-default). (c) `analysis_feedback` and `referrals` have **no RLS at all** → exposed.
**Why it matters:** As written, core flows (create pet, log event) fail, while two tables holding user data are unprotected. This will fail Phase 1.1's own validation checklist.
**Suggested adjustment:** Add `WITH CHECK (auth.uid() = user_id)` + explicit INSERT/SELECT/UPDATE/DELETE policies for `pets`, `analyses`, `health_events`, `reminders`; enable RLS + policies on `analysis_feedback` and `referrals`. Place in **Phase 1.1** (it's a correctness bug, not an enhancement).

**[RISK / INCONSISTENCY FOUND] #3 — Semantic cache: embeddings are never generated; MVP diagram implies caching that doesn't exist.**
**Issue:** The MVP sequence diagram shows "Check semantic cache (pgvector similarity >90%)" in the live flow, and the schema has `embedding vector(1536)` + an ivfflat index. But no task in Phase 1 generates embeddings, and the roadmap's own "issues found" table defers semantic-cache *logic* to Phase 3. So the column/index exist but are never populated until Phase 3, and the MVP diagram is misleading.
**Why it matters:** Implementers following the MVP diagram will look for a cache that isn't built; the ivfflat index on an empty/partial column is dead weight; embedding-generation cost is unaccounted for.
**Suggested adjustment:** Either move embedding generation into Phase 1.3 or annotate the MVP diagram as "Phase 3+." Decompositon already lands the logic in **Phase 3.2** and flags the backfill.

**[RISK / INCONSISTENCY FOUND] #10 — Free-tier counter is never reset.**
**Issue:** `free_analyses_used_this_month` is incremented and checked, and `free_analyses_reset_at` exists, but **no job resets the counter**. Reminder cron arrives in Phase 3.
**Why it matters:** In the MVP (Phases 1–2), free users get 3 analyses *ever*, not 3/month — silently capping the funnel the business model depends on.
**Suggested adjustment:** Add a monthly reset (scheduled function or check-on-read) in **Phase 1.3**; do not wait for the Phase 3 cron.

**[RISK / INCONSISTENCY FOUND] #9 — "Store every analysis permanently" contradicts GDPR "right to deletion," and account deletion is sequenced nowhere.**
**Issue:** §9 promises "every analysis stored permanently for legal record" *and* "right to deletion — 30-day purge" + a user-facing "Delete my account and all data." These conflict. Worse, no phase implements account/data deletion, and `analyses.user_id` has no `ON DELETE` rule, so deleting a `users` row is blocked by the FK. Apple guideline 5.1.1(v) *requires* in-app account deletion.
**Why it matters:** A compliance gap that can trigger App Store rejection (Phase 2.3) and fails GDPR/CCPA diligence at acquisition (Phase 8.4).
**Suggested adjustment:** Define a legal-hold-vs-erasure policy (e.g., anonymize PII but retain de-identified analysis records under legitimate interest), implement in-app account deletion, and fix FK `ON DELETE` semantics. Place an account-deletion sub-phase in **Phase 2** (before public submission).

**[RISK / INCONSISTENCY FOUND] #20 — Inconsistent FK delete semantics.**
**Issue:** `pets`, `health_events`, `reminders` cascade on parent delete; `analyses.pet_id`/`analyses.user_id`, `analysis_feedback.analysis_id`, `referrals.*` have no `ON DELETE` → default NO ACTION blocks deletes/orphans rows.
**Why it matters:** Makes both pet deletion and account deletion (#9) fail or partially complete.
**Suggested adjustment:** Decide per-table (cascade vs. set-null vs. restrict) consistent with the retention policy from #9. Place in **Phase 1.1**.

**[PROPOSED ADDITION] #6 — Specify the client→R2 upload authorization mechanism (presigned URLs).**
Reason: The client uploads directly to R2, but the auth mechanism is unspecified. Embedding R2 write credentials in the app is a credential-leak/abuse hole.
Impact: Prevents anyone from extracting creds and writing arbitrary objects (cost + abuse).
Recommended Placement: **Phase 1.2** — issue short-lived presigned PUT URLs from an Edge Function; never ship R2 write keys in the client.

**[PROPOSED ADDITION] #21 — Webhook signature verification.**
Reason: `/revenuecat-webhook` and `/auth-webhook` are not specified to verify signatures. An unsigned RevenueCat webhook lets anyone POST "I'm premium."
Impact: Prevents subscription fraud and forged auth events.
Recommended Placement: **Phase 1.3** (revenuecat-webhook) and **Phase 1.1** (auth-webhook).

**[PROPOSED ADDITION] #7 — Strip EXIF/GPS from uploaded images.**
Reason: Pet photos carry GPS/EXIF; storing them leaks user location and expands PII handling.
Impact: Privacy hardening; smaller GDPR surface.
Recommended Placement: **Phase 1.2** (client-side, during compression).

## C. Availability, Cost & Operations

**[RISK / INCONSISTENCY FOUND] #5 — No AI provider failover, global cost alerting, or redundancy for a 24/7 safety product.**
**Issue:** The pipeline depends on Gemini + Anthropic (+ later OpenAI) with only "1 retry on timeout." There's no fallback provider/circuit breaker, no global spend alarm (only a per-user daily cap), and the AI service runs on a single Fly machine until Phase 7 autoscaling.
**Why it matters:** An Anthropic outage, a cost-runaway bug, or a single-machine crash each takes down all triage for a product whose promise is "24/7, at 2am." The anonymous web checker (5.2) widens the cost-abuse surface.
**Suggested adjustment:** Add (a) provider circuit-breaker + a degraded "can't analyze now — if urgent, contact a vet" path, (b) provider-level budget alarms, (c) at least two AI-service machines pre-Phase-7. Place foundations in **Phase 1.3**; redundancy ideally before any planned viral push, not Phase 7.

**[PROPOSED ADDITION] #12 — Budget alerts on all metered third parties.**
Reason: Google Places (3.4), R2, Gemini/Anthropic/OpenAI, OneSignal all bill on usage with no alerting specified.
Impact: Prevents silent cost blowouts from bugs/abuse.
Recommended Placement: **Phase 0.4** (set up alerting infra) + per-service as each is added.

**[PROPOSED ADDITION] #13 — Pre-launch and pre-viral load testing.**
Reason: The growth thesis is virality (TikTok), but autoscaling doesn't arrive until Phase 7. A hit could 100× traffic against a single machine.
Impact: Avoids an outage exactly when acquisition spikes.
Recommended Placement: **Phase 2.3** (baseline) and before any planned campaign in **Phase 4.3**.

**[PROPOSED ADDITION] #18 — Reconsider self-hosted PostHog for a solo founder.**
Reason: Self-hosting PostHog (ClickHouse) on Fly.io is meaningful ops burden for one person; PostHog Cloud has a generous free tier.
Impact: Frees solo-founder time for product; reduces an operational failure point.
Recommended Placement: **Phase 0.4** decision (kept out of tasks per transparency rule).

**[PROPOSED ADDITION] #22 — Database backup / PITR + restore drills.**
Reason: For an app storing "permanent legal records," there's no stated backup/PITR or restore-testing plan.
Impact: Recoverability from corruption/accidental deletion; diligence-ready.
Recommended Placement: **Phase 0.2** (enable) + a restore drill in **Phase 2**.

## D. Deployment, Testing & Observability

**[PROPOSED ADDITION] #14-staging — Staging environment + smoke gate for the AI service; automated migrations + rollback.**
Reason: CI deploys the AI service straight to the single prod machine on merge; there's no staging/canary, and DB migration automation/rollback is unspecified.
Impact: Prevents shipping a broken safety service; safe migrations.
Recommended Placement: **Phase 0.4** (staging + migration automation in CI).

**[PROPOSED ADDITION] #16 — Single source of truth for the `AnalysisResult` schema + contract tests.**
Reason: The schema lives in Dart, TypeScript (Edge Fn), and Python (Pydantic). Drift between them causes silent parse failures.
Impact: Eliminates a whole class of integration bugs across the 3 services.
Recommended Placement: **Phase 1.1** (define once; codegen or contract tests across all three).

**[PROPOSED ADDITION] #23 — Distributed tracing / request-ID correlation.**
Reason: Sentry (errors), PostHog (product), Better Uptime (liveness) exist, but nothing correlates a single analysis across Flutter → Edge Fn → AI service → providers.
Impact: Makes debugging slow/failed analyses tractable.
Recommended Placement: **Phase 1.3** (propagate a request ID end-to-end; log it everywhere).

## E. Product, Growth & Compliance Consistency

**[RISK / INCONSISTENCY FOUND] #8 — NSFW/content moderation claimed "done" but absent.**
**Issue:** The Final Validation table marks "Content moderation ✅ NSFW pre-filter on all uploads," and "Issues Found" claims it was "added to Phase 1 backend tasks." It is in **no** task list.
**Why it matters:** A health app accepting user photo/video uploads with no moderation is an App Store and abuse risk; the validation report misrepresents readiness.
**Suggested adjustment:** Either implement an upload moderation step (cheap vision moderation or provider filter) in **Phase 1.2/1.3** or correct the validation report. Don't ship believing it exists.

**[RISK / INCONSISTENCY FOUND] #15 — Optimistic CAC / conversion / churn assumptions.**
**Issue:** Blended CAC $5–12, 10% free-to-paid, and LTV:CAC 6.7–30× are aggressive for consumer health apps (typical freemium 2–5%; consumer-health CAC often $20–50+). Minor copy inconsistencies too ($59.99/yr labeled both "~$5/mo" and "$4.99/mo equivalent"; churn cited as 4% monthly vs. 22%/48% annual).
**Why it matters:** Phase 4's profitability gate ("CAC < $15", "$10K MRR") may be unreachable on these assumptions, distorting go/no-go decisions on paid spend.
**Suggested adjustment:** Treat Phase 4.3 spend as price discovery; set a stop-loss; reconcile the pricing copy. (Strategy-level — flagged, not changed.)

**[RISK / INCONSISTENCY FOUND] #17 — Stale model display names vs. correct IDs; version sprawl.**
**Issue:** "Claude 3.5 Sonnet (`claude-sonnet-4-6`)" and "Claude Opus (`claude-opus-4-7`)" pair outdated marketing names with current IDs; the video path variously cites "Gemini video API / 1.5 Pro / 2.0 Flash."
**Why it matters:** An implementing agent may pick the wrong model from the human-readable name.
**Suggested adjustment:** Standardize on model **IDs** (`claude-sonnet-4-6`, `claude-opus-4-7`) everywhere; pin one Gemini version per tier. Place in **Phase 1.3** / **Phase 3.2**.

**[PROPOSED ADDITION] #24 — Veterinary practice-law review (per-jurisdiction).**
Reason: In several US states, giving "veterinary advice" without a VCPR can constitute unlicensed practice. The "information, not diagnosis" framing is the mitigation but deserves explicit legal review, especially as B2B (7.3) and FNOL (8.3) raise the stakes.
Impact: Reduces regulatory/liability exposure; informs ToS and copy.
Recommended Placement: **Phase 2.2** (initial), revisited at **7.3** and **8.3**.

**[RISK / INCONSISTENCY FOUND] #25 — Referral mechanics are farmable.**
**Issue:** "Friend gets 3 bonus free analyses on signup" grants free AI before any subscription; fake emails farm it. (Referrer reward is correctly gated on the friend subscribing.)
**Why it matters:** Free-AI abuse cost; inflated vanity metrics.
**Suggested adjustment:** Device/identity fraud checks on bonus grants; cap bonus analyses. Place in **Phase 3.3** (referral go-live).

---

# Dependency Graph

```
PHASE 0 (Foundation)
  0.1 Accounts, Domains, Secrets
        │
        ▼
  0.2 Data & Storage Platform ──┐
        │                       │
        ▼                       │
  0.3 AI Service Shell + RevenueCat
        │                       │
        ▼                       │
  0.4 CI/CD + Observability + Verification  ◄── needs repo(0.1), Supabase(0.2), Fly(0.3)
        │
        ▼
PHASE 1 (MVP Core)
  1.1 App Skeleton + Auth + Data Layer  (defines AnalysisResult contract)
        │
        ├───────────────┬───────────────┐
        ▼               ▼               │
  1.2 Capture +     1.3 AI Orchestration + Safety Core   ◄── 1.2 ∥ 1.3 (parallelizable)
      Upload            │
        │               │
        └──────┬────────┘
               ▼
  1.4 Result UX + Monetization + QA   ◄── integration layer; needs 1.2 AND 1.3
        │
        ▼
PHASE 2 (Launch)
  2.1 Production Polish ──┐
                          │   (2.1 ∥ 2.2)
  2.2 Legal & Trust GATE ─┤
        │                 │
        └────────┬────────┘
                 ▼
  2.3 Beta + Store Submission + Public Launch   ◄── HARD-gated by 2.2 (E&O, ToS, Privacy)
        │
        ▼
PHASE 3 (V1 Growth)
  3.1 History + Multi-Pet (foundation)
        │
        ├──────────────┐
        ▼              ▼
  3.2 Video +     3.3 Engagement + Notifications + Referral   ◄── 3.2 ∥ 3.3
  Semantic Cache       │
        │              │
        └──────┬───────┘
               ▼
  3.4 Vet Finder + Widgets + Android Parity (+ SEO)   ◄── validates full V1 set
        │
        ▼
PHASE 4 (Monetization)
  4.1 Experimentation Infra
        │
        ▼
  4.2 Onboarding + Paywall Experiments (needs winners before spend)
        │
        ▼
  4.3 Web Presence + Paid Acquisition
        │
        ▼
PHASE 5 (V2 Expansion)
  5.1 Exotic Species ──┐
  5.2 Web Checker ─────┤  (5.1 ∥ 5.2 ∥ 5.3 — largely independent; all reuse AI service)
  5.3 AI Journal ──────┘
        │
        ▼
  5.4 Embedded Telehealth + German + B2B-Lite   ◄── German needs localized safety net (#11)
        │
        ▼
PHASE 6 (Revenue Opt.)
  6.1 Personalization Engine
        │
        ▼
  6.2 Outcome Feedback Loop + Data Foundation   ◄── seeds Phase 8 dataset
        │
        ▼
  6.3 Revenue Add-ons (insurance, PDF, family sharing*)   *family sharing = RLS redesign
        │
        ▼
PHASE 7 (Infra + B2B) — second hire likely required
  7.1 Infra Hardening + Scale (replicas, pgBouncer, autoscale, partitioning)
        │
        ├──────────────┐
        ▼              ▼
  7.2 Longitudinal   7.3 B2B API v1   ◄── 7.2 ∥ 7.3 after 7.1
  Monitoring           │
        │              │
        └──────┬───────┘
               ▼
  7.4 Community + Proprietary Dataset (50K labeled)   ◄── bridge to Phase 8
        │
        ▼
PHASE 8 (Proprietary AI + Exit) — ML engineer required
  8.1 Model Training Pipeline + Eval (gate: ≥ Claude baseline, ≤ baseline emergency FN)
        │
        ▼
  8.2 Model A/B Routing + Shadow Deployment (kill-switch mandatory)
        │
        ▼
  8.3 Insurance FNOL + German/AU Launch
        │
        ▼
  8.4 Acquisition Readiness
```

**Cross-phase data-moat spine:** `1.3 (capture inputs) → 4.1 (feedback widgets) → 6.2 (outcome labels) → 7.4 (50K dataset) → 8.1 (fine-tune)`. Protect this chain — every link compounds the moat.

---

# AI-Agent Execution Guidance (Claude CLI)

### Branch strategy
- **One branch per sub-phase:** `phase-0.1-accounts`, `phase-1.3-ai-core`, etc. Never mix two sub-phases on one branch.
- `main` is protected (set up in 0.1); all work merges via reviewed PR.
- **Squash-merge** each sub-phase PR to keep `main` history one-commit-per-sub-phase.
- Tag releases (`v0.1.0`…) to trigger the Fastlane TestFlight lane (from 0.4).
- Honor the project convention of committing + pushing to `origin/main` at each completed (sub-)phase after validation — but only after the Definition of Done checklist is green.

### PR strategy
- **PR scope = sub-phase scope.** If a PR grows past its declared deliverables, split it.
- Every PR description embeds that sub-phase's **Definition of Done** as a checklist and links the Validation Checklist results.
- A PR cannot merge unless CI is green (Flutter analyze+test; AI-service tests; the golden-set eval once it exists, per Critical Review #2-eval).
- PRs touching the `AnalysisResult` contract require regenerating/validating all three language bindings (Critical Review #16).

### Parallelizable work (run as concurrent branches)
- **1.2 ∥ 1.3** — Flutter capture/upload vs. Python AI service (disjoint code; meet at 1.4 via the contract frozen in 1.1).
- **2.1 ∥ 2.2** — polish vs. legal (legal is a *gate* on 2.3, not a code dependency).
- **3.2 ∥ 3.3** — video vs. notifications/referral.
- **5.1 ∥ 5.2 ∥ 5.3** — exotic species / web checker / journal.
- **7.2 ∥ 7.3** — longitudinal monitoring vs. B2B API (both after 7.1).
- **Do not** parallelize branches that both edit the shared schema or the system prompt — serialize those to avoid merge hazards.

### Safest execution order
Strictly follow the dependency graph. **Never start a sub-phase whose dependencies' Definition of Done isn't green.** The non-negotiable serial spine is: `0.1→0.2→0.3→0.4 → 1.1 → (1.2∥1.3) → 1.4 → 2.1/2.2 → 2.3 → …`. Safety-core work (1.3) and the legal gate (2.2) are hard checkpoints — do not let later UX work "borrow ahead" past them.

### How to avoid agent drift
- **Pin the contract.** The `AnalysisResult` schema and the architecture-constraints block are the source of truth; paste them into every Phase-1 prompt.
- **Re-read the sub-phase's DoD before coding** and again before opening the PR. Build *only* the declared deliverables.
- **No new systems mid-task.** If the agent identifies a gap (e.g., a Critical-Review item), it must surface it as a proposal in the PR description — never silently add it to the codebase. This mirrors the transparency rule that produced this document.
- **Constrain file scope.** Each sub-phase declares which directories it owns (`mobile/`, `ai-service/`, `supabase/`); reject edits outside that set.
- Carry forward the original roadmap's invariants as guardrails in every prompt: RLS on every table; structured/JSON output only; server-side free-tier enforcement; emergency override pre-AI; EMERGENCY never paywalled; temperature 0.1; disclaimers injected API-level.

### Verification cadence
- **Every push:** CI (analyze, unit, integration).
- **Every prompt or model change:** run the golden-set eval (Critical Review #2-eval) — emergency cases especially. Block merge on any emergency-false-negative regression.
- **End of each Flutter sub-phase (1.2, 1.4, 2.1, 3.x):** manual QA on physical iPhone + Android.
- **End of each phase:** run that phase's full Validation Checklist + confirm Success Metrics are trackable.
- **Post-launch:** weekly latency/cost/crash review; monthly AI quality review (sample 50 analyses), per §13.

### Rollback strategy
- **AI service / Edge Functions:** keep the last-good deploy; rollback = revert the PR + redeploy (CI from 0.4). Gate every new AI path behind a server-side flag and ship the **kill-switch** (Critical Review #19) so a bad path can be disabled without a deploy.
- **Database:** all changes via versioned migrations with a tested down-path; rehearse destructive migrations (e.g., partitioning in 7.1) on a copy first; rely on PITR (Critical Review #22).
- **Mobile:** App Store releases can't be rolled back — therefore gate risky client changes behind remote config / feature flags, and add a **force-upgrade** mechanism so a dangerous client build can be retired. (Force-upgrade is a Proposed Addition; suggest Phase 2.)
- **Model rollout (8.2):** shadow-first, gradual ramp, automatic rollback on safety-metric regression.

### Testing cadence
- **Unit:** every PR (parser, emergency override all 14 keywords, rate limiting 3-ok/4th-blocked, RLS cross-user isolation).
- **Integration:** at each sub-phase close (full flow with mocked AI in 1.4; real-provider smoke in staging).
- **Widget:** for UI sub-phases (onboarding, all three result screens).
- **AI golden-set eval:** gates every prompt/model change from 1.3 onward; mandatory by 6.1 and 8.1.
- **Load test:** before public launch (2.3) and before any planned viral/paid push (4.3) — given the single-machine SPOF until Phase 7 (Critical Review #5, #13).
- **Security/RLS re-test:** whenever the data model changes, and especially when family sharing (6.3) converts the model from per-user to per-group ownership.

---

*Decomposition v1 | Companion to APP_EXECUTION_ROADMAP.md v1.0 | Original vision, architecture, strategy, safety, and monetization preserved in full. All additions and risks are quarantined in the Critical Review section and marked. Effort redistributed, not inflated: sub-phase hours sum to each phase's original budget (total 1,900h).*
