# PHASE M3 REPORT — Emotional milestones

**Date:** 2026-06-11 · **Branch:** `motion-m3` (stacked on `motion-m2`, PR #37) · **Source of truth:** `PAWDOC_MOTION_ROADMAP.md` §3 M3 + §4 A7/A8 + matrix #14–#19 · audit §4 (honesty: celebrations fire only on real events).

## 1 · Scope delivered (matrix #14–#19 — all six moments)

| # | Moment | Type | Delivery |
|---|--------|------|----------|
| 14 | Gift-open claim reveal | L one-shot 2.2s | `referral_gift_open_v1.json` (75KB): pop-in with overshoot, glow bloom over the art's paw-heart, 10 paw-confetti particles (≤12 budget), settles to the open pose. Fires on **claim success only**; failures keep the plain snackbar. |
| 15 | Welcome to Premium | L one-shot 2.5s | `premium_welcome_v1.json` (53KB): sleeper rises + stretches, 6 sparkles, warm glow — **no confetti cannon**. Fires on entitlement-active purchase only; purchase/eligibility logic untouched (visual swap). |
| 16 | Log-save morph | C 300ms | Save button check-morphs ("Saved ✓") for one 320ms beat before the pop; paw-stamp icon now leads the history snackbar. Skipped under reduce-motion; error path unchanged. |
| 17 | First-check toast | C 1.5s, once EVER | `markFirstAnalysisCompleted()` now reports the first flip; "{Pet}'s story has begun" overlay toast (tap-skip, auto-remove, never blocks). **Never on EMERGENCY** — gated in the runner. Reduce-motion → text snackbar. |
| 18 | Quota tick | C 300ms | Count-**down** tick on the remaining number (old value slides out upward — it's "remaining", per spec). Instant under reduce-motion. |
| 19 | Member joined | C 800ms | New member tiles slide in when the list grows while shown (seen-set tracking; opening the screen never animates). The header circle art hides itself at >1 member by existing layout, so the "happy sway" is structurally N/A — documented. |

**Shared contract — `core/celebration_overlay.dart`:** ≤2.5s auto-dismiss (asserted in code), any tap skips, reduce-motion → plain text snackbar (no overlay at all), cancelable timer (leak-free), real events only.

## 2 · Validation gates

| Gate | Result |
|------|--------|
| `flutter analyze` | **PASS** — no issues |
| `flutter test` (full) | **PASS** — 179 passed, 1 documented skip |
| `paywall_policy_test` (re-verified — purchase path touched visually) | **PASS** — 7/7 |
| `./scripts/verify-disclaimers.sh` | **PASS** — 6/6 |
| `flutter build apk --debug` | **PASS** |
| GitHub CI | runs on the PR |
| Device validation | **PASS** — 2026-06-11 live pass; see PAWDOC_MOTION_IMPLEMENTATION_FINAL_AUDIT.md §Device Results |

New tests: celebration contract (reduce-motion=snackbar-only / tap-skip / ≤2.5s auto-dismiss) · first-check rules (flips exactly once; never repeats; **never on EMERGENCY**) · save morph (reduce-motion pops without delay; failure path stays usable). A7/A8 are auto-covered by the existing budget/parse/fallback-shipping gate.

## 3 · M3 acceptance check (roadmap §3)
- Every celebration ≤2.5s ✓ (2.2s / 2.5s / 320ms / 1.5s / 300ms / 800ms) · skippable by tap ✓ · never blocks navigation ✓ (overlays self-dismiss; Done/back never gated) · **never fires on EMERGENCY-adjacent flows** ✓ (runner gate + the M1/M2 guard test keeps motion off the emergency tree) · reduce-motion → text confirmation only ✓ · analyze/test green ✓ · purchase-success path visual-only, `paywall_policy_test` re-verified ✓.

## 4 · Documented deviations
1. **A7 "lid pops"**: the open-gift art is a single raster (lid already off beside the box) — the pop reads through the overshoot entrance + glow + confetti instead of a rigged lid. Same register, honest to the art.
2. **A8 "wakes & stretches"**: the sleeper's eyes are painted closed; the wake reads through the rise + stretch arc (no raster eye-opening possible).
3. **#17 "paw-print draw"**: scale/fade paw glyph instead of a stroke-draw (the toast is 1.5s and 18px — a draw would be imperceptible; the icon + text carry it).
4. **#19 circle-art sway**: structurally N/A (art only renders when the user is alone); tile slide-in carries the moment.

## 5 · Rollback
Per-moment commits; each reverts to the prior snackbar/static behavior independently. The celebration overlay is inert when unused.
