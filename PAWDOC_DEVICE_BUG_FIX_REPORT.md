# PawDoc — Device Bug-Fix Report
**2026-06-13** · fixes made during device validation. PR **#74** (`fix/locale-fallback-en`).

## BUG-1 (HIGH, FIXED) — emergency screen rendered in German on a Turkish device
- **Reproduction:** device locale `tr-TR`; sign up → add pet → describe symptoms
  "my dog is choking and cannot breathe" → Continue. The EMERGENCY result heading,
  CTA, disclaimer, and acknowledgment were in **German** ("Das könnte ein Notfall
  sein", "Sofort einen Notfall-Tierarzt finden", "Weiter"), while the AI concern
  text was English. Evidence: `runtime/final_device_validation/screenshots/07l_emergency_final.png`.
- **Severity:** HIGH — wrong language on the **safety-critical** screen harms
  comprehension in an emergency and erodes trust. (Not CRITICAL: the safety
  *function* held — detected, vet CTA not paywalled, disclaimer present.)
- **Root cause:** `MaterialApp.router` in `mobile/lib/src/app.dart` set
  `supportedLocales` (generated order `[de, en]`) but **no `localeResolutionCallback`**.
  Flutter's default resolution returns the **first** supported locale for any
  unmatched device locale → `de`. So every locale outside en/de got German.
- **Fix:** added `localeListResolutionCallback: resolveAppLocale` — a pure,
  unit-tested function that matches the device locale by language code and
  otherwise returns `const Locale('en')`. Matches E13's intended EN fallback.
- **Validation:** `flutter analyze` clean; `l10n_test.dart` **8/8** incl. 5 new
  guards (`tr→en`, `de→de`, `en-US→en`, empty/null→en, `[fr,de]→de`). Rebuilt the
  APK with the fix + reinstalled. On-device English re-confirmation was deferred
  after the harness incident (the unit test is the definitive evidence; the fix
  is deterministic).
- **Status:** committed + pushed on PR #74. **Founder action:** merge #74, then
  the next build renders English for all non-de locales.

## No other code changes
No other defects warranted a code fix. The MEDIUM (quota-on-override) and LOW
(pricing claim) findings are documented for founder/eng review (see the device
+ verdict reports) — not fixed here, as they need a product/policy decision, not
a clear-cut code repair, and neither blocks beta.

## Not a bug (documented for transparency)
- **Accidental phone call** during blind coordinate-driving — a harness artifact
  (PawDoc backgrounded; a guessed tap hit the launcher/dialer). Ended immediately
  (`KEYCODE_ENDCALL`, `mCallState=0`). The app itself never initiates calls.
- **App exit on BACK from the sign-in root** — expected Android behavior (BACK on
  a root route exits), not a crash (no `FATAL`/exception in logcat).
