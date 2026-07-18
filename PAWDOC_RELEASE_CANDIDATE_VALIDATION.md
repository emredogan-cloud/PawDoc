# PawDoc — Release Candidate Validation

**Date:** 2026-07-18 · **Branch:** `feat/release-candidate` (off `main` @ `b959523`, the merged Final Evolution program) · **Device:** Redmi Note 8 (`M1908C3JGG`), Android 11, 1080×2340 @ 440 dpi, real hardware over ADB.
**Companion reports:** `PAWDOC_PRODUCT_EXPANSION_ROADMAP.md` (Appendix A) · `PAWDOC_ENVIRONMENT_AUDIT.md` (Appendix B).

> **Verdict in one line:** **YES, WITH CONDITIONS** for Android closed beta and Google Play; **NOT YET** for the Apple App Store (iOS has never been built or run on hardware in this project). A fresh release build installs and runs on real hardware, and — after the infrastructure was brought into alignment with the repo (§1.5) — the device now completes a **full authenticated end-to-end journey**: sign in → home → describe symptoms → **real AI analysis** → action-ladder result saved to history → **offline emergency path**. The RC pass fixed every Critical/High UX defect plus a production AI bug that made every analysis silently degrade. Remaining blockers are founder-held (Apple/iOS, RevenueCat products, attorney/E&O/vet review, store consoles).

> **Update (infrastructure authorized mid-mission):** the founder authorized rebuilding the dev/beta database and deploying. That cleared the one blocker that had stopped authenticated on-device testing. §1.5 and §3 now reflect a **completed** E2E, not a blocked one.

---

## 1. What was validated, and how

This was a *fresh* validation: a new **release** APK built from current source (not a reused artifact), installed clean on a physical device, then driven and screenshotted over ADB, with `uiautomator` used to read exact element state and `logcat` scanned for crashes.

### 1.1 Release build — PASS
- `flutter build apk --release` with Doppler `dev` secrets → **`app-release.apk`, 114.8 MB** (universal, all ABIs), built clean (icon tree-shaking 99%+). This exercises R8/resource-shrinking and the release config — the paths that debug/analyze/test never touch.
- **Signing:** still the debug key (the known founder item — a release keystore + Play App Signing are not yet created). Debug-signed installs fine for validation; it is a Play-upload blocker, not a code defect.
- Installed as `app.pawdoc` — note the device previously carried only the **old `com.kindredpaws.kindredpaws` package**, so this was a genuine first run of the current app id.

### 1.2 On-device, unauthenticated surfaces — PASS
| Check | Result | Evidence |
|---|---|---|
| Fresh launch, no crash | ✅ | `MainActivity` resumed; logcat `fps=59.9–60.2`; no exceptions |
| Sign-in screen render | ✅ | logo, headline "Know when to call the vet.", email/password, encryption card — clean on real hardware |
| Consent defaults | ✅ | both checkboxes **default OFF** (analytics opt-in, Terms assent) — Phase 7 confirmed on device |
| **Assent gate (LEG-03)** | ✅ | `uiautomator`: "Create account" is `enabled=false` until Terms is checked, then flips to `enabled=true` |
| Legal links open + render | ✅ | tapping "Terms" opened the live CloudFront portal in Chrome; **all 15 legal pages return HTTP 200 over HTTP/2** with HSTS-preload + `nosniff`; back returns to the app |
| Terms page honesty | ✅ | the page itself declares "Attorney review pending … not yet reviewed by a licensed attorney" — correct posture |
| Graceful failure | ✅ | a transient device DNS blip produced a dismissible error, **no crash**; connectivity then confirmed reaching Supabase |

### 1.3 Emergency path
The offline emergency router (157 EN/DE keywords, 3-way parity), first-aid content, and the "never paywalled" rule are **CI-verified** (widget + parity + golden-set tests). On-device they sit behind auth, so an end-to-end device tap-through is deferred to the founder pass once a beta session exists (§4). Nothing changed on those surfaces in this RC — the project's "never add to the emergency screen" rule was respected.

---

### 1.5 Infrastructure brought into alignment + full authenticated E2E — PASS

The founder authorized rebuilding the dev/beta environment (no production users; repo = source of truth). Executed and verified:

| Step | What / evidence |
|---|---|
| **DB migration state diagnosed** | The hosted dev history recorded `20260717120000` (evolution subtraction) as *applied*, yet `referrals`/`family_members`/`triage_level` still existed — a **corrupted migration record**. That was the root cause of the earlier `Database error querying schema` on signup. |
| **Clean rebuild** | Dropped + recreated the `public` schema (Supabase default grants restored) and applied **all 26 repo migrations in order** via the Management API. Verified end-state: `analyses.action` present, `triage_level`/`referrals`/`family_members` gone, `users.accepted_terms_at` present, signup trigger live, history = 26. |
| **Auth confirmed** | Dev Auth API now issues a JWT on signup; the DB trigger provisions the `public.users` row. |
| **Edge Functions synchronized** | All 6 repo functions deployed to dev (`analyze`, `analyze-anonymous`, `delete-account`, `generate-pdf-report`, `generate-upload-url`, `revenuecat-webhook`); 6 stale `[functions.*]` declarations (referral/crons/vet-finder/journals/family) removed from `config.toml` so `functions deploy` stops choking on deleted entries. |
| **AI service verified** | Fly `pawdoc-ai` healthy (2 machines, `/health` 200); redeployed with the timeout fix below. |

**Full E2E on the device (all screenshotted):** fresh install → **sign in** → **home** (real pet, quota line "Text checks free · 5 of 5 photo logs left") → **Check Rex → Describe symptoms** → a **real Gemini/Claude analysis** returned `CALL YOUR VET TODAY` with a plain-language observation (no diagnosis), *what a vet looks for*, a 6-step *what to do*, timing, the **API-injected disclaimer**, and **"Saved to Rex's history"** → back home → **offline (airplane) Emergency path**: the red screen, Find-an-emergency-vet, Call-poison-control, and all 5 first-aid cards rendered **with the radio off**. This is the mission's core success criterion, met on real hardware.

## 2. Bugs found and fixed (this RC)

A subagent audited all 20 screens; the on-device run found several items; the live E2E found the AI bug. **Every Critical/High is fixed**; the fixes ship on this branch — Flutter `analyze` clean + **222 tests**, ruff clean + **159 pytest**, **59 node**.

| Sev | Bug | Fix |
|---|---|---|
| **CRITICAL** | **Every AI analysis silently returned the safe-degrade fallback** ("We can't analyze this right now"). Fly logs showed both tiers failing on every call: Gemini's 8s deadline is **below its API's 10s minimum** → instant HTTP 400; Claude's 8s timeout was **too short for a Sonnet tool_use response** → timeout. The stubbed unit tests couldn't catch it — only a real call did. | Gemini timeout → 12s (API floor + headroom), Claude → 15s (fits a real response), both under the Edge 25s budget; survivability tests updated to guard the 10s Gemini floor. **Redeployed to Fly and re-verified**: a real limping-dog check now returns `CALL_TODAY` with full v2 guidance. |
| **HIGH** | Sign-in showed users the **raw exception** (`SocketException: Failed host lookup: <project>.supabase.co`, then a raw `{"code":"unexpected_failure"…}` server body) — supabase-dart wraps both in `AuthException.message` and the UI printed it verbatim | New `friendly_error.dart` maps transport/server detail to calm copy; sign-in + reset routed through it; **unit-tested** |
| **HIGH** | Reminders: the trailing **bell** on upcoming rows called delete **immediately, no confirmation** — silent data loss behind a misleading icon | Clear trash icon + confirmation dialog (matches every other delete) |
| **HIGH** | Raw ladder wire tokens (`GET_HELP_NOW`, `CALL_TODAY`) rendered in the **pets-list chip**, home fallback, and prep pack | New `action_labels.dart` single friendly-label source; timeline chip refactored onto it too |
| MED | History/reminders load errors rendered raw `$e` | friendly copy via `friendlyLoadError` |
| MED | Paywall plan title could `RenderFlex`-overflow at the 1.6× text clamp | title made `Flexible` + ellipsis |
| MED | Two **dead affordances** (a non-tapping "+" on symptom prompts; a targetless "Learn more") | removed |
| MED | Camera offline-banner and lighting chip could overlap; capture labels could overflow at 1.6× | stacked in one column; labels wrapped `Flexible` |
| MED | `delete-account` read `REVENUECAT_SECRET_API_KEY` but the provisioned slot is `REVENUECAT_API_KEY` → the GDPR RevenueCat purge **silently no-op'd** | code aligned to `REVENUECAT_API_KEY` (legacy fallback kept) |

Deferred (MEDIUM/LOW, cataloged in Appendix A, none a submission blocker): design-system convergence for 3 legacy-styled screens, `maxContentWidth` tablet sweep, typography-token drift, onboarding-pill height at 1.6×.

---

## 3. What could NOT be validated on-device — and why (honest gaps)

The authenticated-flow gap from the first pass is **now closed** — after the dev DB rebuild (§1.5) the device completes the full journey including a real AI check. What remains genuinely unverifiable here:

1. **Purchases / paywall purchase / restore / manage-subscription** — the dev build has no RevenueCat SDK key and no products/offerings exist. Purchase logic is unit-covered; a live sandbox purchase needs the RevenueCat dashboard + store setup (founder).
2. **iOS — entirely.** No macOS/iOS device exists in this environment; iOS has never been built or run on hardware in the project's history. The iOS submission wiring (scheme, encryption flag, SIWA entitlements) is in code but unverified on a device — and **Apple sign-in is enabled server-side but unprovisioned in prod** (`SUPABASE_AUTH_EXTERNAL_APPLE_*` missing).
3. **A few record micro-features** not individually tapped in this pass (edit/delete pet, weight chart, vaccination→reminder, prep-pack share) — the underlying tables/RLS are rebuilt and the read/write paths proven by the pet-create + analysis-persist + history flows; a founder tap-through is a quick confirmation, not a risk.

These are exactly the mission's allowed external blockers (no iOS device, RevenueCat/store setup), documented rather than faked.

---

## 4. Founder confirmation checklist (dev E2E already passed here)

The Android auth + AI + offline-emergency journey is **validated on-device against the rebuilt dev backend**. Remaining founder confirmations — the items this environment can't reach:
- [x] ~~Sign in → home → text check → action-ladder result saved → offline Emergency path~~ **(done on-device this pass)**.
- [ ] Fresh **signup** flow on a clean beta build (the assent gate + analytics-off default were verified via uiautomator; the account-create round-trip is proven via API — worth one manual tap-through).
- [ ] Record micro-features: create/edit/delete pet, weight → trend chart, vaccination → auto-reminder, contextual notification permission, prep-pack share.
- [ ] Paywall → **sandbox** purchase → entitlement; Restore Purchases; Manage Subscription deep link (needs RevenueCat products).
- [ ] Analytics toggle actually gates PostHog; delete-account cascade (now purges RevenueCat).
- [ ] The whole pass on a **physical iOS device** (first-ever iOS run) + provision Apple auth secrets.
- [ ] Point beta/prod builds at the **prod** Supabase and repeat `db push` there (the rebuild here was the **dev** project).

---

## 5. Environment readiness (headlines — full detail in Appendix B)
Dev Doppler is evolution-clean (14 slots). **Prod** needs attention: **6 legacy secrets** for removed features still present (OneSignal/OpenAI/Places/Resend/invite-link — delete); **Apple sign-in is `enabled=true` but its secrets are missing in prod** (iOS blocker); `SENTRY_DSN`, `POSTHOG_*`, and `ANON_IP_SALT` are unset (quality/privacy, non-blocking — verified to degrade cleanly); `TURNSTILE_SECRET_KEY`/`AI_SERVICE_URL` are *founder-verify* on the project. **~72% production-env readiness.**

---

## 6. Final verdict — the five questions, answered with evidence

**1. Is PawDoc technically production-ready?**
**Yes** — and now demonstrated, not just asserted. Beyond green suites (`flutter analyze` clean, 222 Flutter / 159 pytest / 59 node, the full-migration RLS + deletion-cascade CI job, golden set 0 FN on `GET_HELP_NOW`), the **dev environment was rebuilt to match the repo and the device completed a real end-to-end journey** including a live Gemini/Claude analysis and the offline emergency path. A production AI bug that would have shipped ("AI always degrades") was caught by that live test and fixed. What stands between here and production is founder ops: signing, the same deploy against prod, and store/legal steps.

**2. Is PawDoc ready for closed beta?**
**Yes, with conditions.** The Android app is beta-quality and **validated working end-to-end on real hardware** against a repo-aligned backend. Conditions before a public closed beta: repeat the (now-proven) `db push` + Edge/Fly deploy against the **prod/beta** project, a signed build, and RevenueCat products. All are ops, not engineering — and the deploy path is now a known-good, executed procedure.

**3. Is PawDoc ready for Google Play submission?**
**Yes, with conditions — no code blocker.** Needs: a release keystore + Play App Signing (the standing debug-signing item), the Data Safety form (scope is now small — no location, no ad SDKs, no OneSignal, analytics opt-in), store listing + new-UI screenshots, and the deploys above. Store metadata is already rebuilt and overclaim-guarded.

**4. Is PawDoc ready for Apple App Store submission?**
**Not yet.** iOS has never been built or run on hardware in this project, and **Apple sign-in is enabled server-side but unprovisioned in prod** (`SUPABASE_AUTH_EXTERNAL_APPLE_*` missing) — it would fail at runtime and SIWA is required when other social login is offered. Required before submission: an iOS build + signing/provisioning on a Mac, provision the Apple auth secrets, and a full physical-device pass. iOS is the weakest readiness axis.

**5. What founder-controlled blockers remain?**
Ordered, all founder-held:
1. **Deploys** — **dev is done** (DB rebuilt to 26 migrations, 6 Edge Functions deployed, AI service redeployed + verified). Repeat the same known-good procedure against **prod/beta**; delete the obsolete deployed functions + legacy prod secrets there too.
2. **Signing** — Android release keystore + Play App Signing; iOS signing/provisioning on a Mac.
3. **RevenueCat** — products/offerings/entitlement + sandbox test + review demo account; inject the platform SDK key at build.
4. **Env provisioning** — Apple auth secrets (prod); verify `AI_SERVICE_URL`/`AI_SERVICE_TOKEN`/`TURNSTILE_SECRET_KEY` on the project; add `ANON_IP_SALT`, `SENTRY_DSN`, `POSTHOG_*` if wanted; **delete the 6 legacy prod slots**.
5. **Legal/business (calendar critical path)** — attorney sign-off (Terms/Privacy + age bracket), **vet review of the 5 first-aid cards**, E&O insurance, entity/EU-rep/DSAR, R2 retention decision.
6. **Device passes** — the §4 Android checklist **and** a first-ever physical iOS pass.
7. **Store consoles** — category/age, Data Safety / privacy labels, screenshots, EN/DE listings, review notes, then the review cycles.
8. **Domain** (optional) — pawdoc.app, then fold legal into `web/` and retire the AWS stack.

---

### Bottom line
PawDoc is an **engineering-complete release candidate, now proven end-to-end on real hardware.** This pass rebuilt the dev backend to match the repo, deployed the Edge Functions and AI service, drove a live authenticated journey (sign-in → real AI analysis → saved record → offline emergency), and along the way caught and fixed a production bug that would have made every AI analysis silently degrade — plus every Critical/High UX defect and a silent GDPR-deletion gap. The remaining work is founder-held: the same (now-executed) deploy against prod, release signing, RevenueCat products, attorney/E&O/vet review, store consoles, and a first-ever iOS device pass. **Enter production after those — YES, WITH CONDITIONS** (Android/Play first; iOS after its first device pass and Apple-auth provisioning).
