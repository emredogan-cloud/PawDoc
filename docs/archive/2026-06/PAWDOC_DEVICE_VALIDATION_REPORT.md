# PawDoc — Device Validation Report
**2026-06-13** · real-device forensic QA on merged `main`. Evidence in `runtime/final_device_validation/`.

## Build under test
- **Source:** merged `main` @ `d167ed0`, built fresh via `doppler run -p pawdoc -c dev -- flutter build apk --release` (Supabase URL+anon key injected). Then **rebuilt with the locale fix** (PR #74).
- **Artifact:** `app-release.apk` (102.9 MB), versionName `1.0.0` (+1). **Debug-signed** (release keystore is founder-gated, B1).
- **Optional services absent** in dev config (RevenueCat/OneSignal/PostHog/Sentry) → exercised the app's graceful-degradation paths.

## Device
Xiaomi **Redmi Note 11R**, Android **13** (API 33), arm64-v8a, **1080×2408 @440dpi**, **3.66 GB RAM** (low-mid range — good for surfacing perf issues), **locale tr-TR** (Turkish — unsupported by the app; relevant to the HIGH finding).

## Phases executed
0 repo ✓ · 1 env ✓ · 2 build ✓ · 3 fresh install ✓ · 4 evidence ✓ · 5 launch ✓ · 6 auth ✓ · 7 E2E (partial — see coverage) · 8 visual ✓ · 9 animation ✓ · 12 perf ✓ · 13 logs ✓ · 14 bug-fix loop ✓ (1 fix).

## User journeys exercised (with evidence)
| Journey | Result | Evidence |
|---|---|---|
| Cold launch | ✅ no crash/ANR; 4.8s first, 1.8s subsequent, 0.9s warm | `05_first_launch.png` |
| Sign-in screen | ✅ renders dark-mode; **E3 confirmed** (no "Continue with Apple" on Android), **E1** (Forgot password) present | `05` |
| Sign **up** → auto-signin | ✅ email confirmation off → straight to Home; no SMTP needed for signup | `06d_after_signup.png` |
| Onboarding (5 steps) | ✅ all screens render; personalized ("Rex"); honest safety copy | `07b–07e` |
| Pet create (Rex/Dog) + persistence | ✅ created + persisted (survived reinstall + re-signin) | `07f`, `14c` |
| Sign **in** (existing acct) + session persistence | ✅ re-authenticated; session persisted across relaunch | `14c`, `14e` |
| Capture picker | ✅ distinct per-mode icons (photo/video/text) — the earlier icon bug is gone | `07g` |
| Text symptom input | ✅ **E16 confirmed** ("at least 12 characters"); "Looks good." affirmation | `07h`, `07i2` |
| **EMERGENCY path (safety-critical)** | ✅ **SAFETY FUNCTION PASS** — detected, red screen, ⚠️, "find an emergency vet" CTA **NOT paywalled**, **disclaimer present**, acknowledgment gate | `07l_emergency_final.png` |
| History (indirect) | ✅ "Last check: N min ago" — analysis persisted | `14c` |

## Merged fixes verified LIVE on-device
E1 (forgot-password) · E3 (Apple hidden on Android) · E16 (min-12 + bypass) · B2 (brand launcher icon) · B5 (honest copy: "vet-informed", "we inform; your vet decides") · per-mode capture icons.

## Findings (severity)
- **HIGH — FIXED:** unsupported locale (tr) rendered the **emergency screen in German**. Root cause + fix in PAWDOC_DEVICE_BUG_FIX_REPORT.md (PR #74). Safety *function* was intact; only the language was wrong.
- **MEDIUM — verify:** the emergency text check **decremented free quota 3→2**. The emergency keyword override is `tier_used=0`, and E7 gates the quota increment on `tier_used>0` — so an override result should be **uncounted**. Recommend founder/eng confirm the quota policy for override/degraded results. *Not a beta-blocker* (the safety rule is never-**paywall**-an-emergency, which holds).
- **LOW:** onboarding claims **"Less than $0.33/day"** — reconcile with the final RevenueCat price before launch (B5-adjacent). Jank profile inconclusive (see perf report).

## Coverage gaps (honest)
Exhaustive tapping was curtailed after a **harness incident**: a blind coordinate tap (PawDoc had backgrounded) escaped to the device launcher/dialer and **placed an accidental phone call**, which I **ended immediately** (`KEYCODE_ENDCALL`; `mCallState=0`). This is **not an app defect** — it's a limitation of driving a Flutter canvas by guessed coordinates without live view. To avoid recurrence I stopped aggressive UI-driving.

**Not exercised on-device (founder device-pass recommended):** photo/video capture→analyze (camera flow + real AI cost), MONITOR/NORMAL result screens, the explicit History screen, Family, Referral, Reminders, Premium paywall UI, Settings, **Delete account**. The locale-fix English re-confirmation on-device is **deferred** (proven by unit tests instead — `resolveAppLocale([tr],[de,en])==en`).

## Data note
A test account **`rcqa.beta@example.com`** + 2 analyses were created in the `dev` Supabase (which is prod-shared until D1). **Founder should delete it** (or it can be removed via in-app Delete Account).

→ Verdict in PAWDOC_BETA_READINESS_VERDICT.md.
