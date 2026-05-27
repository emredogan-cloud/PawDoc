# 15 — Verify capture & upload on a physical device

Phase 1.2 produces an analysis *input* (an R2 key or text) — no AI yet.

## 0. One-time backend setup

Deploy the presigned-URL function and give it the R2 secrets (these stay
server-side — CR #6):
```bash
supabase functions deploy generate-upload-url --project-ref <ref>
supabase secrets set --project-ref <ref> \
  R2_ACCOUNT_ID=...  R2_ACCESS_KEY_ID=...  R2_SECRET_ACCESS_KEY=...  R2_BUCKET=pawdoc-uploads-dev
```

Build the app with config (Supabase + PostHog) via `--dart-define`:
```bash
cd mobile
flutter run --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=POSTHOG_API_KEY=$POSTHOG_API_KEY
```

## 1. Camera permission (iOS + Android)

- **iOS:** Home → “Take a photo”. The first time, iOS shows the permission prompt
  with our copy ("PawDoc uses the camera so you can take a photo of your pet…",
  from `NSCameraUsageDescription`). Allow → live preview appears.
- **Android:** same flow; the runtime CAMERA permission dialog appears (declared
  in `AndroidManifest.xml`). Deny once to confirm the graceful "permission needed"
  message; then allow in Settings and retry.

## 2. Quality overlay + compression

- Point at a dark scene → the **"Too dark"** hint appears (live, from the luma plane).
- Capture a blurry shot → after capture you get the **blurry/lighting** dialog
  (Retake / Use anyway).
- Capture a normal shot → it uploads.

## 3. Upload + security (CR #6 / #7)

After a successful capture, confirm in the Cloudflare R2 dashboard (or via S3 CLI):
```bash
# object exists under the user's namespace:
aws s3 ls "s3://pawdoc-uploads-dev/uploads/" --recursive --endpoint-url https://<acct>.r2.cloudflarestorage.com
# download it and confirm size < 2MB and NO GPS/EXIF:
aws s3 cp "s3://pawdoc-uploads-dev/uploads/<user>/<uuid>.jpg" /tmp/x.jpg --endpoint-url https://<acct>.r2.cloudflarestorage.com
exiftool /tmp/x.jpg | grep -iE 'gps|make|model' || echo "no EXIF/GPS — good"
ls -l /tmp/x.jpg   # < 2,097,152 bytes
```
- **CR #6 check:** grep the built app / source for R2 secrets — there are none; the
  client only ever calls `generate-upload-url` and PUTs to the returned URL.
- **CR #7 check:** `exiftool` shows no GPS/Make/Model on the uploaded object.

## 4. Onboarding + analytics

- Fresh sign-in → "Set up a pet" → complete the 5 screens. Target: **< 2 minutes**
  to the camera screen.
- In PostHog, confirm `onboarding_step_completed` (×4–5) and `onboarding_completed`.

> No AI is called in this phase — capture/text just produce an input + a pet profile.
> The camera→AI→result loop is wired in Phase 1.4.
