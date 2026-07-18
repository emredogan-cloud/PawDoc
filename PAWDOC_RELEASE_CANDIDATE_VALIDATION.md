# PawDoc — Release Candidate Validation

**Date:** 2026-07-18 · **Branch:** `feat/release-candidate` (off `main` @ `b959523`, the merged Final Evolution program) · **Device:** Redmi Note 8 (`M1908C3JGG`), Android 11, 1080×2340 @ 440 dpi, real hardware over ADB.
**Companion reports:** `PAWDOC_PRODUCT_EXPANSION_ROADMAP.md` (Appendix A) · `PAWDOC_ENVIRONMENT_AUDIT.md` (Appendix B).

> **Verdict in one line:** **YES, WITH CONDITIONS** for Android closed beta and Google Play; **NOT YET** for the Apple App Store (iOS has never been built or run on hardware in this project). Engineering is release-quality — every remaining blocker is a founder-held credential, console action, or deploy. A fresh release build installs and runs correctly on real hardware, and the RC pass fixed every Critical/High UX defect found.

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

## 2. Bugs found and fixed (this RC)

A subagent audited all 20 screens; the on-device run found the first item. **Every Critical/High is fixed**; the fixes ship on this branch, `analyze` clean and **222 tests green (+6 new)**.

| Sev | Bug | Fix |
|---|---|---|
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

1. **Authenticated flows** (home, in-app emergency tap-through, pet create/edit/delete, AI guidance, reminders, vaccinations, weight trend, prep pack, delete-account). **Blocked by a stale backend schema, not by app code.** Signup returned `{"code":"unexpected_failure","message":"Database error querying schema"}`; PostgREST introspection of the hosted **dev** project proves it is **pre-evolution**: `analyses.triage_level` still exists (with a live `EMERGENCY` row) and `referrals`/`family_members` tables are present, while `analyses.action` and `users.accepted_terms_at` **do not exist**. The evolution migrations were never `supabase db push`ed to dev. I did **not** push migrations to a live DB holding real data — that is a founder-gated deploy. Once the beta project is migrated, these flows are testable (§4 checklist).
2. **Purchases / paywall purchase / restore / manage-subscription** — the dev build has no RevenueCat SDK key and no products/offerings exist. Purchase logic is unit-covered; a live sandbox purchase is a founder pass.
3. **iOS — entirely.** No macOS/iOS device exists in this environment; iOS has never been built or run on hardware in the project's history. The iOS submission wiring (scheme, encryption flag, SIWA entitlements) is in code but unverified on a device.

These are exactly the mission's allowed external blockers (unavailable infra / production credentials / no iOS device), documented rather than faked.

---

## 4. Founder on-device checklist (once the beta backend is migrated + signed)

Do these after `supabase db push` to the beta project and a signed build:
- [ ] Signup → onboarding → home renders; **tap the red Emergency button offline (airplane mode)** → maps deep link, poison-control dial, first-aid cards, **no paywall**.
- [ ] Create / edit / delete a pet; add weight → trend chart; add a vaccination → reminder auto-created; **notification permission asked contextually**; fire/receive a local reminder.
- [ ] Run a text check → action-ladder result (no "normal", no condition name); build a Vet Visit Prep Pack and share it.
- [ ] Paywall → **sandbox** purchase → entitlement; Restore Purchases; Manage Subscription deep link.
- [ ] Analytics toggle in Account actually gates PostHog; delete-account cascades (and now purges RevenueCat).
- [ ] Repeat the whole pass on a **physical iOS device** (first-ever iOS run).

---

## 5. Environment readiness (headlines — full detail in Appendix B)
Dev Doppler is evolution-clean (14 slots). **Prod** needs attention: **6 legacy secrets** for removed features still present (OneSignal/OpenAI/Places/Resend/invite-link — delete); **Apple sign-in is `enabled=true` but its secrets are missing in prod** (iOS blocker); `SENTRY_DSN`, `POSTHOG_*`, and `ANON_IP_SALT` are unset (quality/privacy, non-blocking — verified to degrade cleanly); `TURNSTILE_SECRET_KEY`/`AI_SERVICE_URL` are *founder-verify* on the project. **~72% production-env readiness.**

---

## 6. Final verdict — the five questions, answered with evidence

**1. Is PawDoc technically production-ready?**
**Yes, at the code level.** `flutter analyze` clean, 222 Flutter tests, 159 pytest, 59 node, ruff clean; the full-migration RLS + deletion-cascade suite is a required CI job; a release APK builds and **runs correctly on real hardware** (first run of the current package). The action-ladder safety invariant is tested at three layers and the golden set holds 0 false negatives on `GET_HELP_NOW`. What stands between "code-ready" and "in production" is entirely founder ops: signing, backend deploys/migrations, and env provisioning.

**2. Is PawDoc ready for closed beta?**
**Yes, with conditions.** The app is beta-quality and every Critical/High defect is fixed. Conditions before a closed **Android** beta: push migrations to the beta Supabase project (the exact gap that blocked on-device auth here), produce a signed build, wire a RevenueCat SDK key, and run the §4 device pass. None is engineering work.

**3. Is PawDoc ready for Google Play submission?**
**Yes, with conditions — no code blocker.** Needs: a release keystore + Play App Signing (the standing debug-signing item), the Data Safety form (scope is now small — no location, no ad SDKs, no OneSignal, analytics opt-in), store listing + new-UI screenshots, and the deploys above. Store metadata is already rebuilt and overclaim-guarded.

**4. Is PawDoc ready for Apple App Store submission?**
**Not yet.** iOS has never been built or run on hardware in this project, and **Apple sign-in is enabled server-side but unprovisioned in prod** (`SUPABASE_AUTH_EXTERNAL_APPLE_*` missing) — it would fail at runtime and SIWA is required when other social login is offered. Required before submission: an iOS build + signing/provisioning on a Mac, provision the Apple auth secrets, and a full physical-device pass. iOS is the weakest readiness axis.

**5. What founder-controlled blockers remain?**
Ordered, all founder-held:
1. **Deploys** — `supabase db push` (beta + prod), redeploy the 6 Edge Functions and delete the removed ones, `fly deploy` the AI service.
2. **Signing** — Android release keystore + Play App Signing; iOS signing/provisioning on a Mac.
3. **RevenueCat** — products/offerings/entitlement + sandbox test + review demo account; inject the platform SDK key at build.
4. **Env provisioning** — Apple auth secrets (prod); verify `AI_SERVICE_URL`/`AI_SERVICE_TOKEN`/`TURNSTILE_SECRET_KEY` on the project; add `ANON_IP_SALT`, `SENTRY_DSN`, `POSTHOG_*` if wanted; **delete the 6 legacy prod slots**.
5. **Legal/business (calendar critical path)** — attorney sign-off (Terms/Privacy + age bracket), **vet review of the 5 first-aid cards**, E&O insurance, entity/EU-rep/DSAR, R2 retention decision.
6. **Device passes** — the §4 Android checklist **and** a first-ever physical iOS pass.
7. **Store consoles** — category/age, Data Safety / privacy labels, screenshots, EN/DE listings, review notes, then the review cycles.
8. **Domain** (optional) — pawdoc.app, then fold legal into `web/` and retire the AWS stack.

---

### Bottom line
PawDoc is an **engineering-complete release candidate**. The RC pass proved the release build runs on real hardware, closed every Critical/High UX defect, fixed a silent GDPR-deletion gap, and produced an evidence-backed map of exactly what the founder must do next. **Enter production after the founder-controlled tasks above — YES, WITH CONDITIONS** (Android/Play first; iOS after its first device pass and Apple-auth provisioning).
