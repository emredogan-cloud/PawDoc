# Google Sign-In — Complete Setup Runbook (founder ops)

Next Evolution Phase 7 shipped the code path: a "Continue with Google" button
on the Sign In / Create Account screen (`google_sign_in` 7.x →
`supabase.auth.signInWithIdToken`). The button is **hidden until
`GOOGLE_WEB_CLIENT_ID` is provided at build time** — nothing breaks while the
steps below are pending. This document is EVERY action needed to make it live.

**TL;DR flow:** Google Cloud project → OAuth consent screen → 3 OAuth clients
(Android×2 SHA-1s + 1 Web) → Supabase dashboard (Google provider ON, Web
client id + secret, authorized ids) → build with
`--dart-define=GOOGLE_WEB_CLIENT_ID=…` → test on device → Play data safety
unchanged.

---

## 1. Google Cloud project (NOT Firebase)

Firebase is **not required**. `google_sign_in` on Android talks to Google
Identity Services via OAuth clients that live in a plain Google Cloud project.
(Firebase would only wrap the same OAuth clients; adding it buys nothing here
and adds a config file + SDK we don't ship.)

1. https://console.cloud.google.com → create (or reuse) a project, e.g.
   `pawdoc-prod`. ⚠️ A `pawdoc-prod` service-account key already exists in
   your local repo folder (`pawdoc-prod-*.json`, now gitignored) — so the
   project likely exists; use it.
2. APIs & Services → **OAuth consent screen**:
   - User type: **External**.
   - App name `PawDoc`, support email, developer contact.
   - App domain + privacy policy: use the live legal portal
     (`https://d1klm6zb1x23me.cloudfront.net/privacy` or the final
     pawdoc.app URL once DNS lands).
   - Scopes: only the defaults (`email`, `profile`, `openid`) — add nothing.
   - Publishing status: **In production** (leave "Testing" and Google will
     expire tokens weekly and cap testers at 100).

## 2. SHA certificate fingerprints (the part everyone gets wrong)

Android OAuth clients are keyed by `package name + SHA-1`. PawDoc needs **two**
Android clients because two different keys sign the app:

| Which key | Where it signs | How to get the SHA-1 |
|---|---|---|
| **Upload key** (local `upload-keystore.jks`) | Local release builds you sideload | `keytool -list -v -keystore mobile/android/app/upload-keystore.jks -alias upload` → SHA1 line (password: the one saved during PR #84 — it is NOT in git) |
| **Play App Signing key** | Every build users install from Play | Play Console → your app → **Test and release → Setup → App signing** → "App signing key certificate" → SHA-1 |

Debug builds: the debug keystore SHA-1
(`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey
-storepass android`) can be added as a third Android client if you want Google
sign-in inside `flutter run` sessions. Optional.

## 3. OAuth clients (APIs & Services → Credentials → Create credentials → OAuth client ID)

Create **three**:

1. **Android** — name `PawDoc Android (upload)`, package `app.pawdoc`,
   SHA-1 = upload-key SHA-1.
2. **Android** — name `PawDoc Android (Play signing)`, package `app.pawdoc`,
   SHA-1 = Play App Signing SHA-1.
3. **Web application** — name `PawDoc Web (Supabase)`.
   - No JS origins needed.
   - Authorized redirect URI:
     `https://zbxrvfunaylkscgvsllm.supabase.co/auth/v1/callback`
     (needed if browser-based Google OAuth is ever used; harmless for the
     native id-token flow).
   - **Copy the Client ID and Client Secret** — both are needed in Supabase,
     and the Client ID is the app's `GOOGLE_WEB_CLIENT_ID`.

Why a Web client for a mobile app: the native flow asks Google to mint an
**id token whose audience is the Web client id** (`serverClientId` in the
app). Supabase then validates that audience server-side. The Android clients
authorize the *device flow*; the Web client is the *token audience*.

## 4. Supabase dashboard

Project `zbxrvfunaylkscgvsllm` → Authentication → Providers → **Google**:

1. Toggle **Enabled** (config.toml already ships it enabled for local dev).
2. **Client ID** = the WEB client id. **Client Secret** = the Web client
   secret.
3. **Authorized Client IDs** (a.k.a. "Skip nonce check" list / additional
   client ids): add the WEB client id here too — this is the field
   `signInWithIdToken` validates against.
4. Save. No redeploy needed — auth config is live.

The existing DB trigger (GAP-D3) provisions `public.users` on first sign-in;
Google accounts need no extra schema work.

## 5. Doppler + build wiring

1. Doppler project `pawdoc`, configs `dev` + `prd`: add
   `GOOGLE_WEB_CLIENT_ID = <web client id ending .apps.googleusercontent.com>`.
2. Build/run commands gain one define (everything else unchanged):

```bash
doppler run -p pawdoc -c prd -- flutter build appbundle \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID \
  ... # existing POSTHOG/REVENUECAT/SENTRY defines
```

Without the define the button simply does not render — safe rollout.

## 6. Android specifics (already handled in code — verify only)

- No `google-services.json` (no Firebase). No manifest changes required —
  `google_sign_in` 7.x needs none for Android.
- minSdk requirement (21+) already satisfied.
- Google Play services must exist on the device (all certified devices; the
  plugin throws a catchable error on de-Googled phones and the app shows a
  friendly failure — the email flow remains).

## 7. Test matrix (device, MANUAL — headless env cannot run this)

1. Build a release APK signed with the **upload key**, sideload:
   - Fresh Google sign-in with terms accepted → lands on Home; Supabase
     Auth → Users shows a `google` identity; `public.users` row exists.
   - Cancel the sheet → calm return, no error banner.
   - Sign out → sign in again with the same Google account → same user.
2. Upload to **Internal testing**, install via Play (now signed by the Play
   key) → repeat step 1. If this fails while sideload works, the Play-signing
   SHA-1 client (step 3.2) is missing/typoed.
3. Optional strict branding: replace the self-drawn "G" badge
   (`_GoogleMark` in `sign_in_screen.dart`) with the official
   "Sign in with Google" asset from Google's brand page.

## 8. Play Console

- **Data safety**: no new declarations — Google Sign-In shares the same
  "account identifiers for app functionality" already declared for email auth.
- **App content → Login credentials for review**: add a Google test account
  or keep the email demo account; reviewers must be able to log in.

## 9. iOS (future — when an iOS build exists)

- Create an **iOS** OAuth client (bundle id) in the same project; add its
  REVERSED client id as a URL scheme in `Info.plist`; pass nothing extra in
  code (`google_sign_in_ios` reads the plist). Add the iOS client id to
  Supabase "Authorized Client IDs". Not needed for the Android launch.

## Troubleshooting quick table

| Symptom | Cause |
|---|---|
| `DEVELOPER_ERROR` / code 10 in logs | Package name or SHA-1 mismatch — almost always the missing Play-signing client (step 3.2) |
| Supabase 400 `invalid audience` | `GOOGLE_WEB_CLIENT_ID` ≠ the id configured in Supabase step 4.3 |
| Sheet opens, token null | Consent screen left in "Testing" with an unlisted account |
| Button not visible in app | `GOOGLE_WEB_CLIENT_ID` define missing from the build command |
