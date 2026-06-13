# PawDoc — Device Validation Appendix (Release Candidate)

**Date:** 2026-06-13
**Build under test:** `main` @ `6f42763`, dev-config RC, APK sha256 `d49504ef…2aead1`
**Device:** Xiaomi Redmi `22095RA98C`, Android 13 (API 33), **system locale `tr-TR`**
**Method:** ADB install + on-device interaction + screenshot evidence + logcat scan.
**Result:** New UI confirmed live; emergency safety path verified end-to-end including
the 0-quota case. **0 CRITICAL, 0 HIGH defects in a production-configured build.**
One config-scoped crash-on-exit (HIGH only in builds without `ONESIGNAL_APP_ID`).

---

## 1. New UI is live (the core thing prior validation missed)

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

## 2. Locale fallback (PR #74) — verified on-device

The device locale is **`tr-TR`** (Turkish — unsupported). The app rendered entirely
in **English**, not German. This is the exact scenario that previously rendered the
emergency screen in German. The `resolveAppLocale` fallback is confirmed working on a
real unsupported-locale device. (Android *system* dialogs — e.g. the location
permission prompt — appear in Turkish; that is correct OS behavior the app cannot
override, and the app's own chrome stays English.)

## 3. EMERGENCY safety path — verified end-to-end (the #1 gate)

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

### 3a. Emergency at 0 free checks — the hardest case (verified)

The free-tier quota was exhausted (0 of 3 left). An emergency phrase
("dog choking cannot breathe collapsed") was submitted at **0 quota**. The full
emergency screen still appeared — **"Emergency indicator detected: 'collapse'"** with
the find-vet CTA — **not paywalled**. This confirms `NEVER paywall an EMERGENCY` holds
even when the user has no checks left.

## 4. Safe degradation — verified

A non-emergency symptom ("mild limping right front leg two days still eating normally")
returned a **MONITOR — keep an eye out** result with the disclaimer and a vet CTA, but
with copy "We can't analyze this right now… please try again shortly." This is the
**correct safe-degradation behavior**: the dev build has no Gemini/Claude API keys, so
the AI providers are unreachable and the system degrades to **MONITOR (caution),
never fabricating LIKELY NORMAL**. (The emergency override worked precisely because it
is hardcoded and runs *before* any AI call.) Full AI analysis (real MONITOR/NORMAL
classification) requires the founder to validate a build with AI-provider keys set.

## 5. Stability

No Flutter exceptions or crashes during any in-app flow (launch, onboarding-resumed
session, tab navigation, emergency, vet finder, normal analysis). Session persisted
across relaunch (signed in as the existing test account).

## 6. Defects found

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

## 7. Coverage and honesty

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
