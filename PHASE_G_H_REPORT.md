# PawDoc UI/UX Execution — Cycle 4 Report (Phases G + H)

- **Date:** 2026-06-10
- **Branch:** `ui-cycle-g-h` (off `main` @ `e887a80`, after Cycles 1–3 merged)
- **Source of truth:** `PAWDOC_UI_UX_MASTER_ROADMAP.md` §3.4 (capture), §3.5 (analysis — safety-critical), §8 Phase G/H, §9.G/§9.H, §4.6
- **Scope rule honored:** UI / theme / asset / motion only. **Phase H is the safety-critical phase — it is a PURE VISUAL DIFF.** No triage, confidence, disclaimer, emergency, paywall, upload, EXIF, or moderation logic changed.

> ⚠️ **Safety gate (Phase H):** every safety guarantee was re-verified after the change — see **Safety verification** below. The analysis pipeline (`analysis_runner.dart`, `analysis_service.dart`, the `/analyze` Edge Function, the AI service, `paywall_policy.dart`, `models/analysis_result.dart`) was **NOT touched** — only the three analysis *view* files were restyled.

---

## Implemented phases

- **Phase G — Capture, Camera & Describe**
- **Phase H — Analysis: Loading + Result + Emergency** (🔒 safety-gated, visual-only)

---

## Objectives

**Phase G:** A premium, guided capture entry (frosted sheet with per-mode guidance), a camera viewfinder with a framing guide + live lighting coach + privacy reassurance, and a more helpful describe-symptoms screen (example chips + animated affirmation) — without touching the upload/EXIF/moderation path.

**Phase H:** Elevate the product's heart — a calm AI-thinking pulse on loading, a triage hero that conveys the verdict by **colour + shape + text** (never colour alone) with an AA disclaimer, and a restyled emergency screen — **while preserving every safety guarantee** (server-forced disclaimer, emergency bypass, ack gate + back-block, confidence<0.60 path).

---

## Files changed (6 — all view/UI)

| File | Phase | Change |
|---|---|---|
| `home/home_screen.dart` | G | Frosted `_CaptureSheet` + `_CaptureModeTile` (icon + title + per-mode guidance + "what makes a good photo?" tip + stagger). The sheet still returns `photo`/`video`/`text`; the capture/analysis flow is unchanged. |
| `capture/camera_screen.dart` | G | `_FramingOverlay` (center-your-pet guide), `_LightingChip` (green "looks good" / amber tip — reuses the existing luma hint), `_PrivacyNote` ("location removed"). **`_capture`/`_compress`/`_onFrame` (EXIF strip, <2MB compress, R2 upload, quality dialog) UNCHANGED.** |
| `text_input/symptom_text_screen.dart` | G | `SymptomExampleChips` (seed the field) + animated "Looks good." (reduce-motion-gated) + filled field + `AppButton`. Min-char gate + popped value + keys unchanged. |
| `analysis/loading_screen.dart` | H | `_AiThinkingPulse` (concentric rings + shield-care mark, 1.6s loop) + the existing rotating messages (**timer gated on reduce-motion**) + live-region. Reduce-motion → static shield + one message. |
| `analysis/result_screen.dart` | H | `_TriageHero` (colour + **distinct icon/shape** + text label, AA on-colour, radius xl, live-region, gentle reveal); AA `DisclaimerBanner` (icon + onSurface contrast) — **`if (r.disclaimerRequired)` gate untouched**; "possible causes" label kept. |
| `analysis/emergency_result_screen.dart` | H | **Lightest touch:** secondary text `white70 → white` for AA contrast. Ack gate, back-block (`PopScope`), find-vet, telehealth, paywall bypass, disclaimer gate — **all unchanged**. No illustration/glass/celebration/added motion. |

---

## Safety verification (Phase H extra gate)

| Check | Result |
|---|---|
| `scripts/verify-disclaimers.sh` | **6/6 PASS** — disclaimer is API-injected, payload-driven, UI-gated on BOTH standard + emergency result screens (output below). |
| Emergency never paywalled | **Intact** — `paywall_policy.dart:28` `if (c.lastTriageWasEmergency) return false;`; runner still passes `lastTriageWasEmergency`; Edge `analyze/index.ts` "EMERGENCY IS NEVER PAYWALLED" / "emergencies are free" (Edge **untouched**). |
| `paywall_policy_test` | **7/7 PASS** (incl. emergency block, premium, daily cap). |
| confidence<0.60 → "insufficient information" | **Intact** — handled upstream (AI/Edge); `AnalysisResult.confidence` unchanged; the result view only renders the safe fields it's given. |
| Pipeline untouched | **✓** — `git status` shows changes only in the 6 view files; runner/service/Edge/AI/policy/model **not** modified. |
| Ack gate + back-block (emergency) | **Intact** — `PopScope(canPop: _acknowledged)` + the ack checkbox + gated Continue are byte-unchanged. |

```
$ bash scripts/verify-disclaimers.sh
PASS  AI pipeline forces disclaimer_required at the API level
PASS  AnalysisResult (Pydantic) defaults disclaimer_required to True
PASS  Dart AnalysisResult parses disclaimer_required from the JSON payload
PASS  standard result screen gates the disclaimer on the payload flag
PASS  emergency result screen gates the disclaimer on the payload flag
PASS  disclaimer copy is gated by the flag (flag refs 1 >= copy 1)
Disclaimers are API-injected (backend-forced flag, payload-driven, UI-gated).
```

---

## Acceptance criteria checklist

### Phase G (§3.4 / §9.G)
- [x] Frosted capture sheet with `CaptureModeTile` rows (icon + one-line guidance) + good-photo tip + stagger.
- [x] Camera: framing overlay + lighting chip (green/amber) + "Photos are private (location removed)" note.
- [x] **EXIF/GPS strip, <2MB compress, moderation/quality dialog, R2 presigned upload — verified UNCHANGED** (`_capture`/`_compress`/`_onFrame` byte-unchanged).
- [x] Describe: example chips that seed the field + animated "Looks good." + filled field.
- [x] Permission-denied rationale present (kept). `analyze`/`test` green.
- [ ] **MANUAL:** capture→upload end-to-end on device.
- [~] Post-capture "Use this / Retake" confirm — **deferred** (the existing quality dialog already offers Retake; an always-on confirm would restructure the capture→upload flow — surfaced, not silently added).

### Phase H (§3.5 / §9.H) 🔒
- [x] Loading: `AiThinkingPulse` (rings + shield) + rotating messages; reduce-motion → static; live-region.
- [x] Result: `TriageHero` (colour + **shape** + text, AA on-colour); AA `DisclaimerBanner`; gentle reveal (reduce-motion static).
- [x] Emergency: restyle only (AA contrast); ack gate / back-block / find-vet / bypass preserved; no illustration/glass/celebration/motion.
- [x] **Disclaimer SERVER-FORCED** — `verify-disclaimers.sh` 6/6.
- [x] **Emergency NEVER paywalled** — re-verified (policy + runner + Edge).
- [x] **confidence<0.60 path intact** — upstream, untouched.
- [x] `analyze`/`test` green (109).
- [ ] **MANUAL (MANDATED):** capture real EMERGENCY / MONITOR / NORMAL / degraded results on device (closes Findings F0-1/F1-1) — device unavailable this run.
- [~] pulse→triage cross-screen colour resolve + per-section stagger + min-display 1.2s — **deferred** (cross-screen coupling / loading-timing near the emergency path → conservative omission; surfaced for owner decision).

---

## Device validation results

**Status: BLOCKED → MANUAL.** Device disconnected (`adb devices` empty; earlier locked + MIUI-restricted). The **mandated EMERGENCY/MONITOR/NORMAL/degraded captures** (roadmap Findings F0-1/F1-1) remain founder-side. Build with real Doppler defines, run a check per triage level (use safe test inputs), and screenshot each into `runtime/ui_validation/cycle_gh/`.

## Screenshots index
`runtime/ui_validation/cycle_gh/` — *(empty; device unavailable — founder to capture the four result states + camera + capture sheet).*

## Flutter analyze / test / build
```
$ flutter analyze        → No issues found! (3.3s)
$ flutter test           → 00:07 +109: All tests passed!
$ flutter build apk --debug --dart-define=…  → ✓ Built app-debug.apk (assembleDebug 13.5s)
```
## CI results
Not runnable here (`gh` absent; `main` protected). MANUAL/founder: CI on PR.

---

## Regressions found / fixed
- One unused local (`color`) in `result_screen.dart` after the `_TriageHero` extraction — removed (analyze caught it). No test regressions; full suite green (109).

---

## Self-audit (roadmap requirement → status)

| # | Requirement | Status | Note |
|---|---|---|---|
| G1 | Frosted capture sheet + guided tiles | **COMPLETE** | + good-photo tip + stagger. |
| G2 | Camera framing + lighting + privacy | **COMPLETE** | upload/EXIF/moderation untouched. |
| G3 | Describe example chips + animated affirmation | **COMPLETE** | keys preserved. |
| G4 | Post-capture confirm | **PARTIAL (deferred)** | quality dialog covers retake; always-on confirm would touch capture flow. |
| H1 | AI-thinking pulse + reduce-motion static | **COMPLETE** | message timer gated. |
| H2 | TriageHero (colour+shape+text) + AA disclaimer | **COMPLETE** | reveal gated; gate preserved. |
| H3 | Emergency restyle, all safety preserved | **COMPLETE** | lightest touch (AA). |
| H4 | Disclaimer server-forced / emergency bypass / confidence path | **COMPLETE (verified)** | see Safety verification. |
| — | min-display 1.2s, pulse→triage resolve, section stagger | **DEFERRED** | timing/cross-screen near the safety path — surfaced. |
| — | Device captures (F0-1/F1-1) | **PARTIAL (MANUAL)** | device unavailable. |

---

## Remaining concerns (surfaced)
1. **Mandated emergency/result device captures** (Findings F0-1/F1-1) still open — the EMERGENCY screen has never been screenshotted. Founder must capture the four result states on device.
2. **Deferred near-safety items** (your call): post-capture confirm (touches capture flow), and the loading **min-display 1.2s** / pulse→triage cross-screen resolve. I deferred the min-display deliberately — a forced minimum loading time must never delay an EMERGENCY result, so adding it needs careful, emergency-exempt handling (owner decision).
3. **Illustration assets** (shield-care for the pulse) render the code fallback (verified_user icon) until Phase 6.
4. **Device validation MANUAL**; **fonts runtime-fetched** (carried).

---

## Recommendation

**Phases G + H are code-complete, lint-clean (0 issues), tested (109 green), and build a debug APK.** Critically, **Phase H is a pure visual diff** — `verify-disclaimers.sh` (6/6), `paywall_policy_test` (7/7), and a read-only audit confirm the server-forced disclaimer, the emergency-never-paywalled rule, the ack gate/back-block, and the confidence<0.60 path are all intact; the analysis pipeline was not touched.

The one safety-relevant follow-up that **must** happen before launch is founder-side: **capture the real EMERGENCY/MONITOR/NORMAL/degraded result screens on a device** (the roadmap's standing QA gap). Plus the usual PR/CI → squash-merge.

Branch `ui-cycle-g-h` is pushed and ready. **STOP — say "merge G+H" to squash-merge (same flow as A–F), then I'll begin Cycle 5 (Phases I + J).**
