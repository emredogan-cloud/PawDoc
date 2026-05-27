# SUB-PR Report — Phase 1.2: Capture & Upload Pipeline

**Status:** Built and **verified headless** (analyze + 15 widget/unit tests + Node tests + structural CR checks). Camera + live R2 upload are device-side.
**Branch:** `phase-1.2-capture-upload` (from updated `main`, which now includes 0.1–1.3)
**Date:** 2026-05-27

---

## 1. Files created / modified

```
mobile/lib/src/onboarding/onboarding_flow.dart      5-screen wizard + analytics
mobile/lib/src/pets/pet.dart                        Pet model (pets table)
mobile/lib/src/pets/pets_repository.dart            CRUD + providers (RLS-scoped)
mobile/lib/src/pets/pet_form_screen.dart            add/edit
mobile/lib/src/pets/pets_list_screen.dart           list + soft-delete
mobile/lib/src/capture/image_compressor.dart        compress <2MB + EXIF/GPS strip (CR #7)
mobile/lib/src/capture/image_quality.dart           blur/lighting heuristics (overlay)
mobile/lib/src/capture/upload_service.dart          presigned-URL upload (CR #6)
mobile/lib/src/capture/camera_screen.dart           in-app camera + live hint + capture
mobile/lib/src/text_input/symptom_text_screen.dart  text input + char guidance
mobile/lib/src/analytics/analytics.dart             PostHog onboarding events
mobile/lib/src/{router/app_router,home/home_screen,config/env,main}.dart   wiring + PostHog init
mobile/ios/Runner/Info.plist                        NSCamera/NSPhotoLibrary usage strings
mobile/android/app/src/main/AndroidManifest.xml     INTERNET + CAMERA + READ_MEDIA_IMAGES
mobile/pubspec.yaml                                 camera, image, posthog_flutter, http, path_provider, permission_handler
mobile/test/{capture_test,pet_test,onboarding_test}.dart
supabase/functions/generate-upload-url/index.ts     presigned R2 PUT (CR #6)
supabase/functions/_shared/upload_key.{mjs,test.mjs}  key namespacing + tests
scripts/verify-phase-1.2.sh ; docs/runbooks/15-...md ; ENVIRONMENT_VARS.md
```

## 2. How EXIF stripping (CR #7) & presigned-URL security (CR #6) were implemented

**CR #7 — EXIF/GPS stripping** (`image_compressor.dart`): the captured JPEG is
decoded with the pure-Dart `image` package, then **`working.exif = img.ExifData()`**
(an empty metadata block) is assigned before re-encoding — so the output JPEG
carries no EXIF and, critically, **no GPS**. The image is also downscaled to ≤1600px
and JPEG-quality is stepped down until the result is **< 2MB**. A unit test
constructs an image with `imageIfd['Make']` + `gpsIfd['GPSLatitudeRef']`, runs the
compressor, and asserts the decoded output's `imageIfd` and `gpsIfd` are **empty**.
Corrupt input throws a clean `FormatException` (the `image` package otherwise throws
`RangeError`). Compression runs in a background isolate (`compute`) to avoid jank.

**CR #6 — presigned upload, no client R2 keys**: the Flutter client calls the
**`generate-upload-url` Edge Function** (`functions.invoke`), which holds the R2
credentials server-side, builds a **user-namespaced key** (`uploads/<userId>/<uuid>.jpg`,
validated/sanitized), and returns a **300-second presigned PUT URL** signed with
`aws4fetch` (`signQuery`). The client then `http.put`s the bytes straight to R2 and
gets back only the storage key. The repo is verified to contain **no R2 write
credentials or R2 endpoint** in `mobile/lib` (a `verify-phase-1.2.sh` check greps for
`R2_SECRET_ACCESS_KEY` / `r2.cloudflarestorage.com` and fails if present).

## 3. How to manually verify on a physical device (full steps: runbook 15)

1. **Backend:** `supabase functions deploy generate-upload-url`; set `R2_ACCOUNT_ID`,
   `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` as function secrets.
2. **Build:** `flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=… --dart-define=POSTHOG_API_KEY=…`.
3. **Camera permission:** tap "Take a photo" → iOS shows the `NSCameraUsageDescription`
   prompt / Android shows the CAMERA runtime prompt. Deny once to see the graceful
   "permission needed" screen, then allow.
4. **Quality + compression:** dark scene → live "Too dark" hint; blurry capture →
   Retake/Use-anyway dialog.
5. **Upload + security:** after capture, confirm the object at
   `uploads/<user>/<uuid>.jpg` in the R2 bucket; `aws s3 cp` it and run
   `exiftool` → **no GPS/Make/Model**; `ls -l` → **< 2,097,152 bytes**.
6. **Onboarding:** complete the 5 screens in < 2 min to the camera; confirm PostHog
   `onboarding_step_completed` + `onboarding_completed` events.

## 4. Tests executed & results

| Test | Result |
|------|--------|
| `flutter analyze` | No issues found |
| `flutter test` | **15 passed** — EXIF strip (CR #7), <2MB, corrupt-input, quality heuristics, Pet JSON, onboarding render, text-input gating, + 1.1 tests |
| `node --test upload_key.test.mjs` | **4 passed** — key namespacing, ext sanitize, bad-ext/bad-user rejection |
| `./scripts/verify-phase-1.2.sh` | exit 0 — 14 checks green |

## 5. Security checks

- **No R2 credentials in the client** (verified by grep); presigned PUT only (CR #6).
- **EXIF/GPS stripped** from every upload (CR #7, unit-tested).
- Uploads are **namespaced per user** (`uploads/<userId>/…`); the key is built from
  the authenticated `auth.uid()`, not client input.
- Pet CRUD is **RLS-scoped** (Phase 1.1 policies); inserts carry `user_id = auth.uid()`.
- Presigned URL TTL is **5 minutes**.

## 6. Known issues / scope notes

- **No AI** is invoked (per scope) — capture/text produce an input + a pet profile only.
- **Camera + live R2 upload are device-side** (headless env has no camera): the camera
  screen, real-time luma overlay, and the PUT-to-R2 round-trip are verified on a device
  per runbook 15. The compression/EXIF/quality *logic* is unit-tested headlessly.
- **OneSignal** is intentionally absent — Onboarding Screen 4 is UI only (wired in 2.1).
- Photo-library picking is permission-declared but the in-app camera is the primary path.

## 7. Risks

- Camera permission UX differs iOS↔Android (roadmap risk) — runbook 15 covers both.
- `image`-package CPU cost on very large captures is mitigated by `compute` + downscale.
- Real-time blur detection on the stream is deferred to capture-time (lighting is live);
  acceptable for MVP, can be enhanced in 2.1 polish.

## 8. Git branch

`phase-1.2-capture-upload`

## 9. Commit hash

Implementation commit: `fa848146ca2ed5ed291170afc619c7717653dfcb`.

## 10. Push confirmation

Pushed to `origin/phase-1.2-capture-upload`. Open PR: https://github.com/emredogan-cloud/PawDoc/pull/new/phase-1.2-capture-upload

## 11. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| 5-screen onboarding + pet setup | ✅ built | `onboarding_flow.dart`; render test; analytics events |
| Pet CRUD (RLS) | ✅ built | repository + form/list; round-trip test |
| Camera + quality overlay | ✅ built / device-verify | `camera_screen.dart` + `image_quality` (unit-tested) |
| Compress < 2MB + **EXIF strip (CR #7)** | ✅ DONE | unit test asserts <2MB + empty EXIF/GPS |
| R2 upload via **presigned URL (CR #6)** | ✅ built / device-verify | Edge Function + `upload_service`; no client keys (verified) |
| Text input + guidance | ✅ DONE | widget test (min-char gating) |
| PostHog onboarding events | ✅ built | `analytics.dart`; live verify on device |
| Onboard < 2 min to camera | ⏳ MANUAL | runbook 15 |

**Verified now:** the compression/EXIF/quality/pet logic, security properties, and compilation. **Device-side:** camera capture, the live R2 upload round-trip, and the onboarding timing.
