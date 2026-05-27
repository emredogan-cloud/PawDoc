# SUB-PR Report — Phase 1.4: Result UX, Monetization & End-to-End QA

**Status:** Built and **verified headless** (`flutter analyze` clean, 26 mobile tests, Node monetization tests, 23-check verifier). Live RevenueCat purchase + device e2e are founder-side.
**Branch:** `phase-1.4-result-monetization` (from updated `main` = 0.1–1.3)
**Date:** 2026-05-27

---

## 1. Files created / modified

```
mobile/lib/src/analysis/analysis_service.dart    client -> /analyze (1.2 input -> 1.3 brain) + latestTriageProvider
mobile/lib/src/analysis/analysis_runner.dart      loading -> result -> paywall integration glue
mobile/lib/src/analysis/loading_screen.dart       4 rotating messages
mobile/lib/src/analysis/result_screen.dart        standard result (badge/lists/disclaimer/share) + router
mobile/lib/src/analysis/emergency_result_screen.dart  warm red + vet-finder + acknowledgment gate
mobile/lib/src/monetization/paywall_policy.dart   trust-rule (pure, tested)
mobile/lib/src/monetization/paywall_prefs.dart    once/day + first-analysis persistence
mobile/lib/src/monetization/maybe_show_paywall.dart  applies the trust rule
mobile/lib/src/monetization/paywall_screen.dart   annual-first
mobile/lib/src/account/user_profile.dart          subscription + free counter (RLS)
mobile/lib/src/referral/referral_screen.dart      referral code + deep-link share
mobile/lib/src/analytics/analytics.dart           +6 key-action events
mobile/lib/src/home/home_screen.dart              pet card + "Check [Pet]" + query counter (rewritten)
mobile/lib/{main,src/config/env}.dart             RevenueCat configure + logIn; REVENUECAT_PUBLIC_SDK_KEY
mobile/test/{paywall_policy,result,analysis_integration}_test.dart
supabase/functions/analyze/index.ts (M)           EMERGENCY-never-paywalled + presign GET from R2 key
supabase/functions/revenuecat-webhook/index.ts    signed webhook -> subscription_status (CR #21)
supabase/functions/_shared/{emergency_keywords,revenuecat}.mjs (+ monetization.test.mjs)
supabase/config.toml (M)                          [functions.revenuecat-webhook] verify_jwt=false
scripts/verify-phase-1.4.sh ; docs/runbooks/16-...md ; ENVIRONMENT_VARS.md
mobile/pubspec.yaml                               share_plus, url_launcher, purchases_flutter, shared_preferences
```

## 2. How "EMERGENCY is never paywalled" is strictly enforced

Two independent layers (defense in depth):

1. **Server (authoritative, `analyze` Edge Function):** before the free-tier gate runs, the
   request text is checked with `containsEmergencyKeyword` (the 23-keyword list mirrored from
   the AI service). The free-tier 402 is returned **only** `if (!isEmergencyText && !decision.allowed)`,
   and an emergency analysis is **not counted** against the monthly quota
   (`if (!isPremium && !isEmergencyText)` on the increment). So a paywalled/over-limit user whose
   text trips an emergency keyword is **still analyzed**.
2. **Client (`paywall_policy.dart` + `maybe_show_paywall`):** `shouldShowPaywall` returns `false`
   whenever `lastTriageWasEmergency` — the paywall is never shown on/after an EMERGENCY result.
   The runner passes `lastTriageWasEmergency = (triage == EMERGENCY)`, and the EMERGENCY screen has
   no paywall path at all. Unit-tested in `paywall_policy_test.dart`.

The trust rule also blocks the paywall during onboarding and more than once per day (persisted in
`PaywallPrefs`), and never for premium users.

## 3. How to mock the AI response for local end-to-end testing

- **Riverpod override (offline, CI):** `analysisServiceProvider.overrideWithValue(FakeAnalysisService(result))`
  — `mobile/test/analysis_integration_test.dart` does exactly this, driving the runner
  loading→result for MONITOR and EMERGENCY with no backend. Change the `TriageLevel` to exercise each screen.
- **Full stack:** run the AI service with `AI_KILL_SWITCH=1` (safe degraded path) or inject the
  `FakeProvider` from `ai-service/tests/test_pipeline.py`. (Full steps in runbook 16 §1.)

## 4. Tests executed & results

| Test | Result |
|------|--------|
| `flutter analyze` | No issues found |
| `flutter test` | **26 passed** — paywall trust rule (incl. EMERGENCY), all 3 result screens + acknowledgment gate, mocked e2e loading→result, + earlier phases |
| `node --test monetization.test.mjs` | **3 passed** — emergency keyword mirror (23) + RevenueCat entitlement mapping |
| `./scripts/verify-phase-1.4.sh` | exit 0 — 23 checks green |

## 5. Security / trust checks

- **EMERGENCY never paywalled** — enforced server-side AND client-side (see §2).
- **Disclaimers are API-injected:** the pipeline forces `disclaimer_required = true`; the result
  screens render the disclaimer **gated on that flag from the payload**, not a UI-only decision.
- **RevenueCat webhook is signature-verified** (CR #21) — a forged webhook cannot grant premium.
- Subscription status is updated only via the service role from the verified webhook.
- The home query counter + premium check read the user's own row under RLS.

## 6. Known issues / scope notes

- **Live RevenueCat purchase + device e2e are founder-side** (need RevenueCat products + a device):
  the paywall purchase path uses `purchases_flutter` (offerings/purchase), the analysis round-trip
  hits the deployed `/analyze`. Logic + screens are unit/widget-tested; runbook 16 covers device QA.
- **Vet finder** is a maps deep link (`emergency vet near me`); the full Places-backed finder is Phase 3.4.
- **Referral** generates a code + shareable link; reward payout + fraud controls go live in Phase 3.3.
- **NSFW/content moderation** (CR #8) remains absent and unapproved — surfaced again; an upload
  moderation step belongs here or 1.2/1.3 before public launch.
- Share is **text + watermark line**; a rendered watermark image is a 2.1 polish item.

## 7. Risks

- `purchases_flutter` v10 `purchasePackage` is deprecated (kept with an ignore; migrate to
  `purchase(PurchaseParams)` when wiring real products).
- The emergency keyword list is duplicated (Python + TS) — they must stay in sync (a test asserts the count in each).

## 8. Git branch

`phase-1.4-result-monetization`

## 9. Commit hash

Implementation commit: `__IMPL_COMMIT__` (finalized in report-finalization commit; see `git log`).

## 10. Push confirmation

`__PUSH_STATUS__`

## 11. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Loading (4 messages) + standard result + EMERGENCY (gate) | ✅ built | widget tests (3 levels + gate) |
| Home pet card + "Check [Pet]" + query counter | ✅ built | home_screen + userProfileProvider |
| Paywall annual-first, after first analysis only | ✅ built | paywall_screen + trust-rule tests |
| `/revenuecat-webhook` updates subscription_status | ✅ built | webhook + entitlement-map test |
| **EMERGENCY never paywalled** | ✅ DONE | server + client checks; tested |
| Share / referral / 6 analytics events | ✅ built | result_screen, referral_screen, analytics |
| Disclaimers API-injected on every result | ✅ DONE | pipeline forces flag; UI gates on it |
| End-to-end on a physical device | ⏳ MANUAL | runbook 16 |

---

## Confirmation: Phase 1 (MVP) is completely coded

| Sub-PR | Coded | Headless-verified |
|--------|-------|-------------------|
| 1.1 App Skeleton, Auth & Data Layer | ✅ | analyze+test, RLS isolation proven |
| 1.2 Capture & Upload | ✅ | analyze+15 tests, EXIF/CR#6/CR#7 |
| 1.3 AI Orchestration & Safety Core | ✅ | 43 pytest + free-tier; all safety CRs |
| 1.4 Result UX, Monetization & QA | ✅ | analyze+26 tests; EMERGENCY trust rule |

**Phase 1 MVP is fully coded.** The camera→AI→result→paywall loop exists end-to-end with the
safety core (emergency override, confidence gating, kill-switch), the EMERGENCY-never-paywalled
guarantee, API-injected disclaimers, and analytics. What remains before a public build is the
founder-side **live infrastructure provisioning** (Doppler/Supabase/R2/Fly/RevenueCat accounts +
keys) and **on-device QA** — all documented in `docs/runbooks/00–16`. Next per the roadmap is
**Phase 2.1 (Production Polish & Hardening)**.
