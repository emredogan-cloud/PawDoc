# PawDoc — Google Play Internal Testing Readiness

**Date:** 2026-07-25
**Branch:** `fix/internal-test-readiness` (PR #88, base `main` @ `96a7e61`)
**Devices:** Redmi Note 11R (Android 13) · Redmi Note 8 2021 (Android 11)
**Backend under test:** the live deployment produced during this session — not a local stub.

---

## 1. Deployments performed

Everything the repository was holding is now live on the hosted project
(`zbxrvfunaylkscgvsllm`).

### 1.1 Database migrations

Three migrations were pending since the Next Evolution merge; all applied cleanly.

| Migration | Contents |
|---|---|
| `20260724110000_pet_memories.sql` | `pet_memories` + per-op RLS |
| `20260724130000_assistant.sql` | `assistant_conversations`, `assistant_messages` + quota index |
| `20260724150000_community.sql` | 5 community tables, geohash CHECK, guarded realtime publication |

`supabase migration list --linked` shows local and remote in parity through
`20260724150000`. All seven new tables answer `200` with `[]` to an anonymous
`apikey`-only request — present, and RLS is hiding every row.

### 1.2 Edge Functions

All nine functions in the repository deployed; the hosted set now matches the
repository exactly (no stale functions, none missing).

```
analyze v9   analyze-anonymous v8   assistant-chat v1   delete-account v8
delete-media v1   generate-pdf-report v8   generate-upload-url v8
revenuecat-webhook v8   sign-media-url v1
```

`assistant-chat`, `sign-media-url` and `delete-media` had never been deployed
before this session — the Assistant, memory image display, and memory deletion
were all dead in production until now.

### 1.3 AI service

Already deployed and healthy on Fly (`pawdoc-ai`, two machines in `fra`, health
checks passing). `GET /health` → `{"status":"ok","service":"pawdoc-ai","version":"3.2.0"}`.
No redeploy was needed; no ai-service code changed in this session.

### 1.4 Storage / RLS

No R2 configuration change was required. The bucket ended the session with **0
objects** — the two left by an API-level reproduction script were removed by
hand (they were orphaned because deleting a user through the Auth admin API does
not run the `delete-account` function; the in-app deletion path *does* purge R2,
and that was verified — see §2.9).

### 1.5 Deployment verification

Every deployed surface was probed after deployment:

- `assistant-chat`, `sign-media-url`, `delete-media`, `generate-upload-url`,
  `generate-pdf-report`, `analyze` → **401** without a JWT.
- `POST https://pawdoc-ai.fly.dev/assistant/chat` → **401** without the service token.
- Full Assistant chain with a real user JWT: SSE `200`, `x-conversation-id`
  header set, deltas streamed, conversation + both message rows persisted and
  readable back through RLS.
- Emergency short-circuit through the deployed function: an emergency message
  returned a single emergency frame with **no model call**.
- `sign-media-url` scope enforcement: signed the caller's own `memories/` key,
  refused another user's key and refused an `uploads/` key (not a display scope).

---

## 2. Real device validation

Two physical devices, release builds signed with the upload key, installed
fresh, driven as a first-time user against the deployed backend.

Mid-session the Note 11R began refusing installs with
`INSTALL_FAILED_USER_RESTRICTED` — Xiaomi's "Install via USB" restriction, which
rate-limits repeat ADB installs. That is a device policy, not an app fault, and
it is not reproducible from the host. Validation continued on the second
physical device (Note 8, Android 11), which also widened OS coverage.

| Area | Result | Where |
|---|---|---|
| Splash / cold start | Pass | both |
| Onboarding (3 steps, honesty framing) | Pass | 11R |
| Signup | Pass | both |
| Login | Pass | Note 8 |
| Session restore | Pass — survived 6+ cold starts and a reinstall | both |
| Pet creation | Pass | both |
| Pet editing | Pass — sex + weight persisted (`male`, `31.40`) | 11R |
| Pet Memories | Pass — create, photo upload to R2, gallery, viewer, edit, search hit/miss, delete, second memory | 11R |
| Breed Encyclopedia | Pass — species toggle, search, detail, paw-meters, health disclaimer, image credit | 11R |
| AI Assistant | Pass — SSE streamed live, markdown rendered, history list, per-pet context | 11R |
| AI text analysis | Pass — action + timeframe + "call sooner if" + API-injected disclaimer, persisted to history | 11R |
| AI photo analysis | Pass — see §2.6 | Note 8 |
| Weather cards | Pass — live MET Norway data (score 45, best window 18:00, 29 °C) | 11R |
| Smart Walk recommendations | Pass — hourly strip, best windows, three real nearby parks from OSM, daily reminder toggle, attribution footer | 11R |
| Paw Community | Pass — consent screen, join, **only a 5-char geohash stored** (`sy96w`, ~±2.4 km); no coordinates | 11R |
| Premium UI (paywall) | Pass — opens, honest copy, graceful "Premium is coming soon" with no RevenueCat products | Note 8 |
| Premium Welcome screen | **Not device-verifiable** — see §8 | — |
| Reminders | Pass — daily walk reminder scheduled; vaccination next-due path present | 11R |
| Vaccinations | Pass | both |
| Weight tracking | Pass | Note 8 |
| History | Pass — analysis records persist and render | both |
| Emergency | Pass — reachable, not paywalled | both |
| Offline Emergency | Pass — full first-aid content in airplane mode | 11R |
| Settings | Pass | both |
| Legal pages | Pass — live CloudFront portal, "Attorney review pending" banner intact | 11R |
| Account deletion | Pass — see §2.9 | Note 8 |
| Google Sign-In | **Correctly hidden** (no `GOOGLE_WEB_CLIENT_ID`) — expected | both |

### 2.6 Photo analysis, in detail

Photo triage was exercised two ways because the first result deserved scrutiny.

**On device:** an in-app capture (live lighting guidance, framing guide, and the
"Photos are private — location removed" EXIF notice) of a non-pet scene returned
*"We couldn't process this media"* → `WATCH_AND_RE-CHECK`, "retake and try again
now", the escalation list, and the disclaimer. That is the moderation path
failing closed, and it still produced an action and a timeframe — the action
ladder held.

**Through the API,** with a real pet photo, the full chain ran end to end:
presigned `PUT` → R2 `200` → moderation passed → analysis returned a
contract-shaped result with a persisted `analysis_id`. Confidence came back
`0.1`, so the safety floor correctly rendered "Not enough information to assess
confidently" rather than inventing a finding.

I also re-confirmed in `providers.py` that **real pixels reach both models** —
Gemini via `types.Part.from_bytes`, Claude via a base64 `image` block. The old
CRITICAL from the June launch audit ("providers never send image pixels") is
genuinely closed.

### 2.9 Account deletion cascade

Deleting the account from the app signed the user out and removed everything:

```
auth user           → 404
users row           → 0
pets                → 0      analyses     → 0
pet_memories        → 0      health_events→ 0
community_profiles  → []     assistant_conversations → 0
assistant_messages  → 0
R2 memories/<uid>/  → empty
```

---

## 3. Every bug discovered

Four defects, all found on hardware, none of which any test suite had caught.

### BUG-1 — Offline cold start stranded Home on skeletons forever (HIGH)

In airplane mode, Home rendered loading skeletons **indefinitely** (observed >3
minutes, across relaunches). Two independent causes stacked:

1. The pets read had no timeout. The socket stalled and the future never
   settled, so the provider never left `loading`.
2. Even once it errors, Riverpod 3 retries a failed provider automatically and
   each retry re-enters `AsyncLoading` while *retaining* the error — so
   `when(error:)` was unreachable regardless.

The existing "Could not load your pets" retry branch was therefore dead code.
Emergency stayed reachable throughout (the PR #86 safety fix held), so this was
never a safety defect — but everything else offline was a blank wall.

### BUG-2 — The health-event form wrote content-free records (MEDIUM)

"Save event" on an **untouched** form succeeded and wrote
`event_type: vaccination, notes: null, metadata: null` — a record with no
identifying content, in the history a vet is meant to read. The weight type had
the same hole: an unparseable weight saved a weight event carrying no weight.
Confirmed by reading the row back out of the database.

### BUG-3 — The account's Subscription row was inert (MEDIUM)

Tapping "Subscription" did nothing. The build carries no
`REVENUECAT_PUBLIC_SDK_KEY`, so `main()` skips `Purchases.configure`, and the
profile provider's `Purchases.getCustomerInfo()` then **never answers** — it
hangs rather than throwing. The provider stayed in `loading`, so the tile fell
through to an `orElse` fallback that had no `onTap`: a row that looked tappable
and did nothing, with no route to the paywall at all.

### BUG-4 — One device, two accounts, data bleed-through (HIGH)

After deleting an account and signing up a fresh one in the same app session,
the new account still showed the **deleted user's pet** — "Rex · Labrador
Retriever" on Home, in My Pets, in the Health header, and in the Assistant
subtitle. The database held zero pets for the new user; the reads were correct.
The cached provider values simply outlived the identity that produced them.

On a shared or resold phone this shows one person's pet data to another. Nothing
leaves the device, but it is the wrong data in front of the wrong person.

---

## 4. Every fix applied

Each fix ships with a regression test that reproduces the device symptom.

| # | Fix | Files |
|---|---|---|
| 1 | `kDataReadTimeout` (12 s) bounds every screen-gating read (pets, memories, reminders, health events, profile). Home renders a retained error instead of pretending to still load, with offline-aware copy and a retry. | `core/data_timeout.dart` (new), `pets/`, `memories/`, `reminders/`, `health/` repositories, `home/home_screen.dart` |
| 2 | The save requires the datum that gives each type meaning — a vaccine name, a plausible weight (0–500 kg, comma decimals accepted), a note for the free-text types — and says what is missing rather than leaving a dead button. | `health/health_event_form_screen.dart` |
| 3 | Only probe the store SDK when `main()` configured it (`Env.hasRevenueCat`), bound it anyway (`kEntitlementProbeTimeout`, 6 s), and give the fallback Subscription row a real destination. | `config/env.dart`, `account/user_profile.dart`, `account/account_screen.dart` |
| 4 | User-scoped providers watch the signed-in user id, so an identity change recomputes them instead of serving the previous account's cache. | `pets/`, `account/`, `community/`, `assistant/`, `memories/`, `feedback/` providers |

Also: `client_secret_*.json` added to `.gitignore`. A Google OAuth client-secret
download appeared in the repository root during this session; it is untracked,
never entered git history (verified against `--all`), and is now ignored.

**All four fixes were re-verified on hardware after rebuilding** — BUG-1 on the
Note 11R (error + retry + Emergency, then full recovery via "Try again"), BUG-2,
BUG-3 and BUG-4 on the Note 8.

---

## 5. Stress-test results

No crash, no ANR, and **zero `FATAL EXCEPTION` entries** in logcat across the
entire session.

| Scenario | Result |
|---|---|
| Offline / airplane mode | Surfaced BUG-1; after the fix, a clean error + retry with Emergency reachable |
| Online recovery | "Try again" reloads and the session restores intact |
| Fast navigation — 40 rapid tab taps | No crash; correct final state |
| Rapid tapping — triple-tap "Check", 8× Emergency open/close | Exactly one sheet opened; no duplicate routes |
| Background / foreground | State restored, including mid-flow screens |
| Rotation | Portrait ↔ landscape on both devices; layouts adapt, state preserved |
| Slow network / AI timeout | Assistant stream killed mid-flight: user message preserved, friendly error, input re-enabled, no half-persisted assistant row |
| Upload failures | Moderation reject path degrades safely with an action and a timeframe |
| Invalid input | Weight `abc` and `900` both blocked with an explanation |
| Empty input | Empty Assistant send is a no-op; empty health event now blocked |

---

## 6. CI status

Local gates, all green:

| Gate | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **327 passed** (321 before this session + 6 new regression tests) |
| `ruff` | All checks passed |
| `pytest` | 173 passed |
| `node --test` (shared `.mjs`) | 0 failures |
| `./scripts/test-rls.sh` | RLS ISOLATION: PASS · ACCOUNT DELETION CASCADE OK |
| `shellcheck scripts/*.sh` | Clean |

GitHub Actions on PR #88: the first run **failed** on a real lint —
`prefer_final_fields` in one of my new test files, which the CI runner's
freshly-resolved analyzer flagged and my local pub cache did not. Fixed in
`174dc16`.

**Final run (`30164918583`, sha `8298226`): all 7 jobs green.**

```
AI service — ruff + pytest .......................... success
Secret scan (gitleaks) .............................. success
RLS + deletion cascade (full migrations, Docker pg) . success
Edge shared tests (node --test) ..................... success
Flutter analyze + test + build ...................... success
No placeholders / overclaims ........................ success
ShellCheck (scripts) ................................ success
```

The gitleaks job passing is worth noting specifically: it confirms the Google
OAuth `client_secret_*.json` sitting in the working tree is properly ignored and
did not reach the branch.

---

## 7. Final release build

```
Artifact     mobile/build/app/outputs/bundle/release/app-release.aab
Size         100.4 MB
Package      app.pawdoc
Version      1.0.0 (versionCode 4)
minSdk 24  ·  targetSdk 36  ·  compileSdk 36
Signer       CN=Emre Dogan, OU=PawDoc, O=Pawdoc, L=Turkiye, ST=turkiye, C=90
SHA-256      E8:C3:09:40:57:A7:E2:B2:E7:D2:67:5C:80:6F:1B:AE:37:51:88:74:D6:ED:BF:17:9E:97:55:DC:A2:A7:38:8A
SHA-1        B7:8F:8F:9B:EC:B2:F7:60:0D:4A:0C:CE:CF:C8:46:D1:FE:28:96:59
```

Release-signed with the upload keystore (not the debug key) — confirmed both on
the AAB and via `apksigner` on the matching APK.

**Two things to know about this build:**

1. **The upload keystore was regenerated today** (`android/app/upload-keystore.jks`,
   created 14:27, valid to 2053). Its fingerprint differs from the one recorded
   on 2026-07-18. Since nothing has been uploaded to Play yet this is harmless —
   but **this** keystore and its passwords are now the ones that matter. Back
   them up somewhere you cannot lose them, and register **this** SHA-1 when you
   configure the Google OAuth Android client.
2. `versionCode` moved 2 → 4 and `purchases_flutter` 10.1.1 → 10.4.3 in
   `pubspec` during the session (not my edits — the working tree already carried
   them). Both are fine and were kept: a higher versionCode is required for a new
   Play upload, and the full suite passes on the newer SDK.

The AAB was rebuilt after the last code fix, so the artifact matches the branch head.

---

## 8. Remaining founder-controlled actions

Nothing engineering-side is outstanding. These are all console/account steps
only you can perform:

1. ~~Merge PR #88~~ — **done by you during the session** (squash-merged to `main`
   as `7e6bcfa`, CI was green on its head). All four fixes and this report are on
   `main`. The merge also re-triggers the ai-service deploy, which is harmless
   here — no ai-service code changed.
2. **Google OAuth configuration** — deliberately not done, per your instruction.
   Follow `docs/runbooks/GOOGLE_SIGN_IN_SETUP.md`; use the SHA-1 above for the
   Android client. Until `GOOGLE_WEB_CLIENT_ID` is set the button stays hidden,
   which is exactly what the build does today. The `client_secret_*.json` sitting
   in the repo root belongs in the Supabase dashboard / Doppler — move it out.
3. **RevenueCat products** — `REVENUECAT_PUBLIC_SDK_KEY_ANDROID` is still the
   literal string `NOT YET`. Until it is real, the paywall shows "Premium is
   coming soon" (verified on device — it degrades cleanly, nothing is broken).
4. **Premium Welcome screen** could not be device-verified: it only fires on a
   real purchase or restore, which needs (3). It is covered by widget tests and
   is wired to both hooks in `paywall_screen.dart`. Confirm it visually on your
   first sandbox purchase.
5. **Play Console** — internal testing track, Data Safety (declare *approximate
   location*, collected on-device and not transmitted), UGC declaration for Paw
   Community, store listing, then upload the AAB.
6. **Redmi Note 11R install restriction** — if you want to keep testing on it,
   re-enable "Install via USB" in Developer options (Xiaomi rate-limits it).
7. Optional, unchanged from the previous report: `'choking'` is still absent from
   the triplicated emergency keyword lists — a deliberate product decision to
   make, not a regression. The ai-service `VERSION` constant still reads `3.2.0`
   (cosmetic).

---

## Verdict

**Can I upload this AAB to Google Play Internal Testing after I later configure
Google Sign-In?**

# YES WITH CONDITIONS

The conditions are exclusively the founder-controlled items in §8 — Google OAuth
configuration, RevenueCat products, and Play Console setup. PR #88 is already
merged to `main`.

No engineering work remains. The backend is fully deployed and verified against
real devices, the four defects found on hardware are fixed and re-verified, all
seven CI jobs are green, and the signed AAB is built and ready to upload.
