# SUB-PR Report — Phase 4.2: Onboarding & Paywall Experiments

**Status:** Complete and fully green (flutter analyze/test, node, ruff/pytest, shellcheck). Onboarding A/B + paywall A/B/C wired to PostHog flags, fail-safe to control, with the EMERGENCY trust rule provably intact.
**Branch:** `phase-4.2-ab-experiments` (from `origin/main` = `4abf9c3`, contains 0.1→4.1)
**Date:** 2026-05-28
**Scope note:** the roadmap also lists an Onboarding Variant C (late paywall); your task scoped onboarding to **A/B**, so that's what shipped. Flagged for a follow-up if you want C.

---

## 1. Files created / modified

**Created**
```
mobile/lib/src/monetization/paywall_copy.dart   placeholder testimonial + vet-advisor copy (CMS-swappable)
scripts/verify-phase-4.2.sh                      phase verifier (variants + fail-safe + EMERGENCY assertions)
sub-pr-report/SUBPR_PHASE_4.2.md                 this report
```
**Modified**
```
mobile/lib/src/experiments/feature_flags.dart    + getVariant() (fail-safe to 'A') + onboarding/paywall keys
mobile/lib/src/monetization/paywall_screen.dart  Variant A (annual-first) / B (monthly featured + "Best value")
                                                 / C (social-proof header); fail-safe A until the flag resolves
mobile/lib/src/onboarding/onboarding_flow.dart   Variant B: skippable paywall right after pet creation
mobile/lib/src/analytics/analytics.dart          paywall_shown carries the variant; onboarding_paywall_shown
mobile/test/feature_flags_test.dart              getVariant fail-safe tests
mobile/test/paywall_policy_test.dart             EMERGENCY block asserted variant-independent
```
**No backend changes, no new secrets/env** — the experiments are driven entirely by PostHog flags (configured in the dashboard, §2) read through the resilient client wrapper.

## 2. Exact PostHog flags to configure

Both are **multivariate** flags (PostHog returns the variant **key string**). The client validates against the allowed set and **falls back to `A`** for anything else.

| Flag key | Variant values | Meaning |
|---|---|---|
| `onboarding_variant` | `A` | **Control** — paywall only *after* the first analysis (current behavior). |
|  | `B` | **Aggressive** — a skippable paywall shown inside onboarding, right after pet creation (before the camera). |
| `paywall_variant` | `A` | **Control** — annual-first layout. |
|  | `B` | **Monthly featured** — monthly is the hero card; annual carries a small "Best value" badge. |
|  | `C` | **Social proof** — adds the vet-advisor badge + testimonial above the annual-first layout. |

Set the variant **keys** to exactly `A` / `B` / `C`. Roll out the % split per variant; keep `A` as control. Unset / unknown / offline → the client renders **`A`** seamlessly. Variant exposure is captured automatically by PostHog, and `paywall_shown` additionally carries `variant` for the funnel.

## 3. EMERGENCY trust rule — confirmed unbroken across ALL variants (proof)

**The rule holds by construction — the variants only change paywall LAYOUT and onboarding TIMING; they never touch *whether* an emergency can be paywalled.** Two independent layers, both untouched this phase:

1. **The EMERGENCY result screen never invokes a paywall.** `EmergencyResultScreen` has its own acknowledge-and-pop flow; the runner's `_onResultDone` (the only path that calls `maybeShowPaywall`) is wired solely to the **standard** result screen. The verifier asserts `emergency_result_screen.dart` contains **zero** `PaywallScreen` / `maybeShowPaywall` references.
2. **The policy still blocks emergencies.** The post-analysis paywall routes through `maybeShowPaywall → shouldShowPaywall`, which early-returns `false` on `lastTriageWasEmergency`. `shouldShowPaywall` has **no variant parameter**, so the block is identical for every variant.

**Why the new variants can't break it:**
- **Paywall A/B/C** only re-arrange the `PaywallScreen` layout; they don't change when it appears.
- **Onboarding Variant B** shows a **skippable** paywall **during onboarding — before any analysis exists**, so there is no emergency to block. It can't gate an analysis (free-tier + emergency enforcement remain server-side and unchanged); "Not now" dismisses it.

**Testing proof:**
- `paywall_policy_test.dart`: `NEVER shows during/after an EMERGENCY` **and** a new `EMERGENCY block is variant-independent` test (emergency context stays `false` even when otherwise fully eligible). 
- `verify-phase-4.2.sh`: asserts the emergency screen has no paywall reference, the policy still blocks on `lastTriageWasEmergency`, and `maybe_show_paywall` still gates on the policy.
- `flutter test` → **74 pass** (incl. the above).

## 4. Tests executed & results

| Test | Result |
|------|--------|
| `flutter analyze` | **No issues found** |
| `flutter test` | **74 pass** (+4: getVariant fail-safe, variant-independent emergency) |
| `node --test _shared/*.mjs` | **36 pass** (unchanged) |
| `ruff` + `pytest` (ai-service) | **clean / 56 pass** (unaffected) |
| `./scripts/verify-phase-4.2.sh` | **exit 0** — variants wired, fail-safe to A, EMERGENCY assertions green; 3 MANUAL |
| `shellcheck` (verifier) | **clean** |

## 5. Fail-safe to Control (strict rule)

`FeatureFlags.getVariant(key, defaultValue: 'A', allowed: …)` returns **`A`** when the flag is null, empty, not in the allowed set, a non-string, or on **any** error (unit-tested). `PaywallScreen` initializes `_variant = 'A'` and renders control until/unless a valid variant resolves; onboarding shows the paywall only when the flag is exactly `B`. So a missing/misconfigured flag degrades to the current control experience with no crash.

## 6. MANUAL (founder)

- Create the two multivariate flags in PostHog (§2) and set the rollout %.
- Enforce the **≥ 500 users/variant** sample gate before calling a winner; keep annual-first (`A`) as control.
- On device: confirm each variant renders, and that an EMERGENCY result shows **no** paywall under every variant.

## 7. Git branch / commit / push

- Branch: `phase-4.2-ab-experiments`
- Implementation commit (deliverables): `<filled post-commit>`
- Push: `<filled post-push>`

## 8. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Onboarding Variant A (control) | ✅ DONE | default path unchanged (post-analysis paywall) |
| Onboarding Variant B (paywall in onboarding) | ✅ DONE | `_maybeShowOnboardingPaywall` (skippable, pre-analysis) |
| Paywall Variant A (annual-first control) | ✅ DONE | `paywall_screen.dart` |
| Paywall Variant B (monthly featured + badge) | ✅ DONE | `_plans()` + `_PlanCard.badge` |
| Paywall Variant C (social proof) | ✅ DONE | `_SocialProof` + `paywall_copy.dart` |
| Wired to PostHog flags | ✅ DONE | `getVariant` + the two keys |
| Fail-safe to Variant A | ✅ DONE | `getVariant` default 'A'; unit-tested |
| EMERGENCY never paywalled (all variants) | ✅ DONE | two-layer proof + tests + verifier |
| Run to ≥500/variant + pick winners | ⏳ MANUAL | PostHog (§6) |

**Verified now:** variants render off PostHog flags, everything fails safe to control, and the EMERGENCY trust rule is provably untouched (the variants never enter the policy, and the emergency screen never references a paywall) — analyzer + 74 tests + node + ruff/pytest all green. Stopping for approval.
