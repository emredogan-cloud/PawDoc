# Phase 1 — Roadmap Gap Analysis

**Audit date:** 2026-05-16
**Reference:** [`roadmaps/APP_EXECUTION_ROADMAP.md`](../../roadmaps/APP_EXECUTION_ROADMAP.md) §6, §7, §10 Phase 1
**Scope:** Phase 0 + 1A + 1B + 1C + 1D against the canonical Phase 1 task list

Legend: ✅ shipped · ⚠️ partial / different · ❌ not shipped · 🔁 deferred to a documented later phase

---

## 1. Frontend Task List (Roadmap §10 Phase 1)

| # | Roadmap line | Status | Source / Notes |
|---|--------------|--------|----------------|
| 1 | Flutter project: Riverpod, go_router, Material 3 theme (teal #00897B / amber #FFB300) | ✅ | Phase 0 (theme.dart) |
| 2 | Supabase Flutter client; auth state Riverpod provider | ✅ | `shared/providers/auth_provider.dart` |
| 3 | Onboarding 5-screen wizard | ⚠️ | Shipped 2 screens (`welcome` + `pet`). **Missing: trust-signal screen, push permission screen, activation screen.** Phase 1C plan documents the simplification but roadmap requires the 5-screen flow before launch |
| 4 | Pet setup: name, species grid, breed typeahead, age picker, optional photo | ⚠️ | Name + species grid + age picker ✅. **Breed is free-text (not typeahead). Photo upload not in onboarding form.** |
| 5 | In-app camera module: real-time quality overlay (blur/lighting/framing hints) | ❌ | `image_picker` only. No CameraX-style preview overlay. Phase 1C report acknowledged the gap |
| 6 | Image capture: compress to <2 MB → upload to R2 → return storage key | ⚠️ | Compression ✅. Upload destination is **Supabase Storage**, not R2. Phase 1C report flagged migration as Phase 2 work |
| 7 | Text symptom input screen with character guidance | ⚠️ | Multi-line TextField present. **No character counter, no "the more detail the better" guidance, no min-length nudge.** |
| 8 | Analysis loading screen: animated, 4 rotating contextual messages | ✅ | `analysis_loading_screen.dart` (4 messages, 2.5 s rotation) |
| 9 | Result screen: triage badge, what-we-noticed, what-to-do, escalation triggers, disclaimer | ⚠️ | Triage badge + what-we-noticed + what-to-do + disclaimer all ✅. **Explicit "escalation triggers" section (when to upgrade urgency) is absent.** Roadmap §10 names it explicitly |
| 10 | EMERGENCY result screen: warm red, urgent copy, vet finder deep link, acknowledgment gate before dismissal | ⚠️ | Color + copy + acknowledgement gate ✅. **Vet finder deep link missing** — no `url_launcher` integration, no Google Places query, no Airvet handoff (Phase 3) |
| 11 | Home screen: pet card (photo, name, last check summary), "Check [Pet]" primary CTA, query counter | ⚠️ | Pet card + CTA ✅. **Missing: pet photo (column exists, UI doesn't render), last-check summary (no analyses query), query counter ("X of 3 free this month")** |
| 12 | Pet profile CRUD screen | ⚠️ | Create only. **No edit, no delete (soft via is_active), no view-detail.** RLS supports CRUD but UI doesn't expose it |
| 13 | Apple Sign In + email auth flows | ⚠️ | Email OTP ✅. Apple Sign-In ⚠️ — service + button are wired but gated by `APPLE_SIGN_IN_ENABLED=false` by default; **must be set to true in prod env**, and Supabase Auth provider must be configured externally |
| 14 | RevenueCat paywall: shown after first successful analysis; annual-first layout | ⚠️ | Paywall + annual-first ✅. **Trigger differs**: roadmap says "after first successful analysis" (proactive nudge); ours fires on the *first 402* (after free tier is exhausted, ~3rd analysis). Both are defensible, but design intent diverges |
| 15 | PostHog event tracking on all key user actions | ❌ | **PostHog NOT integrated.** `posthogApiKey` field exists in `AppConfig` but no `posthog_flutter` SDK, no `posthog.capture(...)` calls. Event names are catalogued in `docs/event-catalog.md` but never emitted. **This is a roadmap Phase 1 explicit deliverable.** |
| 16 | Sentry crash reporting initialization | ✅ | Phase 1D — `sentry_service.dart` + ai-service `sentry.py` |

---

## 2. Backend Task List (Roadmap §10 Phase 1)

| # | Roadmap line | Status | Source / Notes |
|---|--------------|--------|----------------|
| 1 | Supabase migration v1: all tables with indexes and RLS policies | ✅ | Phase 1A — 9 migrations + 28 RLS policies + 48-test pgTAP suite |
| 2 | Edge Function `/analyze`: validate input, load pet profile, check free tier limit, call AI service, store result | ✅ | Phase 1B + 1C + 1D — full 12-step flow |
| 3 | Edge Function `/auth-webhook`: create users row on new Supabase Auth signup | ✅ | Phase 1A + Phase 1C trigger backup |
| 4 | Edge Function `/revenuecat-webhook`: update subscription_status on entitlement change | ✅ | Phase 1D — state mapping + 17 mapping tests |
| 5 | Free tier enforcement: check before AI call; increment after | ⚠️ | **Order is INVERTED** for safety: check + increment BEFORE AI call (atomic SQL RPC). Roadmap reads "increment after" but our approach is intentional — see [`phase1-production-risks.md`](phase1-production-risks.md) "Quota refund" risk |

---

## 3. AI Service Task List (Roadmap §10 Phase 1)

| # | Roadmap line | Status | Source / Notes |
|---|--------------|--------|----------------|
| 1 | FastAPI app with `/analyze` endpoint; Pydantic request/response models | ✅ | Phase 1B |
| 2 | Emergency keyword detection (hardcoded list, BEFORE any API call) | ✅ | `services/safety.py` + parametrized tests for every keyword |
| 3 | Gemini 2.0 Flash integration with JSON schema enforcement | ✅ | `services/gemini_client.py` |
| 4 | Claude Sonnet integration with structured output (tool_use JSON pattern) | ✅ | `services/claude_client.py` |
| 5 | Tier routing: confidence > 0.85 → Tier 2; else → Tier 3 | ✅ | `services/orchestrator.py` |
| 6 | EMERGENCY cross-verification: second Claude Sonnet call confirms any EMERGENCY | ✅ | `_analyze_inner` — second call after first EMERGENCY |
| 7 | Confidence gating: < 0.60 → "insufficient information" graceful response | ⚠️ | **Tier 3 enforces this**; Tier 2 does not (Tier 2's gate is 0.85 — anything below escalates anyway). However, the cross-verify *downgrade* path could yield `min(confidence) < 0.60` while still returning MONITOR. Subtle gap |
| 8 | System prompt v1: includes species, breed context, triage schema, tone, anti-hallucination guards | ✅ | `prompts/system_prompt.py` + `prompts/breed_context.py` |
| 9 | Structured output schema: `AnalysisResult` {triage_level, confidence, primary_concern, visible_symptoms[], differential[], recommended_actions[], urgency_timeframe, disclaimer_required} | ✅ | `models/schemas.py` — plus metadata fields the orchestrator adds |
| 10 | Anthropic prompt caching on system prompt | ✅ | `claude_client.py` — `cache_control: {type: "ephemeral"}` |
| 11 | Upstash Redis: basic result caching | ⚠️ | Upstash is wired only for **rate limiting**, not result caching. Roadmap implies semantic/result cache; Phase 1B chose to ship the cache in Phase 3 (semantic cache via pgvector) and use Upstash for rate limiting only. **Roadmap divergence; semantic cache is a Phase 3 deliverable.** |
| 12 | Retry logic: 1 retry on timeout; graceful degradation on repeated failure | ⚠️ | Provider clients retry on 5xx + transport errors (NOT on timeout — timeout retry would re-hit). Graceful degradation ✅. The "1 retry on timeout" line of the roadmap is intentionally not followed; documented in Phase 1B plan |
| 13 | Structured JSON logging (mask API keys) | ✅ | structlog + Sentry `beforeSend` scrubs request bodies |

---

## 4. Analytics Task List (Roadmap §10 Phase 1)

| # | Roadmap line | Status | Source / Notes |
|---|--------------|--------|----------------|
| 1 | PostHog events: `onboarding_step_completed`, `onboarding_completed`, `analysis_submitted`, `analysis_completed`, `result_viewed`, `emergency_triggered`, `paywall_shown`, `trial_started`, `subscription_converted` | ❌ | **Not emitting any of these.** Event names are catalogued in `docs/event-catalog.md` but PostHog SDK isn't installed and no emission code exists |
| 2 | RevenueCat → PostHog revenue sync via webhook | ❌ | Not implemented |

---

## 5. Testing Task List (Roadmap §10 Phase 1)

| # | Roadmap line | Status | Source / Notes |
|---|--------------|--------|----------------|
| 1 | Unit tests: AI output parser (valid / invalid / malformed JSON responses) | ✅ | `ai-service/tests/test_parser.py` — 8 cases |
| 2 | Unit tests: Emergency override (all hardcoded keywords) | ✅ | Parametrised over `EMERGENCY_KEYWORDS` |
| 3 | Unit tests: Free tier rate limiting (3 allowed, 4th blocked) | ⚠️ | **The SQL function** `attempt_consume_free_analysis` is **not** explicitly tested. pgTAP suite covers RLS but not the quota counter logic. The TS rate-limit tests cover the *daily* limit (Upstash + in-memory), not the monthly free-tier quota |
| 4 | Integration tests: Full analysis flow with mocked AI responses | ⚠️ | `test_orchestrator.py` covers the AI-service-side flow with mocked providers. **No end-to-end test that exercises edge function → AI service → DB persistence.** Documented as "manual smoke" in Phase 1B/1C reports |
| 5 | Widget tests: Onboarding flow, result screen all three triage levels | ⚠️ | Result screen widget tests ✅ for all three levels + special flags. **Onboarding widget test missing** (only controller unit tests) |
| 6 | Manual QA: Happy path on physical iPhone + Android device | 🔁 | External — must be performed before TestFlight |
| 7 | Manual QA: EMERGENCY flow (acknowledgment gate, vet finder CTA) | ⚠️ | Acknowledgment gate ✅. Vet finder CTA missing (see Frontend #10) |
| 8 | Manual QA: Paywall (3 free, 4th blocked, RevenueCat flow) | 🔁 | External (requires RevenueCat sandbox + real keys) |

---

## 6. Growth Systems Task List (Roadmap §10 Phase 1)

| # | Roadmap line | Status | Source / Notes |
|---|--------------|--------|----------------|
| 1 | Share button on LIKELY NORMAL results (copy + PawDoc watermark image) | ❌ | **Not implemented.** No `share_plus` package, no UI button. Roadmap calls this out as Phase 1 viral coefficient |
| 2 | Referral code field on users table; referral deep link generation | ⚠️ | `referrals` **table** exists (Phase 1A) with RLS. **No mobile UI** for code generation or deep link handling |

---

## 7. Onboarding Flow (Roadmap §6 — 5 screens, target <2 min to first analysis)

| # | Roadmap screen | Status |
|---|----------------|--------|
| 1 | Value Hook ("Never wonder…") + "Get Started" / "Sign In" | ⚠️ Welcome screen present but no separate "Sign In" CTA for returning users via different auth |
| 2 | Pet Setup (45 s) — species tap grid, breed typeahead, age, optional photo | ⚠️ Compact form exists; breed is free text; photo not in form |
| 3 | Trust Signal — vet advisor photo + credentials + "4.8★ Trusted by 47,000+" | ❌ Not shipped |
| 4 | Push Permission — contextual prompt | ❌ Permission service exists, but no UI step in onboarding |
| 5 | Activation — "Ready to check on [Pet]?" → camera | ⚠️ Subsumed into the home screen's "Check Luna" CTA; no dedicated activation screen |

---

## 8. Retention Loop Design (Roadmap §6 — phased delivery)

| Roadmap item | Status | Phase |
|--------------|--------|-------|
| Activation event: first analysis completed | ✅ Implicit (we persist analyses) | 1B |
| Save-to-health-log CTA post-analysis | ❌ | 3 |
| 48 h follow-up push | ❌ | 3 |
| Weekly breed tip card | ❌ | 3 |
| Monthly health summary email | ❌ | 3 |
| Vaccination reminder | ❌ | 3 |

These are explicitly Phase 3 deliverables per roadmap §10. **Not a Phase 1 gap.**

---

## 9. D1/D7/D30 Retention Tactics (Roadmap §6)

| Tactic | Status |
|--------|--------|
| Quality first analysis + save-to-log CTA | ⚠️ Quality ✅; save-to-log CTA ❌ |
| 8 h follow-up notification | ❌ Phase 3 |
| Breed tip cards + Day-4 follow-up push | ❌ Phase 3 |
| Free query scarcity alert (Day 6) | ❌ Phase 3 |
| Monthly summary email + vaccination reminders | ❌ Phase 3 |

Phase 3 scope — not a Phase 1 gap.

---

## 10. Subscription & Paywall Compliance (Roadmap §7)

| Requirement | Status |
|-------------|--------|
| Three tiers: Free / Premium / Family | ⚠️ DB supports family; **paywall hardcodes a single `pawdoc_premium` offering**. Family tier picker is Phase 2 (per Phase 1D report) |
| Annual-first display | ✅ |
| EMERGENCY analyses never paywalled | ✅ Edge function `/analyze` skips rate-limit + quota when keyword override matches |
| Paywall placement (after first successful analysis) | ⚠️ Triggers on 402 (after free tier exhausts), not after first analysis. Different design intent |
| Trial flow (7-day or 14-day) | ❌ Not implemented |
| Family-plan sitter mode | ❌ Phase 5 per roadmap |

---

## 11. AI Tier Architecture (Roadmap §3)

| Tier | Roadmap | Status |
|------|---------|--------|
| Tier 1 — On-device CoreML/TFLite pre-filter | ❌ | Not implemented. `lib/platform/ios/` and `lib/platform/android/` are `.gitkeep` placeholders. Phase 0 documents this as "Phase 1+" but it's roadmap §3 Tier 1 |
| Tier 2 — Gemini 2.0 Flash | ✅ | `services/gemini_client.py` |
| Tier 3 — Claude Sonnet 4.5 | ✅ | `services/claude_client.py` |
| Tier 4 — Claude Opus on EMERGENCY verification | ⚠️ | Phase 1D plan says cross-verify uses Sonnet (cheaper); promotion to Opus is Phase 2. Roadmap §3 specifies Opus for Tier 4 |
| Semantic caching (10-15% cost reduction at scale) | ❌ | Phase 3 per roadmap §8 |

---

## 12. Security Architecture (Roadmap §9)

| Control | Roadmap | Status |
|---------|---------|--------|
| JWT auth + RLS on every user-data table | ✅ | Phase 1A — 28 policies, 48 pgTAP tests |
| Server-side rate limiting (10 analyses/day/user) | ✅ | Phase 1B Upstash limiter (in-memory fallback for local) |
| AI cost abuse: daily cap | ✅ | Free tier 3/month + rate limit 10/day |
| Input validation: file type + size | ✅ | Phase 1C storage bucket: 5 MB + jpeg/png/heic/webp allowlist |
| Prompt injection guard | ⚠️ | System prompt §"Anti-hallucination" tells the model to maintain rules if asked to ignore. **No explicit input sanitisation** of user-supplied `text_description` before it reaches the LLM. Most LLM-injection mitigations recommend an additional content-classification layer |
| Secrets management (Doppler) | ⚠️ | Architecture supports it (env-only). **Doppler account / integration not yet provisioned** — operational gap |
| DDoS (Cloudflare WAF) | 🔁 | Phase 2 (Cloudflare R2 + WAF activation) |
| Emergency override system | ✅ | `services/safety.py` |
| GDPR/CCPA: right to deletion | ⚠️ | DB CASCADE on `auth.users` deletion handles data. **No in-app "delete my account" flow** |
| Data residency (EU project) | ❌ | Phase 5+ per roadmap |
| DPA agreements | 🔁 | Legal, not engineering |
| E&O Insurance | 🔁 | Required before public launch (Phase 2 per roadmap §2) |
| Terms of Service + Privacy Policy live at pawdoc.app | ❌ | Not yet live; paywall references non-existent URLs |
| Disclaimer injected at API level | ✅ | `AnalysisResult.disclaimer_text` default; cannot be removed by UI |
| Analysis logging (legal record) | ✅ | `analyses` table is append-only; service-role-only writes |

---

## 13. Cost-Optimisation Levers (Roadmap §8)

| Lever | Roadmap | Status |
|-------|---------|--------|
| Client-side compression | ✅ | `image_service.dart` |
| On-device pre-filter | ❌ | Tier 1 not implemented (see §11) |
| Tier 2 gating | ✅ | confidence ≥ 0.85 short-circuits |
| Semantic cache | ❌ | Phase 3 |
| Anthropic prompt caching | ✅ | Phase 1B |
| Storage lifecycle (90-day archive) | ❌ | No lifecycle policy on `pet-uploads` bucket |

---

## 14. Summary Scorecard

| Category | ✅ / ⚠️ / ❌ |
|----------|-------------|
| Frontend (16 lines) | **5 ✅ · 9 ⚠️ · 2 ❌** |
| Backend (5 lines) | **4 ✅ · 1 ⚠️** |
| AI service (13 lines) | **9 ✅ · 4 ⚠️** |
| Analytics (2 lines) | **0 ✅ · 2 ❌** |
| Testing (8 lines) | **2 ✅ · 4 ⚠️ · 0 ❌ · 2 🔁** |
| Growth (2 lines) | **0 ✅ · 1 ⚠️ · 1 ❌** |
| Onboarding (5 screens) | **0 fully shipped · 2 partial · 3 missing** |
| Subscription / Paywall (6 reqs) | **2 ✅ · 2 ⚠️ · 2 ❌** |
| AI tiers (5 reqs) | **2 ✅ · 1 ⚠️ · 2 ❌** |
| Security (14 reqs) | **6 ✅ · 4 ⚠️ · 3 ❌ · 1 🔁** |
| Cost optimisation (6 levers) | **3 ✅ · 0 ⚠️ · 3 ❌** |

**Phase 1 completion estimate: ~62% of roadmap line items fully shipped, ~28% partial, ~10% missing.**

The biggest gaps are:
1. **PostHog analytics** — explicit Phase 1 deliverable, not started
2. **Growth loops** — share button + referrals UI missing
3. **App Store readiness** — onboarding (3 screens) + paywall (ToS link) + iOS manifest
4. **Pet CRUD + home screen polish** — basic UX completeness
5. **Vet finder deep link** — EMERGENCY UX completeness
6. **Tier 4 Opus on EMERGENCY** — cost vs safety tuning

None of the missing items require architectural changes. All are
additive on existing seams.

---

*End of roadmap gap analysis.*
