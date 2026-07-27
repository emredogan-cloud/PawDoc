# PawDoc UI/UX Execution — Cycle 1 Report (Phases A + B)

- **Date:** 2026-06-10
- **Branch:** `ui-cycle-a-b` (off `main` @ `11dc1c9`)
- **Source of truth:** `PAWDOC_UI_UX_MASTER_ROADMAP.md` §8 (Phase A, Phase B), §2 (design system), §3.2.3 / §3.8 (copy), §7 (asset plumbing)
- **Scope rule honored:** UI / theme / asset / copy only. No safety logic, AI pipeline, RLS, Edge Functions, routing guards, or purchase logic changed.

---

## Implemented phases

- **Phase A — Design Tokens, Theme & Asset Plumbing** (the enabler everything else consumes)
- **Phase B — Honesty & Safety Copy Fixes** (launch-blocking trust defects + crash surface)

Both phases ship together in this cycle's single branch/PR per the mission's two-phase model.

---

## Objectives

**Phase A:** Establish a single source of truth (`design_tokens.dart`) for color, type, spacing, radius, elevation, motion and glass; refactor the theme to consume it (warm-ink dark + warm clinical light); add `AppAssets` + `AppImage` (graceful fallback) and declare the asset tree; sweep inline hex/radii to tokens — so every later phase restyles by construction.

**Phase B:** Remove the three launch-blocking trust defects + the cold-start crash surface: (1) fabricated "★ 4.8 / trusted by thousands" + unsubstantiated "Reviewed by veterinary experts"; (2) the "RevenueCat (runbook 09)" dev text on the paywall; (3) broken pet-name tokens ("check on ker", "in 's health"); (4) the Supabase-not-initialized raw red crash; (5) the truncated sitter-mode privacy helper; (6) a repo sweep for other dev/internal leaks.

---

## Files changed

### New files (8)
| File | Purpose |
|---|---|
| `mobile/lib/src/theme/design_tokens.dart` | **AppColors / AppType / AppSpace / AppRadius / AppElevation / AppMotion / AppGlass** — the token contract (§2.2–§2.7). |
| `mobile/lib/src/theme/app_assets.dart` | `AppAssets` path constants (§7.2). |
| `mobile/lib/src/core/app_image.dart` | `AppImage` fallback wrapper — missing asset → themed fallback, never a broken box (§7.4). |
| `mobile/lib/src/core/pet_display.dart` | `petDisplayName()` / `petDisplayPossessive()` name-token hardening (Phase B). |
| `mobile/lib/src/core/boot_error_app.dart` | `BootErrorApp` — calm "couldn't start — retry" screen (Phase B error boundary). |
| `mobile/test/flutter_test_config.dart` | Disables `google_fonts` runtime fetching in tests → deterministic, offline-safe. |
| `mobile/test/pet_display_test.dart` | Unit tests for name-token hardening (empty/lowercase/normal/whitespace/possessive). |
| `mobile/test/boot_error_test.dart` | Widget test: forced boot error → calm retry screen, no raw error. |

### Modified files (18)
| File | Change |
|---|---|
| `mobile/lib/src/theme/app_theme.dart` | Rebuilt light + dark `ThemeData` from tokens (warm-ink dark signature); cards 12→16; stadium buttons kept; re-exports `AppColors` for back-compat. |
| `mobile/pubspec.yaml` | Declared the §7.1 asset tree; added `google_fonts`; documented the offline-bundle follow-up. |
| `mobile/pubspec.lock` | `google_fonts` resolved (8.1.0). |
| `mobile/lib/src/onboarding/onboarding_flow.dart` | **Honesty:** fabricated trust copy → truthful pillars (§3.2.3). **Name token:** `_petName` now capitalizes + falls back. |
| `mobile/lib/src/monetization/paywall_screen.dart` | **Honesty:** removed "runbook 09" dev text → production-safe "Premium is coming soon" state (no purchasable CTAs when unconfigured); Variant C card de-fabricated; radii → tokens. |
| `mobile/lib/src/monetization/paywall_copy.dart` | **Honesty:** removed fabricated testimonial ("Sarah M.") + "Veterinary Advisory team" → truthful value/trust copy. |
| `mobile/lib/main.dart` | **Error boundary:** init wrapped → `BootErrorApp` on failure (closes R09); release-only calm `ErrorWidget` for in-tree errors. |
| `mobile/lib/src/pets/pet_form_screen.dart` | **Truncation fix:** `helperMaxLines: 3` so the sitter-mode privacy note shows fully (no "Visible onl…"). |
| `mobile/lib/src/text_input/symptom_text_screen.dart` | Name token applied to the describe-symptoms entry copy. |
| `mobile/lib/src/home/home_screen.dart` | Name token applied to the AppBar pet switcher (title + menu items). |
| `mobile/lib/src/health/health_event_form_screen.dart`, `…/reminders/reminder_form_screen.dart` | Name token applied to contextual AppBar titles. |
| `mobile/lib/src/analysis/result_screen.dart` | **Sweep:** triage colors codified to identical-valued tokens; 2 radii → tokens (cosmetic). |
| `mobile/lib/src/analysis/emergency_result_screen.dart` | **Sweep:** emergency red codified to `AppColors.emergencyLight` (identical value `#C62828`, zero behavior change). |
| `mobile/lib/src/capture/camera_screen.dart`, `…/capture/video_capture_screen.dart`, `…/health/breed_insight_card.dart`, `…/family/accept_family_invite_screen.dart` | **Sweep:** radii → tokens. |

---

## Acceptance criteria checklist

### Phase A (roadmap §8 Phase A)
- [x] `design_tokens.dart` exposes AppColors/AppType/AppSpace/AppRadius/AppElevation/AppMotion/AppGlass.
- [x] Fonts added (Inter + Bricolage Grotesque via `google_fonts`; bundling documented as offline-hardening follow-up).
- [x] `app_theme.dart` consumes tokens; **light + dark** both build (warm-ink dark).
- [x] `AppAssets` + `AppImage` (fallback) created; asset folders declared in `pubspec.yaml` with `.gitkeep` (13 folders).
- [x] Mechanical sweep done — **grep gate: 0 inline hex outside `design_tokens.dart`, 0 `BorderRadius.circular` in `lib/src`.**
- [x] `flutter analyze` clean; `flutter test` green; **debug APK builds**.
- [ ] **MANUAL:** founder visual smoke on device (blocked this run — device locked; see Device validation).

### Phase B (roadmap §8 Phase B)
- [x] Fabricated "★ 4.8 / trusted by thousands" + "Reviewed by veterinary experts" removed → truthful pillars (§3.2.3).
- [x] Paywall "runbook 09" dev text removed → production-safe "Premium is coming soon" state; "Not now" + emergency bypass untouched.
- [x] Pet-name tokens hardened (capitalize + "your pet" fallback) + **unit tests** for empty/lowercase/normal.
- [x] Error boundary: forced init/boot error → calm `BootErrorApp` (retry), never a raw red stack + **widget test**.
- [x] Truncated sitter-mode privacy helper fixed (full text shows).
- [x] Repo sweep — **grep gate: 0 user-facing "runbook"/rating-literal/fabricated strings** (remaining matches are explanatory code comments only).
- [ ] **Legal/owner sign-off on trust copy** — REQUIRED before merge (see Remaining concerns).

### Cross-cutting gates (§8.1)
- [x] analyze clean / tests green (output below).
- [x] No safety/business-logic diff (UI/theme/asset/copy only). Emergency & result screens: color literals codified to **identical values**; only cosmetic corner-radii bumped — all safety logic (ack gate, back-block, paywall bypass, server-forced disclaimer, confidence<0.60 path) untouched.
- [x] Light **and** dark both build.
- [ ] Reduce-motion / AA contrast device pass — MANUAL (no animations added this cycle; AA designed-in via warm-ink tokens, founder to verify on device).

---

## Device validation results

**Status: BLOCKED → MANUAL (founder-side). Not faked.**

A device is connected (`jfzxugsgnnvsrsg6`, Redmi `22095RA98C`, 1080×2408 — the same device class as the roadmap's evidence screenshots), but:

1. **The device is on a secured lock screen** (PIN/pattern). `screencap` of app screens returns black/empty; I do not have the unlock credentials → **cannot capture app screenshots**.
2. **ADB install is restricted** by MIUI: `INSTALL_FAILED_USER_RESTRICTED: Install canceled by user` (requires on-device confirmation, impossible while locked) → **cannot install the new build**.

What I could verify on the real device: the previously-installed `app.pawdoc` process runs, and logcat during launch shows **no Flutter/Dart fatal errors** — only MIUI/carrier noise (`mi_exception_log`, Vodafone selfservis Wi-Fi permission). This is the *old* build (my APK didn't install), so it is not validation of this cycle's code — it only confirms the device/app pipeline is otherwise healthy.

**Founder runbook to complete device validation (≈3 min):**
```bash
# 1. Unlock the device; enable Developer Options → "Install via USB" (MIUI).
# 2. Build + install with real Doppler defines (so auth-gated screens are reachable):
cd mobile
flutter build apk --debug \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY  # + POSTHOG/REVENUECAT/etc.
adb install -r build/app/outputs/flutter-apk/app-debug.apk
# 3. Validate & screenshot: sign-in (new type/warm-ink), onboarding step 3 (truthful pillars),
#    add-pet (full sitter helper), paywall (coming-soon if RC unconfigured), home (capitalized name).
adb exec-out screencap -p > ../runtime/ui_validation/cycle_ab/after_<screen>.png
```

> The roadmap itself marks Phase A device validation as "MANUAL: founder visual smoke on device," and Phase B as tests + grep — so the automated evidence below is the intended gate; the on-device visual pass is the founder's confirmation step.

---

## Screenshots index

`runtime/ui_validation/cycle_ab/`
| File | Contents |
|---|---|
| `device_locked_blocker.png` | The connected device's secured lock screen — documents why on-device capture is MANUAL this run. |

No `before_*/after_*` app screenshots captured (device locked — see above). Founder to populate via the runbook.

---

## Flutter analyze results

```
$ flutter analyze
Analyzing mobile...
No issues found! (ran in 3.2s)
```

## Flutter test results

```
$ flutter test
00:08 +102: All tests passed!
```
Includes the 2 new Phase-B test files (`pet_display_test.dart`, `boot_error_test.dart`) and the new `flutter_test_config.dart` (google_fonts runtime-fetch disabled for determinism). No prior tests regressed.

## Build results

```
$ flutter build apk --debug --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…
✓ Built build/app/outputs/flutter-apk/app-debug.apk   (Gradle assembleDebug 44.2s; 217 MB debug artifact)
```

## CI results

GitHub CI is **not runnable from this headless environment** (`gh` not installed; `main` is protected — linear history + review). CI runs on PR open. **MANUAL/founder:** open the PR for `ui-cycle-a-b` and confirm CI green before squash-merge. Local equivalents of the CI gates (analyze, test, build) are all green above.

---

## Regressions found

- During the sweep, `flutter analyze` caught: (a) an unnecessary `physics.dart` import (`SpringDescription` is reachable via material); (b) `kReleaseMode` not re-exported by material; (c) modern `unnecessary_underscores` on `errorBuilder (_, __, ___)`; (d) a null-promotion error on the home AppBar pet name (`active` is a widget field). All caught pre-commit by analyze.
- An unintended visual change I introduced and reverted: bumping the paywall featured-card elevation 4→8 during the radius sweep (elevation isn't in the grep gate) — reverted to preserve the exact look.

## Regressions fixed

- All four analyze findings above fixed (import added/removed, wildcard `_`, guarded `active!.name`).
- Elevation change reverted.
- **No test regressions** — full suite green (102).

---

## Self-audit (roadmap requirement → status)

| # | Roadmap requirement (§8 A/B, §2, §3.2.3, §3.8, §7) | Status | Note |
|---|---|---|---|
| A1 | `design_tokens.dart` with all 7 token groups | **COMPLETE** | §2.2–§2.7 values verbatim. |
| A2 | Fonts: Inter + Bricolage Grotesque | **COMPLETE** | via `google_fonts`; **bundling = documented follow-up** for offline determinism. |
| A3 | `app_theme.dart` light + dark from tokens (warm-ink) | **COMPLETE** | both build. |
| A4 | `AppAssets` + `AppImage` fallback | **COMPLETE** | §7.2 / §7.4 verbatim. |
| A5 | pubspec asset folders + `.gitkeep` | **COMPLETE** | 13 folders, §7.1. |
| A6 | Mechanical sweep: no inline hex/radii in `lib/src` | **COMPLETE** | grep gate = 0/0. EdgeInsets tokenized in theme/new code (not in the grep gate; full app-wide EdgeInsets sweep deferred to avoid a large risky diff — see Remaining concerns). |
| B1 | Remove fabricated trust copy → truthful pillars | **COMPLETE** | onboarding S04. Wording pending legal sign-off. |
| B2 | Remove paywall dev text → "coming soon" | **COMPLETE** | + Variant C fabricated testimonial neutralized. |
| B3 | Harden pet-name tokens + tests | **COMPLETE** | applied to onboarding, describe, home, form titles. |
| B4 | Error boundary (calm retry) | **COMPLETE** | `BootErrorApp` + release `ErrorWidget`; widget test. |
| B5 | Fix truncated sitter helper | **COMPLETE** | `helperMaxLines: 3`. |
| B6 | Repo leak sweep | **COMPLETE** | 0 user-facing leaks. "B2B-Lite (sitter)" jargon (family screen) is a **real product term** the roadmap assigns to **Phase K** — flagged, not fixed out-of-phase. |
| — | Device visual validation | **PARTIAL (MANUAL)** | Blocked by locked device; runbook provided. |
| — | l10n `.arb` update for trust copy | **N/A** | onboarding strings are hardcoded English (not localized); fixed in place. Full onboarding localization (en+de) recommended as a separate i18n pass — see Remaining concerns. |

No requirement is silently deferred: the two PARTIAL/N/A items are surfaced here and below.

---

## Remaining concerns (surfaced for owner decision — not silently applied)

1. **Trust copy needs legal/owner sign-off (blocking per §8 Phase B).** The new pillars are the roadmap's §3.2.3 proposal verbatim: "Vet-informed triage protocols", "Errs on the safe side — flags emergencies first", "Your photos are private & encrypted", "We inform; your vet decides." Please confirm "vet-informed triage protocols" is defensible (or soften), and approve the paywall Variant C trust copy.
2. **Variant C fabricated testimonial (found beyond the stated Phase B list).** I replaced "Sarah M., dog parent" + "Reviewed by our Veterinary Advisory team" with truthful value copy, because shipping a fabricated testimonial is the same App-Store/FTC risk as the S04 "★ 4.8" line. Flagging because it changes what the C arm displays (analytics/timing unchanged). Approve, or disable Variant C until a real testimonial exists.
3. **Fonts via runtime fetch.** `google_fonts` caches after first launch; offline-first launch falls back to system font. For a health app, bundling the `.ttf` into `assets/fonts/` + `allowRuntimeFetching=false` is the hardening step — folder + pubspec note are ready; founder can drop the files (or I can in a follow-up).
4. **EdgeInsets not globally tokenized.** The grep gate covers hex + radii only; a full app-wide `EdgeInsets` → `AppSpace` sweep was deferred to avoid a large, regression-prone diff. New/touched code uses `AppSpace`.
5. **"B2B-Lite (sitter)" consumer jargon** is user-facing in `family_settings_screen.dart` — roadmap assigns the Family-screen de-jargonize to **Phase K**; left for that phase.
6. **Onboarding is hardcoded English** (not l10n). The honesty fix is in place; full en+de localization of onboarding is a recommended separate pass.
7. **Device & install constraints (MIUI + lock).** On-device validation requires the founder to unlock + enable "Install via USB".

---

## Recommendation

**Phases A + B are code-complete, lint-clean (0 issues), fully unit/widget-tested (102 green), and build a debug APK successfully.** All honesty/safety acceptance gates pass by grep + tests. Two gates remain founder-side and are the reason to STOP here per the mission's working agreement:

1. **Legal/owner sign-off on the trust copy** (Phase B is explicitly sign-off-gated), including the Variant C decision (#2 above).
2. **On-device visual smoke** (blocked by the locked device; runbook provided) and **PR/CI** (open PR for `ui-cycle-a-b`, confirm green, squash-merge — `main` is protected and `gh` isn't available here).

No safety or business logic was touched. Recommend: approve trust copy → open PR → confirm CI green → squash-merge → then authorize Cycle 2 (Phases C + D).
