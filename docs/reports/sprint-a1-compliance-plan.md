# Sprint A1 — Apple Compliance + Privacy Hardening — PLAN

**Sprint:** A1 (first of three sprints in the Phase 1 stabilization plan)
**Date:** 2026-05-16
**Reference audit:** [`phase1-stabilization-plan.md`](phase1-stabilization-plan.md) §P0
**Scope:** App Store compliance + privacy manifest + permission strings +
ATT decision + medical-claim wording audit + disclaimer normalization

This sprint is purely defensive. No new features, no new monetisation,
no architectural changes. The output is **a binary that the App Store
will accept on first review** plus a paper trail explaining every
privacy choice.

---

## 1. Apple Compliance Strategy

Apple has three overlapping privacy requirements for App Store
submissions since May 2024:

1. **PrivacyInfo.xcprivacy** — a per-app manifest declaring (a) every
   data category collected, (b) every "required-reason API" used and
   why, (c) whether the app or any third-party SDK tracks the user
   across apps/websites.
2. **Usage descriptions** — every `NS*UsageDescription` string in
   Info.plist for every permission the app may request. iOS aborts
   with a runtime fault if a permission is requested without its
   string.
3. **App Tracking Transparency (ATT)** — a runtime prompt
   (`NSUserTrackingUsageDescription`) when the app reads the IDFA
   (`requestTrackingAuthorization()`). Required ONLY if the app or one
   of its SDKs actually reads IDFA; otherwise omitting the prompt is
   correct.

We will satisfy all three. Where Apple gives us a choice between
declaring more data or less, we'll declare less — fewer surfaces to
defend during a review and less work for the user to read.

---

## 2. Required-Reason API Mapping

Apple's `NSPrivacyAccessedAPITypes` covers four families of APIs that
historically have been used for fingerprinting. Apps must declare each
use with one of Apple's published reason codes.

Mapping what our SDKs use:

| API | Used by | Reason code | Justification |
|-----|---------|-------------|---------------|
| `UserDefaults` | `shared_preferences` (onboarding draft + flags) | **CA92.1** | Access info from the same app via user defaults |
| `FileTimestamp` | `image_picker` reads timestamps when picking from the library | **C617.1** | Display file timestamps to the user |
| `DiskSpace` | `sentry_flutter` checks before writing crash dumps | **E174.1** | Ensure sufficient disk space before writing |
| `SystemBootTime` | `sentry_flutter` derives uptime for crash reports | **35F9.1** | User-initiated bug report uses elapsed-since-boot |

We omit `ActiveKeyboards`, `MachAbsoluteTime`, and other categories
that don't apply.

---

## 3. Data Collection Declaration

For `NSPrivacyCollectedDataTypes`, we declare only what we actually
collect or transmit off-device. Linking each entry to its purpose:

| Data type | Linked to user | Used for tracking | Collection purpose |
|-----------|----------------|-------------------|---------------------|
| `EmailAddress` (`NSPrivacyCollectedDataTypeEmailAddress`) | Yes (auth identifier) | No | Authentication |
| `UserID` (`NSPrivacyCollectedDataTypeUserID`) | Yes (UUID from Supabase Auth) | No | Functionality (app uses it to scope user data) |
| `PaymentInfo` (`NSPrivacyCollectedDataTypePaymentInfo`) | Yes | No | Functionality (RevenueCat manages purchases; we never see the card) |
| `Photos` (`NSPrivacyCollectedDataTypePhotosorVideos`) | Yes (uploaded into per-user folder) | No | App Functionality |
| `CrashData` (`NSPrivacyCollectedDataTypeCrashData`) | No (anonymous) | No | App Functionality (diagnostic) |
| `PerformanceData` (`NSPrivacyCollectedDataTypePerformanceData`) | No | No | App Functionality (Sentry 10% traces) |
| `OtherDiagnosticData` (`NSPrivacyCollectedDataTypeOtherDiagnosticData`) | No | No | App Functionality |
| `OtherUserContent` (`NSPrivacyCollectedDataTypeOtherUserContent`) | Yes | No | App Functionality — the free-text symptom description |

We deliberately do NOT declare:
- `AdvertisingData` — we don't run ads
- `PreciseLocation` / `CoarseLocation` — we don't access location in
  Sprint A1 (Phase 3 vet finder would add this, but that's later)
- `DeviceID` (IDFA / advertising ID) — we don't read it (see §4)
- `HealthAndFitness` — pets aren't "health" by Apple's definition
- `SearchHistory`, `BrowsingHistory` — we don't have them

---

## 4. ATT Decision Analysis

**Conclusion: ATT prompt is NOT required and we will NOT add `NSUserTrackingUsageDescription`.**

The ATT framework (`AppTrackingTransparency.requestTrackingAuthorization`)
is required only when the app calls it — i.e., when the app needs the
IDFA for cross-app tracking, attribution networks, or third-party
advertising. Adding the prompt without actually needing IDFA is an
anti-pattern Apple has rejected in the past.

Per-SDK audit:

| SDK | IDFA used? | Notes |
|-----|------------|-------|
| `sentry_flutter` 8.11 | No | Uses `identifierForVendor` for crash deduplication. IFV is NOT IDFA and does not trigger ATT |
| `purchases_flutter` 8.4 | No | RevenueCat documented as not collecting IDFA in their privacy manifest. They use `appUserId` (our Supabase UUID) and StoreKit transactions |
| `onesignal_flutter` 5.2 | Configurable — defaults to off | OneSignal v3+ moved IDFA behind `setRequiresUserPrivacyConsent` / `setLocationShared`. v5 default is no IDFA access. We will not enable IDFA |
| `sign_in_with_apple` 6.1 | No | Apple's native SDK |
| `supabase_flutter` 2.8 | No | HTTP only |
| `image_picker` 1.1 | No | Native photo library API |
| `flutter_image_compress` 2.3 | No | Local-only |
| `shared_preferences` 2.5 | No | UserDefaults wrapper |
| `connectivity_plus` 6.1 | No | Reachability only |
| `intl` 0.19 | No | Pure Dart |
| `http` 1.2 | No | HTTP only |
| `crypto` 3.0 | No | Pure Dart hashing |

The mobile binary makes **zero** calls into `ATTrackingManager`. We
declare `NSPrivacyTracking = false` and `NSPrivacyTrackingDomains = []`
in the manifest. The App Store review tool's automated check will
pass.

If a future feature (e.g., a paid acquisition campaign with MMP
attribution) needs IDFA, we would (a) add the `NSUserTrackingUsageDescription`
string with copy explaining the use, (b) call `requestTrackingAuthorization`
at the appropriate contextual moment, (c) update the manifest to
declare the tracking. None of these apply for Sprint A1.

### 4.1 OneSignal hardening note

We will add an explicit comment in `onesignal_service.dart` that the
SDK is initialised without IDFA access. The current init call
(`OneSignal.initialize(appId)`) does not enable IDFA. Documented
explicit non-use is the strongest defence against an upgraded SDK
silently flipping the default.

---

## 5. iOS Permission Usage Descriptions

Two strings, both required for the Phase 1C analyze flow:

### `NSCameraUsageDescription`

```
PawDoc uses your camera so you can take a photo of your pet and get
instant triage guidance from the AI.
```

Rationale:
- States purpose ("photo of your pet")
- States benefit ("instant triage guidance")
- Uses "triage" — App Store-safe synonym for assessment
- No fear-inducing language
- 102 characters, well under Apple's 256 limit

### `NSPhotoLibraryUsageDescription`

```
PawDoc lets you pick an existing photo of your pet so the AI can give
you triage guidance without having to take a new picture.
```

Rationale:
- Explicit purpose
- Lower-friction framing ("without having to take a new picture")
- 134 characters
- No claim of diagnosis or treatment

We are NOT adding `NSPhotoLibraryAddUsageDescription` (we never write
to the user's library), `NSMicrophoneUsageDescription` (no audio in
1A), or location strings.

---

## 6. Medical-Claim Language Audit Strategy

We are a "triage information tool", not a medical device. Apple has
rejected health-app submissions for any of these strings in user-facing
copy:

| Risky term | Why | Safer alternative |
|------------|-----|---------------------|
| "diagnose" / "diagnosis" | Implies licensed-clinician work | "triage", "assessment" |
| "treatment" | Implies prescriptive intervention | "care", "next steps", "actions" |
| "cure" | Implies medical guarantee | (avoid entirely) |
| "prescribe" | Reserved for licensed vets | "recommend" (with caveats) |
| "medically accurate" | Claim of clinical authority | "based on our triage rules" |
| "guaranteed" | Strict liability trigger | "designed to" |
| "replace your vet" | Direct rejection trigger | "before you call the vet" |

### 6.1 Survey method

Grep the codebase for each risky term and review every hit:
1. User-visible Dart strings in `mobile/lib/features/**` + `mobile/lib/shared/widgets/**`
2. AI service prompt strings in `ai-service/app/prompts/**`
3. AI service emergency response actions in `services/safety.py`
4. Documentation (lower priority — only audit if user-visible)

### 6.2 Pre-audit findings (grep results)

Already surveyed during the Phase 1 audit. The only non-disclaimer hit
in user-visible strings is:

> `services/safety.py:103` — `"Stop any further at-home treatment."`

This is the first action in the EMERGENCY override response. The word
"treatment" is contextual ("what you're doing at home"), but Apple's
automated review tooling does keyword pattern matching, not context.
Soften to:

> `"Stop any at-home remedies or interventions."`

Same intent, no trigger word.

All other hits are inside the standard disclaimer (which uses "NOT a
diagnosis" framing) or in the AI's own system prompt (internal
guardrail; not user-visible).

### 6.3 Items we are NOT changing

- Result-screen disclaimer ("PawDoc provides triage guidance, not a
  veterinary diagnosis. Always consult a licensed veterinarian.") —
  the "NOT a diagnosis" framing IS the protective wording.
- The AI system prompt's "You do NOT diagnose. You do not prescribe.
  You triage and recommend." — internal guardrail, not user-facing.
- `services/safety.py` `"veterinary care immediately"` — appropriate
  in an emergency context.

---

## 7. Disclaimer Normalisation Strategy

Today:
- `analysis_result_screen.dart` has a fallback disclaimer constant
  inline (used when `result.disclaimerText.isEmpty`).
- `analysis_capture_screen.dart` has a separate hardcoded disclaimer
  string.

The Pydantic `AnalysisResult` schema in the AI service defines the
canonical `disclaimer_text` as a default — it always travels with the
API response. The mobile fallback is for defence against accidentally
empty values.

**Action:** Centralise the fallback in `mobile/lib/shared/widgets/disclaimer.dart`:
- `kCanonicalDisclaimer` — the canonical fallback string.
- `DisclaimerCaption` — a small Text widget styled consistently.

Both screens import + use the constant + widget instead of duplicating
the literal. The AI-service-supplied `disclaimer_text` continues to be
the source of truth on the result screen.

Why a widget, not just a constant? Consistency of styling (font size,
colour, line height). Phase 4 may want to tweak typography in one
place.

---

## 8. App Store Metadata Compliance

Sprint A1 does NOT submit to the App Store. It prepares the
metadata copy and review notes in `docs/app-store-metadata.md` so that
Phase 2 submission is a paste-not-write operation.

The doc will include:
- Title (≤ 30 chars): "PawDoc: Pet Health Triage"
- Subtitle (≤ 30 chars): "AI guidance when to vet"
- Promotional text (≤ 170 chars): no medical claims
- Description: emphasises triage, not diagnosis; lists disclaimer
- Keywords (100 chars): "pet,dog,cat,triage,vet,emergency,health,puppy,kitten,symptom,rabbit"
- Review notes: explicit "this is an information tool, all results
  carry a disclaimer, no medical claims, no remote care"

---

## 9. Per-SDK Privacy Manifest Inheritance

Apple takes the union of our app's manifest + each SDK's `PrivacyInfo.xcprivacy`.
Each SDK in our dep list MUST ship its own manifest as of May 2024.

| SDK | Has its own manifest? | Notes |
|-----|----------------------|-------|
| `sentry_flutter` 8.11 | ✅ Yes (bundled since 8.x) | |
| `purchases_flutter` 8.4 | ✅ Yes (RevenueCat 8.x) | |
| `sign_in_with_apple` 6.1 | ✅ Yes (Apple's reference) | |
| `onesignal_flutter` 5.2 | ✅ Yes (OneSignal 5.0+) | |
| `supabase_flutter` 2.8 | ✅ Yes (since 2.x) | |
| `image_picker` 1.1 | ✅ Yes (Flutter team's official plugin) | |
| `flutter_image_compress` 2.3 | ⚠️ Verify | Check the plugin's iOS folder |
| `shared_preferences` 2.5 | ✅ Yes | |
| `connectivity_plus` 6.1 | ✅ Yes | |
| `http` 1.2 | ✅ Yes (pure HTTP) | |
| `crypto` 3.0 | n/a | Pure Dart |
| `intl` 0.19 | n/a | Pure Dart |

If any of the iOS-native plugins lacks its own manifest, App Store
review issues a warning. The plugin maintainer must fix it; we cannot
declare on behalf of an external dep.

We will verify each in the iOS build step (Phase 2). The plan calls
out `flutter_image_compress` as the one to confirm — if missing, we
either (a) update to a newer version, or (b) document and accept the
warning if Apple's check doesn't reject.

---

## 10. Rejection-Risk Analysis

After Sprint A1 completes, the remaining App Store rejection vectors
are:

| Risk | Mitigation status after A1 | Residual |
|------|---------------------------|----------|
| Missing permission strings | ✅ Added | None |
| Missing privacy manifest | ✅ Added | None |
| Tracking declared inconsistently | ✅ Declared NO tracking, consistent | None |
| Medical-claim language in app | ✅ Audit pass | Periodic re-audit on copy changes |
| Medical-claim language in store metadata | ✅ Prepared draft | Submission step (Phase 2) |
| In-app purchase compliance | ⚠️ Paywall has price + renewal text + Maybe Later, but ToS/Privacy links missing | Sprint A2 (P0.4 in the plan) |
| Apple Sign-In presence | ⚠️ Gated by env flag, not yet configured in Supabase | Sprint A2 / operational |
| Subscription receipt validation | ✅ Via RevenueCat (no DIY receipt validation needed) | None |
| Reviewer can sign in to test | ⚠️ Need a test account configured for App Store review notes | Phase 2 |

Sprint A1 closes the privacy + permission + language vectors. The
remaining items move to A2 + Phase 2 work.

---

## 11. Files Added / Modified

### Added
```
mobile/ios/Runner/PrivacyInfo.xcprivacy            new privacy manifest
mobile/lib/shared/widgets/disclaimer.dart          centralised disclaimer
docs/reports/sprint-a1-compliance-plan.md          (this file)
docs/reports/sprint-a1-compliance-implementation.md (post-impl)
docs/app-store-metadata.md                         metadata draft
```

### Modified
```
mobile/ios/Runner/Info.plist                       + NSCameraUsageDescription + NSPhotoLibraryUsageDescription
mobile/ios/Runner.xcodeproj/project.pbxproj        + PrivacyInfo.xcprivacy resource registration
mobile/lib/features/analysis/analysis_capture_screen.dart   uses centralised disclaimer
mobile/lib/features/analysis/analysis_result_screen.dart    uses centralised disclaimer
mobile/lib/shared/services/onesignal_service.dart  + explicit non-use comment
ai-service/app/services/safety.py                  soften "Stop at-home treatment"
```

### Not Touched
- Phase 1A migrations / RLS — none of this involves SQL
- AI orchestrator core — language audit doesn't change behaviour
- Mobile auth / paywall / RevenueCat code — separate sprint
- Test infrastructure — analyzer + existing tests must still pass

---

## 12. Validation

Before commit:
- `flutter analyze --fatal-infos --fatal-warnings` → 0 issues
- `flutter test` → all green (84/84 from Phase 1D + any new disclaimer
  widget test)
- `plutil -lint mobile/ios/Runner/Info.plist` → OK
- `plutil -lint mobile/ios/Runner/PrivacyInfo.xcprivacy` → OK (the
  manifest is a plist file)
- `make lint && make test` → Phase 0/1B/1C/1D gates intact
- ai-service `pytest` → still passes after safety.py wording change
- Grep audit: zero hits for risky terms in `mobile/lib/features/**`
  and `mobile/lib/shared/widgets/**` user-visible strings

---

## 13. Definition of Done

- A submitted-to-TestFlight iOS build would pass Apple's automated
  privacy check.
- A reviewer sampling user-visible strings finds none of the
  prohibited medical-claim terms.
- The disclaimer is consistent across capture + result screens.
- Documentation traces every privacy choice + every wording change.
- All existing tests pass.
- App Store metadata copy is drafted (not submitted).

---

*End of Sprint A1 plan. Implementation follows.*
