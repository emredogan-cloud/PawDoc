# Google Sign-In — Play Build Failure: Root Cause and Fix

**Date:** 2026-07-28 · **Device:** Huawei ANE-LX1 (P20 Lite), Android 9, GMS 26.26.34
**Build under test:** `app.pawdoc` 1.0.0+5, installed from the Play **closed testing** track
**Project:** `pawdoc-prod` (project number **256809920812**) — verified active before any change
**Status:** **RESOLVED — Google Sign-In now works in the Play-distributed build**

Investigation followed `GOOGLE_PLAY_SIGNIN_PLAYBOOK.md`. Nothing below was assumed;
each claim has a command and an output behind it.

---

## 1. Root cause

> The Google Cloud project **did** contain an Android OAuth client intended for Play
> App Signing — but its SHA-1 fingerprint was **wrong**. It held
> `FB:FF:F8:33:57:B2:75:80:C8:2C:5F:05:F3:31:94:8A:BB:20:25:07`, which matches no
> certificate in this app's signing chain. The certificate Play actually signs the
> delivered APK with is `91:2A:93:89:EB:7C:A5:BB:D7:0C:12:24:76:4C:DF:A9:EF:2F:05:82`.
> With no client matching `app.pawdoc` + that runtime signature, Google Play Services
> refused to mint an ID token and reported `UNREGISTERED_ON_API_CONSOLE`.

This is **playbook mistake #2**, not #1 — the client was not missing, it was
mis-fingerprinted. The symptom is identical ("but I already added it"), which is why
the playbook insists on reading the fingerprint off the device (§6.2 Path B) rather
than trusting a value copied from a console screen.

### The three certificates involved

| Key | SHA-1 | Signs | OAuth client |
| --- | --- | --- | --- |
| Upload key (`upload-keystore.jks`) | `B7:8F:8F:9B:EC:B2:F7:60:0D:4A:0C:CE:CF:C8:46:D1:FE:28:96:59` | Local release APKs you sideload | "PawDoc Android (upload)" — **correct** |
| **Play App Signing** (Google-generated) | **`91:2A:93:89:EB:7C:A5:BB:D7:0C:12:24:76:4C:DF:A9:EF:2F:05:82`** | **Every build installed from Play** | "Android Client - Play App Signing" — **held the wrong value** |
| Play source stamp | `B1:AF:3A:0B:F9:98:AE:ED:E1:A8:71:6A:53:9E:5A:59:DA:1D:86:D6` | Provenance stamp only | n/a — not an auth input |

The value that was registered, `FB:FF:F8:33:…`, is none of these.

---

## 2. Why it worked locally

A sideloaded release APK is signed with the **upload key**
(`B7:8F:8F:9B:…`), and an Android OAuth client for exactly that package +
fingerprint exists and is correct. Google Play Services matched it, minted the ID
token, and Supabase accepted it. Every local test therefore passed — including a full
device pass the day before.

## 3. Why it failed in Google Play

Play App Signing **re-signs** the uploaded AAB. What reaches the device is signed by
Google's generated key (`CN=Android, OU=Android, O=Google Inc.`), SHA-1
`91:2A:93:89:…`. At runtime, Google Play Services reads the **package name + the
signature actually on the installed APK** and looks for a matching Android OAuth
client. It found none, and returned:

```
W Auth.Api.Credentials: [AccountReauth_flowRunner] Flow failed.
W Auth.Api.Credentials: cipe: [8] Unknown error [status=UNREGISTERED_ON_API_CONSOLE].
W Auth.Api.Credentials: [GoogleSignIn_flowRunner] Flow failed.
```

Upload key ≠ Play App Signing key. Testing with one proves nothing about the other.

---

## 4. Evidence

### 4.1 The build under test really was the Play build

```
$ adb shell pm list packages -i app.pawdoc
package:app.pawdoc  installer=com.android.vending          ← from Play, not sideloaded

$ adb shell pm path app.pawdoc
.../base.apk
.../split_config.arm64_v8a.apk
.../split_config.tr.apk
.../split_config.xxhdpi.apk                                 ← Play split delivery
```

### 4.2 The certificate on the Play-installed APK

```
$ apksigner verify --print-certs --min-sdk-version 24 --max-sdk-version 36 play_base.apk
V3.0 Signer: certificate DN: CN=Android, OU=Android, O=Google Inc., L=Mountain View, ST=California, C=US
V3.0 Signer: certificate SHA-1 digest:   912a9389eb7ca5bbd70c1224764cdfa9ef2f0582
V3.0 Signer: certificate SHA-256 digest: 790b728b6f29d573c622effba37164040651868e92e21c4fba592a4bf261f021
```

`--max-sdk-version 36` is required (playbook §3.6): Play adds a post-quantum ML-DSA
signature block that JDK 17's `apksigner` cannot parse otherwise.

### 4.3 Ruled out before blaming the signature

| Hypothesis | Test | Result |
| --- | --- | --- |
| Wrong Google Cloud project | `gcloud projects describe pawdoc-prod` → **256809920812**; `GOOGLE_WEB_CLIENT_ID` prefix → **256809920812** | ✅ same project |
| `serverClientId` is an Android id, not Web | `client_secret_*.json` top-level key is `"web"`, `project_id: pawdoc-prod` | ✅ correct type |
| Stale / missing dart-define in the shipped AAB | `strings split_config.arm64_v8a/lib/arm64-v8a/libapp.so \| grep googleusercontent` → `256809920812-….apps.googleusercontent.com` | ✅ correct id, embedded |
| Firebase / `google-services.json` misconfiguration | `find . -name google-services.json` | ✅ file does not exist; not used |
| Device lacks Google Play services | GMS **26.26.34**, Play Store 52.4.41 present | ✅ fully GMS |
| Package-name mismatch | `applicationId = app.pawdoc`; both Android clients say `app.pawdoc` | ✅ matches |
| R8/ProGuard stripping | `build.gradle.kts` sets no `minifyEnabled` | ✅ not enabled |
| Split-APK delivery | Playbook §3.4 eliminated this in the prior incident; same AAB here | ✅ not a factor |

### 4.4 Controlled differential (the decisive test)

Same device, same Google account, same code, same embedded client ID, same AAB
source — **only the signing certificate differs**:

| | Play-installed | Sideloaded |
| --- | --- | --- |
| `installer` | `com.android.vending` | `null` |
| Signing SHA-1 | `91:2A:93:89:…` | `B7:8F:8F:9B:…` |
| `Auth.Api.Credentials` | `Flow failed` · `UNREGISTERED_ON_API_CONSOLE` | `Flow step completed` ×6, no failure |
| Outcome | picker closes, no session | **signed in, Home screen** |

### 4.5 Noise explicitly discounted

Logcat contained many `DEVELOPER_ERROR` lines from `FlagRegistrar` / `FlagStore` /
`Phenotype.API`. Per playbook §3.7 these are unrelated and appear on every device;
only `Auth.Api.Credentials` and `GoogleSignIn_flowRunner` lines belong to the sign-in
flow. The diagnosis rests solely on the latter.

---

## 5. Configuration changes

**One change, in `pawdoc-prod` → Google Auth Platform → Clients →
"Android Client - Play App Signing"** (client id `256809920812-un0oumpjk6dgsc1oo66vgjsd67hvo9ps`):

| Field | Before | After |
| --- | --- | --- |
| Name | Android Client - Play App Signing | *unchanged* |
| Package name | `app.pawdoc` | *unchanged* (already correct) |
| **SHA-1 fingerprint** | `FB:FF:F8:33:57:B2:75:80:C8:2C:5F:05:F3:31:94:8A:BB:20:25:07` | **`91:2A:93:89:EB:7C:A5:BB:D7:0C:12:24:76:4C:DF:A9:EF:2F:05:82`** |

Nothing else was touched. The upload client, the Web client, the API keys and the
service account were all left as they were. `gcloud` cannot manage general OAuth 2.0
clients (`gcloud iam oauth-clients` is Workforce Identity Federation and returns 0
items; there is no public API — playbook §11.5), so this was applied through the
Cloud console, then re-read to confirm it persisted.

Propagation: the change was saved at ~22:14 and validated at ~22:35 — 21 minutes,
comfortably past the ~5 minutes the playbook (§6.3) requires.

---

## 6. Files changed

The configuration fix above is what makes sign-in work. The code change fixes the
reason the failure was **invisible** — it does not substitute for the config fix.

| File | Change |
| --- | --- |
| `mobile/lib/src/auth/google_sign_in_diagnosis.dart` | **New.** Maps a Google sign-in failure to one honest sentence plus a `retryable` flag. Recognises all three wordings Google uses for this condition (`UNREGISTERED_ON_API_CONSOLE`, `Developer console is not set up correctly` / `[28444]`, `DEVELOPER_ERROR`). A configuration fault is **not** retryable and points the user at email sign-in. Also provides `logGoogleSignInFailure`, which uses `debugPrint` — `dart:developer`'s `log()` does not reach logcat in release builds (playbook mistake #12). |
| `mobile/lib/src/auth/auth_controller.dart` | Logs `e.code` / `e.description` before rethrowing, so Google's own diagnosis survives. |
| `mobile/lib/src/auth/sign_in_screen.dart` | Catches `GoogleSignInException` specifically and shows the diagnosed message instead of the blanket `"Google sign-in failed. Please try again."` |
| `mobile/test/google_sign_in_diagnosis_test.dart` | **New.** 9 tests pinning: the exact string Play Services emitted on 2026-07-28 is recognised; a config fault is not retryable and mentions email; no message leaks `UNREGISTERED_ON_API_CONSOLE`, `DEVELOPER_ERROR`, `cipe`, `28444` or `status=` to a user. |

Commit `1e5f577` on branch `fix/google-signin-play-app-signing`.

**Why the user saw "nothing happen":** the error banner renders at the *top* of the
sign-in form, but the Google button sits below the fold — so a user who scrolled down
to reach it never saw the message that was displayed. Worth moving the banner or
scrolling it into view; noted in §9.

---

## 7. Validation results

All performed on the **Play-installed** build (`installer=com.android.vending`,
signature `91:2A:93:89:…`) on the Huawei device, after the config change.

| Check | Result | Evidence |
| --- | --- | --- |
| Google button renders | **PASS** | Visible, disabled until Terms accepted |
| Account picker opens | **PASS** | Native picker, correct app name/icon, both device accounts listed |
| Consent screen | **N/A** | Previously granted for this client; Google skips it. Expected, not a gap |
| Successful authentication | **PASS** | `[GoogleSignIn_flowRunner] Flow completed.` · `[GoogleSignInChimeraActivity] Activity finished successfully.` |
| New account creation | **PASS** | Fresh account, then created pet "PlayFix" — which requires `public.users` + referral code + solo family group, so the whole provisioning chain fired |
| Existing account login | **PASS** | Signed out, signed back in → same account, "PlayFix" still present |
| Session persistence | **PASS** | `am force-stop` + relaunch → straight to Home, no re-auth |
| Logout | **PASS** | Confirmation dialog → clean return to sign-in |
| Login again | **PASS** | Same Google account → same PawDoc account |
| Account deletion | **PASS** | Type-`DELETE` gate → deleted, signed out |
| Login after deletion | **PASS** | Fresh, empty account; quota reset to 5/5; deleted pet did **not** reappear |
| `Flow failed` / `UNREGISTERED_ON_API_CONSOLE` | **0 occurrences** | across every sign-in above |

The post-deletion result also re-confirms, on the Play build, the account
bleed-through fix shipped in PR #91.

**Test suite:** `flutter analyze` clean · **368 tests pass** (up from 359; +9 new).

---

## 8. Remaining issues

1. **The stale `FB:FF:F8:33:…` fingerprint's origin is unexplained.** It matches no certificate in this app's chain. Most likely it was copied from the wrong row of a Play Console screen or from another app. Worth confirming that no *other* project or app of yours is relying on it.
2. **The error banner is above the fold.** The Google button requires scrolling; the banner does not scroll into view. A user hitting any Google error still perceives "nothing happened". Small UI fix — scroll the banner into view or place it near the button.
3. **The debug keystore has no Android OAuth client.** Google sign-in inside `flutter run` (debug) will fail the same way. Optional (playbook §2), but add it if you want debug-session sign-in.
4. **iOS is unconfigured.** No iOS OAuth client, and `REVENUECAT_PUBLIC_SDK_KEY_IOS` is still `NOT YET`. Out of scope for Android, blocks any iOS build.
5. **PR `fix/google-signin-play-app-signing` needs merging** — `main` is protected, so the squash-merge is founder-gated.
6. **This build has no crash reporting** (`SENTRY_DSN` absent from Doppler `prd`), unchanged from the previous report.

### Prevention

The playbook's §7.4 rule is what would have caught this before testers did:

> Testing with one signature does **not** guarantee the other works. On any project
> using Play App Signing, sign-in must be tested from a **Play-installed** build,
> and the two installs' signatures compared.

The `apksigner verify --print-certs --max-sdk-version 36` read on a Play-installed
APK takes about a minute and is the only authoritative source for the App Signing
fingerprint. Prefer it over copying from a console screen — that copy is exactly what
failed here.
