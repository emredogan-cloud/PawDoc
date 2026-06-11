# PHASE M1 REPORT — "First breath" (animate what already exists)

**Date:** 2026-06-11 · **Branch:** `motion-m1` (stacked on `motion-m0`, PR #35) · **Source of truth:** `PAWDOC_MOTION_ROADMAP.md` §3 M1 + §4 (A1–A6, global conventions) + matrix #1–8 · `PAWDOC_MOTION_FINAL_AUDIT.md` §§4–6.

## 1 · Scope delivered (matrix #1–8 — all eight slots)

| # | Slot | Asset (≤250KB gate) | Actual | Motion |
|---|------|--------------------|--------|--------|
| 1 | Onboarding 1 hero | `onboarding_hero_loop_v1.json` 8s | 58KB | duo breath 4s×2, ground glow breathe, 3 sparkles |
| 2 | Home empty welcome | `empty_home_welcome_loop_v1.json` 6s | 65KB | micro-breath, **fur-matched eyelid blinks** (puppy @2.0s, kitten @4.2s, parented to breath), halo shimmer, 4 sparkles |
| 3 | Sign-in logo | `signin_heartbeat_v1.json` **one-shot 1.2s** | 35KB | ECG trim-path sweep across the shield, teal glow pulse @0.9s, settle — **never loops** (test-pinned) |
| 4 | Paywall art | `paywall_peace_loop_v1.json` 8s | 53KB | deep sleeper breath, floating "z" per cycle; placement raised 120→160 per spec |
| 5 | Family circle | `family_circle_loop_v1.json` 8s | 78KB | group breath, rising sparkle drift |
| 6 | Referral gift | `referral_gift_idle_v1.json` 8s | 75KB | 0.6s settle-in **once** (markers `settle`/`loop`), ±2° wiggle @~5s of loop, seamless 360° sparkle orbit |
| 7 | Result (non-emergency) | code (flutter_animate) | — | 280ms section fade-up beats (40ms offsets) + **"Saved to {Pet}'s history"** chip (honest: only when the row stored) + existing hero settle kept |
| 8 | History empty | `history_empty_loop_v1.json` 6s | 35KB | art breath + its own sparkle-trail twinkling |

**Infrastructure:** `AppMotionAsset` wrapper (`core/app_motion_asset.dart`) — reduce-motion → existing `AppAssets` PNG; `VisibilityDetector` pause <10% visible; one-shot + marker-loop modes; controller disposed; missing/corrupt asset degrades to PNG. Registry `AppMotionAssets` with required-fallback map. Deps: `lottie`, `visibility_detector` (pure-Dart). Reproducible producer: `scripts/motion/build_m1_lottie.py` (alpha-trim → resize → octree-quantize ≤165KB embed → vector overlay layers).

## 2 · Validation gates

| Gate | Result |
|------|--------|
| `flutter analyze` | **PASS** — no issues |
| `flutter test` (full) | **PASS** — 157/157 (17 new) |
| `paywall_policy_test` | **PASS** — 7/7 |
| `./scripts/verify-disclaimers.sh` | **PASS** — 6/6 (result-screen stagger did not disturb flag gating) |
| `flutter build apk --debug` | **PASS** |
| GitHub CI | runs on the PR |
| Device validation | **PENDING — no USB device attached** (see §5) |

New tests: asset parse/budget/markers/fallback-existence per slot · wrapper contract (reduce-motion = zero Lottie in tree; PNG path asserted; degrade path) · **permanent safety guard** (EMERGENCY + Delete trees contain no Lottie/AppMotionAsset) · saved-confirmation honesty + never-blocks-Done + reduce-motion-immediate.

Headless frame renders (Flutter rasterizer, all 7 assets × 3 timestamps incl. mid-blink, mid-ECG, settle/orbit frames) archived: `runtime/motion_validation/m1/headless_renders/`.

## 3 · Safety & accessibility (roadmap §5 gates)
1. EMERGENCY + Delete: zero additions — now **enforced by a permanent guard test**.
2. Nothing animates before a safety action is tappable; stagger/confirmation are opacity/offset-only on widgets that are present and hittable from frame one; Done never blocked (test).
3. Reduce-motion → static PNG everywhere (wrapper-level test + per-slot fallback shipping test); blinks/twinkles ≤2 opacity cycles/sec; no strobe.
4. ≤1 ambient loop per screen (each slot is its screen's only loop); pause offscreen via visibility; tickers mute in background; assets 35–78KB (budget ≤250KB, CI-enforced).
5. Result-adjacent change shipped with the H-ritual: disclaimers 6/6 + paywall 7/7 + pipeline untouched (diff is UI-only).

## 4 · Documented deviations (surfaced, not silent)
1. **Production route:** programmatic Lottie builder (committed, reproducible) instead of AE/Bodymovin authoring — same schema, same budgets; the builder is reviewable and re-runnable.
2. **A1 blink spec vs actual art:** the onboarding duo is drawn with closed-happy eyes — blinks are anatomically impossible there. The blink life moved to the **open-eyed** welcome duo (A2) where the roadmap's "the eye expects a blink" observation actually applies; A1 carries breath/glow/sparkles.
3. **Raster-part micro-motion** (A2 ear flick/tail sway, A4 ear twitch, A5 per-figure 0.3s offsets, A6 bow flutter) is not feasible on flat PNGs without destructive slicing; substituted per-slot with breath amplitude, blinks, sparkle systems, wiggle, and orbit — same calm register, no position jumps ≥6px.
4. **"Golden test per slot"** implemented as structural reduce-motion assertions (wrapper renders the exact fallback PNG; no Lottie type in tree) rather than pixel goldens — pixel goldens would couple CI to rasterizer versions; the verified-PNG-fallback intent is fully held. Pixel-level frame audits were done headlessly and archived (see §2).
5. Lottie/visibility_detector added to runtime deps (declared in the roadmap's package list).

## 5 · Device validation — PENDING
Still no USB device attached (checked at phase start). Required pass per the mission: sign-in heartbeat, onboarding duo, home welcome, paywall sleeper, family circle, referral gift settle+idle, save confirmation + stagger, history empty — with recordings, FPS profile, and captures into `runtime/motion_validation/m1/`. **Neither M0 nor M1 merges until their device passes complete.**

## 6 · Rollback
Per-slot: each integration commit swaps one `AppImage` for one `AppMotionAsset`; reverting any slot restores the static PNG (which ships forever as the fallback). The result-screen beat is its own commit.
