# PawDoc UI/UX Execution — Cycle 2 Report (Phases C + D)

- **Date:** 2026-06-10
- **Branch:** `ui-cycle-c-d` (off `main` @ `80b8b04`, i.e. after Cycle 1 A+B merged)
- **Source of truth:** `PAWDOC_UI_UX_MASTER_ROADMAP.md` §4 (Motion System), §8 Phase C/D, §3.2 (onboarding), §9.C/§9.D, §7 (asset plumbing)
- **Scope rule honored:** UI / theme / asset / motion only. No safety logic, AI pipeline, RLS, Edge Functions, routing **guards**, or purchase logic changed. (Router *transitions* were added; the redirect/guard logic is untouched.)

---

## Implemented phases

- **Phase C — Motion Foundation** (the second foundation; primitives + pilots)
- **Phase D — Onboarding Redesign** (first-impression + warmth; depends on A, B, C)

---

## Objectives

**Phase C:** Install the motion system primitives — a `reduceMotion` helper, an `AppButton` (press-scale + haptics), `Skeleton` loaders, and standardized go_router page transitions (shared-axis / fade-through) — every animation with a static reduce-motion equivalent, and the safety screens kept clear. Prove them on 1–2 pilot screens without redesigning those screens.

**Phase D:** Win the first impression: an `OnboardingScaffold` (progress dots + Skip + bottom CTA), a hero illustration slot with graceful fallback, custom species chips with selection feedback + a11y labels, and the per-step signature motion (breathing hero, species spring, shield draw-in/seal, bell ring, activation arrival) — all reduce-motion-gated, with the 5-step flow / analytics / pet creation / routing unchanged.

---

## Files changed

### New files (3)
| File | Purpose |
|---|---|
| `mobile/lib/src/core/motion.dart` | `reduceMotion(context)`, `AppButton` (press-scale 0.97 + light haptic), `Skeleton` / `SkeletonCard` / `SkeletonTimelineNode` (shimmer over ink/700, static under reduce-motion). |
| `mobile/lib/src/router/app_page_transitions.dart` | `AppPageTransitions.fadeThrough` / `sharedAxisVertical` (Material 3 motion via `animations` pkg); collapses to instant under reduce-motion. |
| `mobile/test/motion_test.dart` | reduce-motion contract tests (helper, AppButton, Skeleton shimmer gating). |

### Modified files
| File | Change |
|---|---|
| `mobile/pubspec.yaml` / `.lock` | Added `flutter_animate ^4.5.2` + `animations ^2.2.0`. |
| `mobile/lib/src/router/app_router.dart` | Key routes → `pageBuilder` with `AppPageTransitions` (home/sign-in/onboarding/history = fade-through; pets/family/capture/describe = shared-axis). **Result/EMERGENCY are `Navigator.push`, not routes here — left on the default clear transition.** Redirect/guard logic untouched. |
| `mobile/lib/src/onboarding/onboarding_flow.dart` | Full Phase D rebuild: `_OnboardingHeader` (labeled progress + Skip), hero (`AppImage`+breathing), `_SpeciesChip` (icon+label+spring+semantics), shield draw-in/seal, bell ring, activation avatar+sparkle, CTAs → `AppButton`. Flow logic preserved. |
| `mobile/lib/src/pets/pet.dart` | Added `speciesEmoji()` + `speciesName()` (additive; `speciesLabel()` now composes them — single source of truth kept). |
| `mobile/lib/src/home/home_screen.dart` | Pilot: loading → `SkeletonCard` placeholders; primary Check CTA → `AppButton` (press-scale); pet name → `petDisplayName` (Phase B follow-through). |
| `mobile/lib/src/health/history_timeline_screen.dart` | Pilot: loading → 3× `SkeletonTimelineNode`. |
| `mobile/test/flutter_test_config.dart` | Global: disable animations (reduce-motion) per test → deterministic, no pending-timer flakiness; exercises the static paths. |
| `mobile/test/onboarding_test.dart` | Added scaffold test (progress label + Skip + labeled species chips). |

---

## Acceptance criteria checklist

### Phase C (§8 Phase C / §9.C)
- [x] `flutter_animate` (+ shimmer via flutter_animate) and `animations` added.
- [x] `core/motion.dart`: `reduceMotion`, `AppButton` press-scale+haptics, `Skeleton` widgets.
- [x] `app_page_transitions.dart` + go_router key routes wired (shared-axis / fade-through).
- [x] **Safety:** emergency + result screens use clear transitions (they're `Navigator.push`/`MaterialPageRoute`, not animated go_router routes) — verified.
- [x] Pilots: skeletons on home + history loading; `AppButton` on a primary CTA. No screen redesigned (those are D/F/I).
- [x] Every animation checks `reduceMotion` → static equivalent (unit-tested).
- [x] `analyze` clean; `test` green.
- [ ] **MANUAL:** 60fps profile on a mid-range device + Android "Remove animations" device sweep (device disconnected — see Device validation).

### Phase D (§8 Phase D / §9.D / §3.2)
- [x] `OnboardingScaffold`: progress dots ("step n of 5" semantics) + top-right Skip + bottom CTA. Existing 5-step PageView + 250ms animateToPage kept.
- [x] Step 1: hero via `AppImage(AppAssets.onbHero, fallback: teal radial)` + breathing parallax + staggered copy fade-up. Copy verbatim.
- [x] Step 2: `_SpeciesChip` (`AppAssets.species`, **emoji fallback**) + selection pop/fill + **per-species semantic labels** (fixes emoji a11y gap). Name field filled.
- [x] Step 3: trust pillars (from B) + shield-care hero draw-in + seal shimmer.
- [x] Step 4: bell one-time ring; name token uses the B display helper.
- [x] Step 5: pet avatar spring-in + restrained sparkle; correct name.
- [x] All motion reduce-motion-gated; assets degrade gracefully (fallbacks render today — no art generated yet).
- [x] `analyze`/`test` green; dots/chips/skip labeled (widget-tested).
- [x] Routing/guard logic unchanged (Skip is a new nav action to `/`, not a guard change).
- [ ] **MANUAL:** founder device walkthrough + screenshots for the QA library (device disconnected).

### Cross-cutting (§8.1)
- [x] analyze clean / tests green (107). [x] Reduce-motion verified (tests). [x] No safety/business-logic diff. [x] Light + dark both build.

---

## Device validation results

**Status: BLOCKED → MANUAL (founder-side). Not faked.**

- Earlier in the session the connected device (`jfzxugsgnnvsrsg6`, Redmi `22095RA98C`) was on a **secured lock screen** and MIUI rejected ADB install (`INSTALL_FAILED_USER_RESTRICTED`).
- By the time the Cycle-2 APK was built, the **device had disconnected** (`adb devices` empty), so install + screenshot capture were not possible.

**Founder runbook (≈3 min):** unlock + enable MIUI "Install via USB", then:
```bash
cd mobile
flutter build apk --debug --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
adb install -r build/app/outputs/flutter-apk/app-debug.apk
# Validate: onboarding walkthrough (progress dots, Skip, species chips, hero/shield/bell/avatar motion),
# then toggle Settings → Accessibility → "Remove animations" and confirm every step is static.
adb exec-out screencap -p > ../runtime/ui_validation/cycle_cd/after_onb_<step>.png
```
Reduce-motion is verified at the unit level (the whole suite runs with animations disabled and is green, exercising every static path); the on-device 60fps + visual pass is the founder's confirmation step (the roadmap marks Phase C/D device checks MANUAL).

---

## Screenshots index

`runtime/ui_validation/cycle_cd/` — *(empty; device unavailable this run — founder to populate via the runbook).*
Cycle 1's `runtime/ui_validation/cycle_ab/device_locked_blocker.png` documents the original lock blocker.

## Flutter analyze results
```
$ flutter analyze
Analyzing mobile...
No issues found! (ran in 4.3s)
```

## Flutter test results
```
$ flutter test
00:11 +107: All tests passed!
```
New: `motion_test.dart` (4) + an onboarding scaffold test. The global test config now runs all tests in reduce-motion (deterministic; proves the static fallbacks).

## Build results
```
$ flutter build apk --debug --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…
✓ Built build/app/outputs/flutter-apk/app-debug.apk   (assembleDebug 14.1s)
```

## CI results
Not runnable here (`gh` absent; `main` protected). **MANUAL/founder:** CI runs on PR; local equivalents (analyze/test/build) all green above.

---

## Regressions found
- **Pending-timer test failures** from the new looping/entrance animations (onboarding "breathing" hero, fade-ups) under the test FakeAsync — flutter_animate left timers pending at teardown.
- `AppSpace` undefined in `home_screen.dart` (missing import) — caught by analyze.
- PostHog channel hangs in the headless test (`_advance()` awaits an analytics capture that never resolves without a native handler), so the onboarding scaffold test couldn't advance to step 2.

## Regressions fixed
- Test config now disables animations globally (per-test) → deterministic, no pending timers, and it exercises the reduce-motion static paths. Individual tests opt back into motion via a local `MediaQuery` override (`motion_test.dart`).
- Added the missing `design_tokens` import.
- Onboarding test stubs the `posthog_flutter` method channel so `_advance()` completes.
- **No test regressions** — full suite green (107, up from 102 at Cycle 1 merge).

---

## Self-audit (roadmap requirement → status)

| # | Requirement (§4 / §8 C-D / §3.2 / §9) | Status | Note |
|---|---|---|---|
| C1 | `flutter_animate` + shimmer | **COMPLETE** | shimmer via flutter_animate `.shimmer()`. |
| C2 | `reduceMotion` + `AppButton` + `Skeleton` | **COMPLETE** | all reduce-motion-aware; unit-tested. |
| C3 | `AppPageTransitions` wired to key routes | **COMPLETE** | fade-through + shared-axis; reduce-motion → instant. |
| C4 | Emergency/result kept clear/instant | **COMPLETE** | they are `Navigator.push` (not animated routes). |
| C5 | Pilot skeletons + button press-scale | **COMPLETE** | home + history loading; home Check CTA. |
| D1 | OnboardingScaffold (dots + skip + CTA) | **COMPLETE** | labeled; widget-tested. |
| D2 | Step 1 hero + breathing + copy fade-up | **COMPLETE** | `AppImage` + teal-radial fallback. |
| D3 | Custom species chips + spring + a11y labels | **COMPLETE** | emoji fallback until icons exist. |
| D4 | Step 3 shield draw-in + seal | **COMPLETE** | pillars from Phase B. |
| D5 | Step 4 bell ring | **COMPLETE** | one-time shake (~±8°). |
| D6 | Step 5 avatar spring + sparkle | **COMPLETE** | restrained shimmer, not confetti. |
| D7 | Reduce-motion gating everywhere | **COMPLETE** | per-step + scaffold + chips. |
| D8 | Routing/guard unchanged | **COMPLETE** | only added a Skip nav + router transitions. |
| — | Device visual + 60fps | **PARTIAL (MANUAL)** | device disconnected; runbook provided. |
| — | Illustration assets (hero/shield/species/avatar) | **N/A this phase** | per §7.5, all wired via `AppImage` with code fallbacks; art generation is Phase 6 (founder/GPT-Image). The UI is shippable now via fallbacks. |

No requirement silently deferred.

---

## Remaining concerns (surfaced)
1. **Illustration assets not generated** — every Phase D slot (onboarding hero, shield-care, species icons, pet avatars) renders its code fallback today (teal radial / shield icon / emoji / paw disc). This is by design (§7.5: tokens & screens merge before art). Generating the GPT-Image assets (Phase 6) is a separate founder step; dropping them into `assets/…` will light them up with zero code change.
2. **Fonts still runtime-fetched** (carried from Cycle 1) — bundling `.ttf` remains the offline-hardening follow-up.
3. **Device validation MANUAL** — needs the device reconnected + unlocked.
4. **Page-transition reduce-motion** is verified by the helper logic + the all-tests-in-reduce-motion run; a real-device "Remove animations" sweep across navigations is the founder confirmation.

---

## Recommendation

**Phases C + D are code-complete, lint-clean (0 issues), tested (107 green incl. new reduce-motion + onboarding-scaffold tests), and build a debug APK.** Motion honors reduce-motion throughout; the onboarding is rebuilt with a labeled scaffold, hero, custom chips, and signature motion — all degrading gracefully until art is produced. No safety/business logic was touched; the emergency/result path keeps clear transitions.

Outstanding items are founder-side: **on-device visual + 60fps + reduce-motion sweep** (device must be reconnected/unlocked) and **PR/CI → squash-merge** (protected `main`, no `gh` here).

Branch `ui-cycle-c-d` is pushed and ready. **STOP — say the word to merge C+D (same flow as A+B), then I'll begin Cycle 3 (Phases E + F).**
