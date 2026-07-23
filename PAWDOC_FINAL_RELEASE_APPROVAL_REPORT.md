# PawDoc — Final Release Approval Report (Google Play Internal Testing)

**Date:** 2026-07-23 · **Tester mindset:** a brand-new pet owner installing PawDoc for the first time. **Device:** **Redmi Note 11R** (`22095RA98C`, Android 13 / SDK 33, 1080×2408), real hardware over ADB. **Build:** upload-key-signed release APK (from `main` + fixes), backend = live production project.

> **Verdict up front:** **YES, WITH CONDITIONS.** The app installs, runs, and completes a real first-time journey; the AI triage is correct and safe; it survives stress without crashing. This QA **found and fixed two real defects — one safety-critical** (Emergency was unreachable on an offline cold start). After those fixes (committed + verified on-device), I would upload this to Internal Testing. The conditions are founder Play-console setup + the standing legal/vet items — not app quality.

---

## 1. Complete first-time user journey (as performed on the Note 11R)

Fresh install → launch → **sign-in screen** → **create a brand-new account** (`qa.nr11.0723@…`, assent-gate confirmed: "Create account" stays disabled until Terms is ticked) → **onboarding** ("A calm, clear read…", honest "We inform; your vet decides" framing; **back and Skip both behave**) → **add a pet** (Dog, species picker, name/breed, "Add more pets later") → **home** → **describe a symptom** → **real AI analysis** → **saved to history** → **emergency path** (online + offline) → Settings/Account → paywall → History/Health timeline. No step crashed.

*(One cosmetic note: the device keyboard autocorrected the typed name "Rex"→"Red" and my breed-field tap landed on the still-focused name field, so the pet saved as "Red Labrador". That's a **test-harness input artifact, not an app defect** — the app stored exactly what the field received, and the record is editable.)*

## 2. Every screen tested

| Screen / flow | Method | Result |
|---|---|---|
| Install + first launch + splash | on-device | ✅ 60fps, no crash |
| Sign-in | on-device | ✅ renders; "careful triage" copy (softened) live |
| Signup / account creation | on-device | ✅ new account created |
| Onboarding + nav + Skip/Back | on-device | ✅ back returns home safely; Skip present |
| Permissions | on-device | ✅ notification permission is contextual (not upfront); no camera prompt until photo |
| Add / pick pet (species, name, breed) | on-device | ✅ |
| Home | on-device | ✅ pet hero, Check, Emergency, tips, quotas |
| AI check — text (mild) | on-device | ✅ `WATCH AND RE-CHECK`, re-check 12h, saved |
| Result screen | on-device | ✅ observed / noticed / vets-look-for / disclaimer |
| Emergency screen + first-aid card | on-device | ✅ Choking card safe (no meds/doses, routes to vet) |
| **Offline emergency** | on-device | ✅ **after fix** — reachable + red screen renders |
| Settings + Account | on-device | ✅ analytics toggle OFF by default; legal links; Sign out |
| Paywall / Premium | on-device | ✅ graceful "coming soon" (no RC products — founder) |
| History / Health timeline | on-device | ✅ friendly "Watching" label (no raw token), observation, timeline |
| Log event | on-device | ✅ (created a medication entry during stress) |
| Pets tab | on-device | ✅ |
| Session restore | on-device | ✅ app killed + reopened stays logged in |
| Pet edit · weight · vaccination · reminder · prep-pack data · **account deletion + cascade** · AI `CALL_TODAY` · AI photo (presign→upload→moderation) | live API (this + prior QA) | ✅ all verified against the real backend |
| Logout→login round-trip, prep-pack UI, more AI severities on-screen | not re-tapped this pass | ⏳ backend-proven; quick founder confirmation |

## 3. Issues discovered — and fixed this pass

| Sev | Issue | Fix (committed `541a072`, verified on-device) |
|---|---|---|
| **CRITICAL (safety)** | On an **offline cold start**, the home showed only "Could not load your pets" / long loading skeletons with **no way to reach Emergency** — the offline-capable red path was gated behind the pet-list network fetch. | `EmergencyHelpButton` now renders in the **loading, error, and empty** home states (data state unchanged). Verified: offline cold-start now shows the red "Emergency? Get help now" button. + regression test. |
| **HIGH (stability)** | `supabase_flutter`'s background session auto-refresh threw `AuthRetryableFetchException` (SocketException) **every ~20s while offline**, surfacing as **unhandled exceptions** (log spam, would flood Sentry). | Added a global `PlatformDispatcher.onError` that swallows transient network/auth-retry errors and reports the rest. |

Both are real, both are now fixed, `flutter analyze` clean, **222 tests green**.

## 4. Crash + stress testing
- **Stress batch:** 30 rapid random taps, fast Home/Pets/Health/Settings switching, 4× background→foreground cycles, orientation flip. **App stayed alive (pid 16004), zero FATAL/ANR.**
- A persistent crash monitor ran through the whole session. The only "died" events were my own `force-stop`s (MIUI SmartPower) — **no genuine app crash**. The one real error class it caught (the auth-refresh unhandled exception) is the HIGH fix above.

## 5. AI validation
- **Mild** ("dry flaky skin, eating/playing normally") → on-device `WATCH AND RE-CHECK`, re-check 12h. Correct lowest rung, no false reassurance.
- **Serious** (coughing/gagging; limping non-weight-bearing) → API `CALL_TODAY` with full vet-look-for + steps. Correct.
- **Unclear/sparse** ("cat sneezing") → API confidence-floor `WATCH_AND_RECHECK` / "not enough information". Correct — never fabricates.
- **Photo** → presign → R2 upload (200) → AI fetch → **moderation fail-closed** → safe result. Path works; a moderation-*pass* needs a real pet photo (founder).
- Across all: action ladder + timeframe + injected disclaimer + "saved to history"; **no diagnosis, no condition name, never "normal"**. Safety spine intact.

## 6. Premium validation
RevenueCat products are **not configured**, so the paywall shows a graceful **"Premium is coming soon / Subscriptions aren't available just yet"** + Restore purchases + Not now. No crash, no dead purchase button. **Founder action:** create the RevenueCat offering + Play IAP products to enable/test purchases (not a blocker for Internal Testing).

## 7. Legal validation
All 15 legal pages live at `https://d1klm6zb1x23me.cloudfront.net`, **HTTP 200, public, HTTPS/HSTS**, and now **contain the corrected wording** ("likely normal" appears **0 times** — the earlier fix was deployed this cycle). Privacy `/privacy`, Terms `/terms`, Deletion `/deletion`, AI-Transparency `/ai-transparency` all confirmed. *(Remaining: the legal-entity placeholders + counsel-bracketed liability values are still present and need counsel + a redeploy before public launch — see §9.)*

## 8. Performance
No jank, freezes, or ANRs observed in the flows or the stress batch (initial cold-start frames are expectedly janky; steady-state is smooth). No duplicate-request or memory-abuse signals in logcat. The uncaught-async fix removes a recurring background-error tick.

## 9. Remaining founder actions (not engineering-blocking for Internal Testing)
1. Build/upload the AAB from the **fixed** code (these two fixes) + the Play Console setup (account, App Signing with the generated upload key, App-content/Data-Safety/content-rating) — see `ENVIRONMENT_SETUP.md` and the Play report.
2. **RevenueCat** products/offering (to enable premium testing).
3. **Legal:** fill the entity/liability placeholders + **redeploy the portal**; **licensed-vet review** of the first-aid cards.
4. Optional: `SENTRY_DSN` in the build (tester crash visibility); purge QA test data if launching on this shared project.

## 10. Final decision

**Should PawDoc now be uploaded to Google Play Internal Testing? — YES, WITH CONDITIONS.**

The app is stable and safe on real hardware: it completes the full first-time journey, the AI triage is correct across severities and never fabricates or reassures, the emergency path is offline-capable, and it survives deliberate abuse without crashing. This pass **caught a safety-critical defect (offline Emergency unreachable) and fixed it** — which is exactly what a final QA is for. The conditions are (a) shipping the AAB built from this fixed code and (b) the founder Play-console + RevenueCat + legal/vet items — none of which is app-quality.

**"Would I trust it with my own pet?"** — For a controlled internal test, **yes**, now that Emergency is reachable offline and the AI behaves conservatively. I would want the **licensed-vet sign-off on the first-aid content** before trusting it broadly with strangers' pets — but the product's instinct (err safe, push to a vet, never diagnose, never reassure) is sound, and it held up under real use.
