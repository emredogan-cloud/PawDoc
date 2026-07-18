# PawDoc — Environment Setup (Google Play Internal Testing)

**Scope:** ONLY the variables actually required to build the signed Android AAB and run it against the live backend for **Google Play Internal Testing**. Removed services (OneSignal, OpenAI, Google Places, Resend, family-invite, referral crons) are **not** listed — they no longer exist in any code path and their Doppler/secret slots should be deleted.

**How it's organized:**
- **A. App build** — `--dart-define`s compiled into the AAB. *The founder sets these at build time.*
- **B. Android signing** — the upload keystore. *Already generated this session (see status).*
- **C. Backend** — Edge Function + AI-service secrets. *Already deployed and verified; listed for reference/verification only.*

> **Golden rule:** never commit real values. `key.properties`, `*.jks`, and `.env*` are git-ignored. Real values live in Doppler (`pawdoc` project).

---

## A. App build — `--dart-define` (compiled into the AAB)

### `SUPABASE_URL`
- **Used by:** the Flutter app (Supabase client — auth, DB, Edge Functions).
- **Required?** **YES.** Without it the app cannot reach the backend.
- **Current status:** ✅ set in Doppler (`dev` + `prd`), value `https://zbxrvfunaylkscgvsllm.supabase.co`. **Note:** dev and prd point at the *same* project (there is no isolated prod — see the final report).
- **Where to obtain:** Supabase dashboard → your project → **Project Settings → API → Project URL**.
- **Official URL:** https://supabase.com/dashboard/project/_/settings/api
- **Step-by-step:** copy *Project URL*; pass it as `--dart-define=SUPABASE_URL=…` at build.
- **Verify:** app reaches sign-in and a signup returns a JWT (not a "host lookup" error).
- **Common mistakes:** using the `db.…` connection host instead of the REST URL; trailing slash.
- **Example:** `--dart-define=SUPABASE_URL=https://YOURREF.supabase.co`

### `SUPABASE_ANON_KEY`
- **Used by:** the Flutter app (public, RLS-guarded auth/API key).
- **Required?** **YES.**
- **Current status:** ✅ set (`dev` + `prd`).
- **Where to obtain:** Supabase → **Project Settings → API → Project API keys → `anon` / `public`**.
- **Official URL:** https://supabase.com/dashboard/project/_/settings/api
- **Verify:** signup/login succeed on-device.
- **Common mistakes:** using the `service_role` key here — **never** ship service_role in the client.
- **Example:** `--dart-define=SUPABASE_ANON_KEY=eyJhbGciOi…` (a long JWT).

### `REVENUECAT_PUBLIC_SDK_KEY`
- **Used by:** the Flutter app (RevenueCat SDK → subscriptions / IAP).
- **Required?** **YES for the premium flow** (Internal Testing can test IAP). The app builds and runs without it, but the paywall shows "Premium is coming soon."
- **Current status:** ⏳ Doppler `prd` holds the platform-split keys `REVENUECAT_PUBLIC_SDK_KEY_ANDROID` / `_IOS`. For an **Android** build, inject the **Android** key as `REVENUECAT_PUBLIC_SDK_KEY`. Products/offerings still need to be created in RevenueCat + Play (founder — see report §5).
- **Where to obtain:** RevenueCat dashboard → **Project → API keys → Public app-specific key (Google Play)**.
- **Official URL:** https://app.revenuecat.com → Project settings → API Keys
- **Verify:** the paywall renders **real localized prices** (not "coming soon" / not the hardcoded `$39.99/$6.99`).
- **Common mistakes:** using the iOS public key for the Android build; using the *secret* key (that is server-side only).
- **Example:** `--dart-define=REVENUECAT_PUBLIC_SDK_KEY=goog_XXXXXXXX`

### `SENTRY_DSN` — *optional (recommended)*
- **Used by:** the Flutter app (crash/error reporting; PII-stripped).
- **Required?** OPTIONAL. No-op if unset (degrades cleanly, verified).
- **Current status:** ❌ not in Doppler. Recommended for Internal Testing so tester crashes are visible.
- **Where to obtain:** sentry.io → Project → **Settings → Client Keys (DSN)**.
- **Official URL:** https://sentry.io → Settings → Projects → Client Keys
- **Verify:** a forced test error appears in Sentry.
- **Example:** `--dart-define=SENTRY_DSN=https://xxxx@oyyy.ingest.sentry.io/123`

### `POSTHOG_API_KEY` + `POSTHOG_HOST` — *optional*
- **Used by:** the Flutter app (product analytics — only after the user **opts in**).
- **Required?** OPTIONAL. Analytics is off by default; unset = fully inert.
- **Current status:** ❌ not in Doppler. `POSTHOG_HOST` defaults to `https://us.i.posthog.com` if omitted.
- **Where to obtain:** PostHog → **Project Settings → Project API Key** (the `phc_…` project key).
- **Official URL:** https://us.posthog.com → Settings → Project
- **Common mistakes:** using the *personal* API key here (that is server-side, for the deletion purge).
- **Example:** `--dart-define=POSTHOG_API_KEY=phc_XXXX --dart-define=POSTHOG_HOST=https://us.i.posthog.com`

### `APP_VERSION` / `LEGAL_BASE_URL` — *optional*
- `APP_VERSION` — a display string; defaults are fine. `LEGAL_BASE_URL` — overrides the legal-portal base; defaults to the live CloudFront URL, so only set it once a custom domain exists.

**Canonical Android build command (Internal Testing):**
```bash
doppler run -p pawdoc -c prd -- bash -c 'flutter build appbundle --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=REVENUECAT_PUBLIC_SDK_KEY="$REVENUECAT_PUBLIC_SDK_KEY_ANDROID" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN" \
  --dart-define=POSTHOG_API_KEY="$POSTHOG_API_KEY"'
```

---

## B. Android signing — the upload keystore (build-time, NOT a dart-define)

The release signing config (`android/app/build.gradle.kts`) reads **`mobile/android/key.properties`** and auto-activates the release key when present.

### `mobile/android/key.properties` (git-ignored)
- **Used by:** Gradle at release build time to sign the AAB with your upload key. **Play rejects debug-signed AABs**, so this is required for upload.
- **Required?** **YES** for any Play upload.
- **Current status:** ✅ **Generated this session.** A 2048-bit RSA upload key (alias `upload`, 27-yr validity) was created at `mobile/android/app/upload-keystore.jks`, and `key.properties` points at it. **The SHA-256 fingerprint is `D7:85:1E:A1:52:E9:5D:63:F5:D1:70:1E:01:C7:43:8F:53:7F:67:5A:6B:4D:93:17:B7:12:B6:B1:05:3F:B9:4A`.** The passwords were printed once in the build session — **the founder must save the keystore file + passwords securely.** (Neither is committed; both are git-ignored.)
- **Fields (format):**
  ```
  storePassword=<your keystore password>
  keyPassword=<your key password>
  keyAlias=upload
  storeFile=upload-keystore.jks   # relative to mobile/android/app/
  ```
- **To generate your own instead** (recommended if you want full custody from the start):
  ```bash
  keytool -genkeypair -v -keystore upload-keystore.jks -alias upload \
    -keyalg RSA -keysize 2048 -validity 10000
  ```
  place it at `mobile/android/app/upload-keystore.jks` and fill `key.properties`.
- **Official URL (Play App Signing):** https://play.google.com/console → your app → **Setup → App integrity → App signing**.
- **Verify:** `jarsigner -verify build/app/outputs/bundle/release/app-release.aab` prints "jar verified" and the signer is `CN=PawDoc` (not `CN=Android Debug`).
- **Common mistakes:** committing the keystore/passwords (they are git-ignored — keep it that way); losing the keystore (with Play App Signing you can reset the *upload* key, but keep it safe); a wrong `storeFile` path.

> **Play App Signing:** on first upload, enroll in Play App Signing. Google holds the *app signing key*; you sign uploads with this *upload key*. If the upload key is ever lost, you can request a reset in the Console.

---

## C. Backend — already deployed & verified (reference / verification only)

These are **already set** on the Supabase project + Fly app and were verified working this session (real AI analysis, uploads, deletion). The founder does not set these to build the app; listed so they can be verified and rotated.

| Variable | Used by | Required | Status |
|---|---|---|---|
| `SUPABASE_SERVICE_ROLE_KEY` 🔒 | Edge Functions (admin writes / deletion) — never in the client | Yes | ✅ auto-injected |
| `AI_SERVICE_URL` / `AI_SERVICE_TOKEN` 🔒 | Edge `analyze` → Fly AI service (must match on both sides) | Yes | ✅ set |
| `ANTHROPIC_API_KEY` 🔒 | AI service (Tier-3 Claude) | Yes | ✅ set (Fly) |
| `GOOGLE_AI_API_KEY` 🔒 | AI service (Tier-2 Gemini) + moderation | Yes | ✅ set (Fly + Edge) |
| `R2_ACCOUNT_ID` / `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` / `R2_BUCKET` 🔒 | `generate-upload-url` (presigned photo PUT) | Yes (photo) | ✅ set |
| `REVENUECAT_WEBHOOK_SECRET` 🔒 | `revenuecat-webhook` (entitlement sync) | Yes (subs) | ✅ set |
| `REVENUECAT_API_KEY` 🔒 | `delete-account` (GDPR subscriber purge) | Optional | ✅ set |
| `TURNSTILE_SECRET_KEY` 🔒 | `analyze-anonymous` (web checker, fails closed) | Only if web checker used | ✅ set |
| `UPSTASH_REDIS_REST_URL` / `_TOKEN` 🔒 | rate-limit + AI kill-switch | Optional | ✅ set |
| `ANON_IP_SALT` | `analyze-anonymous` IP hashing | Optional (recommended) | ❌ unset (add for real salting) |

**Not needed for Internal Testing:** SMTP (auth emails — only if you enable email confirmation), and the iOS-only secrets (Apple auth, App Store Connect, match). **Delete from Doppler:** `ONESIGNAL_*`, `OPENAI_*`, `PLACES_API_KEY`, `RESEND_*`, `INVITE_LINK_BASE_URL` — removed services.

---

## Minimum to upload to Internal Testing
1. **A:** `SUPABASE_URL`, `SUPABASE_ANON_KEY` (must), `REVENUECAT_PUBLIC_SDK_KEY_ANDROID` (for IAP).
2. **B:** the upload keystore + `key.properties` (generated — take custody, or generate your own).
3. **C:** already deployed. Optionally add `SENTRY_DSN` for tester crash visibility.
