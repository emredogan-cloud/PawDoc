# PawDoc — Final Pre-Launch Product Audit

> **Verdict: 🔴 NO — not submittable today · Overall launch readiness ≈ 62%**
> A safety-verified, well-engineered core blocked by **6 CRITICAL** findings that collapse to **3 distinct root causes** (debug-signed release, account-deletion failure, non-operable legal pages), plus a store/iOS/light-mode blocker cluster. See [Launch Verdict](#launch-verdict).

**Audit date:** 2026-07-06 · **Branch audited:** `feat/legal-portal-integration` (= `main` + legal-portal PR #78, **unmerged to protected `main`**)
**Findings:** 64 total — **6 CRITICAL · 11 HIGH · 33 MEDIUM · 14 LOW**

This audit produced **exactly three files** (per the mission spec):
- `PAWDOC_PRELAUNCH_FINAL_AUDIT.md` — this report
- `PAWDOC_STORE_REVIEW_CHECKLIST.md` — Appendix A (Apple + Google submission checklist)
- `PAWDOC_FOUNDER_ACTION_PLAN.md` — Appendix B (founder-controlled work)

## Scope & Method

A 15-perspective independent audit run as a multi-agent workflow: parallel specialist finders (Flutter, backend, QA, DevOps, AWS, security, product, UI, UX, veterinary safety, Apple reviewer, Google reviewer, GDPR, RevenueCat, founder) each read the **actual current source** — prior reports were treated as hypotheses to confirm or refute, not as truth. Every CRITICAL and HIGH finding was then handed to an independent adversarial verifier that re-read the cited files and tried to disprove it; refuted findings were dropped, so what remains survived a skeptic. Each finding carries severity, evidence (file\:line), root cause, and user / business / store impact, plus an exact solution and acceptance criteria. Runtime coverage that requires a physical device or live production infrastructure is marked as founder-side and was **not** faked.

---

## Executive Summary

**No — PawDoc cannot be submitted to either store today.** This audit covers branch `feat/legal-portal-integration` (protected `main` plus the legal-portal work from PR #78, which remains **unmerged** to `main`). The engineering, AI/veterinary-safety, and backend cores are genuinely strong and the single biggest historical risk is resolved: image pixels are now actually sent to Gemini and Claude (AI-01, SEC-03, verified by payload-capture tests), the emergency-never-paywalled rule holds end-to-end, RLS is enabled on all 13 user tables, and the disclaimer is force-injected server-side. But six CRITICAL findings and a cluster of hard store blockers stand directly between this build and submission: the Android release is still signed with the **debug keystore** (SEC-01/INF-01/PLAY-01/REC-01 — a flat Play rejection and the prior "beta-ready" verdicts' most damaging blind spot), account deletion **500s** for any user in a referral relationship because the referral FKs lack `ON DELETE` (RLS-01 — a GDPR/Apple erasure blocker), the published legal pages carry **unfilled controller-identity/EU-rep placeholders** and their sole DSAR contact is a **non-deliverable** `pawdoc.app` mailbox with no MX record (LEG-01/LEG-02), iOS ships with **no entitlements file** so Sign in with Apple and Push silently fail in a signed build (APPL-01), and light-mode users get near-invisible text on 13 forced-dark screens including safety guidance (UX-01). Compounding this, the dead `pawdoc.app` domain is actively shipped in referral/invite/share links (REC-03) and pointed at by store metadata (APPL-02), and launch-critical device flows — premium purchase, delete-account cascade, real AI results — have **never** been exercised on-device (QA-01). The overall shape is a technically excellent, safety-solid core wrapped in unfinished release-engineering, store-provisioning, legal-operability, and cross-platform (iOS/light-mode/large-screen) gaps — most are low-effort configuration fixes, but several are non-negotiable before submission.

## Overall Readiness Score

**~62%** — a strong, safety-verified engineering and AI core dragged down by six unresolved CRITICALs concentrated in release-signing, legal operability, data-erasure, and iOS/store provisioning; none are deep product defects, but every one is a hard submission blocker.

## Readiness by Dimension

| Dimension | Readiness | Rationale |
|---|---|---|
| Engineering | 82% | Strongest area: clean `flutter analyze`, 217 passing tests, disciplined Riverpod, no debt; held back only by no e2e layer (ENG-02/QA-02) and the debug-signing config that lives at the release boundary (REC-01). |
| Product | 70% | Core activation/onboarding is well-built and honest, but the referral/growth loop is non-functional (PRD-01/REC-03), one headline overclaims for a health app (PRD-02), and all conversion analytics silently no-op without PostHog (PRD-03). |
| UI/UX | 55% | Polished, premium **dark portrait** experience, but an unresolved HIGH launch blocker (UX-01) breaks legibility for every light-mode user across 13 screens, plus large-screen sprawl (UX-02) and unclamped text scaling (UX-03). |
| Security | 60% | Secrets clean, client SSRF genuinely closed, presigned uploads, EXIF stripped — but the CRITICAL debug-keystore signing (SEC-01) caps this dimension, with a residual non-client-exploitable SSRF defense-in-depth gap (SEC-02). |
| Infrastructure | 55% | Legal-portal Terraform is production-grade, but the CRITICAL debug-signing (INF-01), unpinned `@master` deploy action (INF-02), local-only unlocked TF state (INF-03), ungated RLS suite (INF-04), and single unscaled AI machine (INF-05) concentrate here. |
| Store | 45% | Both storefronts carry multiple CRITICAL/HIGH blockers: debug signing (PLAY-01), incomplete Data Safety (PLAY-02), no iOS entitlements (APPL-01), dead-domain metadata (APPL-02), placeholder reviewer account (APPL-03), unprovisioned deletion mailbox (PLAY-04). |
| Legal | 50% | Content is ~90% drafted and the disclaimer is genuinely non-strippable, but two CRITICAL/HIGH blockers remain: unfilled controller/EU-rep placeholders (LEG-01) and a non-deliverable sole DSAR contact (LEG-02), plus no affirmative signup consent (LEG-03) and outstanding attorney sign-off. |
| Founder | 55% | Nearly all remaining blockers are founder-side and low-effort but unstarted: generate a real upload keystore, fill legal identities, provision the domain/mailbox, add iOS entitlements, complete Data Safety, run a scripted device-pass (QA-01), and merge PR #78. |
| **Overall** | **~62%** | A safety-verified, well-engineered core that is **not submittable today**: six CRITICALs and a dense store/legal/iOS blocker cluster must close first, but most are configuration-grade fixes rather than product rework. |

## Top Launch Blockers

1. **[SEC-01]** Android release build signed with the debug keystore — hard Google Play upload rejection plus update-integrity/supply-chain risk; prior claim it was fixed is false in this tree.
2. **[INF-01]** Android release build signed with the debug key (release-pipeline view of SEC-01) — Play will reject the upload.
3. **[PLAY-01]** Release AAB signed with the debug keystore — Play rejects the upload outright.
4. **[REC-01]** Release build still debug-signed despite prior "engineering GO / beta-ready" verdicts — the same blocker, re-confirmed as a reporting blind spot.
5. **[RLS-01]** Referral FKs lack `ON DELETE` — account deletion 500s for any referrer/referee once the live referral feature is used; GDPR / Apple 5.1.1(v) erasure blocker on both stores.
6. **[LEG-01]** Published privacy/terms/deletion pages carry unfilled data-controller identity and EU-representative placeholders — not legally enforceable; blocks both stores.
7. **[LEG-02]** Sole DSAR/deletion/support contact (`pawdoc.app` email) is non-deliverable — domain has no MX record; users cannot exercise data rights.
8. **[APPL-01]** No iOS entitlements file — Sign in with Apple and Push Notifications fail in a signed build; hard App Review rejection.
9. **[APPL-02]** Store metadata and review notes point at the dead `pawdoc.app` domain while the live portal is a CloudFront URL — Support/Privacy links broken at review.
10. **[PLAY-02]** Data Safety mapping is materially incomplete vs the SDKs actually bundled (location, purchase history, device analytics, third-party AI sharing) — Play policy violation.
11. **[UX-01]** Light-mode users get near-invisible theme-default text on the forced-dark background across 13 screens, including result-screen safety guidance — broad legibility failure (`blocks_launch=true`).
12. **[QA-01]** Launch-critical flows (premium purchase, delete-account cascade, photo/video capture, real AI result, family invite) have never been exercised on-device.
13. **[REC-02]** iOS never registers the `pawdoc://` URL scheme — password-reset and all deep links silently broken on iOS; no prior report ever tested iOS.
14. **[APPL-03]** Reviewer demo account is a placeholder against an auth-gated app; IAP falls back to "coming soon" if offerings aren't live at review — likely App Review rejection.
15. **[REC-03]** App ships live `pawdoc.app` referral/invite/share links to a dead domain with no App Links configured — growth funnel is non-functional (`blocks_launch=true`).

Additional store blocker not in the launch-blocker set: **[PLAY-04]** web account-deletion (Play data-deletion URL) routes to the unprovisioned `pawdoc.app` mailbox; **[QA-03]** OneSignal crash-on-exit still unguarded in code for builds without `ONESIGNAL_APP_ID`; **[REC-04]** legal/privacy URLs default to an ephemeral CloudFront hostname while the brand domain is dead.

## Honesty Note — Where Prior Reports Were Incomplete or Wrong

The reconciliation (REC-01 through REC-04, plus AI-01 and SEC-03) is a mixed verdict: **the highest-stakes safety claims genuinely hold, but the prior "beta-ready / YES-WITH-CONDITIONS" verdicts were produced with real blind spots.**

What holds up: the prior CRITICAL that providers never sent image pixels (photo triage secretly text-only) is **resolved and re-verified** — Gemini and Claude now fetch and base64-attach real bytes, asserted by payload-capture tests (AI-01). The client `image_url` SSRF is genuinely closed at the Edge boundary and no real secrets are committed (SEC-03). RLS is enabled on all 13 tables with per-op policies, the emergency-never-paywalled server logic is intact, the disclaimer is force-injected server-side, the EN/DE emergency keyword lists byte-match between `safety.py` and `emergency_keywords.mjs`, and `flutter analyze` is clean. On the substance of AI/veterinary safety, the prior reports were accurate.

Where prior "done/verified" claims are contradicted by current code:
- **Debug signing (REC-01 / SEC-01 / INF-01 / PLAY-01):** every prior "engineering GO / beta-ready" verdict shipped on a **debug-signed** release build. The claim this was addressed is **false in this tree** — it remains a hard Play blocker.
- **iOS was never tested at all (REC-02):** all "device-validated" verdicts were Android-only, dev-config builds. iOS never registers the `pawdoc://` scheme, so password-reset and every deep link are silently broken — and no prior report caught it because none ran on iOS.
- **Dead brand domain shipped in-app (REC-03 / REC-04 / UX-04):** the app actively ships `pawdoc.app` referral/invite/share links to a dead domain, and legal/store links lean on an ephemeral CloudFront hostname because the brand domain is dead. Prior audits flagged `pawdoc.app` as dead but did not flag that the **app itself** ships those links as a launch blocker.
- **Device-QA coverage was overstated (QA-01):** premium purchase has been unreachable on every device to date, and delete-account cascade, real AI results, and family invite were never device-tested — yet verdicts read as broadly validated. Note one genuine correction *in the app's favor*: the alarming German-emergency screenshot (07l) is an archived **pre-fix** capture, not current behavior (the locale bug is verified fixed).
- **Test/infra false confidence (RLS-02 / INF-04 / INF-07):** `test-rls.sh` applies only a curated subset of migrations (never loading the referrals migration that contains RLS-01) and is not gated in CI, so the deletion blocker went unverified; and the CI "no-placeholders" gate documented as intentionally red is actually **green** while placeholder store URLs remain.

Net: prior reports were accurate on the safety core they focused on, but their launch-readiness verdicts were over-optimistic because they never covered iOS, the release-signing config, the shipped dead-domain links, or the unexercised purchase/deletion flows.

---

## Every Finding (64)

_Grouped by audit area, ordered by severity within each area. IDs are stable references used throughout this report and the appendices. “Verification: CONFIRMED/PARTIAL” marks findings a second agent independently re-checked against source; MEDIUM/LOW are reported as found._

### Engineering — Flutter / Client Architecture

_Area readiness (finder self-assessment): 85% — Engineering/architecture is the strongest area of this codebase. flutter analyze is clean (0 issues), all 217 widget/unit tests pass, feature modules are consistently structured, controllers/subscriptions are disposed, image compression + EXIF stripping run off the UI isolate via compute(), and Riverpod 3 usage is disciplined (33 providers, mostly Future/Stream, only 1 mutable global state). No god-objects (largest file 801 lines of small private widgets), no TODO/FIXME debt, no unsafe force-unwraps of AsyncValue. Real gaps are narrower: fonts are fetched from Google at runtime (no bundled assets, runtime-fetch not disabled), there is no end-to-end/integration test layer so the router redirect and safety path are only exercised with mocked services, and one capture-path decode runs on the UI isolate._

#### [ENG-01] Fonts fetched from Google at runtime — offline first-launch degrades typography and adds an unconsented third-party network call

**Severity:** MEDIUM · **Category:** engineering · **Perspectives:** performance, privacy, ui-ux · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.9

**Evidence:** `mobile/lib/src/theme/design_tokens.dart:94-122` builds the entire `TextTheme` via `GoogleFonts.bricolageGrotesque(...)` and `GoogleFonts.inter(...)`. `assets/fonts/` contains only a `.gitkeep` (no bundled `.ttf`), there is no `fonts:` block in `mobile/pubspec.yaml` (lines 148-155 are the commented-out template), and `GoogleFonts.config.allowRuntimeFetching` is never set to false (grep finds zero hits in `lib/`). The pubspec comment at `pubspec.yaml:139-146` explicitly acknowledges this is unfinished. So both display and body fonts are fetched over HTTP from Google's font CDN on first launch.
**Root cause:** The design adopted `google_fonts` for convenience but never completed the offline-deterministic path (bundle the `.ttf` + disable runtime fetching) that the package recommends for production.
**User impact:** A user who opens the app for the first time with no/poor connectivity gets system fallback fonts across every screen — including the safety-critical EMERGENCY/result screens — instead of the intended type ramp; a FOUT (flash of fallback then swap) is also possible once the fetch lands. First paint is gated on a network round-trip.
**Business impact:** Undermines the polished, clinical brand on the highest-stakes first impression and on the safety path; adds a launch-time dependency on a Google endpoint that can be slow or blocked in some regions.
**Store impact:** The runtime request to Google's font CDN fires before any consent and is a third-party data flow (IP address) that must be disclosed in the privacy nutrition/data-safety forms; undisclosed, it is a latent policy risk on both stores.
**Solution:** Download the exact Inter and Bricolage Grotesque weights actually used, drop the `.ttf` files into `mobile/assets/fonts/`, declare them in a `fonts:` block in `pubspec.yaml`, and call `GoogleFonts.config.allowRuntimeFetching = false;` once at startup in `main()` before `runApp`. Keep the `GoogleFonts.inter(...)` calls (they resolve to the bundled family when fetching is disabled) or switch to `TextStyle(fontFamily: 'Inter')`. Verify no network call to `fonts.gstatic.com` occurs on a cold offline launch.
**Acceptance criteria:** Cold launch in airplane mode renders correct Inter/Bricolage type on the home and result screens; a network trace on first launch shows zero requests to Google font hosts; `flutter analyze` and `flutter test` stay green.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [ENG-02] No end-to-end/integration test layer — router redirect, deep links, and the safety path are only tested with a mocked service

**Severity:** MEDIUM · **Category:** engineering · **Perspectives:** engineering, ai · **Effort:** L 2-4d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.8

**Evidence:** There is no `mobile/integration_test/` directory (`ls` fails). All 47 test files under `mobile/test/` are unit/widget tests. The only e2e-style test, `mobile/test/analysis_integration_test.dart`, overrides `analysisServiceProvider` with a `FakeAnalysisService` and mounts `AnalysisRunnerScreen` directly — it never exercises the real `SupabaseAnalysisService`, the go_router `redirect` in `app_router.dart:61-85`, `GoRouterRefreshStream`, or the deep-link routes (`/invite/:token`, `/r/:code`, `/recovery`). The auth-redirect/recovery/invite-capture logic (the most brittle navigation in the app, `app_router.dart:44-158`) has no test that drives it through GoRouter. Assertion density is thin in places (e.g. `analysis_integration_test.dart` asserts one `find.text` per flow; several files have 2-4 expects).
**Root cause:** Testing strategy stopped at the widget/unit layer; the headless CI environment has no device/emulator, so the integration_test harness was never stood up.
**User impact:** Regressions in redirect ordering (recovery vs. signed-in vs. pending-invite), deep-link restoration, or the emergency-never-paywalled path can ship undetected because nothing integration-tests the assembled router + providers together — and this is a safety-critical app where a missed emergency is the #1 risk.
**Business impact:** Lower confidence in each release; the safety guarantee ('EMERGENCY is never paywalled/delayed') is asserted only against a mocked service, not the real invoke→parse→route chain.
**Store impact:** None directly.
**Solution:** Add an `integration_test/` package with `integration_test` in dev_dependencies and at least: (1) a router test that drives `routerProvider` through unauthenticated→sign-in→home, a `passwordRecovery` event forcing `/recovery`, and an `/invite/:token` capture-and-restore across sign-in; (2) a boot smoke test that pumps `PawDocApp` with an overridden Supabase/auth layer and asserts the sign-in gate. Strengthen `analysis_integration_test.dart` to also assert the EMERGENCY branch does NOT invoke the paywall (`maybeShowPaywall`) and that a 402/quota outcome shows the upgrade sheet. Wire these into the existing `flutter test` phase verifier.
**Acceptance criteria:** `flutter test integration_test/` runs in CI and covers the four redirect branches plus deep-link restoration; a deliberate inversion of the emergency paywall guard makes a test fail.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [ENG-03] Capture path decodes JPEG and assesses quality on the UI isolate after the isolate-offloaded compress

**Severity:** LOW · **Category:** performance · **Perspectives:** performance, device · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.75

**Evidence:** `mobile/lib/src/capture/camera_screen.dart:85` correctly offloads compression to a background isolate via `compute(_compress, raw)`, but the very next lines run on the UI isolate: `img.decodeJpg(result.bytes)` (line 88) and `assessQuality(decoded)` (line 90), which iterate the decoded bitmap in `image_quality.dart:31-67`. The quality pass is grid-sampled (cheap), but the full `decodeJpg` of the compressed frame is the heavy op and runs on the main thread while `_busy` is true.
**Root cause:** Only the compress+EXIF step was moved into `compute`; the subsequent decode-for-quality-check was left inline.
**User impact:** A brief frame hitch / dropped frames right after the shutter on lower-end devices; masked by the `_busy` spinner so it reads as a short pause rather than jank, but it is main-thread work on an image.
**Business impact:** Minor perceived-performance cost on the core capture flow; negligible otherwise.
**Store impact:** None.
**Solution:** Fold the decode+quality assessment into the same background isolate: have `_compress` (or a combined top-level function) return both the compressed bytes and the `QualityReport`, so `decodeJpg`/`assessQuality` never touch the UI isolate. Then only the dialog decision runs on the main thread.
**Acceptance criteria:** No `img.decodeJpg`/`assessQuality` call executes on the root isolate in the capture path; capture-to-preview stays smooth on a mid-tier device; existing capture tests remain green.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### UI / UX Design

_Area readiness (finder self-assessment): 70% — In its intended dark presentation the app is genuinely polished and premium: a coherent teal-green "warm-ink" world, consistent PawCard/PawPrimaryButton primitives, a well-considered token system (design_tokens.dart), safety-locked triage hues paired with icons + text (not color alone), and a robust emergency screen with its own red scaffold and explicit white text. The on-device dark-mode screenshots (runtime/legal_validation/*.png) confirm the account, delete-account, and referral screens render cleanly. However two systemic issues undercut readiness: (1) 13 screens hard-force PawBackground(PawSurface.dark) while MaterialApp.themeMode is left at ThemeMode.system, so every user whose phone is in LIGHT mode gets near-black theme-default text and mismatched native Material surfaces over the forced-dark background — a broad legibility failure that includes result-screen safety guidance; (2) AppSpace.maxContentWidth (480) is defined but applied on only 2 of ~15 screens, so content sprawls edge-to-edge in landscape / on tablets & foldables (visible in the landscape home capture 02_app_launch.png). Dynamic-text-scaling is unclamped against fixed-height cards. The dark, portrait experience is ~90% done; the app as a whole is held back by the light-mode and large-screen gaps._

#### [UX-01] Light-mode: theme-default text renders near-invisible on the forced-dark background across 13 screens

**Severity:** HIGH · **Category:** ui-ux · **Perspectives:** Senior UI Designer, Senior UX Researcher, Accessibility · **Effort:** S <=2h · **Blocks launch:** YES · **Blocks store:** none · **Confidence:** 0.9

**Evidence:** `mobile/lib/src/app.dart:17-19` sets `theme: AppTheme.light()`, `darkTheme: AppTheme.dark()` and leaves `themeMode` at the default `ThemeMode.system`. Meanwhile 13 screens hard-code a dark background: `grep -rln 'PawSurface.dark'` returns home, analysis/result, monetization/paywall, onboarding, account, delete_account, referral, pets_list, family_settings, history_timeline, symptom_text, reminders, health_event_form. `AppType.textTheme()` intentionally leaves text colors null so they inherit `onSurface` (design_tokens.dart:90-92). In `AppTheme.light()` `onSurface = lightText = 0xFF1A2220` (design_tokens.dart:58, app_theme.dart:51). That near-black inherits onto plain text over the dark `PawBackground` (paw_ui.dart:65-88, ramp 0xFF123A31→0xFF07100E). Concrete unstyled call-sites: result_screen.dart:391 (`_section` title `titleSmall`) and :393 (`Text(l)` for 'What to do' / 'When to seek a vet' lists); paywall_screen.dart:421 (`_ValueStack` bodyLarge); home_screen.dart:668 (`_CaptureModeTile` title). Native Material widgets (Card/ListTile in _PlanCard, dialogs, TextField) additionally paint their LIGHT surfaces over the dark world, producing mismatched light boxes. Emergency screen is unaffected (own red scaffold + explicit `Colors.white`, emergency_result_screen.dart:59-71).
**Root cause:** The redesign committed to a single always-dark visual world (`PawSurface.dark` hard-coded per screen) but the ThemeData/ColorScheme is still system-driven, so inherited `onSurface`/native-surface colors flip to their light-mode values while the background stays dark. Screens are only legible because the QA device happened to be in dark mode (all runtime/legal_validation/*.png were captured in OS dark mode).
**User impact:** Any user with their phone set to Light appearance sees body copy, list items, capture-mode tiles, paywall value bullets, and result-screen 'What to do' / 'When to seek a vet' guidance as near-black text on a dark green background — effectively invisible — plus jarring light Material cards/dialogs. On a safety-critical triage app this means the escalation guidance itself can be unreadable for a large share of users.
**Business impact:** Light-mode is a very common setting; broken legibility on the paywall and result screens directly suppresses conversion and drives 1-star 'text is invisible / unreadable' reviews and support load at launch.
**Store impact:** Not an automatic rejection, but violates both stores' accessibility/quality expectations and Google Play's visual-quality guidelines; likely flagged in review notes.
**Solution:** Since the product is deliberately a single dark visual world, lock it: set `themeMode: ThemeMode.dark` on `MaterialApp.router` in `mobile/lib/src/app.dart` (and mirror in `core/boot_error_app.dart:21-22`). This makes the active ColorScheme always the dark one, so inherited `onSurface` text and native surfaces match the dark `PawBackground`. Then delete the now-unused `AppTheme.light()` wiring or keep it only if a real light variant of `PawBackground` is later built. Verify with `flutter run` on a device/emulator set to Light appearance and confirm result_screen sections, paywall value stack, and home capture sheet are legible.
**Acceptance criteria:** With the OS set to Light mode, every screen listed by `grep -rln 'PawSurface.dark'` renders all body text at >=4.5:1 contrast; no native Material Card/ListTile/dialog paints a light surface over the dark background; result-screen 'What to do' and 'When to seek a vet' lines are clearly readable; existing dark-mode screenshots are visually unchanged.

**Verification:** CONFIRMED — Reproduced in current tree. app.dart:14-19 leaves themeMode at ThemeMode.system (line 19 comment confirms) with theme=AppTheme.light()/darkTheme=AppTheme.dark(), so the active ColorScheme follows the OS. AppType.textTheme() (design_tokens.dart:91-92) leaves text colors null; light-mode onSurface=lightText=0xFF1A2220 near-black (app_theme.dart:53 + design_tokens.dart:58), onSurfaceVariant=0xFF4C5A56. PawBackground(PawSurface.dark) (paw_ui.dart:50-88) paints a hardcoded dark gradient 0xFF123A31->0xFF07100E with NO brightness dependence, so it stays dark when the OS is light. Confirmed uncolored call-sites over that dark bg: result_screen.dart:391 (titleSmall, no color) and :393 (plain Text(l) 'What to do'/'When to seek a vet' lists); paywall_screen.dart:421 (bodyLarge value bullets); home_screen.dart:668 (titleMedium capture tile) and :673 (onSurfaceVariant hint). All three screens wrap content in PawBackground(variant: PawSurface.dark) (result:207-208, home:105-106, paywall:133-134) with no DefaultTextStyle override. Emergency path is genuinely safe (emergency_result_screen.dart:59-71: own red Scaffold + explicit Colors.white). Nuance: headline is slightly overstated -- explicitly-colored elements (PawFeatureRow ink50/ink300 at paw_ui.dart:351-352, buttons, headings) stay readable; only theme-default text and native Material surfaces break. Real, reproducible legibility defect for any light-mode user on paywall + result + home; fix (themeMode: ThemeMode.dark) is correct.

---

#### [UX-02] Content sprawls full-width in landscape and on tablets/foldables — maxContentWidth defined but applied on only 2 screens

**Severity:** MEDIUM · **Category:** ui-ux · **Perspectives:** Senior UI Designer, Senior UX Researcher, Responsiveness · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.85

**Evidence:** `AppSpace.maxContentWidth = 480` is defined (design_tokens.dart:143) but `grep -rl maxContentWidth mobile/lib/src` returns only `auth/sign_in_screen.dart` and `auth/recovery_screen.dart` (plus the token file). Home (`home_screen.dart:150-152` — `ListView(padding: EdgeInsets.all(AppSpace.s16))`, no width cap), result (`result_screen.dart:216-217`), and paywall (`paywall_screen.dart:142-143`) place their `ListView`s edge-to-edge with no `ConstrainedBox`/`Center`. The on-device landscape capture `runtime/legal_validation/02_app_launch.png` (2408x1080) shows the 'Check Rex' primary CTA and pet hero card stretched across the full ~2400px width, with a tiny centered label — visibly unfinished. No orientation lock exists (`grep -rn setPreferredOrientations mobile/lib` and `screenOrientation` in AndroidManifest.xml both return nothing), so phones rotate to landscape and the app also runs windowed on tablets/foldables.
**Root cause:** The max-content-width constraint was only wired into the two auth screens during the redesign; the remaining ~13 screens were never wrapped, so their `ListView` bodies expand to the full viewport width.
**User impact:** In landscape or on large screens, buttons stretch to absurd widths, forms and cards sprawl, and line lengths become uncomfortable — the app reads as unpolished and non-premium exactly where a wide canvas should look best.
**Business impact:** Undercuts the premium positioning that justifies the subscription; weak large-screen presentation hurts tablet/foldable users and app-store screenshots taken on large devices.
**Store impact:** Google Play surfaces a large-screen/foldable quality tier; sprawling, unconstrained layouts commonly draw large-screen quality warnings (not a hard block).
**Solution:** Introduce a shared centered-max-width wrapper (e.g. `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: AppSpace.maxContentWidth), child: ...))`) and apply it to the body of every `PawSurface.dark` screen's `ListView`/scroll body — home, result, paywall, onboarding, account, pets_list, reminders, health/history, family_settings, symptom_text, delete_account. Alternatively lock the app to portrait via `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, portraitDown])` in `main` AND still cap width for tablets. Prefer the width-cap since tablets/foldables render portrait wide too.
**Acceptance criteria:** On a landscape phone and a 7"+ tablet, no primary CTA exceeds ~480dp, form/list content is centered within a 480dp column, and the home 'Check' button is not full-bleed; verified by re-capturing the landscape home screen.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [UX-03] No text-scale clamp against fixed-height cards and single-line rows risks overflow at large accessibility font sizes

**Severity:** MEDIUM · **Category:** ui-ux · **Perspectives:** Senior UX Researcher, Accessibility · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.6

**Evidence:** `grep -rn 'textScaler|textScaleFactor|MediaQuery.*clamp' mobile/lib/src` returns nothing — the app never bounds the OS font-scale. Meanwhile layouts assume default scale: fixed-height skeletons `SkeletonCard(height: 120)` / `height: 72` / `height: 44` (home_screen.dart:161-164), fixed 40x40 and 44x44 icon tiles (paw_ui.dart:360-367, home_screen.dart:654-661), and single-line `Row`s such as `_QuotaStrip` (home_screen.dart:496-527) and the emergency acknowledge/continue buttons with `minimumSize: Size.fromHeight(56)` (emergency_result_screen.dart:147-159). At the OS 'largest' accessibility font setting (~1.3-2.0x) text in these fixed-height/one-line containers can clip or overflow.
**Root cause:** Dynamic Type / font-scale was not exercised; layouts were tuned at 1.0x scale and there is no upper clamp to keep them from breaking at extreme scales.
**User impact:** Low-vision users who raise system font size may see truncated triage labels, clipped quota text, or overflowing buttons — undermining the accessibility of a health app.
**Business impact:** Accessibility complaints and poor reviews from an audience (older pet owners) who disproportionately use large fonts.
**Store impact:** No hard block, but counts against accessibility quality signals in both stores.
**Solution:** Apply a sane global clamp via `MediaQuery` in `app.dart` builder, e.g. wrap the router with `MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.6)), child: child)`, and convert the fixed-height skeletons/rows to intrinsic or min-height so they grow with text. Manually verify home, result, paywall, and emergency screens at 1.6x.
**Acceptance criteria:** At OS font scale 1.6x, no text is clipped and no `RenderFlex overflow` is logged on home, result, paywall, and emergency screens.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [UX-04] Result share text advertises pawdoc.app, a domain flagged dead in prior launch audits

**Severity:** LOW · **Category:** product · **Perspectives:** Senior UX Researcher · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.5

**Evidence:** `result_screen.dart:199` shares `'Shared via PawDoc 🐾 — pawdoc.app'`, and referral/invite links are hard-coded to the same host: `referral/referral_screen.dart:35` (`https://pawdoc.app/r/$code`) and `router/app_router.dart:139-148`. The project launch-audit memory (launch_audit_2026_06_12) explicitly lists 'pawdoc.app dead' as a gap, and the legal portal was instead deployed to a CloudFront domain via `LEGAL_BASE_URL`. This tree still ships pawdoc.app in user-facing share copy.
**Root cause:** Share/referral strings were never migrated to the live domain after the legal/marketing host moved to CloudFront.
**User impact:** Recipients who tap a shared/referral link land on a non-resolving domain, breaking the referral loop and looking broken to the sharer.
**Business impact:** Referral acquisition (a growth lever) silently fails; brand looks unfinished in shared messages.
**Store impact:** None.
**Solution:** Confirm the live public domain; if pawdoc.app is not provisioned, route share/referral text through the same configurable base used for legal (`config/legal_urls.dart`) rather than a hard-coded host, and update `result_screen.dart:199` and `referral_screen.dart:35`. If pawdoc.app IS now live, verify DNS + universal/app-link association and mark resolved.
**Acceptance criteria:** Every user-facing shared URL resolves to a live page and, on mobile, opens the app via the configured app-link association; no hard-coded pawdoc.app string remains in share/referral copy unless the domain is verified live.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Product — Onboarding, Activation, Conversion, Retention, Trust

_Area readiness (finder self-assessment): 72% — The new-user journey is genuinely well-built: a 5-step onboarding (value hook → pet setup → trust → push priming → activation) with honest, defensible trust copy, a warm illustrated home empty state that frames quota positively, a solid post-analysis paywall whose EMERGENCY-never-paywalled trust rule is enforced in a unit-tested pure function, and an honest result-screen disclaimer. The main product gaps are growth/measurement, not core flow: the referral/acquisition loop is effectively broken (shared links point to a hardcoded dead domain with no Android App Link, and reward messaging contradicts the backend mechanic), one onboarding headline overclaims in a way a health-triage app must avoid, and all activation/conversion analytics plus every A/B experiment silently no-op unless PostHog is configured. Core activation should work at beta; the conversion, referral, and measurement loops need attention before a real launch._

#### [PRD-01] Referral loop is non-functional: shared links point to a hardcoded dead domain with no Android App Link

**Severity:** HIGH · **Category:** product · **Perspectives:** Growth/Referral, Mobile Engineering · **Effort:** L 2-4d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.85

**Evidence:** `mobile/lib/src/referral/referral_screen.dart:35` hardcodes the shared link as `https://pawdoc.app/r/$code`, and the Share/social CTAs share only that https string (`referral_screen.dart:74-78, 338`). But `mobile/android/app/src/main/AndroidManifest.xml:51-56` registers ONLY the `pawdoc://` custom scheme; the App Link (`autoVerify` + `assetlinks.json`) for `https://pawdoc.app` is an explicit unfinished TODO in the same file (`AndroidManifest.xml:49-50`: "For https://pawdoc.app App Links, add an autoVerify host filter + assetlinks.json"). Project memory (launch audit 2026-06-12) records pawdoc.app as dead and the legal portal already moved off it to CloudFront (`mobile/lib/src/config/legal_urls.dart:19`). The router only captures the code via `/r/:code` (`app_router.dart:150-157`), which an https tap can never reach without a verified App Link.
**Root cause:** The referral link was hardcoded to a canonical domain that is neither live nor wired as an App Link, and the deep-link handler only works for the `pawdoc://` custom scheme (which a not-yet-installed recipient cannot receive).
**User impact:** A friend who taps a shared referral link lands on a dead/parked domain with no app-open and no install path; the referral code is never captured, so neither party gets their +3 bonus credits. The entire word-of-mouth loop is silently dead.
**Business impact:** Referral is a primary organic-acquisition and viral-growth lever for a solo-founder consumer app; shipping it broken means paying full CAC for every user and losing the K-factor the product was designed around. Also erodes trust when promised rewards never appear.
**Store impact:** none directly, though a link to a dead domain in share sheets is a poor-quality signal.
**Solution:** (1) Point the link base at a live, owned domain via the same override pattern as `LegalUrls` (add `REFERRAL_BASE_URL`/reuse `LEGAL_BASE_URL`) instead of a literal `pawdoc.app`. (2) Stand up the destination as a real web page that either deep-links installed apps or routes to the store listing with the code preserved (deferred-deep-link, e.g. Branch/Firebase Dynamic Links replacement, or a `?ref=CODE` store param read on first launch). (3) Add the Android App Link: `<intent-filter android:autoVerify="true">` with `<data android:scheme="https" android:host="<domain>"/>` and publish `/.well-known/assetlinks.json`; add the iOS Associated Domain + `apple-app-site-association`. (4) Until deferred deep-linking exists, the shared copy should tell recipients to install then paste the code (which the Claim card already supports).
**Acceptance criteria:** Tapping a shared referral link on a device without the app installed leads to the store, and after install the code is auto-captured and the Claim flow credits both users (verify `bonus_analyses += 3` on both). With the app installed, the https link opens directly into the app and captures the code. `assetlinks.json`/AASA resolve and Android verification passes.

**Verification:** CONFIRMED — All cited evidence reproduced in current tree. referral_screen.dart:35 hardcodes `https://pawdoc.app/r/$code` with no build-time override; Share/social CTAs share only that https string (referral_screen.dart:74-78 and :338 shareText feeding all social buttons :344-371). AndroidManifest.xml:51-56 registers ONLY the `pawdoc://` custom scheme (no https intent-filter at all), with an explicit unfinished TODO at :48-50 to add autoVerify + assetlinks.json. Router captures the code only via `/r/:code` at src/router/app_router.dart:150-157 (finding pointed to app_router.dart:150-157 — correct lines, path is src/router/ not src/core/), unreachable by an https tap without a verified App Link. legal_urls.dart:17-20 shows the legal portal already moved OFF pawdoc.app to CloudFront and demonstrates the exact String.fromEnvironment override pattern the referral link lacks. Confirmed absences: no REFERRAL_BASE_URL anywhere; no iOS .entitlements/Associated Domains; no assetlinks.json or apple-app-site-association files in repo. Minor overstatement: the code is embedded in the shared URL path and the in-app Claim card accepts pasted codes, so manual claim is technically possible — but the designed auto-capture-on-tap path is genuinely dead. Growth loop is non-functional as designed.

---

#### [PRD-02] Onboarding value-prop headline overclaims — implies the app replaces vet judgment

**Severity:** HIGH · **Category:** product · **Perspectives:** Product/Trust, Legal/Compliance · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.75

**Evidence:** `mobile/lib/src/onboarding/onboarding_flow.dart:198` — the first thing a new user reads is the value-hook headline: "Never wonder if your pet needs the vet again." This directly contradicts the app's own result-screen disclaimer at `mobile/lib/src/analysis/result_screen.dart:305`: "PawDoc provides information, not a veterinary diagnosis. When in doubt, contact your vet." and the onboarding trust pillar "We inform; your vet decides" (`onboarding_flow.dart:356`).
**Root cause:** Marketing-strength copy in the value hook was not reconciled with the honesty rebuild applied to the trust/paywall screens (prior audits flagged this class as GAP-B5). The headline promises certainty a triage tool cannot deliver.
**User impact:** Sets an expectation that the app definitively answers whether a vet is needed. For a safety-critical product whose #1 risk is a false negative, this actively discourages the escalation behavior the disclaimer tries to encourage — a user who "never wonders" may not seek care when they should.
**Business impact:** Undermines the credibility of a health brand at the exact moment of first impression; inconsistent messaging (headline vs. disclaimer) reads as untrustworthy. Elevated liability exposure if a user relies on the promise and a real emergency is missed.
**Store impact:** Health/medical overclaims are scrutinized by both Apple (1.4.1 / medical) and Google (Health misrepresentation); an unqualified "never wonder if your pet needs the vet" claim is the kind of statement reviewers and FTC guidance treat as deceptive for a diagnostic-adjacent app.
**Solution:** Reword to a benefit that is true and non-diagnostic, consistent with the disclaimer — e.g. "Get a calm, clear read on your pet's symptoms in seconds" or "Know when it may be time to call the vet." (the paywall's `PaywallSocialProof.valueLine` in `paywall_copy.dart:19-21` already models the approved tone). Route this and any other superlative launch copy through the same honesty review; grep onboarding/store metadata for absolute claims ("never", "always know", "replaces").
**Acceptance criteria:** No onboarding, paywall, or store-metadata string asserts the app tells the user whether they need a vet in absolute terms; the value hook is consistent with the result disclaimer; copy reviewed/approved by owner (and attorney per the legal gate).

**Verification:** CONFIRMED — All cited evidence reproduced verbatim in current tree. onboarding_flow.dart:198 (value-hook Step 1, first content screen) reads: 'Never wonder if your pet needs the vet again.' This directly contradicts result_screen.dart:305 disclaimer ('PawDoc provides information, not a veterinary diagnosis. When in doubt, contact your vet.') and onboarding_flow.dart:356 trust pillar 'We inform; your vet decides'. Root cause corroborated in-code: the Phase B honesty rebuild explicitly scrubbed the paywall (paywall_copy.dart:5-12 header names the '★ 4.8' overclaim as the same defect class) and the trust-signal screen (onboarding_flow.dart:338 comment 'honesty rebuild from Phase B'), but the value-hook headline at line 198 was never reconciled. paywall_copy.dart:19-21 valueLine ('Get a calm, clear read on your pet's symptoms in seconds — and know when it's time to call the vet.') already models the approved non-diagnostic tone the finding proposes. grep confirms line 198 is the only occurrence. Copy-only defect (no functional safety mechanism broken), but absolute 'needs the vet' claim on a diagnostic-adjacent medical app is a real store-review (Apple 1.4.1 / Google Health misrepresentation) and trust/safety-messaging risk — HIGH retained.

---

#### [PRD-03] Activation & conversion are unmeasurable and all A/B experiments serve control unless PostHog is configured

**Severity:** MEDIUM · **Category:** product · **Perspectives:** Product Analytics, Growth · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.8

**Evidence:** PostHog is initialized only when a key is present: `mobile/lib/main.dart:59` `if (Env.posthogApiKey.isNotEmpty) { ... Posthog().setup(config); }`. Every analytics call is best-effort and swallows failure (`mobile/lib/src/analytics/analytics.dart:8-14`), and the feature-flag wrapper fails safe to the CONTROL variant on any error or absent flag (`mobile/lib/src/experiments/feature_flags.dart:37-79`). So with no `POSTHOG_API_KEY` at build/launch, zero funnel events fire and `onboarding_variant`/`paywall_variant`/`pulse_pet_variant` all resolve to control.
**Root cause:** Analytics and experimentation are entirely dependent on founder-side configuration (Doppler `POSTHOG_API_KEY` + PostHog flag definitions) that is not verified in-app; there is no fallback measurement and no launch guard that surfaces the missing key.
**User impact:** None directly (correctly non-blocking), but the product team is flying blind — no way to see where the onboarding→first-triage→paywall funnel leaks.
**Business impact:** For a launch, inability to measure activation rate and premium conversion means you cannot detect or fix the very conversion leaks this app's monetization depends on; the built A/B infrastructure (onboarding/paywall variants) delivers no learning because every user silently gets Variant A. The instrumentation exists but is inert.
**Store impact:** none.
**Solution:** (1) Treat `POSTHOG_API_KEY` as a required launch config: document it in the go-live checklist and add a startup log/Sentry breadcrumb when it is absent so it can't ship unnoticed. (2) Before launch, define the `onboarding_variant`, `paywall_variant`, and any kill-switch flags in the PostHog project and confirm bucketing with the identified Supabase uid (`main.dart:62-69`). (3) Add a lightweight release smoke test that verifies `onboarding_completed`, `analysis_completed`, `paywall_shown`, and `subscription_converted` events reach PostHog from a test build.
**Acceptance criteria:** A production build emits the core funnel events to PostHog; the three experiment flags exist and split users deterministically; a documented checklist item confirms the key is set; missing-key state is observable in logs/Sentry rather than silent.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [PRD-04] Referral reward messaging is vague and contradicts the actual grant mechanic

**Severity:** MEDIUM · **Category:** monetization · **Perspectives:** Growth/Referral, Product Copy · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.85

**Evidence:** The referrer's reward is shown as the placeholder "Amazing rewards" (`mobile/lib/src/referral/referral_screen.dart:517`) and the hero says users "earn rewards when they subscribe" (`referral_screen.dart:168`), with How-it-works step 2 stating the friend "signs up and subscribes" as the trigger (`referral_screen.dart:588`). But the backend RPC grants the reward on CODE CLAIM, not on subscription, and the amount is a fixed `bonus_analyses + 3` to BOTH sides (`supabase/migrations/20260527030000_referrals.sql:96-101`, capped at 30 by `20260613100000_referral_bonus_cap.sql`). The "They get: 3 free health checks" card (`referral_screen.dart:474`) also equals the 3 free checks every new user already receives, so the referred-friend incentive appears non-differentiated.
**Root cause:** UI copy was written before/independently of the reward RPC and never reconciled; the reward is undefined to the user ("Amazing rewards") and mis-attributes the trigger (subscribe vs. claim).
**User impact:** Users can't tell what they'll actually earn, and are told the reward requires the friend to subscribe when it does not — leading to confusion and unmet expectations (they may believe they earned nothing, or wait for a subscribe event that isn't the trigger).
**Business impact:** Vague, inaccurate incentives depress referral send-rate and claim-rate and generate support/trust friction; the growth loop's conversion is throttled by unclear value on both sides.
**Store impact:** none, though undefined-but-implied rewards can be a mild consumer-protection concern.
**Solution:** State the real reward explicitly and consistently: "You get 3 free checks when a friend joins with your code" (matching the +3 grant) instead of "Amazing rewards"; fix the trigger copy at `referral_screen.dart:168,588` to reflect claim-on-signup (or change the RPC to subscribe-gated if that is the intended economics — but the two must agree). Consider a differentiated new-user perk (e.g. extra credits beyond the standard 3) so the "They get" side is a real incentive. Keep the values in a single copy constant so they track the migration.
**Acceptance criteria:** Referral UI states the exact credit amount and the exact trigger, and both match `claim_referral` behavior; no placeholder/superlative reward text remains; a referred user visibly receives more than the default free quota (or copy is corrected to not imply so).

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [PRD-05] Onboarding Variant B shows the paywall before any value is delivered and can dead-end on 'coming soon'

**Severity:** LOW · **Category:** monetization · **Perspectives:** Monetization, Activation · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.7

**Evidence:** `mobile/lib/src/onboarding/onboarding_flow.dart:100-116` (`_maybeShowOnboardingPaywall`, called at `:88`) pushes the full `PaywallScreen` immediately after pet creation — before the user's first analysis — when the `onboarding_variant` flag resolves to 'B'. When RevenueCat offerings aren't configured, that paywall renders `_PremiumComingSoon` (`paywall_screen.dart:187-188, 317-352`), i.e. a screen with no purchasable action, mid-onboarding.
**Root cause:** The aggressive-monetization experiment arm places the paywall before the activation moment; combined with the common launch state of no configured offerings, it can present a purposeless "coming soon" interstitial during first-run.
**User impact:** A brand-new user who hasn't yet experienced a single triage is asked to consider paying (or shown a dead-end "coming soon"), adding friction at the most fragile point of activation. Mitigated by being skippable and gated behind a flag that defaults to 'A' (`feature_flags.dart:15`, control).
**Business impact:** If enabled prematurely (before offerings exist, or before there's data to justify pre-value monetization) it risks depressing activation more than it lifts conversion. Low blast radius today because the default is control.
**Store impact:** none.
**Solution:** Guard the onboarding paywall so it never shows when `Purchases.getOfferings().current == null` (no purchasable plans), and keep Variant B disabled until offerings are live and there is a measured baseline to compare against. Prefer running the pre-vs-post-value paywall test only after the funnel is instrumented (see the PostHog finding).
**Acceptance criteria:** With no configured offerings, onboarding never shows a paywall/coming-soon interstitial; Variant B is only activatable once offerings exist; the experiment is documented as off-by-default for launch.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### AI & Veterinary Safety

_Area readiness (finder self-assessment): 88% — The AI/veterinary-safety area is in strong shape and the single biggest historical risk is resolved. The prior CRITICAL claim that providers never send image pixels (photo triage secretly text-only) is NO LONGER true in this tree: both Gemini and Claude now fetch and attach real image bytes via media.gather_media, and this is asserted by genuine payload-capture tests (test_providers_payload.py). The core safety contract is fully present and tested — hardcoded emergency override before any AI call (locale + species aware, Python/JS keyword lists in exact parity), EMERGENCY cross-verification, confidence<0.60 → insufficient-information (never fabricate), temperature 0.1 on every health call, structured-JSON-only parsing with reject/degrade, safe degrade to MONITOR (never NORMAL) on media/provider failure, and quota that never paywalls an EMERGENCY (text or visual). 186 pytest cases pass, including a stub-driven golden-set gate that hard-fails on any EMERGENCY false negative. Remaining gaps are non-blocking: there is no live-model regression/quality monitoring (the golden set uses stub providers, so a silently-regressing model is invisible), the NSFW moderator hardcodes a jpeg MIME (legit PNG/WebP photos can be wrongly rejected, though it fails safe), and media.py's SSRF allowlist is documented but not implemented (real defense lives at the Edge)._

#### [AI-02] No live-model quality/regression monitoring — a silently-regressing model (false NORMALs) is invisible in production

**Severity:** MEDIUM · **Category:** ai · **Perspectives:** AI Systems Reviewer, Veterinary Safety Reviewer · **Effort:** L 2-4d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.85

**Evidence:** The golden-set eval is provider-free by design and runs against STUBS: `ai-service/app/eval_harness.py:9-11,27-58` (`_StubProvider`/`_FailingProvider`) and `tests/test_golden_set.py` enforces `false_negatives_on_emergency == 0` only over stubbed responses (12 cases: 7 EMERGENCY/4 MONITOR/1 NORMAL). It validates pipeline routing, not real model output. Production observability is limited to Sentry error capture (`ai-service/app/main.py:53-83`, `tests/test_observability.py`) and per-row DB storage (`supabase/functions/analyze/index.ts:322-339` stores `triage_level`/`confidence`/`full_response`). Grep for `canary`/`shadow`/`model drift`/output sampling in `ai-service/app` and `ai-service/tests` returns nothing.
**Root cause:** No mechanism samples/evaluates actual live-model outputs or watches the triage distribution; the eval harness deliberately mocks the model, so a real Gemini/Claude regression that returns well-formed but wrong triage (e.g. NORMAL for a sick pet) throws no error and trips no gate.
**User impact:** In a safety-critical triage app, a bad model day producing false-negative NORMALs would reach users undetected until harm/complaints surface — the stated #1 business risk.
**Business impact:** Delayed detection of a safety regression is a reputational and liability exposure; the mitigating architecture (hardcoded override, EMERGENCY cross-verify, borderline-NORMAL→MONITOR bias, temp 0.1) reduces but does not eliminate silent NORMAL errors.
**Store impact:** None directly.
**Solution:** (1) Add a scheduled live-model eval: reuse `golden_set.json` but call the REAL providers behind a flag, run daily via a cron/CI job, and alert (Sentry/email) on any EMERGENCY case not returning EMERGENCY or any pass-rate drop. (2) Add lightweight production monitoring: emit a metric per analysis of `triage_level`+`tier_used`+`degraded`+`cross_verified` and alert on distribution shifts (e.g. NORMAL-rate spike, cross-verify disagreement rate). (3) Add a periodic human-review sample of NORMAL/MONITOR results (query the `analyses` table) during beta. None block launch but (1)+(2) should land before scale-up.
**Acceptance criteria:** A daily job exercises real providers against the golden set and pages on any EMERGENCY false negative; a dashboard/alert exists for triage-distribution and degrade-rate; documented runbook for a suspected bad-model day.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [AI-03] NSFW moderator hardcodes image/jpeg MIME for every upload — legitimate PNG/WebP pet photos can be wrongly rejected (fails safe) and each image is fetched twice

**Severity:** MEDIUM · **Category:** ai · **Perspectives:** AI Systems Reviewer · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.75

**Evidence:** `ai-service/app/moderation.py:41-52` — `GeminiModerator.is_safe` does `httpx.get(image_url)` then `types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg")` — the MIME is hardcoded jpeg even though the upload allowlist accepts png and webp (`ai-service/app/media.py:22-28`). On any exception it returns `False` (fail closed, moderation.py:53-54). The moderator fetch also bypasses the media.py SSRF/redirect/size guards and is a SECOND fetch: the pipeline moderates each url (`pipeline.py:183-184`) and the provider then re-fetches the same url via `gather_media` (`providers.py:161`, `providers.py:83`).
**Root cause:** MIME is assumed jpeg rather than derived from the object; feeding PNG/WebP bytes labeled jpeg to Gemini can error → is_safe False → the pipeline rejects with a 'couldn't process this media' MONITOR result (`pipeline.py:184-199`).
**User impact:** An owner uploading a PNG/WebP photo (e.g. a gallery screenshot of an injury) may be told to retake it and get no analysis. It fails SAFE (never a false NORMAL), so this is reliability/UX, not a safety false-negative. The double fetch adds latency and R2 egress (a 6-frame video = 12 R2 GETs + 6 Gemini moderation calls).
**Business impact:** Avoidable drop-off and support load on a core flow; extra per-analysis cost.
**Store impact:** None.
**Solution:** Derive the MIME from the object rather than hardcoding: have moderation reuse `media.fetch_media(url)` (which returns validated bytes + correct MIME and enforces https/size/no-redirect), pass that MIME to `types.Part.from_bytes`, and thread the already-fetched bytes into the provider call so each item is fetched once. At minimum, replace the literal `"image/jpeg"` with the MIME from `_guess_mime`.
**Acceptance criteria:** A PNG and a WebP pet photo pass moderation and are analyzed; add a moderation unit test asserting the correct MIME is passed for png/webp; each media item is fetched at most once per analysis.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [AI-01] Prior CRITICAL resolved: image pixels ARE now sent to Gemini and Claude (photo/video triage is genuinely multimodal)

**Severity:** LOW · **Category:** reconcile · **Perspectives:** Veterinary Safety Reviewer, AI Systems Reviewer · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.97

**Evidence:** `ai-service/app/providers.py:81-85` (Gemini builds `types.Part.from_bytes(...)` from `gather_media(...)` and sends `[*parts, text]`), `ai-service/app/providers.py:161-174` (Claude base64-encodes each fetched item into `image` content blocks before the text), `ai-service/app/media.py:105-115` (`gather_media` actually fetches R2 bytes, up to 6 frames or one image). Real payload-capture tests assert this end-to-end: `ai-service/tests/test_providers_payload.py:98-137` capture the SDK kwargs and assert a base64 image block (Claude) / `types.Part` (Gemini) is present, frames capped at 6, and text-only stays a plain string. Suite: 186 passed.
**Root cause:** `PAWDOC_LAUNCH_GAP_ANALYSIS.md` (GAP-A1) claimed providers never send pixels and photo triage was text-only. That was true historically but has been remediated in this tree; the fix is code-verified, not just report-asserted.
**User impact:** Photo/video symptom checks now actually reason over the uploaded image, not a text stub — the product does what it claims.
**Business impact:** Removes the #1 launch-blocking safety/trust defect from the record; multimodal triage is the core value prop.
**Store impact:** None (positive — removes a would-be misrepresentation risk).
**Solution:** No action required beyond keeping the contract tests in CI. Confirmed: do NOT re-open or re-implement GAP-A1; treat it as closed. Optionally add one live smoke test (founder, with keys) that sends a real pet JPEG and asserts a non-degraded, non-NORMAL structured result to catch SDK/API-shape drift.
**Acceptance criteria:** `pytest tests/test_providers_payload.py` stays green in CI; any change to providers.py/media.py that drops the image part fails these tests.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [AI-04] media.py documents a 'strict host allowlist' SSRF defense that is not implemented — only Edge-side key presigning actually prevents SSRF

**Severity:** LOW · **Category:** security · **Perspectives:** AI Systems Reviewer · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.8

**Evidence:** `ai-service/app/media.py:8-10` docstring: 'GAP-A2 (SSRF) layers a strict host allowlist on top of this'. `fetch_media` (media.py:57-102) implements only: https-scheme check, IP-literal-host refusal, no-redirects, size/timeout/content-type bounds — there is NO host allowlist (grep for allowlist/allowed_host/R2 host in `ai-service/app` finds none). A hostname that resolves to a private/link-local IP (e.g. cloud metadata 169.254.169.254) is NOT an IP literal and would pass. The REAL SSRF defense is at the Edge: `supabase/functions/analyze/index.ts:96-97,195-200` no longer accepts client `image_url` and presigns only own-namespace storage keys (`isOwnUploadKey`), and `/analyze` is auth-gated to Edge callers (`ai-service/app/main.py:102-127`). So it is not exploitable today, but the in-code defense-in-depth does not match its own comment.
**Root cause:** Documentation/defense-in-depth drift: the allowlist described in the docstring was never added; the module relies on the Edge closing the vector.
**User impact:** None currently.
**Business impact:** If a future caller (new internal service, a bug that reintroduces client-supplied URLs, or a service-token leak) reaches `/analyze` with an arbitrary https URL, the fetcher would follow it to any resolvable host, enabling blind SSRF to internal/metadata endpoints.
**Store impact:** None.
**Solution:** Implement the documented allowlist in `fetch_media`: restrict the host to the configured R2 endpoint suffix (e.g. `<account>.r2.cloudflarestorage.com`) via an env-driven allowlist, and additionally resolve the hostname and reject private/link-local/loopback/reserved IP ranges (DNS-rebind protection) before the GET. Keep the existing https/redirect/size guards. If an allowlist is intentionally deferred, correct the docstring to state that Edge presigning is the sole SSRF control.
**Acceptance criteria:** A unit test proves `fetch_media` rejects a non-R2 host and a hostname resolving to a private IP; the media.py comment matches the implemented control.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Backend — Edge Functions, Migrations, AI Service

_Area readiness (finder self-assessment): 84% — The backend is mature and generally well-defended: RLS is enabled on every user table (users/pets/analyses/health_events/reminders/analysis_feedback/referrals plus family/journals/invites and the deny-all internal ledgers), the AnalysisResult contract is genuinely consistent across Python/TS/Dart, GAP-A1 (real pixels attached to model calls) and GAP-A2 (SSRF closed by presigning only the caller's own R2 keys) are both fixed in this tree, the RevenueCat webhook has a working idempotency ledger and constant-time secret check, cron/AI-service endpoints fail closed, and the auth-webhook is correctly superseded by an in-transaction DB trigger. The material gaps are cost/abuse controls and robustness, not data-safety: the authenticated /analyze path deliberately runs the full (paid) AI pipeline for out-of-quota PHOTO/VIDEO requests with no per-user or per-IP rate limit, so one free account can drive unbounded AI spend; outbound fetches from Edge Functions to the Fly AI service carry no timeout; and a few counter updates use non-atomic read-modify-write. The dead auth-webhook function still ships in the repo and should be deleted to prevent accidental redeploy. None of these are store blockers; the cost-abuse vector is the one to close before scaling to public traffic._

#### [BE-01] Out-of-quota visual /analyze runs the full paid AI pipeline with no rate limit — unbounded AI-cost abuse from a single free account

**Severity:** HIGH · **Category:** engineering · **Perspectives:** backend, security, monetization · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.88

**Evidence:** `supabase/functions/analyze/index.ts:136-138` computes `quotaExceeded` then calls `blockBeforeAi(quotaExceeded, isVisual)`; `supabase/functions/_shared/quota_gate.mjs:14-16` returns `false` for any visual input, so a free, out-of-quota PHOTO/VIDEO request is never blocked pre-AI. The AI service is then always called at `analyze/index.ts:263-290` (Gemini moderation per media + Gemini analysis + possible Claude escalation + possible Claude cross-verify), and only afterward is a non-EMERGENCY verdict blocked with a 402 (`analyze/index.ts:310-319`). The authenticated path has no per-user or per-IP rate limit anywhere in the function — the only throttle is the monthly quota, which is deliberately bypassed for visuals. (Contrast the anonymous path, which has Turnstile + an Upstash 3/day IP limit: `analyze-anonymous/index.ts:98-114`.)
**Root cause:** The safety rule "never paywall a visual emergency" (correct) was implemented by removing the pre-AI gate for visual inputs, but no compensating abuse control was added, so quota exhaustion no longer bounds AI spend for image/video inputs.
**User impact:** None directly for honest users; the safety behavior is correct.
**Business impact:** A single free account (verify_jwt only needs a valid session) can script unlimited photo/video submissions, each incurring real Gemini moderation + Gemini/Claude inference cost, returning zero revenue. At modest scale this can run the AI provider bill up arbitrarily (financial DoS) with no server-side ceiling and no alerting tied to it.
**Store impact:** None.
**Solution:** Add a server-side rate limit on the out-of-quota visual AI run keyed by user id (and/or client IP), reusing the existing Upstash primitives from `analyze-anonymous` (`incr`+`expire`). Concretely: before the AI call, when `quotaExceeded && isVisual`, enforce e.g. max N out-of-quota visual analyses per user per 24h (N small, e.g. 5); on exceed return the same 402 free_limit_reached body WITHOUT calling the AI. Keep EMERGENCY-text bypass unchanged (it never reaches this branch). Also set hard monthly spend caps on the Gemini/Anthropic accounts as an interim backstop.
**Acceptance criteria:** A free out-of-quota account submitting >N photo requests/24h receives 402 without an AI call (verify via logs / no provider invocation); a genuine visual EMERGENCY still returns free and unthrottled; a unit test covers the new gate in `quota_gate.mjs`.

**Verification:** CONFIRMED — Reproduced in current code. quota_gate.mjs:14-16 `blockBeforeAi = quotaExceeded && !isVisual` → visual out-of-quota is never blocked pre-AI. analyze/index.ts:136-138 computes quotaExceeded/isVisual and calls blockBeforeAi; 263-290 always calls AI service /analyze on cache miss (Gemini moderation + analysis + possible Claude escalation/cross-verify); only at 310-319 does blockAfterAi return 402 for non-EMERGENCY — after the paid pipeline already ran. Grep confirms NO rate-limit primitive (Upstash/incr/rateLimit/Turnstile) anywhere in the authenticated /analyze path or its _shared imports; those exist only in the anonymous path (web_checker.mjs; analyze-anonymous/index.ts:98-114 = Turnstile + 3/day IP limit). So an authenticated free, out-of-quota account can script unlimited photo/video analyses, each incurring real provider cost, with no per-user or per-IP ceiling and no counting (quota deliberately bypassed for visuals to preserve the never-paywall-visual-emergency safety rule). Financial-DoS / unbounded AI-cost abuse; no user-data or safety compromise. Requires a valid session but signup is free/scriptable. HIGH is appropriate.

---

#### [BE-02] No outbound timeout on Edge Function → Fly AI service fetches (/analyze, /embed, cron); a hung upstream ties up the function

**Severity:** MEDIUM · **Category:** engineering · **Perspectives:** backend, infrastructure, performance · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.83

**Evidence:** Every `fetch()` from an Edge Function to the AI service omits an `AbortSignal`/timeout: `analyze/index.ts:227` (`/embed`, on the hot analyze path), `analyze/index.ts:267` (`/analyze`), `analyze-anonymous/index.ts:118` (`/analyze`), and `generate-journals/index.ts:88` (`/generate_journal`). `aiServiceHeaders` (`_shared/ai_service.mjs:16-26`) sets no timeout either. Deno's `fetch` has no default request timeout, so a hung AI service (or a stacked pipeline: Gemini retry ~16s + Claude escalation retry ~16s + cross-verify ~8s) is awaited until the Supabase platform wall-clock limit rather than failing fast.
**Root cause:** Outbound calls rely on the upstream's own 8s provider timeouts (`providers.py:91,182`), but there is no client-side deadline on the Edge→AI hop itself.
**User impact:** On an AI-service stall the user's analyze request hangs (spinner) far longer than necessary before any error, instead of a prompt 503 "analysis_unavailable" with the vet-CTA.
**Business impact:** Degrades perceived reliability of the core triage flow and can pile up concurrent long-lived function invocations during an AI incident; the AI service's sync `def` endpoints share a threadpool, so /health can be starved under enough stacked calls, risking Fly machine restarts mid-request.
**Store impact:** None.
**Solution:** Wrap each AI-service fetch with `signal: AbortSignal.timeout(ms)` (e.g. 12000ms for /analyze to cover the worst-case pipeline, 3000ms for /embed since it is best-effort), and treat the AbortError like the existing catch → return 503 for /analyze, and for /embed fall through to a fresh analysis (already the catch behavior). Optionally make the AI service `/analyze` and `/health` `async def` or run the pipeline via `run_in_threadpool` with a bounded pool so /health is never starved.
**Acceptance criteria:** A simulated slow/hung AI service causes /analyze to return 503 within the configured deadline (not platform-max); /embed timeout falls through to a normal analysis; existing tests stay green.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [BE-03] Dead auth-webhook Edge Function still ships in the repo (superseded by DB trigger) — risk of accidental redeploy

**Severity:** LOW · **Category:** engineering · **Perspectives:** backend, infrastructure · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.95

**Evidence:** `supabase/functions/auth-webhook/index.ts` still exists on disk. It is intentionally NOT wired: `supabase/config.toml` has no `[functions.auth-webhook]` block and instead a comment ("GAP-D3: /auth-webhook is REMOVED from config") explaining the DB trigger supersedes it. Profile provisioning is now guaranteed in-transaction by `supabase/migrations/20260609150000_auth_user_profile_trigger.sql` (`on_auth_user_created` AFTER INSERT on `auth.users`, idempotent `on conflict do nothing`, plus a backfill). The webhook fails closed (returns 500 "server misconfigured" when its secret is unset) and, absent a config override, would default to `verify_jwt=true` — which Supabase Auth Hooks do not send — so even if deployed it cannot function. Verdict: dead, not dangerous.
**Root cause:** The function directory was left behind when the approach switched from an Edge Auth Hook to a Postgres trigger; only the config wiring was removed.
**User impact:** None.
**Business impact:** A bulk `supabase functions deploy` (deploy-all) could re-publish a confusing, non-functional endpoint; the stale code also invites future maintainers to mistakenly re-enable a redundant provisioning path that races/duplicates the trigger's work (mitigated by ON CONFLICT, so harmless data-wise).
**Store impact:** None.
**Solution:** Delete `supabase/functions/auth-webhook/` from the repo (and its any test), and have the founder run the already-documented `supabase functions delete auth-webhook --project-ref <ref>` to remove any deployed copy. Keep the config.toml explanatory comment or move it to `docs/`.
**Acceptance criteria:** Directory removed from git; `supabase functions list` on the project shows no auth-webhook; signup still creates a `public.users` row (trigger) verified in the RLS/deletion test harness.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [BE-04] Non-atomic read-modify-write on quota and add-on counters allows extra free analyses / PDFs under concurrency

**Severity:** LOW · **Category:** engineering · **Perspectives:** backend, monetization · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.86

**Evidence:** The free-tier counter is updated with a value computed from a prior read: `analyze/index.ts:354-358` writes `free_analyses_used_this_month: decision.newUsed` (and `bonus_analyses: decision.newBonus`) where `decision` was derived from the row read at `analyze/index.ts:113-131`. The PDF add-on decrement is the same pattern: `generate-pdf-report/index.ts:132-135` writes `pdf_reports_remaining: credits - 1` where `credits` was read at :71-81. Two concurrent requests read the same starting value and both write the same decremented/incremented result (classic TOCTOU), so a user can obtain one or more extra free analyses or an extra PDF beyond entitlement.
**Root cause:** Counter mutation is done in application code as read-then-write rather than as a single atomic conditional UPDATE / RPC.
**User impact:** None negative.
**Business impact:** Minor revenue leakage — a small number of extra free AI analyses (quota is only 3/mo) or an extra paid-consumable PDF per concurrent burst. Low individual value but scriptable; compounds the cost-abuse theme.
**Store impact:** None.
**Solution:** Replace both with atomic guarded writes. For the free counter, use a Postgres RPC (SECURITY DEFINER) doing `update users set free_analyses_used_this_month = free_analyses_used_this_month + 1, bonus_analyses = greatest(bonus_analyses - :spent,0), free_analyses_reset_at = :reset where id = :uid` (or a conditional CAS), returning the new value. For PDFs, `update users set pdf_reports_remaining = pdf_reports_remaining - 1 where id = :uid and pdf_reports_remaining > 0` and treat 0 rows affected as "no credit". Keep the existing decision logic for the reset-window computation.
**Acceptance criteria:** Concurrent duplicate requests can never push usage below/above the true entitlement (verified with a concurrency test against the RPC); PDF decrement returns rows-affected=0 when out of credits and the function then 402s instead of serving.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Security

_Area readiness (finder self-assessment): 72% — Security posture is largely solid on the highest-risk surfaces I own: no real secrets are committed (the five secret files in the repo root are all untracked, absent from history, and covered by .gitignore, with a gitleaks CI gate), the previously-flagged client-image_url SSRF is genuinely closed at the Edge boundary (storage-key-only + isOwnUploadKey namespace check + server-side R2 presign), the AI service is bearer-token gated and fail-closed in production, uploads use short-lived presigned PUT URLs with no R2 write creds in the client, and EXIF/GPS is stripped before upload. Two issues remain: the Android release build is STILL signed with the well-known debug keystore (a hard Google Play upload blocker and a supply-chain risk — the prior audit's claim this was addressed is false in this tree), and the AI service retains a defense-in-depth SSRF weakness (media.py's docstring claims a host allowlist that does not exist; moderation.py fetches with an unguarded httpx.get). The debug-signing issue is a launch blocker; the SSRF residual is not client-exploitable today because it sits behind the token + Edge boundary._

#### [SEC-01] Android release build is signed with the debug keystore (Play upload blocker + update-integrity risk)

**Severity:** CRITICAL · **Category:** store-google · **Perspectives:** security, store-google, engineering · **Effort:** M 0.5-1d · **Blocks launch:** YES · **Blocks store:** google · **Confidence:** 0.98

**Evidence:** `mobile/android/app/build.gradle.kts:33-38` — the `release` buildType still contains `// TODO: Add your own signing config for the release build.` / `// Signing with the debug keys for now, so \`flutter run --release\` works.` and `signingConfig = signingConfigs.getByName("debug")`. No `key.properties` / upload keystore is wired (confirmed: no `key.properties` or keystore load logic anywhere under `mobile/android`). Prior audit memory claimed release-signing was remediated; that is NOT true in this tree.
**Root cause:** The Flutter template placeholder signing config was never replaced with a real upload key. Every `flutter build appbundle/apk --release` is signed with the shared, well-known Android debug certificate.
**User impact:** None at first install, but any future update signed with a different (real) key would fail to install over the debug-signed build, forcing users to uninstall/reinstall and lose local state — after launch this is catastrophic.
**Business impact:** Cannot ship. Blocks the entire Google Play release path; also undermines update integrity (the debug key is public, so a build's authenticity is not cryptographically owned by the founder).
**Store impact:** Google Play rejects AAB/APK uploads signed with the debug certificate ("You uploaded an APK signed with a certificate that is not valid / debug certificate"). Hard blocker for Play. Apple uses its own signing chain, so this specific file does not block Apple, but the equivalent iOS release signing must be independently verified.
**Solution:** 1) Generate a release keystore: `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`. 2) Store it OUTSIDE git and add `mobile/android/key.properties` (already gitignored per root `.gitignore`) with `storeFile`, `storePassword`, `keyAlias`, `keyPassword` (values from Doppler, never committed). 3) In `build.gradle.kts`, load `key.properties` into a `Properties` object, define `signingConfigs { create("release") { … } }` reading those values, and set `release { signingConfig = signingConfigs.getByName("release"); isMinifyEnabled = true; isShrinkResources = true }`. 4) Enroll in Google Play App Signing and keep the upload key in Doppler + an offline backup. 5) Rebuild and confirm the cert is not the debug cert.
**Acceptance criteria:** `keytool -printcert -jarfile app-release.aab` shows the release/upload certificate (CN != `Android Debug`, SHA-256 matches the Play App Signing enrolled upload key); a Play internal-testing upload of the AAB is accepted; `key.properties` and the `.jks` are confirmed untracked (`git status` clean, `git ls-files` shows neither).

**Verification:** CONFIRMED — Reproduced verbatim in current tree. mobile/android/app/build.gradle.kts:33-38 buildTypes { release { // TODO: Add your own signing config for the release build. // Signing with the debug keys for now, so `flutter run --release` works. signingConfig = signingConfigs.getByName("debug") } }. This is the unmodified Flutter template placeholder — no signingConfigs.create("release"), no Properties/key.properties load logic anywhere in the file (only 45 lines total). find over mobile/android returns no *.jks/*.keystore/key.properties; git ls-files mobile/android shows none tracked. Every `flutter build appbundle/apk --release` is therefore signed with the shared public Android debug certificate. Google Play rejects AAB/APK uploads signed with the debug cert (hard upload blocker), and any later real-key update would fail to install over a debug-signed build. iOS signing is a separate chain and not affected by this file. Severity CRITICAL upheld as a Play release blocker.

---

#### [SEC-02] AI service SSRF defense-in-depth gap: media.py has no host allowlist (docstring lies) and moderation.py fetch is unguarded

**Severity:** MEDIUM · **Category:** security · **Perspectives:** security, ai, infrastructure · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.8

**Evidence:** `ai-service/app/media.py:6-9` docstring states "GAP-A2 (SSRF) layers a strict host allowlist on top of this" and "already refuses non-https and IP-literal hosts", but `fetch_media` (`media.py:56-103`) only enforces https + rejects IP-literal hostnames — there is NO host allowlist anywhere in the fetch path (grep for `allowlist`/`R2_HOST`/`allowed_host` in `ai-service/app/*.py` returns nothing operative). A DNS name that resolves to a private/link-local address (e.g. `169.254.169.254` via a rebinding record) passes the `_is_ip_literal` check. Separately, `ai-service/app/moderation.py:41` does `httpx.get(image_url, timeout=5.0)` with NO scheme check, NO IP check, NO size cap, and default redirect-following.
**Root cause:** The Edge boundary (`analyze/index.ts`) was hardened to only ever pass server-presigned R2 URLs, so the in-service guards were left as first-line/best-effort and the promised allowlist was never implemented; the moderation fetch predates the media.py hardening and never got the same guards.
**User impact:** None in the normal flow — the URLs reaching these functions are server-generated R2 presigned URLs.
**Business impact:** Residual blind-SSRF exposure if the AI service is ever reached directly with an attacker-chosen `image_url` (requires the `AI_SERVICE_TOKEN` to leak, or a future caller that forwards a client URL). A successful hit could reach the Fly metadata endpoint / internal services. Low likelihood, real blast radius; also the misleading docstring will cause a future reader to believe an allowlist exists.
**Store impact:** None.
**Solution:** 1) Add a real allowlist in `media.py`: read an env `R2_MEDIA_HOST` (e.g. `<account>.r2.cloudflarestorage.com`) and reject any `parsed.hostname` not exactly equal (or not a suffix of the configured host). 2) Resolve the hostname and reject if any resolved address is private/loopback/link-local/reserved (`ipaddress.ip_address(addr).is_private/is_loopback/is_link_local/is_reserved`) to defeat DNS-rebinding, ideally pinning the connection to the validated IP. 3) Replace `moderation.py:41` `httpx.get` with a call to the hardened `fetch_media()` (same scheme/host/IP/size/redirect guards, `follow_redirects=False`) instead of a raw fetch. 4) Fix the `media.py` docstring to describe what is actually enforced.
**Acceptance criteria:** A unit test proves `fetch_media` and the moderator both reject `https://attacker.example/` resolving to `169.254.169.254`, reject a non-R2 host, and do not follow a 302 to an internal address; moderation.py no longer calls a bare `httpx.get`; docstring matches the code.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [SEC-03] Prior audit's client-image_url SSRF and committed-secrets risks are genuinely closed (reconciliation)

**Severity:** LOW · **Category:** reconcile · **Perspectives:** security, reconcile · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.95

**Evidence:** Client `image_url` is no longer accepted by `/analyze` — `supabase/functions/analyze/index.ts:88-90` documents its removal, and media is addressed only by storage keys validated via `isOwnUploadKey(body.input_storage_key, user.id)` (`analyze/index.ts:110-113`; `_shared/upload_key.mjs:32-45` enforces `uploads/<caller-uid>/<uuid>.<ext>` with no traversal), then presigned server-side (`presignGet`, 120s expiry). Secrets: `.env`, `doppler.env`, `prd_secrets.env`, `temp_prod.env`, `doppler.json` are all present on disk but `git ls-files --error-unmatch` reports each untracked and `git log` shows no history; `.gitignore` covers `*.env`, `doppler.json`, keystores, `*.p8`; gitleaks CI job exists (`.github/workflows/ci.yml:39-48`). Uploads use presigned PUT with no client R2 creds (`mobile/lib/src/capture/upload_service.dart:50-82`; grep for R2/AWS secret keys in `mobile/lib` returns nothing). EXIF/GPS stripped pre-upload (`image_compressor.dart:60,71`).
**Root cause:** N/A — this documents that previously-reported CRITICAL security items are verified fixed in THIS tree, so they should not be re-raised.
**User impact:** Positive — user photos are uploaded metadata-stripped over presigned URLs; server cannot be pointed at arbitrary URLs by the client.
**Business impact:** These specific blockers are cleared; remaining security blocker is the debug-signing finding only.
**Store impact:** None.
**Solution:** No action required beyond the separate MEDIUM defense-in-depth hardening of the AI-service-internal fetch guards. Keep the gitleaks job as a required check on `main`.
**Acceptance criteria:** N/A (informational reconciliation).

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Data Layer — RLS & Integrity

_Area readiness (finder self-assessment): 68% — The RLS policy design itself is genuinely strong: every user-data table (users, pets, analyses, health_events, reminders, analysis_feedback, referrals, family_groups, family_members, family_invites, health_journals, deletion_log, processed_rc_events) has RLS enabled with per-operation USING+WITH CHECK policies bound to auth.uid(), the family-sharing redesign correctly uses SECURITY DEFINER helpers to avoid recursion, and the E12 patch closes the cross-tenant UPDATE-reparent hole. However data-model integrity has one CRITICAL erasure defect: the two referral FKs (referrals.referred_user_id, users.referred_by_user_id) were added with NO ON DELETE action, so once the live, farmable referral feature is used, account deletion 500s for any referrer or referee — a GDPR/Apple 5.1.1(v) blocker that account_deletion.sql never catches. Compounding this, scripts/test-rls.sh applies only a hand-picked SUBSET of migrations (it never loads the referrals migration) and is not gated in CI at all, so the deletion blocker and several tables' RLS go entirely unverified. Fix the FKs and the harness before launch._

#### [RLS-01] Referral FKs lack ON DELETE — account deletion (GDPR/Apple erasure) fails for any user in a referral relationship

**Severity:** CRITICAL · **Category:** privacy · **Perspectives:** Senior Security Engineer (data), DBA · **Effort:** S <=2h · **Blocks launch:** YES · **Blocks store:** both · **Confidence:** 0.9

**Evidence:** `supabase/migrations/20260527030000_referrals.sql:18` `alter table public.users add column referred_by_user_id uuid references public.users (id);` and `:22` `alter table public.referrals add column referred_user_id uuid references public.users (id);` — both FKs omit any `ON DELETE` clause, so they default to `NO ACTION`. `supabase/functions/delete-account/index.ts:147` deletes the account solely via `admin.auth.admin.deleteUser(user.id)` and relies entirely on FK cascades (it never manually deletes referral rows). No later migration alters these FKs (grep across `supabase/migrations/` confirms only the two definitions).

**Root cause:** Every other user-owned FK was deliberately made `ON DELETE CASCADE` (CR #20), but the two referral linkage columns added in Phase 3.3 were left at the Postgres default `NO ACTION`. When `public.users` row X is deleted (cascaded from `auth.users` via `deleteUser`), Postgres checks inbound references: (a) any `referrals` row with `referred_user_id = X` — its `referrer_user_id` points at a *different* user so it is NOT cascade-removed — trips `NO ACTION`; and (b) any `users` row whose `referred_by_user_id = X` (the people X referred) trips `NO ACTION`. Either raises a foreign-key violation, aborting the whole delete.

**User impact:** A user who was referred by anyone, OR who referred anyone, cannot delete their account. `delete-account` returns HTTP 500 ("deletion failed") and their auth user, PII, pets, and analyses all remain. R2 media and third-party PII were already purged before the failing `deleteUser`, leaving the account in a half-erased, broken state.

**Business impact:** Direct GDPR/KVKK right-to-erasure violation and Apple Guideline 5.1.1(v) violation (account-deletion is mandatory and must actually work). The referral feature is live and, combined with email auto-confirm (GAP-E16 notes referrals are near-free to farm), referral relationships will be common, so this hits real users, not an edge case. Regulatory exposure plus App Store rejection/removal risk.

**Store impact:** Apple rejects/removes apps whose in-app account deletion fails (5.1.1(v)); Google Play Data deletion policy similarly requires working deletion.

**Solution:** Add a migration that rewrites both FKs to self-heal on delete. For `referrals.referred_user_id` and `referrals.referrer_user_id` the whole referral row is meaningless once either party is gone, so: `alter table public.referrals drop constraint referrals_referred_user_id_fkey, add constraint referrals_referred_user_id_fkey foreign key (referred_user_id) references public.users(id) on delete cascade;` (verify the auto-generated constraint name via `\d public.referrals`). For `users.referred_by_user_id` use `on delete set null` (the referee should survive, just lose the backlink): drop and re-add that constraint with `on delete set null`. Because Phase 3.3 revoked client UPDATE on `users`, the SET NULL runs as the deleting superuser/service role and is unaffected by column grants. Alternatively, if the current constraint names are unknown, look them up first. Do NOT try to patch this only in the Edge Function — enforce it at the DB layer so admin-API and raw-cascade deletion paths are also correct.

**Acceptance criteria:** A migration exists changing both FKs off `NO ACTION`. A new case in `supabase/tests/account_deletion.sql` (or family_deletion_cascade.sql): user A refers user B (creates a `referrals` row + sets `B.referred_by_user_id = A`), then `delete from auth.users where id = A` succeeds AND `delete from auth.users where id = B` succeeds, with zero orphaned/blocking rows and B's row correctly retained-or-removed per the chosen semantics. `scripts/test-rls.sh` includes the referrals migration so this is actually exercised.

**Verification:** CONFIRMED — Reproduced. supabase/migrations/20260527030000_referrals.sql:18 (users.referred_by_user_id) and :22 (referrals.referred_user_id) both reference public.users(id) with NO ON DELETE clause → NO ACTION. By contrast initial_schema.sql:97 gives referrals.referrer_user_id ON DELETE CASCADE and :18 gives public.users.id references auth.users on delete cascade, so admin.auth.admin.deleteUser (delete-account/index.ts:147) cascades into public.users and then trips the two inbound NO-ACTION FKs. Deleting a referee blocks on referrals.referred_user_id; deleting a referrer blocks on referees' users.referred_by_user_id. claim_referral RPC (lines 97-104) populates exactly these columns, so live data exists. delete-account purges R2/third-party PII (lines 126,131) BEFORE the failing auth delete, returning HTTP 500 (line 150) and leaving a half-erased account. No later migration alters these FKs (grep confirmed). Additionally scripts/test-rls.sh:41-52 does not even load the referrals migration and account_deletion.sql omits referral columns, so the cascade is untested. GDPR/KVKK erasure + Apple 5.1.1(v) mandatory-deletion failure = CRITICAL.

---

#### [RLS-02] test-rls.sh applies only a curated SUBSET of migrations and is not gated in CI — RLS/cascade coverage is a false-confidence illusion

**Severity:** MEDIUM · **Category:** engineering · **Perspectives:** DBA, Senior Security Engineer (data) · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.92

**Evidence:** `scripts/test-rls.sh` (the `psql -f` block) applies exactly 7 migrations: enable_extensions, initial_schema, rls_policies, family_sharing, family_invites, family_deletion_cascade, family_update_boundary. It NEVER applies `20260527030000_referrals.sql`, `20260527020000_semantic_cache.sql`, `20260527040000_reminders_engagement.sql`, `20260527070000_health_journals.sql`, `20260612170000_deletion_log.sql`, `20260613120000_rc_event_idempotency.sql`, or several others. Grep of `.github/workflows/*.yml` shows `test-rls` is referenced nowhere — `ci.yml` runs ruff/pytest, shellcheck, gitleaks, node --test, and flutter, but no Postgres/RLS job. `account_deletion.sql` deletes a user (`11111111-…`) with no referral relationship, so it passes even though the referral-FK deletion blocker (see the CRITICAL finding) exists.

**Root cause:** The RLS harness was assembled by hand-listing the migrations relevant to a given feature rather than replaying the full ordered migration set the way Supabase does in production. Because the referrals/health_journals/deletion_log/rc_events migrations are omitted, their schema (including the two un-cascaded referral FKs) never exists in the test DB, so no test can catch defects in them. CI never runs the harness at all, so even the subset only runs when the founder manually invokes Docker.

**User impact:** None directly, but this is the control that was supposed to catch the CRITICAL erasure blocker and any future RLS regression on referrals, health_journals, deletion_log, and processed_rc_events — and it structurally cannot.

**Business impact:** The project's stated verification discipline ("RLS on EVERY user table, verify with test-rls.sh") gives false assurance. A data-leak or erasure regression on any table outside the curated 7 ships unnoticed. Given the app is safety- and privacy-critical, an untested RLS surface is a standing liability.

**Store impact:** none directly, but it is why the CRITICAL store-blocker went undetected.

**Solution:** (1) Change `scripts/test-rls.sh` to apply ALL of `supabase/migrations/*.sql` in filename (timestamp) order rather than a hand-picked list — e.g. iterate `for f in $(ls /repo/supabase/migrations/*.sql | sort); do ... -f "$f"; done` so the test schema equals production. Ensure `_local_shim.sql` provides the `auth`, `service_role`, `anon`, `authenticated` roles the later migrations expect. (2) Add the referral / cross-user negative RLS assertions and the referral-deletion case. (3) Add a CI job to `.github/workflows/ci.yml` that runs `./scripts/test-rls.sh` on a `pgvector/pgvector:pg16` service container (Docker is available on ubuntu-latest runners) so it gates every PR, matching the existing node-tests/flutter jobs.

**Acceptance criteria:** `test-rls.sh` loads the full migration set (adding referrals reproduces the CRITICAL failure until that finding is fixed, then goes green). A CI job named e.g. "RLS + cascade (postgres)" runs the script and is required on PRs to `main`. Running the script locally applies every file under `supabase/migrations/` with `ON_ERROR_STOP=1` and passes.

**Verification:** PARTIAL — All factual claims reproduced in current tree. scripts/test-rls.sh lines 39-52 apply exactly 7 migrations (enable_extensions, initial_schema, rls_policies, family_sharing, family_invites, family_deletion_cascade, family_update_boundary) via an explicit hand-listed -f chain, not a loop over supabase/migrations/*.sql. 23 migration files exist; 16 are never applied, including referrals, semantic_cache, reminders_engagement, health_journals, deletion_log, and rc_event_idempotency — so those tables/RLS/FKs never exist in the test DB. grep 'test-rls' across .github/ = NO MATCH; ci.yml jobs are ai-service, shell-lint, secret-scan, node-tests, no-placeholders, flutter — no Postgres/RLS/docker service job, so the harness only runs on manual local Docker invocation. supabase/tests/account_deletion.sql (lines 6-16) deletes user 11111111-... and asserts only on users/pets/analyses, with no referral relationship, so it cannot detect a referral-FK deletion blocker. Severity adjusted from HIGH to MEDIUM: the defect is genuine (curated-subset schema + ungated CI = false verification confidence) but by the finding's own admission has no direct user or store impact; its HIGH framing is inherited from a separate CRITICAL erasure finding not proven within this file evidence. It is a legitimate test-coverage/verification-discipline gap worth fixing (replay full ordered migration set + add CI Postgres job).

---

#### [RLS-03] Analyze Edge Function reads the caller's users/subscription row via service_role, contrary to the 'never service_role for user reads' convention

**Severity:** LOW · **Category:** reconcile · **Perspectives:** Senior Security Engineer (data) · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.55

**Evidence:** `supabase/functions/analyze/index.ts:112-115` uses the `admin` (service_role) client to `from("users").select("subscription_status, free_analyses_used_this_month, free_analyses_reset_at, bonus_analyses, preferred_locale").eq("id", user.id)`. CLAUDE.md states: "NEVER use service_role for user-data reads. Reads go through the user's JWT + RLS; service_role is server-only for writes/admin."

**Root cause:** The free-tier counter and subscription gate are server-authoritative and read+written atomically with the same admin client, so the read was co-located on the service-role path rather than the JWT path.

**User impact:** None — the read is strictly scoped to `user.id` taken from the verified JWT (`userClient.auth.getUser()` above), and RLS on `public.users` would only ever expose that same own row anyway, so there is no cross-user leak.

**Business impact:** A strict reading of the project's own non-negotiable convention is violated, which could confuse future auditors or be copied into a genuinely unsafe read elsewhere. Purely a consistency/defense-in-depth concern here.

**Store impact:** none.

**Solution:** Either (a) document an explicit, narrowly-scoped exception in CLAUDE.md for server-authoritative counter/subscription reads that are keyed by the JWT `user.id` (recommended, since the value must be trusted server-side and cannot be client-influenced), or (b) read the non-sensitive fields via `userClient` (RLS) and keep only the atomic counter increment on `admin`. Do not weaken the rule broadly.

**Acceptance criteria:** The service_role read is either justified by a written exception in CLAUDE.md scoped to JWT-keyed own-row server-authoritative reads, or refactored so user-facing fields come through the RLS-enforced client; no service_role read is keyed by any client-supplied identifier.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Infrastructure, DevOps & Release

_Area readiness (finder self-assessment): 58% — The legal-portal Terraform is genuinely production-grade: private S3 origin with a public-access block and BucketOwnerEnforced, CloudFront-only reads via OAC + a SourceArn-scoped bucket policy, SSE, versioning, redirect-to-HTTPS, and a strong response-headers policy (HSTS preload, CSP, X-Content-Type-Options, frame-options DENY, Permissions-Policy) plus automatic CDN invalidation — and no secrets are hardcoded or committed (tfstate is gitignored and not tracked). The release/CI pipeline is where the risk sits: the Android release build is still signed with the debug key (a hard Google Play blocker), the AI-service auto-deploy uses an unpinned @master action on the FLY_API_TOKEN path, Terraform state is local-only with no locking, the mandated RLS test suite is never run in CI, and the AI service is a single 512 MB machine with no scaling ceiling or alerting. Lower-severity items: CloudFront's default cert pins TLSv1.0, and the 'no-placeholders' CI forcing-function is green rather than the documented red._

#### [INF-01] Android release build is signed with the debug key — Play Store upload will be rejected

**Severity:** CRITICAL · **Category:** store-google · **Perspectives:** Senior DevOps Engineer, Release Engineer · **Effort:** M 0.5-1d · **Blocks launch:** YES · **Blocks store:** google · **Confidence:** 0.98

**Evidence:** `mobile/android/app/build.gradle.kts:33-38` — the only `buildTypes { release { ... } }` block sets `signingConfig = signingConfigs.getByName("debug")` with the comment `// TODO: Add your own signing config for the release build.` No `key.properties`, keystore, or `signingConfigs.create("release")` exists (`find android -name key.properties` returns nothing). CI compounds this: `.github/workflows/ci.yml:98-102` runs `flutter build appbundle` (release mode) which succeeds because it silently falls back to the debug key, so CI stays green while producing an unshippable artifact. `fastlane/Fastfile:25-34` `play_internal` then uploads `app-release.aab`.

**Verification:** CONFIRMED — Reproduced in current tree. mobile/android/app/build.gradle.kts:33-38 release buildType sets `signingConfig = signingConfigs.getByName("debug")` with TODO comment "Add your own signing config"; it is the ONLY signingConfig reference under mobile/android (grep). No key.properties / *.jks / *.keystore / signingConfigs.create("release") exists. .github/workflows/ci.yml:98-102 runs `flutter build apk --debug` then `flutter build appbundle` (release-mode default) which succeeds via the debug-key fallback, keeping CI green while emitting an unshippable AAB. mobile/android/fastlane/Fastfile play_internal lane uploads build/app/outputs/bundle/release/app-release.aab to Play internal track. Google Play rejects debug-signed uploads, so Play Store upload is blocked. Founder-side config item (signing already tracked as a founder blocker in project memory), but code state matches the finding exactly.

---

#### [INF-02] AI-service auto-deploy uses an unpinned @master GitHub Action on the FLY_API_TOKEN path

**Severity:** MEDIUM · **Category:** security · **Perspectives:** Senior DevOps Engineer, Security · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.9

**Evidence:** `.github/workflows/deploy.yml:31` — `uses: superfly/flyctl-actions/setup-flyctl@master`. This job (`deploy.yml:32-36`) then runs `flyctl deploy --remote-only` with `FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}` exposed to the action's environment. The same repo explicitly pinned another action off master for exactly this reason: `.github/workflows/ci.yml:35` `ludeeus/action-shellcheck@2.0.0 # GAP-D5: pin off @master (supply chain)`. The deploy path was left inconsistent.

**Verification:** PARTIAL — Reproduced verbatim: .github/workflows/deploy.yml:31 `uses: superfly/flyctl-actions/setup-flyctl@master` (unpinned mutable ref); same job at deploy.yml:32-36 runs `flyctl deploy --remote-only` with `FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}` in env. Repo precedent confirmed at ci.yml:35 `ludeeus/action-shellcheck@2.0.0 # GAP-D5: pin off @master (supply chain)`. Finding is accurate; the @master path was left inconsistent with the pinning done elsewhere. Severity HIGH is overstated: exploit requires compromise of a Fly.io first-party action, and the deploy job only triggers on green main CI (workflow_run). This is a real supply-chain/pinning-hygiene gap warranting a pin to a release tag/SHA, but MEDIUM is the appropriate rating.

---

#### [INF-03] Terraform state is local-only — no remote backend, no locking, single point of failure

**Severity:** MEDIUM · **Category:** infrastructure · **Perspectives:** Senior DevOps Engineer, AWS Architect · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.92

**Evidence:** `infra/legal-portal/main.tf:6-14` declares `terraform { required_version / required_providers }` but has NO `backend` block (`grep -rn backend infra/legal-portal/*.tf` returns nothing). State lives as local files `infra/legal-portal/terraform.tfstate` (76 KB) + `terraform.tfstate.backup` in the working tree (correctly gitignored via `.gitignore:2-3`, and verified not git-tracked). The deployed distribution is real (state contains `d1klm6zb1x23me.cloudfront.net`, distribution `E8Y2A826AQCDC`). `deploy.sh:16-19` runs `terraform init/apply` against this local state.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [INF-04] RLS test suite (test-rls.sh) is mandated but never gated in CI

**Severity:** MEDIUM · **Category:** infrastructure · **Perspectives:** Senior DevOps Engineer, Security · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.85

**Evidence:** `.github/workflows/ci.yml` defines jobs ai-service, shell-lint, secret-scan, node-tests, no-placeholders, flutter — but no RLS job (`grep -rn 'test-rls\|rls' .github/workflows/` returns nothing). CLAUDE.md makes RLS the primary data-security control ("RLS on EVERY user table … Verify with scripts/test-rls.sh") and `scripts/test-rls.sh` exists for exactly this. The script needs Docker/Postgres so it was likely omitted for runner simplicity, but that leaves the #1 data-isolation control unverified on every PR.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [INF-05] AI service runs on a single 512 MB shared machine with no scaling ceiling or alerting

**Severity:** MEDIUM · **Category:** infrastructure · **Perspectives:** Senior DevOps Engineer, AWS Architect · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.8

**Evidence:** `ai-service/fly.toml:16-18` sets `auto_stop_machines = "off"`, `min_machines_running = 1`; `[[vm]]` (lines 33-36) is a single `shared` cpu / `512mb` machine. There is no `max_machines_running` / autoscaling and no `[metrics]` or alert config. The header comment (`fly.toml:6-9`) admits config drift: it claims the live deployment runs 2 machines in `fra` while the file declares `min_machines_running = 1`. The only availability guard is the Fly health check (`fly.toml:26-31`) which restarts a dead machine but provides no redundancy during the restart window.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [INF-06] CloudFront default cert forces a TLSv1.0 minimum on the legal portal

**Severity:** LOW · **Category:** infrastructure · **Perspectives:** Senior DevOps Engineer, Security · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.85

**Evidence:** `infra/legal-portal/cloudfront.tf:113-118` — with no custom domain, `acm_certificate_arn` defaults to `""` (`variables.tf:31-35`), so the ternary selects `cloudfront_default_certificate = true` and `minimum_protocol_version = "TLSv1"`. The portal is live on the default domain `d1klm6zb1x23me.cloudfront.net` (from state), i.e. this TLSv1.0 floor is the active configuration. The stronger `TLSv1.2_2021` branch only activates when a custom-domain ACM cert is supplied.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [INF-07] CI 'no-placeholders' gate documented as intentionally-red is actually green while placeholder store URLs remain

**Severity:** LOW · **Category:** reconcile · **Perspectives:** Senior DevOps Engineer · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.88

**Evidence:** `.github/workflows/ci.yml:63-72` comments the `no-placeholders` job as a forcing function that "stays RED until GAP-B5 truthifies the store/web/legal copy." Running the script directly (`./scripts/verify-no-placeholders.sh`) exits 0 (OK) — it only fails under `--strict`, which CI does not pass. It reports surviving placeholders including fake store URLs `web/app/page.tsx:6` (`https://apps.apple.com/app/pawdoc // TODO: real App Store URL`) and `:7` (Play URL TODO), plus `docs/legal/terms-of-service.md:69,78` `[LEGAL ENTITY + ADDRESS]`. So the guard is green and these can ship silently — the opposite of the documented behavior.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Legal & Privacy Compliance

_Area readiness (finder self-assessment): 64% — The legal portal is substantively strong: 15 well-drafted pages are live (all 16 URLs return 200), the vet/AI disclaimer is genuinely non-strippable (server-forced `disclaimer_required=True` in ai-service/app/pipeline.py, payload-parsed in Dart, UI-gated on both result screens — verify-disclaimers.sh passes green), AI transparency is honest, CCPA "we don't sell" is stated, and account deletion is documented and reachable in-app (account_screen.dart:190 → DeleteAccountScreen). However, the published documents still carry unfilled controller-identity/EU-representative placeholders, the sole DSAR/deletion contact channel (pawdoc.app email) has no MX record and cannot receive mail, and signup presents Terms/Privacy as passive footer links with no affirmative acceptance. Real attorney sign-off remains outstanding and several counsel-to-confirm brackets are live. Content is ~90% done; enforceability/operability gaps keep the area from launch-ready._

#### [LEG-01] Published privacy/terms/deletion pages carry unfilled data-controller identity and EU-representative placeholders

**Severity:** CRITICAL · **Category:** legal · **Perspectives:** Privacy/GDPR, Legal/Compliance, Store-Apple, Store-Google · **Effort:** M 0.5-1d · **Blocks launch:** YES · **Blocks store:** both · **Confidence:** 0.97

**Evidence:** The LIVE portal serves literal placeholders. `curl https://d1klm6zb1x23me.cloudfront.net/privacy` returns 2×`[LEGAL ENTITY]`, 2×`[BUSINESS ADDRESS]`, 1×`[EU REPRESENTATIVE ... to be appointed]`; `/terms` returns 2×`[LEGAL ENTITY]`, 1×`[BUSINESS ADDRESS]`; `/deletion` and `/ccpa` end with `[LEGAL ENTITY], [BUSINESS ADDRESS].` Source: web-legal/content/privacy.md:16,119-121; terms.md; deletion.md:59; ccpa.md:55. Softer `[counsel to confirm]` brackets are also live in subscriptions.md:64,68, data-retention.md:16,28-30, ccpa.md:36.
**Root cause:** The June 2026 legal-content pass shipped attorney-review templates to production with bracketed fields never populated; PR #78 published them as-is without a placeholder gate.
**User impact:** Users cannot learn who controls their data or where to send GDPR/CCPA requests; the erasure/DSAR promise names no accountable entity, undermining trust in a health-data app.
**Business impact:** GDPR Art. 13(1)(a) requires the controller's identity and Art. 27 an EU representative when targeting EU users — absence is a direct compliance violation exposing the founder personally and inviting DPA complaints; contracts (SCCs/DPF) can't reference a named entity.
**Store impact:** Apple Guideline 5.1.1 and Google Play's User Data policy require a complete, accurate privacy policy; reviewers routinely reject policies containing obvious `[PLACEHOLDER]` tokens.
**Solution:** Founder + attorney finalize the operating legal entity and registered address; do a repo-wide sweep replacing every `[LEGAL ENTITY]`, `[BUSINESS ADDRESS]`, `[ADDRESS]`, `[EU REPRESENTATIVE ...]`, `[UK REPRESENTATIVE ...]` and each `[counsel to confirm ...]` bracket in web-legal/content/*.md with final text (or delete the note once resolved); appoint a GDPR Art. 27 EU representative if EU is in scope; rerun web-legal/build.mjs and redeploy to CloudFront; grep the built dist/ for `\[[A-Z ]` to prove zero brackets remain before publishing.
**Acceptance criteria:** `curl` on all 16 live pages returns zero `[BRACKET]` tokens; privacy.md and terms.md state a real legal entity + address; an EU representative is named (or a documented decision that EU is out of scope at launch); a build-time check fails if any `[A-Z...]` placeholder survives.

**Verification:** CONFIRMED — Reproduced exactly in the current tree (branch feat/legal-portal-integration). Source content still carries unfilled placeholders: web-legal/content/privacy.md:16 and :119 (2× [LEGAL ENTITY], 2× [BUSINESS ADDRESS]), :120 ([EU REPRESENTATIVE — to be appointed]), :121 ([UK REPRESENTATIVE …]); terms.md:14 and :69 (2× [LEGAL ENTITY], 1× [BUSINESS ADDRESS]) plus :65 [GOVERNING LAW/JURISDICTION] and :51 [12]/[USD 50] caps; deletion.md:59 and ccpa.md:55 both end with "[LEGAL ENTITY], [BUSINESS ADDRESS]."; gdpr.md:18 and contact.md:29-38 repeat entity/EU/UK/DPO/registration placeholders. Softer counsel brackets confirmed at subscriptions.md:64,68, data-retention.md:16,36, ccpa.md:36, referrals.md:43. Critically, these are already rendered into the built output: dist/privacy/index.html, dist/terms/index.html, dist/deletion/index.html, dist/ccpa/index.html, dist/gdpr/index.html, dist/contact/index.html all contain [LEGAL ENTITY]; build.mjs has NO placeholder/bracket gate, so nothing prevents publishing them. privacy.md:16 itself openly labels them "placeholders that the operator will complete before public launch" — a documented, founder-gated pre-launch item rather than a hidden defect, but still live/publishable as-is. GDPR Art. 13(1)(a) controller identity and Art. 27 EU-rep absence, plus obvious [PLACEHOLDER] tokens triggering Apple 5.1.1 / Google User-Data rejection, make this a genuine hard launch blocker for a health-data app.

---

#### [LEG-02] Sole DSAR / account-deletion / support contact (pawdoc.app email) is non-deliverable — domain has no MX record

**Severity:** HIGH · **Category:** legal · **Perspectives:** Privacy/GDPR, Legal/Compliance, Infrastructure, Store-Apple, Store-Google · **Effort:** M 0.5-1d · **Blocks launch:** YES · **Blocks store:** google · **Confidence:** 0.85

**Evidence:** Every legal page routes rights requests to `privacy@pawdoc.app` / `support@pawdoc.app` (privacy.md:92,117-118; deletion.md:30 web-deletion path; ccpa.md:51,55; gdpr.md; data-retention.md:44). `host -t MX pawdoc.app` → "pawdoc.app has no MX record"; `curl https://pawdoc.app` → HTTP 000. The web-deletion path (deletion.md §2) is literally "email privacy@pawdoc.app from your account address."
**Root cause:** The pawdoc.app domain email (MX/SMTP inbound) was never provisioned; legal copy assumes a working mailbox that does not exist. Consistent with the standing founder SMTP gate in project memory.
**User impact:** A user emailing to exercise GDPR access/erasure, a CCPA request, or web-based account deletion gets a bounce or silent drop — their statutory request is never received or actioned.
**Business impact:** GDPR (Art. 12/15/17) and CCPA require an operable request channel with statutory response deadlines (CCPA promises acknowledgment in 10 business days, ccpa.md:51); a dead inbox is non-compliance and the missed-deadline clock still runs. Support channel is also dead.
**Store impact:** Apple Guideline 5.1.1(v) and Google Play's Data deletion policy require a working account-deletion request path reachable by users; the documented web path (email) being non-functional can fail Play Data-safety / account-deletion review. (In-app deletion still works — this is the web fallback both stores expect.)
**Solution:** Register/verify pawdoc.app, add MX records and provision inbound mail (Google Workspace / Fastmail / SES receiving) for privacy@ and support@; route to a monitored inbox; send a test to each and confirm receipt; document response SLAs. If the launch domain differs, update every `@pawdoc.app` reference in web-legal/content/*.md and LegalUrls before publishing.
**Acceptance criteria:** `host -t MX pawdoc.app` returns records; a test email to privacy@pawdoc.app and support@pawdoc.app is delivered to a monitored inbox; the web-deletion request flow in deletion.md is exercised end-to-end at least once.

**Verification:** CONFIRMED — Independently reproduced. Email references confirmed: web-legal/content/privacy.md:16, ccpa.md:51+55 (10-business-day ack / 45-day response), gdpr.md:18+48, deletion.md:30 (web-deletion path is literally "Email privacy@pawdoc.app ... from the email address on your PawDoc account"), deletion.md:51+59, data-retention.md, contact.md:20-22 (routes privacy@/support@/legal@pawdoc.app). Live DNS/HTTP checks I ran: `host -t MX pawdoc.app` → "pawdoc.app has no MX record"; `dig +short A pawdoc.app` → empty; `curl https://pawdoc.app` → HTTP 000. So every documented DSAR/erasure/support channel targeting @pawdoc.app is non-deliverable. Corroborated by the repo's own launch audit (PAWDOC_LAUNCH_GAP_ANALYSIS.md:117 GAP-C3 "no MX → support@pawdoc.app cannot receive mail") and remediation playbook F-4 (add MX + Email Routing). Not overstated: in-app deletion still works (deletion.md §1), so the gap is the web/email fallback + GDPR/CCPA/support inbox, which is what stores expect as the web path. HIGH (legal/compliance) is correct — statutory channels dead with the deadline clock running; also a Play Data-safety / Apple 5.1.1(v) review risk on the documented web-deletion path.

---

#### [LEG-03] No affirmative Terms/Privacy acceptance at signup — legal links are passive footer buttons only

**Severity:** MEDIUM · **Category:** legal · **Perspectives:** Legal/Compliance, Privacy/GDPR, UI-UX · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.9

**Evidence:** sign_in_screen.dart `_legalLinks()` (lines 437-456) renders only two `TextButton`s labeled 'Privacy' and 'Terms' at the bottom of the sign-in sheet. A repo-wide grep for `by continuing|you agree|acknowledge|consent` across mobile/lib/src/ (auth + onboarding) finds no acceptance statement — the only 'acknowledge' hit is the unrelated emergency-result gate (emergency_result_screen.dart:15). There is no checkbox or 'By continuing you agree to the Terms and Privacy Policy' line before account creation.
**Root cause:** Signup UX added legal links for discoverability but never wired an affirmative assent step; terms.md is written as a binding contract that assumes acceptance the flow never captures.
**User impact:** Users can create an account and submit pet health data without ever being told they are bound by the Terms or that their inputs are sent to third-party AI providers, weakening informed consent.
**Business impact:** Browsewrap (passive links) is materially weaker/harder to enforce than clickwrap; limitation-of-liability, arbitration, and the 'as is / no warranty' terms — central to a safety-critical triage product's risk posture — may be unenforceable without demonstrable assent. GDPR consent-based processing (analytics, push) is also not cleanly captured at entry.
**Store impact:** Not a hard store blocker (a linked policy exists), but strengthens Apple/Google data-consent posture.
**Solution:** Add an assent line directly above the sign-in/create-account CTA: 'By continuing, you agree to our Terms and Privacy Policy,' with both words as tappable links (reuse LegalUrls.terms / LegalUrls.privacy). For strict clickwrap on account creation, gate the create-account button on an explicit checkbox. Log acceptance timestamp + policy version server-side for evidentiary record.
**Acceptance criteria:** The primary signup CTA is accompanied by visible 'agree to Terms and Privacy' text linking both documents; acceptance is recorded (timestamp + version) at account creation; flutter analyze/test green.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [LEG-04] Divergent duplicate legal documents in docs/legal/ still carry TEMPLATE warnings and a conflicting DPO contact

**Severity:** MEDIUM · **Category:** reconcile · **Perspectives:** Legal/Compliance, Privacy/GDPR · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.9

**Evidence:** Two parallel, inconsistent legal sets exist. Published set: web-legal/content/privacy.md uses `privacy@pawdoc.app` as the privacy contact. Stale set: docs/legal/privacy-policy.md:1-9 is headed '⚠️ TEMPLATE — NOT LEGAL ADVICE ... Replace every [BRACKETED] placeholder', lists '**Contact / DPO:** support@pawdoc.app' (line 9), and docs/legal/terms-of-service.md:9 names a different operator string. They contradict the live portal on both the DPO contact address and completeness.
**Root cause:** The web-legal portal superseded the original engineering-drafted docs/legal/ templates, but the old files were left in the repo un-deleted and un-reconciled, creating two sources of truth.
**User impact:** None directly today (the app links only to the CloudFront web-legal pages), but the contradictory DPO/contact address could surface in support or store submissions.
**Business impact:** Risk of the wrong (template, placeholder-laden) version being copied into App Store Connect / Play Console or served if base URLs change; inconsistent contact addresses (support@ as DPO vs privacy@) create ambiguity about the authoritative privacy contact.
**Store impact:** Only if a stale template URL is submitted to a store; otherwise none.
**Solution:** Decide the single source of truth (web-legal/content/) and either delete docs/legal/privacy-policy.md and terms-of-service.md or replace their bodies with a one-line pointer to the canonical published URLs; ensure the privacy contact address is identical across all surviving documents (standardize on privacy@pawdoc.app for privacy, support@ for general).
**Acceptance criteria:** Only one canonical privacy policy and one terms document remain authoritative; no repo legal doc contains a 'TEMPLATE — NOT LEGAL ADVICE' banner or a contact address that conflicts with the live portal.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [LEG-05] 18+ eligibility is asserted in Terms/Children pages but never presented or attested in-app (no age gate, no ToS assent)

**Severity:** LOW · **Category:** privacy · **Perspectives:** Privacy/GDPR, Legal/Compliance · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.82

**Evidence:** children.md:14,33 and terms.md state users must be 18+ ('PawDoc requires users to be 18 or older'). In-app there is no age gate and no ToS acceptance step (grep for age/18/adult/birth in mobile/lib/src/auth + onboarding finds only the pet-profile `_birthDate` in onboarding_flow.dart:43, not a user age check; no assent per the prior finding). Eligibility rests entirely on a self-attestation the user is never actually asked to make.
**Root cause:** The 18+ requirement lives only in legal prose; the signup flow captures no acknowledgment of it.
**User impact:** A minor can sign up with no friction; the stated eligibility rule is unenforced.
**Business impact:** For a general-audience (non-child-directed) app this self-attestation-by-ToS model is common and defensible, so risk is low — but with no ToS assent at all (see related finding) there is nothing tying the user to the 18+ representation, weakening the COPPA/GDPR-Art.8 'we don't knowingly collect from minors' posture.
**Store impact:** None at this severity, provided the store age rating is set consistently (18+/mature or the app's chosen rating) in App Store Connect / Play Console.
**Solution:** Fold the eligibility representation into the signup assent line added for the acceptance finding ('By continuing you confirm you are 18+ and agree to the Terms and Privacy Policy'); ensure the store-listing age rating matches the 18+ claim. A hard date-of-birth gate is optional and not recommended for a general-audience app.
**Acceptance criteria:** Signup presents an 18+ / Terms confirmation before account creation; store age-rating configuration is consistent with the documented 18+ requirement.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Apple App Store Readiness

_Area readiness (finder self-assessment): 62% — Reviewed as an adversarial Apple App Reviewer against the current working tree. The fundamentals are genuinely strong: required purpose strings for camera (Info.plist:69) and location (Info.plist:71) are present and specific; no photo-library or microphone strings are needed because the app only uses the `camera` plugin with enableAudio:false (camera_screen.dart:42, video_capture_screen.dart:44) and has no gallery picker; in-app account deletion exists and is real (delete_account_screen.dart, 5.1.1(v) satisfied); the paywall carries the 3.1.2 auto-renew disclosure plus functional Terms/Privacy/Subscription links (paywall_screen.dart:220-266); Sign in with Apple is implemented (auth_controller.dart:31); and store copy is carefully scrubbed of medical-diagnosis overclaims (ios_app_store.md). The blockers are configuration/provisioning, not product: there is NO iOS entitlements file at all, so Sign in with Apple and Push will not function in a signed build; the App Store Connect metadata and review notes point at the dead pawdoc.app domain for Support/Privacy while the live portal is a CloudFront URL; the reviewer demo account is still a placeholder against an auth-gated app; and ITSAppUsesNonExemptEncryption is absent. None of these are safety issues, but several are hard App Review rejections until fixed._

#### [APPL-01] No iOS entitlements file — Sign in with Apple and Push Notifications will fail in a signed build

**Severity:** HIGH · **Category:** store-apple · **Perspectives:** Apple App Store Reviewer · **Effort:** M 0.5-1d · **Blocks launch:** YES · **Blocks store:** apple · **Confidence:** 0.8

**Evidence:** The app offers native Sign in with Apple on iOS (mobile/lib/src/auth/auth_controller.dart:31-51 `SignInWithApple.getAppleIDCredential`; button shown when `_appleAvailable` at mobile/lib/src/auth/sign_in_screen.dart:325-332) and initializes OneSignal push (mobile/lib/main.dart:78). But there is NO entitlements file anywhere under `mobile/ios` (`find mobile/ios -iname '*.entitlements'` returns nothing), and the Xcode project declares no capabilities: `grep -n 'entitlements\|applesignin\|aps-environment\|CODE_SIGN_ENTITLEMENTS' mobile/ios/Runner.xcodeproj/project.pbxproj` returns nothing. There is no `com.apple.developer.applesignin` and no `aps-environment` key.
**Root cause:** The Sign in with Apple and Push Notifications capabilities were never added to the Xcode target, so no `Runner.entitlements` was generated or referenced. Automatic signing does not embed the Apple-Sign-In or Push entitlements without an entitlements file listing them.
**User impact:** On a real signed build, tapping "Continue with Apple" throws (getAppleIDCredential fails with an authorization error) and push notifications never register — two features the UI actively advertises.
**Business impact:** Apple sign-in is a primary onboarding path; if it errors during review the app reads as broken. Push is a core retention/reminders channel that silently won't deliver.
**Store impact:** Guideline 2.1 (App Completeness — non-functional feature) and, because Sign in with Apple is presented, 5.1.1(iv). If the capability is enabled in the provisioning profile via `match` but absent from the binary, archive/upload validation fails outright.
**Solution:** Add a `mobile/ios/Runner/Runner.entitlements` containing `com.apple.developer.applesignin` = `[Default]` and `aps-environment` = `production`. Reference it via `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` in both Debug and Release build configs of `project.pbxproj`. Enable the "Sign in with Apple" and "Push Notifications" capabilities on the `app.pawdoc` App ID in the Apple Developer portal and regenerate the App Store provisioning profile in the `match` repo. Verify on a TestFlight build that the Apple button returns a credential and push registration succeeds.
**Acceptance criteria:** `Runner.entitlements` exists and is referenced in both configs; App ID has Sign in with Apple + Push enabled; a signed TestFlight build completes Apple sign-in end-to-end and receives a test push.

**Verification:** CONFIRMED — Reproduced all cited evidence in current tree. No entitlements file exists: `find mobile/ios -iname '*.entitlements'` returns nothing; `mobile/ios/Runner/` contains no Runner.entitlements (only AppDelegate.swift, Info.plist, SceneDelegate.swift, etc.). `grep -nE 'entitlements|applesignin|aps-environment|CODE_SIGN_ENTITLEMENTS' mobile/ios/Runner.xcodeproj/project.pbxproj` returns nothing — no capabilities declared. Both dependent features are genuinely wired: native Sign in with Apple at mobile/lib/src/auth/auth_controller.dart:31-51 (SignInWithApple.getAppleIDCredential with nonce), button shown when _appleAvailable at mobile/lib/src/auth/sign_in_screen.dart:325-332; OneSignal push init at mobile/lib/main.dart:78. Without com.apple.developer.applesignin and aps-environment entitlements a signed build cannot exercise these — Apple sign-in errors and push never registers; if capabilities are present in the provisioning profile, archive/upload validation fails. HIGH is appropriate (Apple review Guideline 2.1 / 5.1.1(iv)). Final runtime confirmation needs a signed TestFlight build (device/live infra), so keep regardless.

---

#### [APPL-02] Store metadata and review notes point at the dead pawdoc.app domain while the live portal is a CloudFront URL

**Severity:** HIGH · **Category:** store-apple · **Perspectives:** Apple App Store Reviewer · **Effort:** M 0.5-1d · **Blocks launch:** YES · **Blocks store:** apple · **Confidence:** 0.72

**Evidence:** The submitted App Review notes and public contact links use pawdoc.app: `Support: support@pawdoc.app · Privacy: https://pawdoc.app/privacy · Terms: https://pawdoc.app/terms` (docs/store_metadata/ios_app_store.md:127). But the actual shipped app links all legal pages to the CloudFront host, not pawdoc.app: `defaultValue: 'https://d1klm6zb1x23me.cloudfront.net'` (mobile/lib/src/config/legal_urls.dart:19), with a comment explicitly noting the base is a placeholder "so the founder can switch to the final custom domain" (legal_urls.dart:9-13). Project memory (Launch Audit 2026-06-12) records pawdoc.app as dead.
**Root cause:** The custom domain pawdoc.app was never provisioned/pointed at the legal portal; the app was switched to the CloudFront distribution as a stopgap, but the store metadata and support email were not updated to match.
**User impact:** A user (or reviewer) tapping the App Store listing's Support URL or Privacy Policy URL, or emailing support@pawdoc.app, hits a dead domain / bouncing mailbox.
**Business impact:** No working support channel at launch; erodes trust and blocks support-driven retention.
**Store impact:** Guideline 1.5 (Developer Information — Support URL must be functional) and 5.1.1 (Privacy — a resolvable, accurate Privacy Policy URL is mandatory in App Store Connect). A non-resolving Support or Privacy URL is a routine rejection.
**Solution:** Pick one canonical, live base URL. Either (a) provision pawdoc.app, deploy the portal there, set a working support@pawdoc.app mailbox, and set `--dart-define=LEGAL_BASE_URL=https://pawdoc.app`; OR (b) use the live CloudFront URL everywhere — App Store Connect Support URL, Privacy Policy URL, Marketing URL, and the review notes in ios_app_store.md:127 — and use a real reachable support email. Confirm every URL returns HTTP 200 and the mailbox receives mail before submitting.
**Acceptance criteria:** App Store Connect Support URL + Privacy Policy URL resolve to live pages; the support email delivers; the app's `LegalUrls.base` and the store metadata reference the identical live host.

**Verification:** CONFIRMED — Reproduced both cited facts verbatim. docs/store_metadata/ios_app_store.md:127 lists `Support: support@pawdoc.app · Privacy: https://pawdoc.app/privacy · Terms: https://pawdoc.app/terms` as concrete (non-placeholder) values. mobile/lib/src/config/legal_urls.dart:17-20 defaults `LegalUrls.base` to `https://d1klm6zb1x23me.cloudfront.net`, with comment (lines 8-13) confirming pawdoc.app was never provisioned and CloudFront is the stopgap. Project memory records pawdoc.app as dead. The two hosts genuinely diverge, so store Support/Privacy URLs and support email point at a non-resolving domain — Apple 1.5 / 5.1.1 rejection risk. Tempering context (not refuting): the listing's public release is hard-gated per ios_app_store.md:129-130 and the doc still contains founder-fill placeholders (e.g. [REVIEWER_DEMO_EMAIL] line 122), so this is a pre-submission metadata artifact requiring founder finalization, not something already shipped. Fix is trivial: pick one canonical live host across LegalUrls.base and the store metadata + a reachable support mailbox.

---

#### [APPL-03] Reviewer demo account is a placeholder against an auth-gated app; IAP falls back to 'coming soon' if offerings aren't live at review

**Severity:** MEDIUM · **Category:** store-apple · **Perspectives:** Apple App Store Reviewer · **Effort:** M 0.5-1d · **Blocks launch:** YES · **Blocks store:** apple · **Confidence:** 0.7

**Evidence:** The App Review notes still carry unfilled credentials: `Demo account: [REVIEWER_DEMO_EMAIL] / [REVIEWER_DEMO_PASSWORD] (founder to fill)` (docs/store_metadata/ios_app_store.md:122). The client has no anonymous/guest entry path (`grep -rn 'anonymous\|guest' mobile/lib` in the app UI returns nothing), and sign-in is via email/Apple only (mobile/lib/src/auth/auth_controller.dart). Separately, the paywall renders a non-purchasable `_PremiumComingSoon` state whenever RevenueCat offerings are unset: `else if (_offering == null) const _PremiumComingSoon()` (mobile/lib/src/monetization/paywall_screen.dart:187-188), and offerings load silently no-op on failure (paywall_screen.dart:52-58).
**Root cause:** Demo credentials are a founder submission task not yet completed, and the paywall degrades to 'coming soon' when RevenueCat offerings/products aren't approved and live in the reviewed environment.
**User impact:** None directly for end users; this is a review-time gating issue.
**Business impact:** A failed review round costs 24-48h+ per cycle and delays launch.
**Store impact:** Guideline 2.1 — App Review must be able to (a) sign in (a working demo account is required for an account-gated app) and (b) exercise any In-App Purchase attached to the version. If the reviewer sees only "Premium is coming soon," the submitted auto-renewable subscription cannot be reviewed and the IAP is rejected.
**Solution:** Create a persistent reviewer account (with a few checks pre-seeded), fill the real email/password into ios_app_store.md:122 and the App Store Connect App Review Information fields. Ensure the auto-renewable subscription products are in "Ready to Submit," attached to the version, and that the RevenueCat offering is configured and returns products for the reviewed build (so `_offering != null` and real plans + the 3.1.2 legal block render). Confirm in the reviewed build that the paywall shows purchasable plans, not the coming-soon state.
**Acceptance criteria:** Demo credentials are real and log in; the paywall shows live plans with prices and the auto-renew disclosure; IAP products are attached and in a reviewable state.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [APPL-04] ITSAppUsesNonExemptEncryption missing from Info.plist — blocks automated TestFlight/submission processing

**Severity:** MEDIUM · **Category:** store-apple · **Perspectives:** Apple App Store Reviewer · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.85

**Evidence:** mobile/ios/Runner/Info.plist (full file read, lines 1-76) contains no `ITSAppUsesNonExemptEncryption` key. The app only uses standard HTTPS/TLS (exempt encryption) — no custom/proprietary crypto in the codebase — so the correct declared value is `false`.
**Root cause:** The export-compliance declaration key was never added to Info.plist.
**User impact:** None.
**Business impact:** Every build upload stalls awaiting a manual export-compliance answer in App Store Connect, and CI/fastlane `upload_to_testflight` can't auto-advance builds to testers, slowing every release.
**Store impact:** Export-compliance is a submission gate (App Store Connect requires the answer before a build is submittable). Not a content rejection, but it halts processing until answered.
**Solution:** Add to mobile/ios/Runner/Info.plist: `<key>ITSAppUsesNonExemptEncryption</key><false/>`. If any non-exempt encryption is ever added, switch to `true` and attach the required documentation instead.
**Acceptance criteria:** Info.plist declares `ITSAppUsesNonExemptEncryption = false`; a fresh upload processes to TestFlight without prompting for export compliance.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Google Play Readiness

_Area readiness (finder self-assessment): 62% — Google Play readiness is mixed. Store-listing copy is policy-clean (medical disclaimer present, no "diagnose/treat/cure" claims, emergency-never-paywalled stated), targetSdk resolves to 36 (Flutter 3.41.9 default, exceeds Play's API-35 floor), permission diet is mostly disciplined (RECORD_AUDIO/READ_MEDIA/storage stripped via tools:node="remove"), in-app account deletion is real (delete-account Edge Function) and the subscription paywall carries proper auto-renew/cancellation disclosure with functional Terms/Privacy links. The launch-blocking problem is that the release build is still signed with the debug keystore, which Play rejects outright. Secondary policy risks: the Data Safety mapping documented in-repo is materially incomplete versus the SDKs actually bundled (location, purchase history, device analytics, third-party AI sharing), FINE location is over-declared for a feature that only uses medium accuracy, and the web deletion path routes to a mailbox on an unprovisioned domain._

#### [PLAY-01] Release AAB is signed with the debug keystore — Play will reject the upload

**Severity:** CRITICAL · **Category:** store-google · **Perspectives:** Google Play Reviewer, Release Engineering · **Effort:** M 0.5-1d · **Blocks launch:** YES · **Blocks store:** google · **Confidence:** 0.97

**Evidence:** `mobile/android/app/build.gradle.kts:35-38` — the `release` buildType sets `signingConfig = signingConfigs.getByName("debug")` with the TODO comment "Signing with the debug keys for now". No `key.properties`, `storeFile`, or upload-key signing config exists anywhere (`mobile/android/.gitignore:12` reserves `key.properties`, but no real config is wired in `build.gradle.kts`). CI (`.github/workflows/ci.yml`) injects no keystore either.
**Root cause:** The Flutter template's placeholder debug-signing was never replaced with an upload/release signing config before treating this branch as the launch candidate.
**User impact:** None directly, but the app cannot be distributed — no build reaches users.
**Business impact:** Hard launch blocker: a `flutter build appbundle --release` produced by this tree is signed with the Android debug certificate, which Google Play rejects at upload ("You uploaded an APK or Android App Bundle that was signed in debug mode"). Even if accepted, debug-signed artifacts are non-shippable and cannot be enrolled in Play App Signing.
**Store impact:** Google Play upload is refused; no track (internal/closed/production) can accept the artifact. Apple unaffected (separate signing).
**Solution:** Create a release upload keystore (`keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`), store its path/passwords in `android/key.properties` (git-ignored) or CI secrets, load them in `build.gradle.kts` via a `Properties` read, define a `signingConfigs.create("release") { storeFile/keyAlias/storePassword/keyPassword }`, and set `release { signingConfig = signingConfigs.getByName("release") }`. Enroll in Play App Signing so Google manages the app signing key. Remove the debug fallback.
**Acceptance criteria:** `flutter build appbundle --release` produces an `.aab` whose signer certificate is NOT the Android debug cert (verify with `jarsigner -verify -verbose -certs` / `apksigner verify --print-certs`); the bundle uploads successfully to a Play internal-testing track; Play App Signing enrollment completes.

**Verification:** CONFIRMED — Reproduced in current tree. mobile/android/app/build.gradle.kts:34-38 — release buildType sets ONLY `signingConfig = signingConfigs.getByName("debug")` (line 37) with TODO "Signing with the debug keys for now" (line 36). grep over mobile/android/ finds no storeFile/keyAlias/create("release") — debug config is the sole signer. mobile/android/.gitignore:12 reserves key.properties (13-14 reserve *.keystore/*.jks) but no such file exists and nothing loads it. .github/workflows/ci.yml:102 runs `flutter build appbundle` (release, default) with no keystore injection, so the CI-built AAB is debug-signed. Google Play rejects debug-signed bundles at upload and they cannot enroll in Play App Signing — hard launch blocker. Finding cited lines 35-38; actual release block is 34-38 (signingConfig on 37): trivial offset, evidence exact.

---

#### [PLAY-02] Data Safety mapping is materially incomplete vs the SDKs the app actually bundles

**Severity:** HIGH · **Category:** store-google · **Perspectives:** Google Play Reviewer, Privacy · **Effort:** M 0.5-1d · **Blocks launch:** YES · **Blocks store:** google · **Confidence:** 0.82

**Evidence:** The only in-repo Data Safety guidance, `docs/store_metadata/google_play.md` ("Data safety form" note), tells the founder to declare only "account email, pet profile, uploaded photos" + encryption-in-transit + deletion. But the app bundles data-collecting/sharing SDKs not covered by that mapping: `posthog_flutter` (`mobile/pubspec.yaml:56` — product analytics + device/user identifiers), `sentry_flutter` (`:48` — crash logs, device data), `onesignal_flutter` (`:67` — push token/device ID), `purchases_flutter` (`:65` — RevenueCat purchase history), `geolocator` (`:64` — precise/approximate location, used in `mobile/lib/src/vet_finder/vet_finder_screen.dart:56`). Uploaded pet photos/videos are additionally SHARED with third-party AI subprocessors (Gemini/Claude via the analyze pipeline) — not disclosed as data sharing.
**Root cause:** The Data Safety note was written early against a partial data inventory and never reconciled against the full SDK/subprocessor set now in the tree.
**User impact:** Users see an inaccurate Data Safety card and cannot make an informed choice about location, analytics, purchase, and photo-sharing data.
**Business impact:** Data Safety mismatches are a top Play enforcement trigger — Google compares declared data types against detected SDK behavior and can reject, warn, or remove the listing. Undisclosed "Location", "Purchase history", "Device or other IDs", "Crash logs / analytics", and third-party data "sharing" are exactly the categories automated scanning flags.
**Store impact:** Google Play — post-review enforcement / takedown risk; blocks a clean production approval.
**Solution:** Build a data-flow matrix from the code: declare Collected = {email (auth), pet profile, photos/videos, approximate+precise location, purchase history, app interactions/analytics, crash logs, device IDs, push token}; mark Shared = photos/videos + inputs sent to AI providers (Gemini/Claude) and RevenueCat/PostHog/Sentry/OneSignal per their processor roles; state encryption-in-transit, and "users can request deletion". Update `docs/store_metadata/google_play.md` to match, then fill the Play Console Data Safety form identically. Confirm EXIF/GPS stripping claim still holds so "precise location" is not implicitly collected via image metadata.
**Acceptance criteria:** Every collecting/sharing SDK in `mobile/pubspec.yaml` maps to a declared Data Safety data type; the Play Console form declares Location, Purchase history, Device IDs, Crash logs, and Photos/Videos with correct collected/shared/encryption flags; internal review passes Google's Data Safety consistency check without warnings.

**Verification:** CONFIRMED — Reproduced in current tree. The only in-repo Data Safety guidance is docs/store_metadata/google_play.md lines 92-94, which tells the founder to declare ONLY "account email, pet profile, uploaded photos" + encryption-in-transit + deletion + EXIF/GPS stripping. Yet mobile/pubspec.yaml bundles data-collecting/sharing SDKs the note omits: sentry_flutter (:48, crash logs/device data), posthog_flutter (:56, analytics/device+user IDs), geolocator (:64, location), purchases_flutter (:65, RevenueCat purchase history), onesignal_flutter (:67, push token/device ID). Location collection is real, not theoretical: mobile/lib/src/vet_finder/vet_finder_screen.dart:56 calls Geolocator.getCurrentPosition (LocationAccuracy.medium) and passes lat/lng to the vet-finder service. Uploaded photos are additionally sent to third-party AI subprocessors (Gemini/Claude) via the analyze pipeline = undisclosed data "sharing". The only other doc mentioning the form (docs/runbooks/19-beta-and-launch.md:102) merely says to fill it, giving no mapping — so nothing supersedes the incomplete note. Undisclosed Location, Purchase history, Device IDs, Crash logs/Analytics, and third-party sharing are exactly the categories Google's automated SDK scanning flags as consistency-check violations, a top post-review enforcement/takedown trigger. This is a store-metadata/compliance gap (not a code defect), but it is launch-gating for a clean Play production approval, so HIGH stands.

---

#### [PLAY-03] ACCESS_FINE_LOCATION is over-declared — app only uses medium (coarse-grade) accuracy

**Severity:** MEDIUM · **Category:** store-google · **Perspectives:** Google Play Reviewer, Privacy · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.8

**Evidence:** `mobile/android/app/src/main/AndroidManifest.xml` declares BOTH `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION` (GAP-E2 comment: nearby-clinic finder). But the only location call, `mobile/lib/src/vet_finder/vet_finder_screen.dart:56-57`, requests `Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium))` — medium maps to ~coarse precision and never needs FINE. No feature consumes precise GPS.
**Root cause:** The geolocator plugin's default FINE permission was left declared even though the code was tuned down to medium accuracy for the peripheral vet-finder feature.
**User impact:** Users are asked to grant precise location (and see a "precise location" runtime prompt) for a feature that functionally needs only approximate location.
**Business impact:** Play's Location Permissions policy requires the minimum scope necessary and treats foreground FINE location as elevated; for a Medical-category app requesting precise location for a non-core feature, reviewers may require a Location declaration/justification and can flag it as overreach, delaying approval.
**Store impact:** Google Play — added review friction / possible declaration requirement; Apple unaffected.
**Solution:** Remove the `ACCESS_FINE_LOCATION` line from the main manifest (add `tools:node="remove"` if the geolocator plugin merges it back), keep only `ACCESS_COARSE_LOCATION`, and keep `LocationAccuracy.medium`. Re-verify the merged manifest (`./gradlew :app:processReleaseManifest` output) contains coarse only. If precise is ever genuinely needed later, add a Play Console Location declaration.
**Acceptance criteria:** Final merged release manifest contains `ACCESS_COARSE_LOCATION` but NOT `ACCESS_FINE_LOCATION`; vet-finder still resolves nearby clinics on-device; runtime prompt requests approximate location only.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [PLAY-04] Web account-deletion path (Play data-deletion URL) routes to an unprovisioned pawdoc.app mailbox

**Severity:** MEDIUM · **Category:** store-google · **Perspectives:** Google Play Reviewer, Infrastructure · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** google · **Confidence:** 0.7

**Evidence:** The public deletion page `web-legal/content/deletion.md` (served as `/deletion` on the CloudFront portal) instructs off-app users to email `privacy@pawdoc.app` for verified web deletion (§2). But the app's own `mobile/lib/src/config/legal_urls.dart:17` still defaults `LegalUrls.base` to the raw `https://d1klm6zb1x23me.cloudfront.net` — i.e. the `pawdoc.app` custom domain is not yet the canonical host, and project memory records `pawdoc.app` as dead/unprovisioned. If the `pawdoc.app` MX/mailbox is not live, the `privacy@pawdoc.app` deletion channel silently fails. The page footer §7 also still contains `[LEGAL ENTITY], [BUSINESS ADDRESS]` placeholders.
**Root cause:** Legal portal published on a temporary CloudFront hostname before the production domain and its email were provisioned.
**User impact:** A user who uninstalled the app and tries the documented web-deletion route may email a non-existent mailbox and never get their data deleted.
**Business impact:** Play's User Data / account-deletion policy requires the Data-deletion URL in the Play Console to lead to a WORKING deletion request mechanism (including without reinstalling). A dead deletion email breaks that requirement and is an enforcement/removal risk; unfilled legal-entity placeholders also undercut the page's credibility on review.
**Store impact:** Google Play — account-deletion policy compliance risk on the Data-deletion URL field.
**Solution:** Provision `pawdoc.app` (or commit to the CloudFront host) and stand up a monitored `privacy@` mailbox that actually receives mail; verify end-to-end by sending a test deletion request and confirming receipt. Fill the `[LEGAL ENTITY]`/`[BUSINESS ADDRESS]` placeholders. Enter the live deletion page URL in the Play Console "Data deletion" field and confirm the in-app path (Account → Delete account → `delete-account` Edge Function) is also cited.
**Acceptance criteria:** A test email to the published deletion address is received and answerable; the deletion page has no bracketed placeholders; the Play Console Data-deletion URL resolves to that page over HTTPS; in-app deletion still succeeds via the Edge Function.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Monetization & RevenueCat

_Area readiness (finder self-assessment): 73% — The safety-critical rule holds: EMERGENCY is provably never paywalled or quota-blocked, both server-side and client-side. Traced the 0-remaining-quota + emergency case end-to-end: text emergencies set isEmergencyText→quotaExceeded=false so blockBeforeAi/blockAfterAi/countsAgainstQuota all pass the result through free and uncounted (analyze/index.ts:125-138,310-319,345-358); visual emergencies deliberately run the AI before any block and are released when triage==EMERGENCY (quota_gate.mjs:14-25); the client only ever hits the 402 path the server returns, and paywall_policy.dart:28 blocks the paywall on any emergency. Webhook auth (constant-time secret) and add-on idempotency (processed_rc_events PK claim + release-on-failure) are sound, and the referral bonus is capped at 30 by a DB trigger. Weaknesses are in the paid-user integration UX, not safety: Restore Purchases is a silent no-op, premium recognition is entirely webhook-dependent with no SDK-entitlement fallback, and the client quota counter ignores bonus credits and the monthly reset the server honors._

#### [SUB-01] Restore Purchases is a silent no-op — no feedback, no navigation, no entitlement refresh

**Severity:** HIGH · **Category:** monetization · **Perspectives:** RevenueCat Reviewer, Monetization Engineer · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.85

**Evidence:** `mobile/lib/src/monetization/paywall_screen.dart:196-203` — the Restore button does `await Purchases.restorePurchases();` inside `try { } catch (_) {}` with an empty body: no success/failure UI, no `Navigator.pop`, no `ref.invalidate(userProfileProvider)`, no inspection of the returned `CustomerInfo.entitlements`. Contrast the purchase path (`:70-86`) which checks `entitlements.active.isNotEmpty`, shows a celebration, and pops `true`.
**Root cause:** The handler fires the RevenueCat call for its side effect only and discards the result; there is no follow-up to reflect a restored entitlement in the UI or refresh the app's premium state (which is read from `userProfileProvider`/DB, `user_profile.dart:20`).
**User impact:** A returning subscriber (reinstall / new device) taps Restore, and on success nothing visibly happens — the paywall stays on-screen still showing purchasable plans. The user cannot tell restore worked, and may re-purchase or leave a 1-star "restore is broken" review. On failure they get no message either.
**Business impact:** Double-charges, refund requests, and churn from paying users who cannot recover access; directly erodes LTV of the exact cohort that already converted.
**Store impact:** Apple guideline 3.1.1 / 2.1 reviewers routinely tap "Restore Purchases" and expect a visible outcome (restored, or "nothing to restore"). A button that produces no observable result is a common concrete rejection reason — plausible App Review block, not certain.
**Solution:** In `_purchase`-style flow: `setState` a busy flag; capture `final info = await Purchases.restorePurchases();` then `if (info.entitlements.active.isNotEmpty) { ref.invalidate(userProfileProvider); await Analytics.subscriptionConverted(); if (mounted) { ScaffoldMessenger.show('Purchases restored'); Navigator.of(context).pop(true); } } else { ScaffoldMessenger.show('No purchases found to restore'); }`. In `catch (e)` show a SnackBar with the error (mirror line 88-90). Remove the empty catch.
**Acceptance criteria:** Tapping Restore with an active subscription dismisses the paywall and the app shows premium state; with none, a "No purchases found" message appears; on error, a visible error message appears; a widget test drives all three branches.

**Verification:** CONFIRMED — Reproduced in current tree at mobile/lib/src/monetization/paywall_screen.dart:196-203. Restore button: onPressed does `try { await Purchases.restorePurchases(); } catch (_) {}` — empty catch, return value discarded. No entitlement inspection, no Navigator.pop, no ref.invalidate(userProfileProvider), no SnackBar, no busy/setState. Contrast _purchase (lines 61-95): checks result.customerInfo.entitlements.active.isNotEmpty (70), celebration + pop(true) (76-83), error SnackBar (88-90). So the purchase path gives all three (success UI / navigation / error), restore gives none — a true silent no-op on success, failure, and the empty-restore case. Real store-review and returning-subscriber UX risk. Caveat: restore is only reachable once RevenueCat offerings are configured (founder-gated), and premium state is DB-backed via the revenuecat-webhook, so a client-side ref.invalidate alone may not immediately reflect the restore until the webhook fires — the fix should account for that. Core defect confirmed; HIGH justified by App Review being a launch gate.

---

#### [SUB-02] Premium recognition is 100% webhook-dependent — no client entitlement fallback, so a paid user is blocked until the webhook lands (or forever if misconfigured)

**Severity:** MEDIUM · **Category:** monetization · **Perspectives:** RevenueCat Reviewer, Monetization Engineer · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.75

**Evidence:** The app's `isPremium` is derived only from `users.subscription_status` in the DB (`mobile/lib/src/account/user_profile.dart:18-20,33-37`). The ONLY code that flips `subscription_status` to a paid tier is the webhook (`supabase/functions/revenuecat-webhook/index.ts:117-120`). The client configures RevenueCat and calls `Purchases.logIn(uid)` (`mobile/lib/main.dart:84-90`) but never reads `CustomerInfo.entitlements` to seed/refresh premium state; there is no `addCustomerInfoUpdateListener`. Server-side `/analyze` also gates on the same DB column (`supabase/functions/analyze/index.ts:113-117`).
**Root cause:** Single source of truth (DB) is written by exactly one asynchronous, founder-configured path (the webhook, guarded by `REVENUECAT_WEBHOOK_SECRET`, `:20-24`). No secondary reconciliation from the RevenueCat SDK's own entitlement state.
**User impact:** Immediately after a successful purchase the SDK reports the user as entitled, but `subscription_status` is still `free` until the webhook is delivered/processed AND `userProfileProvider` refetches (`home_screen.dart:61/74/87`). During that window the user is re-shown the paywall and blocked at the 3/month quota. If the webhook secret is unset or the endpoint misconfigured, the paid user is treated as free everywhere, indefinitely.
**Business impact:** Paid-but-blocked users → refunds, chargebacks, and "I paid and it still locks me out" reviews; the failure is invisible in dev because it only manifests when the webhook is degraded in prod.
**Store impact:** None directly, but repeated "paid, still locked" reports raise Apple/Google review-and-refund friction.
**Solution:** Add a client reconciliation: register `Purchases.addCustomerInfoUpdateListener` (and check `getCustomerInfo()` on launch/after purchase); when `entitlements.active.isNotEmpty` but `userProfileProvider` still shows free, `ref.invalidate(userProfileProvider)` and treat the SDK entitlement as an optimistic premium override for gating until the DB catches up. Add a founder-side runbook check that `REVENUECAT_WEBHOOK_SECRET` is set and the webhook URL is registered in RevenueCat before launch.
**Acceptance criteria:** After a purchase, home no longer shows the paywall/quota strip even before the webhook lands; a delayed/failed webhook does not leave an entitled RevenueCat user gated in-app; runbook item verifies webhook config.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [SUB-03] UI "free checks left" ignores referral bonus credits and the monthly reset the server honors

**Severity:** MEDIUM · **Category:** monetization · **Perspectives:** Monetization Engineer · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.8

**Evidence:** `mobile/lib/src/account/user_profile.dart:21` computes `freeRemaining => (3 - freeUsedThisMonth).clamp(0,3)` and the query at `:33-37` selects only `subscription_status, free_analyses_used_this_month, pdf_reports_remaining` — it never fetches `bonus_analyses` or `free_analyses_reset_at`. The server, however, spends bonus credits after the monthly allowance (`supabase/functions/_shared/free_tier.mjs:45-52`) and does a check-on-read monthly reset (`:38-43`). The value is shown to users as "$freeRemaining of 3 free checks left" (`home_screen.dart:521`).
**Root cause:** Client quota display is a naive `3 - used` and is unaware of the two other inputs (bonus pool, reset date) that the authoritative server-side `evaluateFreeTier` uses.
**User impact:** A user who earned +3 referral credits (or whose monthly reset date has passed) sees "0 of 3 free checks left" while the server will still run their check for free. The mismatch makes the app look like it's withholding earned rewards and can nudge an unnecessary upgrade.
**Business impact:** Undermines the referral reward's perceived value (referral loop is the growth mechanism) and erodes trust in the quota counter.
**Store impact:** None.
**Solution:** Add `bonus_analyses` and `free_analyses_reset_at` to the select; compute remaining as `monthlyLeft = reset_at passed ? 3 : (3 - used).clamp(0,3)` plus `+ bonus_analyses`, and label bonus credits distinctly (e.g. "2 free + 3 bonus checks"). Reuse the same reset/bonus semantics as `evaluateFreeTier` so client and server agree.
**Acceptance criteria:** A user with bonus credits sees them reflected in the home chip; after the reset date passes the chip shows a full allowance without waiting for a server call; a widget/unit test covers used>=3 with bonus>0 and reset-passed.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [SUB-04] Free-tier counter uses a read-modify-write with no locking — concurrent requests can lose an increment (extra free analyses)

**Severity:** LOW · **Category:** monetization · **Perspectives:** Monetization Engineer · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.7

**Evidence:** `supabase/functions/analyze/index.ts:113-131` reads `free_analyses_used_this_month`/`bonus_analyses` into `profile`/`decision`, then at `:354-358` writes back the pre-computed `decision.newUsed`/`decision.newBonus` with a plain `update(...).eq('id', user.id)`. There is no atomic increment, row lock, or conditional (compare-and-set) write.
**Root cause:** The counter is incremented via application-level read-modify-write rather than an atomic DB operation (e.g. `used = used + 1` in SQL / an RPC).
**User impact:** Two overlapping analyses from the same user both read the same snapshot and both write `used+1`, so one increment is lost and the user gets a free check beyond the intended 3/month.
**Business impact:** Minor revenue leak; not a safety issue. Requires concurrent same-user requests, which the sequential UI makes uncommon.
**Store impact:** None.
**Solution:** Replace the write with an atomic RPC, e.g. a `SECURITY DEFINER` `increment_free_usage(uid, new_reset_at)` doing `update users set free_analyses_used_this_month = free_analyses_used_this_month + 1 ...` (and a symmetric bonus decrement guarded by `bonus_analyses > 0`), or use a conditional update on the observed value and retry on miss.
**Acceptance criteria:** A test firing N concurrent authenticated analyses for one at-limit user consumes at most the correct number of credits; no double-spend of the same bonus credit.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [SUB-05] Paywall purchase uses deprecated purchasePackage API

**Severity:** LOW · **Category:** monetization · **Perspectives:** Monetization Engineer · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.85

**Evidence:** `mobile/lib/src/monetization/paywall_screen.dart:68-69` — `// ignore: deprecated_member_use` immediately precedes `await Purchases.purchasePackage(pkg)`.
**Root cause:** The purchases_flutter SDK deprecated `purchasePackage` in favor of `purchase(PurchaseParams...)`; the call is suppressed rather than migrated.
**User impact:** None today; functional risk is that a future SDK major removes the method, breaking purchases on upgrade.
**Business impact:** Tech debt; a silent break of the sole conversion path if the SDK is bumped without re-testing.
**Store impact:** None.
**Solution:** Migrate to the current `Purchases.purchase(PurchaseParams.package(pkg))` API per the installed purchases_flutter version and remove the ignore; re-run the purchase widget test.
**Acceptance criteria:** No `deprecated_member_use` ignore remains in the purchase flow; `flutter analyze` is clean; purchase flow test still passes.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Performance

_Area readiness (finder self-assessment): 68% — Performance fundamentals are mostly sound: the boot path (main.dart) is guarded and lazy, image compression is correctly offloaded to a background isolate via compute() (camera_screen.dart:85), the two message-rotation timers are cancelled on dispose, there is only one AnimationController and the Rive StateMachineController is disposed properly (living_pet_avatar.dart:193), and the /analyze flow is a single request with sensible timeouts (no polling). The real weaknesses are all asset/memory hygiene: 36MB of grossly oversized PNGs (1254x1254 icons rendered at 22-48px; 1024x1536 illustrations rendered at ~96-150px) shipped without any cacheWidth/cacheHeight so they decode at full resolution into the image cache; 7.4MB of dead, unreferenced action-icon PNGs still bundled by a pubspec glob; and google_fonts left in runtime-fetch mode so the two brand fonts are downloaded from Google over the network on first launch. None are safety-critical or hard store blockers, but they inflate the 49.5MB release AAB, hurt cold start and first-run offline typography, and cause decode jank / memory pressure on low-end Android._

#### [PERF-01] Full-resolution image assets decoded without cacheWidth/cacheHeight — memory blowup and decode jank on low-end devices

**Severity:** MEDIUM · **Category:** performance · **Perspectives:** performance, device, ui-ux · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.92

**Evidence:** `mobile/lib/src/core/app_image.dart:32-41` — the single `AppImage` widget every asset image routes through calls `Image.asset(asset, width:, height:, fit:)` with **no `cacheWidth`/`cacheHeight`**. The source PNGs are enormous relative to display size: `assets/icons/actions/action_camera.png` and `action_share.png` are 1254x1254 (`file` output), `assets/illustrations/results/analysis_companion_v1.png` is 1024x1536, yet call sites render them tiny — `species_chip.dart:31-34` renders a species icon at 22x22, `sign_in_screen.dart:427-429` at height 44, illustrations at height 96–150 (`result_screen.dart:228-230`, `onboarding_flow.dart:278-280`, `family_settings_screen.dart:255-257`). A 1254x1254 RGBA image decodes to ~6.3 MB in the image cache regardless of the 22px it is painted at; a 1024x1536 illustration ~6.3 MB each.
**Root cause:** `Image.asset` decodes at the asset's intrinsic pixel dimensions, not the layout size, unless `cacheWidth`/`cacheHeight` are supplied. `AppImage` never forwards them, so every icon/illustration is decoded and held at full resolution.
**User impact:** On low-/mid-tier Android (the device-validation target was a Redmi Note 11R) screens that show several illustrations/icons (onboarding, home, paywall, result) spike memory tens of MB and can drop frames during the first paint / GPU texture upload; the 100MB default `ImageCache` evicts and re-decodes, producing repeated scroll/transition jank and, at worst, low-memory image failures that trigger the `errorBuilder` fallback.
**Business impact:** Jank and heavy memory on cheap Android hurt retention and ratings in exactly the price-sensitive segment that installs a new pet app; sluggishness on a safety-triage screen erodes trust.
**Store impact:** Not a store rejection, but Android vitals (frozen frames / ANR-adjacent jank) feed Play ranking.
**Solution:** In `AppImage.build`, compute target cache dimensions from the layout size and device pixel ratio and pass them to `Image.asset`: `final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3.0; cacheWidth: width != null ? (width! * dpr).round() : null; cacheHeight: (width == null && height != null) ? (height! * dpr).round() : null;` (only set one dimension so aspect ratio is preserved). This alone caps decode to the painted size. Additionally regenerate the source assets to sane maximum dimensions (icons ≤ 96px, illustrations ≤ ~600px wide) so the on-disk and decoded sizes both drop.
**Acceptance criteria:** `Image.asset` in `AppImage` receives non-null `cacheWidth`/`cacheHeight`; a devtools memory snapshot of the onboarding/paywall screens shows per-image decoded size proportional to display size (KB, not MB); no visual regression on 1x/2x/3x devices.

**Verification:** PARTIAL — Reproduced in current tree. mobile/lib/src/core/app_image.dart:32-41 — sole AppImage widget calls Image.asset(asset, width:, height:, fit:, semanticLabel:, excludeFromSemantics:, errorBuilder:) with NO cacheWidth/cacheHeight. Repo-wide `grep cacheWidth|cacheHeight lib/` = 0 hits. Assets confirmed oversized via file/identify: assets/icons/actions/action_camera.png & action_share.png = 1254x1254 RGBA; every illustration under assets/illustrations is 1024x1024 or 1024x1536 (e.g. analysis_companion_v1.png 1024x1536). 15 AppImage call sites; small render targets (e.g. species chip 22x22, sign-in logo h44, result/onboarding illustrations h96-150) confirm intrinsic decode dwarfs painted size (~6.3MB decoded per full-res image). Mechanism and fix (forward cacheWidth/cacheHeight from layout size * DPR, plus downscale source PNGs) are technically sound. Severity lowered HIGH->MEDIUM: genuine memory/decode-jank optimization but non-safety (not the emergency path), no crash, and the retention/ratings/low-memory-failure impact chain is speculative — the finder itself notes it is not a store rejection.

---

#### [PERF-02] 7.4MB of unused action-icon PNGs and grossly oversized art bloat the 49.5MB release AAB

**Severity:** MEDIUM · **Category:** performance · **Perspectives:** performance, engineering · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.95

**Evidence:** `runtime/build_aab.log:9` — `app-release.aab (49.5MB)`. `mobile/assets` totals 38MB: illustrations 26MB, icons 9.8MB. `mobile/pubspec.yaml` bundles `assets/icons/actions/` via glob, and that directory alone is 7.4MB (`action_camera.png` 1.0MB, `action_share.png` 924K, `action_describe.png` 964K, etc.), but `grep -rn 'action_\|icons/actions'` over `mobile/lib/` returns **zero references** — no code loads any action icon (`AppAssets` maps only species/status/avatars). Individual shipped illustrations are 1–1.6MB PNGs (e.g. `illustrations/onboarding/welcome_duo_moon_v1.png` 1.6M) at 1024x1536 for ≤150px display.
**Root cause:** A directory-level asset glob (`assets/icons/actions/`) pulls in an entire unused icon set, and art was exported at generation resolution (1024–1536px, PNG) with no downscale or WebP conversion before bundling.
**User impact:** Larger download/install and more device storage; slower first install over mobile data (Play data-saver friction). ~7.4MB is pure dead weight; another ~20MB+ is recoverable by resizing/WebP.
**Business impact:** Bigger downloads measurably reduce install conversion, worst on the cheap-Android / poor-network users this app targets.
**Store impact:** Under Play's 200MB base limit, so not a rejection, but download size is surfaced on the store listing and affects conversion.
**Solution:** Remove the `- assets/icons/actions/` line from `pubspec.yaml` (delete the dir) since nothing references it — verify with `grep -rn 'actions/' mobile/lib` first. Convert all illustration/icon PNGs to WebP and downscale to display-appropriate max dimensions (icons ≤128px, illustrations ≤600px wide) — e.g. `cwebp -q 82 -resize 600 0 in.png -o out.webp`; update `AppAssets` extensions accordingly. Confirm the empty `assets/icons/avatars/` (4K) is intentional or drop its glob too.
**Acceptance criteria:** `assets/icons/actions/` no longer in the bundle; `mobile/assets` under ~10MB; rebuilt AAB materially smaller (target < ~30MB); every screen still renders (no fallback boxes) in a device smoke test.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [PERF-03] Brand fonts fetched from Google over the network at runtime — cold-start FOUT and broken typography offline on first launch

**Severity:** MEDIUM · **Category:** performance · **Perspectives:** performance, privacy, ui-ux · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.9

**Evidence:** `mobile/lib/src/theme/design_tokens.dart:94-108` builds the entire `TextTheme` from `GoogleFonts.bricolageGrotesque(...)` and `GoogleFonts.inter(...)`. `assets/fonts/` contains only a 0-byte `.gitkeep` (no bundled `.ttf`), no `fonts:` block is declared in `pubspec.yaml`, and `grep -rn 'allowRuntimeFetching'` over `mobile/lib` returns nothing — so `google_fonts` is in its default **runtime-fetch** mode, downloading Inter and Bricolage Grotesque from `fonts.gstatic.com` on first launch. The design-token comment itself notes the offline path is not wired: 'To make them fully offline-deterministic, drop the .ttf files into assets/fonts/ ... and set GoogleFonts.config.allowRuntimeFetching = false'.
**Root cause:** Fonts are loaded via the network-fetching `google_fonts` API instead of being bundled as assets, and runtime fetching was never disabled.
**User impact:** On first launch (and until the font cache is warm) text renders in the system fallback and then visibly swaps once the download completes (FOUT) — extra network + a startup hitch. A user who opens the app for the first time offline or on flaky data sees the whole app in the wrong typography, undermining a safety-triage product that must feel trustworthy; it also adds a network dependency and a third-party (Google) call at boot.
**Business impact:** Weaker, inconsistent first impression and an avoidable startup network/battery cost; a privacy-review flag (undisclosed connection to Google's font CDN).
**Store impact:** None directly, though the Google-fonts network call is data the privacy/data-safety disclosures should account for.
**Solution:** Vendor the two font families: add `Inter` and `BricolageGrotesque` `.ttf` weights under `assets/fonts/`, declare them in a `pubspec.yaml` `fonts:` block, and either reference them via `TextStyle(fontFamily: ...)` or keep `GoogleFonts.*` but set `GoogleFonts.config.allowRuntimeFetching = false` at startup so it resolves from the bundled assets (google_fonts matches bundled files when runtime fetching is off). Verify no `fonts.gstatic.com` request fires at launch.
**Acceptance criteria:** App shows Inter/Bricolage on first launch with airplane mode on; a network capture at cold start shows no request to Google font hosts; `allowRuntimeFetching` is false (or fonts referenced directly from assets).

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Device Experience & QA / Test Integrity

_Area readiness (finder self-assessment): 66% — Automated test integrity is genuinely strong: all 217 flutter widget/unit tests pass (1 legitimate skip for an unavailable native rive lib), and the server-side quota gate has 8/8 passing unit tests covering every emergency/quota quadrant. Of the three prior device bugs, (a) the German-emergency-locale bug is verified fixed in current code (app.dart:40 resolveAppLocale + l10n_test 8/8 + device re-confirmed English on tr-TR in Appendix Part B) — note the alarming German screenshot 07l is the archived pre-fix capture, not current behavior; (b) quota-on-emergency-override is fixed server-side but not re-verified on device; (c) the OneSignal crash-on-exit is UNFIXED in code and only mitigated by configuring ONESIGNAL_APP_ID. The real weaknesses are coverage, not correctness: there is no integration_test/golden/e2e layer at all (every test mocks the backend), the analysis error/degrade safe-messaging path has zero assertions, and launch-critical flows — premium PURCHASE (never reachable on any device to date), delete-account cascade, photo/video capture, real AI results, and family invite — have never been device-tested. A scripted founder device-pass on a fully-configured release build is required before launch._

#### [QA-01] Launch-critical device flows never exercised on-device (premium PURCHASE, delete-account cascade, photo/video capture, real AI result, family invite)

**Severity:** HIGH · **Category:** device · **Perspectives:** qa, product, monetization · **Effort:** L 2-4d · **Blocks launch:** YES · **Blocks store:** none · **Confidence:** 0.9

**Evidence:** Both on-device passes explicitly list these flows as NOT exercised. `PAWDOC_DEVICE_VALIDATION_REPORT.md:40` — "Not exercised on-device: photo/video capture→analyze, MONITOR/NORMAL result screens, History screen, Family, Referral, Reminders, Premium paywall UI, Settings, Delete account." `DEVICE_VALIDATION_APPENDIX.md:218-226` (B7) repeats: new-user onboarding, pet creation, family invite acceptance, paywall purchase, delete-account, and a real (non-degraded) MONITOR/NORMAL AI result "remain for the founder device-pass." The paywall was never even reachable: `DEVICE_VALIDATION_APPENDIX.md:81-83` — RevenueCat offerings unconfigured, paywall shows "coming soon," so the PURCHASE flow has been tested on ZERO devices to date.
**Root cause:** Device validation ran on a single dev-config build with no RevenueCat/OneSignal/AI keys and a single test account with no known password; exhaustive tapping was curtailed after a harness incident (`PAWDOC_DEVICE_VALIDATION_REPORT.md:38`).
**User impact:** A broken IAP purchase, a delete-account that silently fails its R2/auth cascade, or a crash in the camera-capture path would ship undetected to the first real users.
**Business impact:** Premium purchase is the entire revenue path and has literally never completed on a device; a failed first purchase is unrecoverable churn. A delete-account that doesn't fully cascade is a privacy/GDPR liability.
**Store impact:** A non-functional IAP or Account-Deletion path is a concrete Apple/Google rejection risk, but that belongs to monetization/store reviewers; from QA the gate is that these are unverified.
**Solution:** Before launch, the founder runs a scripted device-pass on a fully-configured RELEASE build (RevenueCat offering live, OneSignal app id set, AI keys set) covering, each with a screenshot: (1) sandbox premium purchase → entitlement unlocks PDF/unlimited; (2) real photo capture → analyze → MONITOR/NORMAL/EMERGENCY result; (3) family invite create + accept on a second account; (4) delete-account → confirm row + storage + auth user gone via `scripts/test-rls.sh` cascade check; (5) sign-in with a known password after sign-out; (6) reminders scheduling. Record pass/fail per flow in a checklist.
**Acceptance criteria:** A completed device-pass checklist where each of the six flows above has an evidence screenshot and a PASS, run on a release-signed, fully-configured build; delete-account cascade re-verified by `test-rls.sh`.

**Verification:** CONFIRMED — All cited lines reproduced verbatim in the current tree. PAWDOC_DEVICE_VALIDATION_REPORT.md:40 lists "Not exercised on-device": photo/video capture→analyze, MONITOR/NORMAL result screens, History, Family, Referral, Reminders, Premium paywall UI, Settings, Delete account. Line 38 documents the harness incident (blind tap placed an accidental phone call) that curtailed tapping. DEVICE_VALIDATION_APPENDIX.md:81-83 confirms paywall was gated to "coming soon" (RevenueCat offerings unconfigured) so PURCHASE rendered on zero devices. Lines 218-226 (B7) repeat that onboarding, pet creation, family invite acceptance, paywall purchase, delete-account, and a real non-degraded MONITOR/NORMAL AI result all remain for the founder device-pass. Lines 210-211 confirm no AI keys in dev → analyses degrade to MONITOR, so the full Tier-2/3 path is unvalidated. These are launch-critical revenue (IAP) and GDPR (delete-account cascade) flows never exercised on a device; verifying they work requires a release-signed, fully-configured build + physical device I cannot access, so the gap stands.

---

#### [QA-02] No integration/e2e/golden test coverage — the safety-critical emergency path can regress with a fully green suite

**Severity:** MEDIUM · **Category:** engineering · **Perspectives:** qa, ai, engineering · **Effort:** L 2-4d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.95

**Evidence:** No `mobile/integration_test/` directory exists and `pubspec.yaml` has no `integration_test` dependency (verified: `ls integration_test/` → absent; `grep integration_test pubspec.yaml` → none). Zero golden tests (`grep -rln matchesGoldenFile test/` → empty). All 217 test blocks (463 `expect()`s) are widget/unit tests running on `flutter_tester` with the backend mocked — e.g. `test/analysis_integration_test.dart:12` overrides `analysisServiceProvider` with a `FakeAnalysisService`. The emergency path is asserted only at widget level (`analysis_integration_test.dart:59` "mocked EMERGENCY analysis flows to the emergency screen") and server-side unit level (`supabase/functions/_shared/quota_gate.test.mjs`, 8/8 green). Nothing exercises the assembled app end-to-end on a real engine in CI.
**Root cause:** The project relied on one-off manual device passes instead of an automated on-device/emulator e2e harness; no CI job assembles and drives the app.
**User impact:** A regression in routing, capture wiring, or the emergency screen (the #1 safety surface) would ship because no automated test drives the full flow — exactly the class of bug (locale-on-emergency-screen) that a manual pass caught late.
**Business impact:** For a safety-critical app a false-negative regression is the stated #1 business risk; with no e2e guard, every release depends on remembering to manually re-run the founder device-pass.
**Store impact:** None directly.
**Solution:** Add `integration_test` (Flutter's package) with at least: (a) emergency text "dog choking" → asserts red EMERGENCY screen + un-paywalled vet CTA + disclaimer + acknowledgment gate; (b) a MONITOR result path; (c) offline/AI-unreachable → safe error screen. Wire a CI job (`flutter test integration_test` on an emulator, or `flutter drive`) so it runs on every PR. Optionally add golden tests for the EMERGENCY and disclaimer surfaces to pin their copy/layout.
**Acceptance criteria:** `integration_test/` exists with a passing emergency e2e that fails if the vet CTA is paywalled or the disclaimer/acknowledgment is missing; the job runs in CI and is required before merge to `main`.

**Verification:** PARTIAL — All structural claims reproduce in current tree: no mobile/integration_test/ dir (ls fails); no integration_test dep in pubspec.yaml (dev_deps = flutter_test, fake_async, flutter_lints, flutter_native_splash, flutter_launcher_icons only); zero golden tests (grep -rln matchesGoldenFile test/ empty). test/analysis_integration_test.dart:13 defines FakeAnalysisService, line 41 overrides analysisServiceProvider, wrapping only AnalysisRunnerScreen in a bare MaterialApp — not the assembled app, not routed through go_router. The EMERGENCY assertion at line 63 only checks find.text('This may be an emergency'); it does NOT assert un-paywalled vet CTA, disclaimer, or acknowledgment gate. supabase/functions/_shared/quota_gate.test.mjs exists (server-side emergency-bypass coverage). So the finding is factually accurate. Severity downgraded HIGH->MEDIUM: this is a missing-e2e-infrastructure gap, not a live defect; the top safety surface (emergency paywall bypass) is already guarded by server-side quota-gate unit tests + client-side paywall_policy + widget-level routing coverage + a documented manual device-pass process — so the 'regresses with a green suite' risk is real but partially mitigated, not unguarded. Minor: finder's counts (217 test blocks/463 expects) not independently confirmed — I counted 47 test files, 24 using testWidgets; the specific numbers are non-load-bearing to the finding.

---

#### [QA-03] OneSignal crash-on-exit still unguarded in code for builds without ONESIGNAL_APP_ID

**Severity:** MEDIUM · **Category:** engineering · **Perspectives:** qa, engineering, device · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** google · **Confidence:** 0.85

**Evidence:** `mobile/lib/src/notifications/onesignal_service.dart:14-17` still `return`s early without calling `OneSignal.initialize()` when `Env.oneSignalAppId.isEmpty`, and there is no native `initWithContext` guard in `MainActivity`. The device pass captured the resulting FATAL: `DEVICE_VALIDATION_APPENDIX.md:176-198` (B6 HIGH) — `IllegalStateException: Must call 'initWithContext' before use` in `OneSignalNotifications.onDetachedFromEngine` on every graceful activity destroy, in any build without `ONESIGNAL_APP_ID`. The report notes it was left as a founder config decision, so the crashing code path is unchanged in this tree.
**Root cause:** The OneSignal Flutter plugin registers engine callbacks unconditionally; its teardown calls `getNotifications()` which throws if `initialize()` was never invoked — which is exactly the skipped-init branch.
**User impact:** If a release/beta build ships without OneSignal configured (an easy founder omission), the app throws a FATAL on every exit/relaunch — logged to Sentry and visible as crash-rate; on some devices an "app stopped" dialog.
**Business impact:** A non-zero crash rate on exit inflates Google Play's Android vitals (bad-behavior threshold) and erodes early-user trust; it is entirely avoidable.
**Store impact:** Elevated crash rate can trigger Google Play quality warnings, but only if the mis-configured build actually ships.
**Solution:** Either (a) add a defensive native guard so teardown never throws (call `OneSignal.initWithContext` guarded, or upgrade/pin a plugin version that no-ops teardown when uninitialized), OR (b) make `ONESIGNAL_APP_ID` a required dart-define for release builds via a build-time assertion so a mis-configured release cannot be produced. Re-run the exit/relaunch on-device after the change and scan logcat for `initWithContext`/FATAL.
**Acceptance criteria:** A release-config build exits and relaunches 3× with zero `initWithContext`/FATAL in logcat, AND a build without the app id either does not crash or fails to build.

**Verification:** PARTIAL — Code evidence reproduced exactly. onesignal_service.dart:14-17 returns early (`if (Env.oneSignalAppId.isEmpty) return;`) before OneSignal.initialize(), leaving the plugin's engine callbacks registered but uninitialized. MainActivity.kt (mobile/android/app/src/main/kotlin/app/pawdoc/MainActivity.kt) is a bare `class MainActivity : FlutterActivity()` with no initWithContext guard. env.dart:19 has no release-mode assertion; main.dart:78 calls initialize() unconditionally, so no build-time gate forces ONESIGNAL_APP_ID for release. Plugin is onesignal_flutter ^5.5.5 (unpinned caret). DEVICE_VALIDATION_APPENDIX.md:176-198 records the FATAL initWithContext crash on graceful destroy. So the crashing path is real and unchanged. Severity downgraded HIGH→MEDIUM: per the same appendix the crash is config-scoped (only builds missing ONESIGNAL_APP_ID, which is already required for push on the beta/prod path), was silent on-device with no 'app stopped' dialog, fires on exit only (no in-app or safety-path impact), and a dummy-app-id build was verified crash-free. Impact requires a misconfigured release to actually ship — a latent, avoidable risk, not a HIGH affecting normal operation.

---

#### [QA-04] Analysis error/degrade path (offline & AI-unreachable safe-messaging screen) has zero automated test coverage

**Severity:** MEDIUM · **Category:** engineering · **Perspectives:** qa, ai · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.9

**Evidence:** `mobile/lib/src/analysis/analysis_runner.dart:126-138` catches network/generic failures and shows the safety-relevant error screen (`:216` "We couldn't analyze this right now. If this seems urgent, contact a veterinarian."). No test forces `AnalysisService` to throw: `grep` for `throw`/`Future.error` combined with `analysisServiceProvider` across `test/*.dart` returns nothing, and no test references `_Phase.error`. `analysis_integration_test.dart` has only 2 tests (`:52` MONITOR, `:59` EMERGENCY), both happy-path. The `OfflineBanner` widget itself is tested (`test/polish_test.dart:30-42`) but it is mounted only on Home (`lib/src/home/home_screen.dart:153`), not on the capture/analyze screens.
**Root cause:** Tests only supplied a `FakeAnalysisService` that resolves successfully; the failure/degrade branch was never fixtured.
**User impact:** The screen a user sees when the AI is down or they are offline — the one place the app must still steer an anxious owner to a vet — is unasserted and could regress its safe copy or fall back to an unsafe default.
**Business impact:** A safety-messaging regression on the degrade path directly raises false-negative risk (the stated #1 risk).
**Store impact:** None.
**Solution:** Add a widget test that overrides `analysisServiceProvider` with a fake that throws a `SocketException`/generic error and asserts `_Phase.error` renders the "contact a veterinarian" copy and a Try-again button; add a second asserting the degraded-MONITOR path never renders LIKELY NORMAL. Optionally mount `OfflineBanner` (or an inline offline hint) on the capture/analyze screens so offline users are warned before submitting.
**Acceptance criteria:** A failing-service widget test asserts the safe error copy + retry; test is green in `flutter test`.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [QA-05] Quota-decrement-on-emergency-override fixed server-side but never re-verified on device

**Severity:** MEDIUM · **Category:** monetization · **Perspectives:** qa, monetization · **Effort:** S <=2h · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.6

**Evidence:** On device the free-check count went 2→1→0 across an emergency + a degraded submission (`DEVICE_VALIDATION_APPENDIX.md:201-206`, B6 MEDIUM). Current server logic now correctly excludes both: `supabase/functions/_shared/quota_gate.mjs:35-42` `countsAgainstQuota` returns false for `isEmergencyText`, `triageLevel===EMERGENCY`, and `tierUsed===0` (degraded), and it is unit-tested green (`quota_gate.test.mjs`, ran 8/8 pass; call site `supabase/functions/analyze/index.ts:345-353`). But no on-device or CI e2e check confirms the assembled path no longer decrements — the fix is proven only by the pure-function unit test.
**Root cause:** The device observation predates/差 the current guard; the guard is a pure function, not exercised through the real Edge Function invocation with a real user row.
**User impact:** If the call site or client display still decrements, a free user is silently charged a check for an emergency they were promised is free — not a safety issue (emergency is never paywalled, proven at 0 quota) but an accounting/trust deviation.
**Business impact:** Under-counting erodes the promised free-tier and could surface as a support complaint; low blast radius.
**Store impact:** None.
**Solution:** During the founder device-pass, submit an emergency-keyword text at a known quota and confirm the displayed free-check count is unchanged; add a Supabase edge-function test (or supabase/tests) that invokes `/analyze` with an emergency text and asserts `free_analyses_used_this_month` is not incremented.
**Acceptance criteria:** A device screenshot showing quota unchanged after an emergency submission, plus an edge-function/DB test asserting no increment for `isEmergencyText` and for `tier_used===0`.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

#### [QA-06] Offline emergency triage is unavailable — keyword override is server-only, and capture/analyze screens show no offline warning

**Severity:** MEDIUM · **Category:** ai · **Perspectives:** qa, ai, ui-ux · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** none · **Confidence:** 0.75

**Evidence:** The emergency keyword override runs server-side in the Edge Function (`supabase/functions/analyze/index.ts:124` "The AI service still runs the authoritative hardcoded override"; CLAUDE.md: "Emergency override runs BEFORE any AI call"). There is no client-side emergency-keyword check in `mobile/lib/src/analysis/`. Offline, `analysis_runner.dart:126-138` falls straight to the generic error screen; the `OfflineBanner` is mounted only on Home (`home_screen.dart:153`), so a user on the capture/describe/analyze screens gets no proactive offline signal before submitting. The error copy is safe (`analysis_runner.dart:216`, "If this seems urgent, contact a veterinarian") but there is no triage at all offline.
**Root cause:** Triage is fully server-dependent by design; no lightweight client-side keyword pre-check exists for the no-connectivity case.
**User impact:** An owner in a dead-zone typing "my dog is choking" gets a generic "couldn't analyze" screen rather than an EMERGENCY red-screen + vet CTA; the safe fallback copy mitigates but does not triage.
**Business impact:** Rare but high-consequence (the emergency the app exists to catch, missed due to connectivity); reputationally severe if it coincides with a real emergency.
**Store impact:** None.
**Solution:** (1) Show an offline indicator on the capture/analyze screens (reuse `OfflineBanner` or gate the submit button with an offline hint). (2) Consider a client-side copy of the hardcoded emergency-keyword list that, when offline, routes straight to the EMERGENCY screen + vet-finder (which is local) instead of the generic error — keeping the server override authoritative when online. Add a widget test for the offline-emergency path.
**Acceptance criteria:** Offline, an emergency-keyword text surfaces the EMERGENCY vet CTA (or at minimum a clear offline warning before submit); covered by a test.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---


### Prior-Report Reconciliation (Honesty)

_Area readiness (finder self-assessment): 68% — I re-verified the launch-critical claims from prior reports against the current tree. Most high-stakes claims HOLD: image pixels are now actually sent to the models (providers.py base64 + media.py fetch), the client SSRF vector is genuinely closed (analyze Edge Function rejects client image_url and presigns only own-namespace keys), RLS is enabled on all 13 tables with per-op policies, the emergency-never-paywalled server logic is intact, the disclaimer is force-injected server-side, the EN/DE emergency keyword lists byte-match between safety.py and emergency_keywords.mjs, and flutter analyze is clean. The trust problem is the blind spots the reports never covered: every "device-validated / beta-ready / YES-WITH-CONDITIONS" verdict was produced on an Android-only, debug-signed, dev-config build, so an iOS-breaking deep-link gap, a still-unfixed debug release-signing config, and a dead brand domain that the app actively ships in referral/invite links all went unflagged as launch blockers._

#### [REC-01] Release build still signed with the debug key — Google Play upload blocker despite "engineering GO / beta-ready" verdicts

**Severity:** CRITICAL · **Category:** store-google · **Perspectives:** reconcile, engineering, store-google · **Effort:** M 0.5-1d · **Blocks launch:** YES · **Blocks store:** google · **Confidence:** 0.9

**Evidence:** `mobile/android/app/build.gradle.kts:34-38` still contains the stock Flutter template: `release { // TODO: Add your own signing config ... signingConfig = signingConfigs.getByName("debug") }`. There is no `key.properties`, no keystore reference, no `signingConfigs.create("release")`. Meanwhile `PAWDOC_FINALIZATION_REPORT.md`, `PAWDOC_ENGINEERING_GO_REPORT.md` and memory declare "ENGINEERING GO FOR 50-USER BETA" and the device-validation build (`DEVICE_VALIDATION_APPENDIX.md:15-16`) is explicitly a `flutter build apk --release` produced with this same debug-signing config.
**Root cause:** The Android signing config was never replaced; it was deferred to the founder but no report treats it as a hard, still-open store gate — several read as if the app is submittable.
**User impact:** None directly, but no genuine production build can be shipped/updated.
**Business impact:** Cannot publish or push updates to the Google Play track; the "validated" artifact is not the artifact that can go live, so all on-device validation was performed on a build that can never ship.
**Store impact:** Google Play rejects/blocks AABs signed with the Android debug certificate; the app cannot be uploaded. Apple uses a separate provisioning-profile path so this specific config does not block Apple, but the iOS signing was likewise never verified in-repo.
**Solution:** Create a release keystore; add `mobile/android/key.properties` (git-ignored) with `storeFile/storePassword/keyAlias/keyPassword`; in `build.gradle.kts` load it via `Properties()` and define `signingConfigs.create("release")`, then set `release { signingConfig = signingConfigs.getByName("release"); isMinifyEnabled = true; isShrinkResources = true }`. Enroll in Play App Signing. Rebuild the RC with the release key and re-run device validation on THAT artifact (not the dev-signed one). Do the equivalent iOS Distribution profile + `flutter build ipa` check.
**Acceptance criteria:** `flutter build appbundle --release` produces an AAB whose signer cert is the release key (verify with `jarsigner -verify -verbose -certs`, not `androiddebugkey`); Play Console accepts the internal-testing upload; a report records the release-signed SHA256 that was device-validated.

**Verification:** CONFIRMED — Reproduced exactly in current tree. mobile/android/app/build.gradle.kts:33-39 has `buildTypes { release { // TODO: Add your own signing config for the release build. // Signing with the debug keys for now... signingConfig = signingConfigs.getByName("debug") } }`. No key.properties exists; find over mobile/android for key.properties / *.jks / *.keystore returns nothing (only fastlane/, Gemfile, standard gradle files present). No signingConfigs.create("release"), no Properties() load, no keystore reference anywhere. Google Play hard-rejects AABs signed with the Android debug certificate, so any `flutter build appbundle --release` here cannot be uploaded to Play. This is a genuine, still-open store gate — severity CRITICAL for the Google Play track is accurate. Note: it blocks Play submission but does not corrupt runtime behavior, and it is a founder-side task (keystore generation cannot be done in-repo by an agent), yet no report treats it as a hard open blocker despite "engineering GO / beta-ready" framing.

---

#### [REC-02] iOS never registers the pawdoc:// URL scheme — password-reset and all deep links silently broken on iOS, and no report ever tested iOS

**Severity:** HIGH · **Category:** engineering · **Perspectives:** reconcile, engineering, device · **Effort:** M 0.5-1d · **Blocks launch:** YES · **Blocks store:** apple · **Confidence:** 0.88

**Evidence:** `mobile/lib/src/auth/auth_controller.dart:59-64` sends password recovery with `redirectTo: 'pawdoc://login-callback'`, and `recovery_screen.dart` / `sign_in_screen.dart:95-122` wire a live "Forgot password" flow to it. On Android the scheme is registered (`AndroidManifest.xml:52-56` `<data android:scheme="pawdoc"/>`). But `mobile/ios/Runner/Info.plist` (76 lines) contains NO `CFBundleURLTypes`/`CFBundleURLSchemes` key (grep count 0), and there is no `.entitlements` file anywhere under `mobile/ios/` (find returns nothing) — so no custom scheme and no Associated Domains. Every device-validation report (`DEVICE_VALIDATION_APPENDIX.md`, `PAWDOC_DEVICE_VALIDATION_REPORT.md`, memory) was run on a Redmi Note 11R Android device only.
**Root cause:** Deep-link plumbing was implemented and validated on Android; iOS Info.plist/entitlements were never configured, and no report exercised iOS, so the gap is invisible in the "beta-ready" verdicts.
**User impact:** On iOS, tapping the password-reset email link opens Safari to a `pawdoc://` URL the OS cannot route — the app never reopens, so a locked-out iOS user cannot reset their password. Referral/invite deep links are equally dead on iOS.
**Business impact:** iOS account recovery is broken; support load and churn from locked-out users; contradicts the cross-platform "YES-WITH-CONDITIONS" launch posture.
**Store impact:** Apple review can hit the broken recovery path (a functional-completeness rejection risk under Guideline 2.1) though not a guaranteed reject.
**Solution:** Add `CFBundleURLTypes` with `CFBundleURLSchemes = [pawdoc]` to `mobile/ios/Runner/Info.plist`; if Universal Links are wanted, add `Runner.entitlements` with `com.apple.developer.associated-domains = applinks:pawdoc.app` and host `apple-app-site-association`. Then run the password-reset flow end-to-end on a physical iPhone before claiming iOS validated.
**Acceptance criteria:** On iOS, a `pawdoc://login-callback` link reopens the app into the recovery screen; a documented iOS device pass covers reset-password + referral deep link.

**Verification:** CONFIRMED — Reproduced. mobile/ios/Runner/Info.plist (76 lines) has zero CFBundleURLTypes/CFBundleURLSchemes (grep count 0); no .entitlements file under mobile/ios/; no applinks/associated-domains/pawdoc.app anywhere in ios/. Android registers the scheme at android/app/src/main/AndroidManifest.xml:55 (<data android:scheme="pawdoc"/>, VIEW+BROWSABLE). auth_controller.dart:62 sends resetPassword redirectTo 'pawdoc://login-callback'; sign_in_screen.dart:122+308 wires a live "Forgot password?" flow to it. So the pawdoc:// custom scheme is routable on Android but unregistered on iOS — the reset email link opens Safari to a pawdoc:// URL iOS cannot route, app never reopens, recovery is dead on iOS. Same for referral deep links. Every device-validation report was Android-only (Redmi Note 11R). HIGH is appropriate IF iOS is a launch target (cross-platform YES-WITH-CONDITIONS posture implies it); the only mitigating caveat is that the validated beta so far is Android-only, so it is not yet a live-user regression. Fix = add CFBundleURLTypes/CFBundleURLSchemes=[pawdoc] to Info.plist (+ optional Runner.entitlements associated-domains for Universal Links) and run reset flow on a physical iPhone.

---

#### [REC-03] App ships live pawdoc.app referral/invite/share links to a dead domain with no App Links configured — growth funnel is non-functional

**Severity:** MEDIUM · **Category:** product · **Perspectives:** reconcile, product, infrastructure · **Effort:** L 2-4d · **Blocks launch:** YES · **Blocks store:** none · **Confidence:** 0.85

**Evidence:** `mobile/lib/src/referral/referral_screen.dart:35` builds and shares `final link = 'https://pawdoc.app/r/$code';`; `result_screen.dart:199` shares copy "Shared via PawDoc 🐾 — pawdoc.app"; `family/invite_token.dart:5` and `router/app_router.dart:139-148` expect `https://pawdoc.app/invite/<token>` and `/r/CODE`. Memory (`launch_audit_2026_06_12`) states "pawdoc.app dead." `AndroidManifest.xml:49-50` explicitly leaves App Links unconfigured ("add an autoVerify host filter + assetlinks.json") and iOS has no associated-domains entitlement (see prior finding). So the domain is dead AND, even if revived, https links would not route to the app on either platform.
**Root cause:** Referral/family-sharing were built against a brand domain that was never registered/hosted, and App Links/Universal Links verification was deferred; reports treat referrals as a complete feature.
**User impact:** A shared referral or family-invite link opens a dead host (DNS/404); the recipient never installs via the link and, on a device with the app installed, the link opens a browser instead of the app. The referral reward loop cannot complete.
**Business impact:** The primary organic-growth mechanism (referrals) and family onboarding are broken end-to-end; any CAC/virality assumptions built on referrals are invalid at launch.
**Store impact:** None (no store rejection), but it is a launch-quality/product blocker.
**Solution:** Register and host pawdoc.app (or repoint links to the live CloudFront domain already in `legal_urls.dart`) with `/r/*` and `/invite/*` routes that deep-link or fall back to store pages; publish `/.well-known/assetlinks.json` and `apple-app-site-association`; add `autoVerify="true"` + host intent-filter on Android and Associated Domains on iOS. Until the domain is live, gate the referral/invite share UI behind a feature flag so users are not handed dead links.
**Acceptance criteria:** Sharing a referral link resolves to a live page; on a device with the app installed the link opens the app to the referral/invite handler; assetlinks.json/AASA are reachable over HTTPS and verified.

**Verification:** CONFIRMED — All cited evidence reproduced in current tree. referral_screen.dart:35 hardcodes `https://pawdoc.app/r/$code` (not build-time overridable, unlike legal_urls.dart which defaults to live CloudFront d1klm6zb1x23me.cloudfront.net). result_screen.dart:199 shares "pawdoc.app" copy. invite_token.dart:5 and app_router.dart:139-155 target https://pawdoc.app for /invite/:token and /r/:code. AndroidManifest.xml:48-56 registers ONLY the pawdoc:// custom scheme; the inline comment says App Links still need an autoVerify host filter + assetlinks.json (none present). iOS has NO .entitlements file at all under mobile/ios (no Associated Domains) → Universal Links impossible. legal_urls.dart:8-10 treats pawdoc.app as the yet-to-adopt "final custom domain," and memory records it dead. Net: referral/share links point at a dead host with no App Links on either platform. Downgraded HIGH→MEDIUM: not safety/store-impacting, and family invites have a documented manual-token-paste fallback (invite_token.dart), though the referral reward loop has no fallback and is genuinely non-functional end-to-end.

---

#### [REC-04] Legal/privacy URLs default to an ephemeral CloudFront hostname while the brand domain is dead — fragile store privacy-policy link

**Severity:** MEDIUM · **Category:** legal · **Perspectives:** reconcile, legal, infrastructure · **Effort:** M 0.5-1d · **Blocks launch:** no · **Blocks store:** both · **Confidence:** 0.72

**Evidence:** `mobile/lib/src/config/legal_urls.dart:17-20` hardcodes `defaultValue: 'https://d1klm6zb1x23me.cloudfront.net'` as the base for privacy/terms/disclaimer, overridable only at build time via `LEGAL_BASE_URL`. `PAWDOC_LEGAL_PORTAL_REPORT.md` and memory declare the portal "LIVE" and "app-integrated" — technically true — but the same tree still references the dead `https://pawdoc.app` for referrals/share, so the app presents two different, inconsistent brand identities and the canonical legal URL is a random CloudFront distribution ID.
**Root cause:** The legal portal was deployed to a raw CloudFront default domain as an interim host; the intended custom domain (pawdoc.app) was never provisioned, and no report reconciles the two.
**User impact:** Privacy/Terms links work today but sit on a non-branded, disposable hostname; if the CloudFront distribution is ever recreated the store-listed privacy URL breaks.
**Business impact:** App Store / Play Console require a stable privacy-policy URL; anchoring it to `d1klm6zb1x23me.cloudfront.net` is brittle and off-brand, and forces a store-metadata update whenever the domain finally moves to pawdoc.app.
**Store impact:** Both stores require a resolvable privacy policy URL at submission; a CloudFront default domain satisfies the letter but is fragile and inconsistent with in-app pawdoc.app copy.
**Solution:** Provision pawdoc.app (or a dedicated legal subdomain), point it at the existing CloudFront/S3 origin, and build the release with `--dart-define=LEGAL_BASE_URL=https://pawdoc.app`; use that same domain as the store privacy-policy URL and in the referral/share copy so the brand is consistent.
**Acceptance criteria:** Privacy/Terms open on the final custom domain from the release build; the store-listing privacy URL matches; no remaining `cloudfront.net` or dead-`pawdoc.app` link is shipped in the RC.

**Verification:** reported (not independently re-verified; MEDIUM/LOW tier)

---

---

## Execution Phases (0–10)

_Branch `feat/legal-portal-integration` (main + legal portal, PR #78 unmerged) · Audit date 2026-07-06 · 64 findings · Safety-critical: a false negative is the #1 risk._

Every finding ID is assigned to exactly one phase. Duplicate findings (the debug-keystore issue reported four times as SEC-01/INF-01/PLAY-01/REC-01; the referral-dead-domain reported as REC-03/PRD-01/UX-04; SSRF as SEC-02/AI-04; fonts as PERF-03/ENG-01) are noted where the same work resolves several IDs.

---

### Phase 0 — Critical Launch Blockers
**Priority:** P0 — nothing ships until these clear.
**Estimated effort:** ~4–6 eng-days + founder/attorney/device-pass critical path.
**Dependencies:** none (this is the gate; all other phases follow).
**Expected impact:** Removes every hard launch/store-rejection blocker and the one broad legibility failure; makes the app submittable to both stores and legally operable.
**Implementation roadmap:**
1. Replace the debug keystore with a real upload/signing key and wire release signing — resolves **SEC-01, INF-01, PLAY-01, REC-01** (single fix, four IDs).
2. Add `ON DELETE` behavior to the two referral FKs (`referrals.referred_user_id`, `users.referred_by_user_id`) so account deletion no longer 500s — resolves **RLS-01** (GDPR/Apple 5.1.1(v)).
3. Set `MaterialApp.themeMode` to force the dark theme (or theme the 13 forced-dark screens) so light-mode users get legible safety text — resolves **UX-01**.
4. Create the iOS entitlements file (Sign in with Apple + Push) so a signed build functions — resolves **APPL-01**.
5. Register the `pawdoc://` URL scheme on iOS so password-reset/deep links work — resolves **REC-02**.
6. Repoint all shipped referral/invite/share links off the dead `pawdoc.app` domain to a live target with proper App Links/Universal Links — resolves **REC-03**.
7. Fill data-controller identity + EU-representative fields in the published privacy/terms/deletion pages — resolves **LEG-01**.
8. Stand up a deliverable DSAR/support mailbox (real MX) and point the legal pages at it — resolves **LEG-02**.
9. Update App Store Connect + Play metadata/review notes to the live portal URL and off `pawdoc.app` — resolves **APPL-02**.
10. Provision a working reviewer demo account and ensure IAP offerings are live at review (no "coming soon" dead-end) — resolves **APPL-03**.
11. Complete the Play Data Safety mapping against the SDKs actually bundled (location, purchase history, analytics, third-party AI sharing) — resolves **PLAY-02**.
12. Run a scripted founder device-pass on a fully-configured release build: premium purchase, delete-account cascade, photo/video capture, real AI result, family invite — resolves **QA-01**.

---

### Phase 1 — Store Approval Blockers
**Priority:** P1 — required for clean review, not for build-upload.
**Estimated effort:** ~2–3 days.
**Dependencies:** Phase 0 (signing + live domain/mailbox must exist first).
**Expected impact:** Clears the remaining store-policy and compliance-gate rejections beyond the hard blockers.
**Implementation roadmap:**
1. Add `ITSAppUsesNonExemptEncryption` to Info.plist so TestFlight/submission auto-processing isn't blocked — resolves **APPL-04**.
2. Downgrade `ACCESS_FINE_LOCATION` to coarse to match actual usage — resolves **PLAY-03**.
3. Route the Play web account-deletion URL to the now-live deletion mailbox/flow — resolves **PLAY-04**.
4. Point store privacy/legal URLs at a stable domain instead of the ephemeral CloudFront hostname — resolves **REC-04**.
5. Guard the OneSignal init so builds without `ONESIGNAL_APP_ID` don't crash-on-exit (code fix, not config) — resolves **QA-03**.
6. Add affirmative Terms/Privacy acceptance at signup — resolves **LEG-03**.
7. Add an in-app 18+ eligibility attestation / age gate consistent with the Terms — resolves **LEG-05**.

---

### Phase 2 — Security
**Priority:** P1 — close before scaling to public traffic.
**Estimated effort:** ~2 days.
**Dependencies:** Phase 0.
**Expected impact:** Closes the cost-abuse vector and the defense-in-depth SSRF residual; tightens the CI supply chain and RLS convention.
**Implementation roadmap:**
1. Add per-user/per-IP rate limiting so out-of-quota PHOTO/VIDEO `/analyze` can't drive unbounded paid-AI spend — resolves **BE-01**.
2. Implement the media.py host allowlist and guard `moderation.py`'s `httpx.get` — resolves **SEC-02** and **AI-04** (one hardening, two IDs).
3. Pin the AI-service deploy GitHub Action to a SHA instead of `@master` on the `FLY_API_TOKEN` path — resolves **INF-02**.
4. Move the Analyze Edge Function's user/subscription reads onto the caller's JWT + RLS instead of `service_role` — resolves **RLS-03**.

---

### Phase 3 — Infrastructure
**Priority:** P2 — robustness, observability, and test-integrity.
**Estimated effort:** ~6–9 days.
**Dependencies:** Phase 0 (schema/signing stable); overlaps with Phase 2.
**Expected impact:** Turns the green-but-shallow test suite into real coverage, adds scaling/alerting, and hardens backend robustness so a regression or outage is caught rather than silent.
**Implementation roadmap:**
1. Load the full migration set in `test-rls.sh` (incl. referrals) and gate it in CI — resolves **RLS-02** and **INF-04**.
2. Build an integration/e2e/golden layer exercising router redirect, deep links, and the emergency safety path against real (not mocked) services — resolves **ENG-02** and **QA-02**.
3. Add automated assertions on the analysis error/degrade safe-messaging path — resolves **QA-04**.
4. Add outbound timeouts on all Edge → Fly AI fetches (`/analyze`, `/embed`, cron) — resolves **BE-02**.
5. Make quota/add-on counter updates atomic (backend) — resolves **BE-04**.
6. Delete the dead `auth-webhook` Edge Function from the repo — resolves **BE-03**.
7. Move Terraform state to a locking remote backend — resolves **INF-03**.
8. Add a scaling ceiling + alerting to the AI service (raise off the single 512 MB machine) — resolves **INF-05**.
9. Override the CloudFront default cert to lift the TLS floor above TLSv1.0 — resolves **INF-06**.
10. Make the CI "no-placeholders" gate actually fail (red) while placeholder store URLs remain — resolves **INF-07**.
11. Add live-model quality/regression monitoring so silent false-NORMAL drift is visible — resolves **AI-02**.
12. Fix the NSFW moderator to use the real image MIME (stop wrongly rejecting PNG/WebP; fetch once) — resolves **AI-03**.

---

### Phase 4 — Onboarding & Activation
**Priority:** P1 for the copy fix (safety/honesty), P3 otherwise.
**Estimated effort:** ~0.5–1 day.
**Dependencies:** none blocking; do the copy fix early.
**Expected impact:** Removes a health-app overclaim that risks trust and medical-claims scrutiny; smooths the first-run flow.
**Implementation roadmap:**
1. Rewrite the onboarding value-prop headline so it no longer implies the app replaces vet judgment — resolves **PRD-02** (do this in the Phase 0 window given safety sensitivity).
2. Reorder Onboarding Variant B so value precedes the paywall and cannot dead-end on "coming soon" — resolves **PRD-05**.

---

### Phase 5 — UI Polish
**Priority:** P2.
**Estimated effort:** ~1.5–2 days.
**Dependencies:** Phase 0 (UX-01 theme decision) precedes layout work.
**Expected impact:** Fixes large-screen/landscape sprawl, accessibility text overflow, and the missing offline-safety cue.
**Implementation roadmap:**
1. Apply `AppSpace.maxContentWidth` across all ~15 screens so content doesn't sprawl on tablets/foldables/landscape — resolves **UX-02**.
2. Clamp dynamic text scaling against fixed-height cards/single-line rows — resolves **UX-03**.
3. Add an offline warning banner on capture/analyze screens (and consider a client-side emergency-keyword cue) so users aren't left unwarned when triage is unavailable offline — resolves **QA-06**.

---

### Phase 6 — Animations & Motion
**Priority:** —
**Estimated effort:** —
**Dependencies:** —
**Expected impact:** —
**Implementation roadmap:** None. (Motion work was completed and device-validated in prior cycles; no open findings.)

---

### Phase 7 — Performance
**Priority:** P2.
**Estimated effort:** ~1.5–2 days.
**Dependencies:** none.
**Expected impact:** Shrinks the 49.5 MB AAB, cuts cold-start/decode jank and memory pressure on low-end Android, and fixes offline first-launch typography plus an unconsented network call.
**Implementation roadmap:**
1. Add `cacheWidth`/`cacheHeight` to the oversized image assets so they decode at display size — resolves **PERF-01**.
2. Remove the 7.4 MB of unreferenced action-icon PNGs and downscale the oversized art / tighten the pubspec glob — resolves **PERF-02**.
3. Bundle the two brand fonts and disable google_fonts runtime fetching — resolves **PERF-03** and **ENG-01** (one change, two IDs).
4. Move the capture-path JPEG decode + quality assessment off the UI isolate — resolves **ENG-03**.

---

### Phase 8 — Premium / Monetization Optimization
**Priority:** P2 (SUB-01 is user-facing HIGH).
**Estimated effort:** ~2 days.
**Dependencies:** Phase 0 device-pass surfaces purchase issues; overlaps Phase 3 (atomic counters).
**Expected impact:** Fixes paid-user recovery/recognition UX and quota-count accuracy without touching the (already-solid) emergency-never-paywalled path.
**Implementation roadmap:**
1. Make Restore Purchases actually restore, give feedback, and refresh entitlement — resolves **SUB-01**.
2. Add a client SDK-entitlement fallback so premium isn't 100% webhook-dependent — resolves **SUB-02**.
3. Make the client "free checks left" honor referral bonus credits and the monthly reset the server already applies — resolves **SUB-03**.
4. Fix the free-tier counter read-modify-write race client-side — resolves **SUB-04**.
5. Migrate off the deprecated `purchasePackage` API — resolves **SUB-05**.
6. Align referral reward messaging with the actual grant mechanic — resolves **PRD-04**.
7. Re-verify quota-decrement-on-emergency-override on device — resolves **QA-05**.

---

### Phase 9 — Growth
**Priority:** P3 (post-launch loop).
**Estimated effort:** ~3 days.
**Dependencies:** Phase 0 (REC-03 live-domain/App Links must land first).
**Expected impact:** Restores a functional acquisition funnel and makes activation/conversion measurable once the domain is live.
**Implementation roadmap:**
1. Rebuild the referral/acquisition loop on the live domain with working App Links/Universal Links — resolves **PRD-01** (completes what REC-03 unblocked in Phase 0).
2. Update the result-screen share text off the dead `pawdoc.app` domain — resolves **UX-04**.
3. Ensure activation/conversion analytics and A/B experiments actually record instead of silently serving control (configure/verify PostHog) — resolves **PRD-03**.

---

### Phase 10 — Nice-to-have
**Priority:** P4.
**Estimated effort:** ~0.5 day.
**Dependencies:** none.
**Expected impact:** Documentation/reconciliation hygiene; no runtime behavior change.
**Implementation roadmap:**
1. Record verification that image pixels are now genuinely sent to Gemini/Claude (prior CRITICAL resolved) — closes **AI-01** (no code change).
2. Record verification that the client-image_url SSRF and committed-secrets risks are closed — closes **SEC-03** (no code change).
3. Reconcile/delete the divergent duplicate legal docs in `docs/legal/` still carrying TEMPLATE warnings and a conflicting DPO contact — resolves **LEG-04**.

---

### Recommended Path to Launch
Fastest safe route to a submittable build, safety never compromised:

1. **Phase 0 in two parallel tracks.** Eng track: keystore/signing (SEC-01/INF-01/PLAY-01/REC-01), referral-FK deletion (RLS-01), theme/light-mode (UX-01), iOS entitlements + URL scheme (APPL-01, REC-02), and the domain repoint (REC-03). Founder/attorney track (critical path — start day 1): fill legal identities (LEG-01), stand up the DSAR mailbox (LEG-02), fix store metadata (APPL-02), demo account + live offerings (APPL-03), Data Safety mapping (PLAY-02). Fold the honesty copy fix **PRD-02** in here.
2. **Founder device-pass (QA-01)** on the newly-signed, fully-configured release build — this is the go/no-go gate and must follow signing.
3. **Phase 1** to clear the remaining review-time rejections (APPL-04, PLAY-03/04, REC-04, QA-03, LEG-03/05). → **App is submittable to both stores here.**
4. **Phase 2** (BE-01 cost-abuse rate limit + SSRF/CI hardening) before opening public traffic.
5. **Phase 3** test-integrity + robustness (RLS-02/INF-04 CI gate, ENG-02/QA-02 e2e) to lock the safety path against silent regression — begin in parallel with 1–2 and land before scaling.
6. **Phases 7 → 8 → 5 → 4** for AAB size, paid-user UX, large-screen polish, and onboarding flow — non-blocking, ship in the first post-submission updates.
7. **Phase 9** growth loop once the live domain is stable; **Phase 10** doc hygiene anytime. **Phase 6** has no work.

---

## Launch Verdict

**Can PawDoc be submitted to the Apple App Store or Google Play today?**

### 🔴 NO — not submittable today. Overall launch readiness ≈ 62%.

PawDoc's core is genuinely strong and — most importantly — its **safety spine is verified**. Providers now send real image pixels to Gemini and Claude (the single most dangerous historical defect, re-confirmed fixed by payload-capture tests — AI‑01 / SEC‑03); the emergency-override-before-AI path holds; EMERGENCY results are never paywalled or quota-blocked end-to-end; RLS is enabled on all 13 user tables; and the medical disclaimer is force-injected server-side. That is the hard, expensive part, and it is done well.

But **six CRITICAL findings sit directly on the submission path — and they collapse to three distinct root causes.** The multi-agent audit had four independent finders (security, infrastructure, Play-review, reconciliation) converge on the same debug-signing defect; that convergence is a confidence signal, not four separate fires:

1. **Release builds are debug-signed** (SEC‑01 = INF‑01 = PLAY‑01 = REC‑01). Google Play rejects a debug-keystore AAB outright, and every prior "beta-ready / engineering GO" verdict shipped on this build without catching it.
2. **Account deletion 500s** for any user touched by the referral feature, because the referral foreign keys lack `ON DELETE` (RLS‑01) — a GDPR Article 17 and Apple 5.1.1(v) erasure blocker on **both** stores. It slipped through because `test-rls.sh` never loads the referrals migration and isn't gated in CI (RLS‑02 / INF‑04).
3. **The published legal pages are not legally operable** — unfilled data-controller identity and EU-representative placeholders (LEG‑01), and the sole DSAR/deletion/support contact is a `pawdoc.app` mailbox with no MX record, so it bounces (LEG‑02, HIGH).

Layered on top is a dense cluster of store / iOS / cross-platform blockers — individually small, collectively fatal to a submission: iOS ships with **no entitlements file**, so Sign in with Apple and Push fail in a signed build (APPL‑01) and it never registers the `pawdoc://` scheme, so password reset and every deep link are silently broken on iOS (REC‑02) — and **no prior report ever ran on iOS at all**. The dead `pawdoc.app` domain is actively shipped in referral/invite/share links (REC‑03 / PRD‑01) and in store metadata (APPL‑02); Play's Data Safety form is materially incomplete versus the SDKs actually bundled (PLAY‑02); light-mode users get near-invisible text across 13 screens including safety guidance (UX‑01); and launch-critical flows — premium purchase, delete-account cascade, real AI results — have **never** been exercised on a real device (QA‑01).

**None of this is deep product rework.** The team built the safety-critical machinery correctly; what remains is release-engineering, store-provisioning, legal-operability, and iOS/light-mode finishing — mostly configuration-grade fixes plus one small migration. Realistic effort to clear all six CRITICALs and the launch-blocking HIGHs is a few engineering days plus founder-gated external work (domain + mailbox provisioning, a real keystore, filled legal identities, attorney sign-off), with **attorney review and DNS propagation as the true critical path**.

### Per-dimension readiness

| Dimension | Readiness | One-line status |
|---|---|---|
| Engineering | **82%** | Strongest area — clean `flutter analyze`, 217 passing tests, disciplined Riverpod, no debt; only real gap is no end-to-end test layer. |
| Product | **70%** | Solid activation/onboarding core, but the referral/growth loop is dead (PRD‑01) and one headline overclaims for a health app (PRD‑02). |
| UI/UX | **55%** | Premium in dark + portrait; broken for every light-mode user (UX‑01) and sprawls on large screens (UX‑02). |
| Security | **60%** | Secrets clean, client SSRF genuinely closed, uploads presigned, EXIF stripped — capped by the debug-signing CRITICAL (SEC‑01). |
| Infrastructure | **55%** | Legal-portal Terraform is production-grade, but debug signing, an unpinned `@master` deploy action, local-only unlocked TF state, and an ungated RLS suite concentrate here. |
| Store | **45%** | Multiple CRITICAL/HIGH blockers on both storefronts: signing, no iOS entitlements, incomplete Data Safety, dead-domain metadata, placeholder reviewer account. |
| Legal | **50%** | Content ~90% drafted and the disclaimer is non-strippable, but controller/EU-rep identities are unfilled and the DSAR contact bounces; attorney sign-off outstanding. |
| Founder | **55%** | Nearly all remaining blockers are founder-side, low-effort, but unstarted (keystore, legal identities, domain/mailbox, Data Safety, device-pass, merge PR #78). |
| **Overall** | **≈62%** | A safety-verified, well-engineered core that is **not submittable** until the six CRITICALs and the launch-blocking HIGHs close. |

### Exact gating conditions — every item must be TRUE before submission

1. **Real upload keystore** generated and wired into `android/app/build.gradle` release signing; the AAB verified **not** debug-signed. *(SEC‑01 / INF‑01 / PLAY‑01 / REC‑01)*
2. **Referral FK `ON DELETE` migration** added; `test-rls.sh` extended to load it and gated in CI; account deletion verified to succeed for a referrer **and** a referee. *(RLS‑01, RLS‑02, INF‑04)*
3. **Legal identities filled** (data controller + EU representative) and a **live, monitored DSAR/support mailbox** on a provisioned domain; attorney sign-off obtained. *(LEG‑01, LEG‑02, REC‑04)*
4. **iOS entitlements file** added (Sign in with Apple, Push) and **`pawdoc://` URL scheme** registered; both verified in a signed iOS build. *(APPL‑01, REC‑02)*
5. **Live custom domain** provisioned; every shipped `pawdoc.app` / `cloudfront.net` link (referral, invite, share, legal, store metadata) repointed, with App Links / Universal Links configured. *(REC‑03, REC‑04, PRD‑01, APPL‑02, UX‑04)*
6. **Play Data Safety form** completed to match the actual SDK data flows (location, purchase history, device/analytics, third-party AI sharing). *(PLAY‑02, PLAY‑04)*
7. **Light-mode legibility** fixed across the 13 affected screens — or light mode explicitly disabled app-wide for v1. *(UX‑01)*
8. **Scripted on-device validation pass** covering premium purchase, delete-account cascade, capture → real AI result, and the emergency path, on a real **Android and a real iOS** device. *(QA‑01, REC‑02)*
9. **PR #78 merged** to `main`, so the audited tree is the tree that ships.

Clear these and PawDoc moves from ≈62% to submittable. The verdict is **NO today**, transitioning to **YES‑WITH‑CONDITIONS** the moment items 1–4 and 9 are complete with 5–8 in flight. No safety-path defects gate this launch — the blockers are release, store, legal-operability, and iOS provisioning.
