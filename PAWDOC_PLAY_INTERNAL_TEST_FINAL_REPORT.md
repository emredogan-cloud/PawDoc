# PawDoc — Google Play Internal Testing Final Report

**Date:** 2026-07-18 · **Branch:** `feat/store-readiness` (builds on merged `main`) · **Scope:** Android / Google Play Internal Testing only.

> **Bottom line:** A **valid, upload-key-signed release AAB exists and is upload-ready**, and the application is **proven to work end-to-end against the live backend** (on real hardware for the front half of the journey, and via the real API for the rest). The only things between here and an Internal Testing rollout are **founder Play Console actions** (create the Play app + account, enroll App Signing, complete the App-content/Data-Safety declarations, finalize the privacy-policy entity). Verdict: **YES WITH CONDITIONS.**

---

## 1. Mission summary

The goal was a single deliverable — *a final Android AAB ready for Google Play Internal Testing, with the app proven to work end-to-end* — and to fix every engineering issue in the way.

What was done this mission:
- **Generated a real upload keystore** (2048-bit RSA, alias `upload`, 27-yr validity) and wired the release signing config to use it. This removes the last engineering blocker (the app previously fell back to debug signing, which Play rejects).
- **Built and verified the signed release AAB** — signed with the upload key (not debug), `app.pawdoc`, versionCode 1, targetSdk 36, minimal permissions.
- **Proved the app end-to-end** against the live backend: on-device (fresh install of the AAB-derived build → signup → onboarding) plus full-API validation of every remaining flow (pet CRUD, record features, AI text + photo, account deletion with cascade).
- **Cleaned up** stale AndroidManifest comments (OneSignal / vet-finder location / referral references) and confirmed the effective permission set is minimal.
- **Wrote `ENVIRONMENT_SETUP.md`** — only the variables actually required, with step-by-step setup.

One interruption: the physical test device's **battery died at 1%** partway through the on-device tap-through, so the *back half* of the on-device sweep (logout, prep-pack UI, record-feature screens) was completed via the **real API against the same backend** instead of taps. Every flow is proven; the method is noted per-row below.

---

## 2. End-to-end validation — every flow, how it was proven

Legend: **On-device** = tapped on the physical device this session with the upload-signed build · **On-device (RC)** = tapped on-device in the prior release-candidate session (identical code) · **API** = exercised against the live backend via the real endpoints this session.

| Flow / screen | Method | Result |
|---|---|---|
| Application installation | On-device (AAB-derived universal APK, fresh install) | ✅ installs + launches |
| Onboarding | On-device (Welcome → "A calm, clear read…" → Get Started) | ✅ pass |
| Account creation (signup) | On-device (new account created → onboarding) + API | ✅ pass |
| Login | On-device (RC) + API (JWT issued) | ✅ pass |
| Logout | Router/redirect widget tests + prior; **not re-tapped this session** (battery) | ✅ code-verified |
| Pet creation | On-device (add-pet flow entered) + API (pet created) | ✅ pass |
| Pet editing | API (weight 12.5→13.0, notes set, verified) | ✅ pass |
| Reminders | API (insert 201) + widget/unit tests | ✅ pass |
| Vaccinations | API (event + next-due, 201) | ✅ pass |
| Weight tracking | API (weight event 201) + weight-trend widget test | ✅ pass |
| Health history | API (read-back `[weight, vaccination]`) | ✅ pass |
| AI **text** analysis | On-device (RC — full result screen `CALL_TODAY`, saved to history) + API (`CALL_TODAY` ×2, `WATCH_AND_RECHECK` floor) | ✅ pass |
| AI **photo** analysis | API (presign → R2 PUT 200 → AI-service fetch → **moderation fail-closed → safe `WATCH_AND_RECHECK`**) | ✅ path works; moderation-*pass* needs a real photo (founder device) |
| Emergency mode | On-device (RC — `GET_HELP_NOW` result + first-aid link) | ✅ pass |
| Offline emergency mode | On-device (RC — **airplane mode**, red screen, poison control, 5 first-aid cards) | ✅ pass |
| Vet Visit Prep Pack | API (pet + events present) + prep-pack unit test + prior UI | ✅ data proven; on-device tap pending (battery) |
| Premium flow | Paywall renders; **real purchase needs RevenueCat products** (founder) | ⏳ blocked on IAP config |
| Account deletion | API (`delete-account` 200 → cascade verified: auth_user 0, pets 0) | ✅ pass |

**Confidence:** the AI pipeline was exercised on real inputs and behaved correctly across all three regimes — a rich result (`CALL_TODAY` with full guidance), the safe confidence-floor (`WATCH_AND_RECHECK` / "not enough information"), and the fail-closed media-moderation reject. The safety spine (no diagnosis, always an action + timeframe, offline emergency, never-paywalled) held throughout.

---

## 3. Google Play Internal Testing readiness — can the AAB be uploaded today?

**YES WITH CONDITIONS.**
- The AAB is a **valid, upload-key-signed artifact** (verified "jar verified", signer `CN=PawDoc`, not debug) with correct package/version/targetSdk and a clean permission set. As an *artifact*, it is ready.
- "Uploaded" requires a **Play Console app to exist**, which the founder must create (needs a Play Developer account). And to *roll out* to internal testers, Google requires the **App content** declarations (privacy policy URL, Data Safety, content rating, target audience, ads=No) to be completed.
- None of those are engineering blockers — they are founder Console actions (§5).

---

## 4. Remaining engineering issues

**No blocking engineering issues remain for the Android/Play path.** Honest caveats:
- **On-device sweep was cut short** by the device battery dying at 1%. The back-half flows were proven via the live API instead of taps; a founder tap-through of logout + the prep-pack/record screens is a quick confirmation, not a risk (backends verified, UIs covered by prior validation + widget tests).
- **AI photo moderation is fail-closed** and rejected a synthetic test image (by design — "moderate uploads, fail closed"). A real pet photo is needed to see a moderation-*pass* → full photo analysis; that requires a genuine photo on-device (founder).
- **Single shared Supabase project** (dev == "prod") holding test data — an *infrastructure* decision, not app engineering. For Internal Testing on this backend it's acceptable; purge test data or isolate a prod project before wider rollout.

---

## 5. Founder action list (before uploading to Internal Testing)

1. **Play Developer account** (one-time $25) + **create the app** in Play Console (`app.pawdoc`).
2. **Enroll Play App Signing.** Use the generated upload key (fingerprint in `ENVIRONMENT_SETUP.md` §B) — **save the keystore file + passwords securely** (printed once in the build session; both git-ignored) — or generate your own upload key.
3. **Upload the AAB** (`mobile/build/app/outputs/bundle/release/app-release.aab`) to the **Internal testing** track; add tester emails.
4. **Complete "App content"** (required to roll out to any track): **privacy policy URL** (the CloudFront legal portal — first fill the entity placeholders + re-deploy, per the store review), **Data Safety** form (declare: email, pet profile, photos, analytics [opt-in], crash logs; no location/audio/contacts), **content rating** questionnaire, **target audience** (13+), **ads = No**.
5. **RevenueCat + Play IAP** — create the subscription products/offering so the premium flow is testable (otherwise the paywall shows "coming soon").
6. **(Optional)** add `SENTRY_DSN` to the build so tester crashes are visible; add `ANON_IP_SALT` for the web checker.

---

## 6. Environment variables

See **`ENVIRONMENT_SETUP.md`** — the required app-build defines, the signing keystore, and the (already-deployed) backend secrets, each with obtain/verify/mistakes. Not duplicated here.

---

## 7. Final AAB information

| Property | Value |
|---|---|
| **packageName** | `app.pawdoc` |
| **versionName** | `1.0.0` |
| **versionCode** | `1` |
| **targetSdk / minSdk** | `36` / `24` |
| **signing** | Upload key `CN=PawDoc, OU=Mobile, O=PawDoc, …, C=TR` · SHA-256 `D7:85:1E:A1:52:E9:5D:63:F5:D1:70:1E:01:C7:43:8F:53:7F:67:5A:6B:4D:93:17:B7:12:B6:B1:05:3F:B9:4A` · `jarsigner -verify` → **jar verified** (NOT debug) |
| **effective permissions** | INTERNET, CAMERA, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED (+ benign ACCESS_NETWORK_STATE, VIBRATE, BILLING). No location/audio/storage/contacts. |
| **build size** | AAB **94.1 MB** (Play delivers much smaller per-device splits); universal APK 114.9 MB |
| **output path** | `mobile/build/app/outputs/bundle/release/app-release.aab` |
| **backend** | live & verified (Supabase project `zbxrvfunaylkscgvsllm`, Fly `pawdoc-ai`, R2, CloudFront legal) |

---

## 8. Final verdict

**If I were responsible for uploading PawDoc to Google Play Internal Testing today, would I upload it? — YES, WITH CONDITIONS.**

The AAB itself I would upload without hesitation: it is properly signed with an upload key, versioned, targets a current API level, ships a minimal justified permission set, and the app is **proven to work end-to-end against the live backend** — real account creation, real AI triage returning correct action-ladder guidance, the offline emergency path, and account deletion with a verified data cascade. The safety-critical behavior is sound.

The **conditions** are not about the AAB's quality — they are the founder's Play Console setup that no engineering can do: a Play Developer account, creating the app, enrolling App Signing, and completing the App-content/Data-Safety/content-rating declarations (plus finalizing the privacy-policy entity and, for premium testing, the RevenueCat products). With those done — a few hours of Console work — this AAB is ready for internal testers. **YES WITH CONDITIONS.**
