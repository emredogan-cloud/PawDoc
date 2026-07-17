# PawDoc — Device Validation Appendix

> This file holds two on-device validation passes. **Part A** is this mission's
> Legal-Portal validation (2026-06-15). **Part B** is the prior Release-Candidate
> device validation (2026-06-13), preserved unchanged for the record.

---

# Part A — Legal Portal Integration (2026-06-15)

**Supporting Appendix 2** to `PAWDOC_LEGAL_PORTAL_REPORT.md`.

| | |
|---|---|
| **Build under test** | `app-release.apk` · **SHA256 `62136aac65102297b9f45015c11784cd3672e79122f1409bf076d0af06584ef2`** · v1.0.0+1 · built 2026-06-15 16:49 +03 |
| **Built with** | `doppler run -p pawdoc -c dev -- flutter build apk --release --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=… --dart-define=LEGAL_BASE_URL=https://d1klm6zb1x23me.cloudfront.net` |
| **Device** | Xiaomi `22095RA98C`, Android 13 (API 33), system locale `tr-TR` |
| **Portal under test** | https://d1klm6zb1x23me.cloudfront.net (live, public HTTPS) |
| **Method** | Fresh ADB install (old artifact removed) → launch → tap each legal entry point → confirm external browser opens the correct portal page → capture screenshot + launched-intent URL from `logcat` |
| **Result** | **0 CRITICAL, 0 HIGH defects.** Legal links open the correct, live portal pages over HTTPS; pages render with the premium design on the real device; return-to-app works. |

## A1. Screenshot index (`runtime/legal_validation/`)

| File | What it shows |
|------|---------------|
| `01_portal_home_device_browser.png` | Portal opened directly in the device browser (public-accessibility check) |
| `02_app_launch.png` | PawDoc launches to Home (persisted session, pet "Rex") |
| `03b_after_settings_tap.png` | **Account/Settings** screen — Privacy, Terms, **AI Transparency** tiles visible |
| `04_browser_privacy.png` | Privacy tap → **"Gizlilik Politikası"** (Privacy Policy) on `…cloudfront.net` |
| `05_browser_terms.png` | Terms tap → **"Hizmet Şartları"** (Terms of Service); Chrome shows "Page translated to Turkish" |
| `06_account_scrolled.png` | Lower Settings tiles — **AI Transparency** + **Contact & Legal** (both new) + Sign out + Delete |
| `07b_browser_ai_transparency.png` | AI Transparency tap → **"Yapay Zeka Şeffaflığı ve Sınırlamaları"**, "Safety & AI" category |
| `08_browser_contact.png` | Contact tap → **"İletişim ve Yasal Bildirim"** (Contact & Legal Notice) |
| `09_account_dangerzone.png` | Settings danger zone — Delete account |
| `10_delete_account_screen.png` | Delete Account screen with the new AppBar **"?"** policy link (top-right) |
| `11_browser_deletion.png` | Delete "?" tap → **"Hesap Silme Politikası"** (Account Deletion Policy), "Your Data & Rights" |
| `12_account_top.png` | Settings top (navigation reference) |

## A2. Per-link evidence

For each tap: the app fired an Android `ACTION_VIEW` intent (captured in `logcat` as
`dat=https://d1klm6zb1x23me.cloudfront.net/…`; Android truncates the long path with `…`),
the foreground became `com.android.chrome`, and the rendered page title/content confirmed
the **correct, distinct** target page.

| Entry point (screen) | Tapped | Portal page shown | Page title (as rendered, tr auto-translation) |
|---|---|---|---|
| Settings | Privacy Policy | `/privacy` | Gizlilik Politikası (Privacy Policy) |
| Settings | Terms of Service | `/terms` | Hizmet Şartları (Terms of Service) |
| Settings | **AI Transparency** (new) | `/ai-transparency` | Yapay Zeka Şeffaflığı ve Sınırlamaları |
| Settings | **Contact & Legal** (new) | `/contact` | İletişim ve Yasal Bildirim |
| Delete account | **AppBar "?"** (new) | `/deletion` | Hesap Silme Politikası |

Each page rendered with the **premium dark-mode design** (teal/cream tokens, botanical sprig,
hero icon, category eyebrow, effective date `15.06.2026`, version `v1.0`, and the "Attorney
review pending" notice). The portal is authored in English; the Turkish text is **Chrome's
on-device translation** for the `tr-TR` locale (Chrome explicitly showed "Page translated to
Turkish / Undo"), confirming both that the live English page loaded and that it is locale-friendly.

**Return-to-app:** after each external page, Android **Back** returned focus to
`app.pawdoc/.MainActivity` (verified via `dumpsys activity`).

## A3. Public accessibility (independent of the app)

From the host, all **16 routes** (index + 15 policies) returned **HTTP 200 over HTTPS** via
clean URLs; HTTP→HTTPS redirected (301); a bogus path returned 404; security headers
(HSTS-preload, CSP, X-Frame-Options DENY, nosniff, Referrer-Policy, Permissions-Policy) and
Brotli compression were present. The device's own browser also loaded the portal directly.

## A4. Coverage & honesty

- **Fully validated on-device:** five legal links across two screens (Settings ×4, Delete ×1),
  the presence of the two new Settings tiles + the Delete-screen AppBar link, return-to-app,
  premium rendering, and locale behavior — plus full HTTPS route verification of the portal.
- **Not individually re-tapped on-device (verified by equivalence):** sign-in Privacy/Terms,
  referral "Referral terms apply", and the result/emergency disclaimer links. All use the
  **identical `LegalUrls.open(...)` mechanism** proven above; they were not exercised to avoid
  signing out the only available test account (no password to sign back in) and to avoid
  re-running an AI analysis. The code paths are covered by `flutter test` + `flutter analyze`
  + CI, and the URL constants are confirmed compiled into the APK.
- **Paywall legal links:** correctly **gated off** in the dev build because RevenueCat
  offerings are not configured (the paywall shows its "coming soon" state, so the
  subscription-terms disclosure does not render). Validate on a RevenueCat-configured build.
- **Device note:** the phone is PIN-secured; the founder unlocked it for this session. The
  screen was kept awake via `svc power stayon` during testing and reset afterward.

**No code defects were found in this validation.** (One blind-coordinate tap during navigation
opened MIUI's system "App info" page — a test-automation artifact, not an app defect.)

---
---

# Part B — Release Candidate device validation (2026-06-13) — *archived, unchanged*

**Date:** 2026-06-13
**Build under test:** `main` @ `6f42763`, dev-config RC, APK sha256 `d49504ef…2aead1`
**Device:** Xiaomi Redmi `22095RA98C`, Android 13 (API 33), **system locale `tr-TR`**
**Method:** ADB install + on-device interaction + screenshot evidence + logcat scan.
**Result:** New UI confirmed live; emergency safety path verified end-to-end including
the 0-quota case. **0 CRITICAL, 0 HIGH defects in a production-configured build.**
One config-scoped crash-on-exit (HIGH only in builds without `ONESIGNAL_APP_ID`).

## B1. New UI is live (the core thing prior validation missed)

The defining feature of the new UI — a **bottom navigation shell** (`root_shell`) —
is present and functional. The old UI had no bottom nav.

| Surface | Observed | New UI? |
|---|---|---|
| Bottom nav | Home · Pets · Health · Settings (paw/heart/gear icons) | ✓ |
| Home | Pet card, "Check Rex" CTA, "Know your baseline", decorative leaf art | ✓ |
| Pets | "My pets", Rex card, "+ Add pet" FAB | ✓ |
| Health | "Rex's history", health-journal card, stored Emergency triage entry | ✓ |
| Settings | "Account", plan + checks-left, menu, "Language follows your device" | ✓ |
| Capture sheet | Take a photo / Record a video / Describe symptoms | ✓ |
| Describe screen | symptom chips, free-text field, min-12 hint, "Looks good" | ✓ |
| Analyzing | "Checking for anything concerning…" shield animation | ✓ |
| Result | triage band + `_v1` companion illustration + history note + disclaimer | ✓ |
| Referral | "Refer a friend", code, share row, "3 free health checks" | ✓ |
| Vet finder | "Emergency vets nearby" list with call/directions/maps | ✓ |

## B2. Locale fallback (PR #74) — verified on-device

The device locale is **`tr-TR`** (Turkish — unsupported). The app rendered entirely
in **English**, not German. This is the exact scenario that previously rendered the
emergency screen in German. The `resolveAppLocale` fallback is confirmed working on a
real unsupported-locale device. (Android *system* dialogs — e.g. the location
permission prompt — appear in Turkish; that is correct OS behavior the app cannot
override, and the app's own chrome stays English.)

## B3. EMERGENCY safety path — verified end-to-end (the #1 gate)

Text: "dog choking and cannot breathe" (override keywords). Result screen showed:

- ⚠️ **"This may be an emergency"** — red urgent screen.
- Reasoning + "Recommended: immediately."
- ➕ **"Find an emergency vet now"** — prominent CTA, **not paywalled**.
- **Disclaimer**: "PawDoc provides information, not a diagnosis. In an emergency,
  contact a veterinarian immediately."
- ☑ **Acknowledgment gate** — "I understand this needs urgent attention"; **Continue
  is disabled until the box is checked** (verified: tapping the box flips Continue
  from disabled grey to enabled).
- Rendered in English.

**Vet finder works**: the CTA navigates to "Emergency vets nearby", requests location,
and loads **real nearby clinics** (distance, open/closed, address, call + directions +
"Open in Maps").

### B3a. Emergency at 0 free checks — the hardest case (verified)

The free-tier quota was exhausted (0 of 3 left). An emergency phrase
("dog choking cannot breathe collapsed") was submitted at **0 quota**. The full
emergency screen still appeared — **"Emergency indicator detected: 'collapse'"** with
the find-vet CTA — **not paywalled**. This confirms `NEVER paywall an EMERGENCY` holds
even when the user has no checks left.

## B4. Safe degradation — verified

A non-emergency symptom ("mild limping right front leg two days still eating normally")
returned a **MONITOR — keep an eye out** result with the disclaimer and a vet CTA, but
with copy "We can't analyze this right now… please try again shortly." This is the
**correct safe-degradation behavior**: the dev build has no Gemini/Claude API keys, so
the AI providers are unreachable and the system degrades to **MONITOR (caution),
never fabricating LIKELY NORMAL**. (The emergency override worked precisely because it
is hardcoded and runs *before* any AI call.) Full AI analysis (real MONITOR/NORMAL
classification) requires the founder to validate a build with AI-provider keys set.

## B5. Stability

No Flutter exceptions or crashes during any in-app flow (launch, onboarding-resumed
session, tab navigation, emergency, vet finder, normal analysis). Session persisted
across relaunch (signed in as the existing test account).

## B6. Defects found

### HIGH — OneSignal crash on app exit (config-scoped)

- **Symptom:** `FATAL EXCEPTION … Unable to destroy activity … IllegalStateException:
  Must call 'initWithContext' before use`, in
  `com.onesignal.flutter.OneSignalNotifications.onDetachedFromEngine`, on every
  graceful activity destroy (exit/relaunch).
- **Root cause:** `onesignal_service.dart` skips `OneSignal.initialize()` when
  `ONESIGNAL_APP_ID` is empty (the dev/unconfigured case). The OneSignal Flutter
  plugin's teardown then calls `getNotifications()`, which requires the SDK to have
  been initialized → throws.
- **Scope:** occurs **only in builds without `ONESIGNAL_APP_ID`**. It is **silent**
  on this device (the launcher appeared normally; no "app stopped" dialog) and occurs
  on exit, so it does not affect any in-app function or the safety path.
- **Empirically verified fix-by-config:** a diagnostic build with a (dummy, well-formed)
  `ONESIGNAL_APP_ID` was installed and exited via the same path — **no OneSignal crash,
  clean exit** (logcat scan found zero `initWithContext`/FATAL hits). So a
  production/beta build with OneSignal configured does **not** exhibit this crash.
- **Why no code change was made here:** the obvious native guard
  (`initWithContext(null)` in `MainActivity`) creates a double-init with the later
  Dart `initialize(appId)` on the production path, which could silently break push and
  cannot be verified without the real App ID. Per "surface, don't silently apply," this
  is left as a founder decision (see verdict). Remediation = configure
  `ONESIGNAL_APP_ID` (already required for push).

### MEDIUM — emergency override decrements the free-tier quota

The free-check count went 2 → 1 → 0 across two emergency/normal submissions. Per the
E7 intent, an emergency *override* uses `tier_used = 0` and should not be counted. This
is a billing-accounting deviation, **not** a safety issue (the emergency result is
shown and never paywalled, confirmed even at 0 quota). Pre-existing; flagged previously.
Recommend founder confirm the intended quota policy for overrides.

### MEDIUM (environment) — full AI analysis not exercisable in dev

No Gemini/Claude keys in the dev secret set → normal analyses degrade to MONITOR.
Founder must validate the full Tier-2/Tier-3 analysis path on a build with AI keys.

### LOW (known) — referral link uses `pawdoc.app`

The referral share link points at `pawdoc.app/r/<code>`; that domain is not yet live
(pre-existing founder item).

## B7. Coverage and honesty

Validated: new-UI presence across all bottom-nav tabs + the capture/describe/result/
referral/vet-finder flow, the emergency safety path (incl. 0-quota), locale fallback,
safe degradation, stability. Not exhaustively re-tapped on the new UI (logic unchanged
from `main` and previously validated; constrained by dev environment and a single test
account): new-user onboarding, pet creation, family invite acceptance, paywall purchase,
delete-account, and a real (non-degraded) MONITOR/NORMAL AI result. These remain for the
founder device-pass on a fully-configured production build.

**Test data left in dev Supabase:** account `rcqa.beta@example.com` now at 0/3 quota
with extra Rex analyses — recommend cleanup before metrics matter.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
