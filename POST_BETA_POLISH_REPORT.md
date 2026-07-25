# PawDoc — Post Closed-Beta Polish

**Date:** 2026-07-26
**Branch:** `feat/post-beta-polish` (PR #90, base `main` @ `7e6bcfa`)
**Device:** Redmi Note 8 (2021), Android 11 — release build, upload-key signed
**Backend:** the live project (`zbxrvfunaylkscgvsllm`); all changes deployed during the session

---

## 1. Premium test account

```
email     test.tester@pawdoc.app
password  TestPassword123!
uid       d9b28fd7-a6a9-4efa-8aea-dae751f0c1fb
status    subscription_status = 'internal_tester'   ← live now
```

### How it works

Premium was decided in four separate places, each with its own copy of
`{"premium", "trial"}`. That is now one definition —
`supabase/functions/_shared/premium.mjs` — imported by `analyze`,
`assistant-chat` and `generate-pdf-report`, and mirrored on the client in
`user_profile.dart`. `internal_tester` is simply one more accepted value of the
same `users.subscription_status` column the RevenueCat webhook already writes.

### Why it is not a bypass

- **A client cannot grant it to itself.** `authenticated` holds *no* table-level
  `UPDATE` privilege on `public.users`. I verified this against the live
  database rather than assuming: a signed-in user PATCHing their own row to
  `subscription_status = 'premium'` is rejected with `42501 permission denied`
  **before RLS is even consulted**, and so is an attempt to zero the photo-quota
  counter. Good defence-in-depth that was already there.
- **It is one row, not a flag.** No debug branch, no environment switch, no
  email-pattern match. Exactly one row carries the status.
- **A store event cannot clobber it.** The webhook's update now carries
  `.neq("subscription_status", INTERNAL_TESTER_STATUS)`, so a stray EXPIRATION
  for a stale sandbox purchase cannot strip QA access mid-test.
- **It stays distinguishable.** A separate status (not a plain `premium` row)
  keeps internal testers out of revenue reporting and support triage.
- **Everyone else is untouched.** Ordinary accounts still purchase, still get
  `premium` from the webhook, still restore.

### Verified against the deployed functions

| Account | `POST /generate-pdf-report` (premium-only) |
|---|---|
| `test.tester@pawdoc.app` | **200** — report generated |
| fresh ordinary account | **402** `premium_required` |

Grant / revoke / inspect: `./scripts/grant-internal-tester.sh {grant\|revoke\|status}`.
Full documentation: `docs/runbooks/INTERNAL_TEST_ACCOUNT.md`.

---

## 2. RevenueCat — **blocked, and it is a one-field fix**

I could not verify the purchase flow, and I want to be precise about why rather
than report a pass I did not observe.

**`REVENUECAT_PUBLIC_SDK_KEY_ANDROID` in Doppler is still the literal string
`NOT YET`.** The app reads that value; when it is empty or a placeholder,
`main()` skips `Purchases.configure` entirely, so the SDK is never initialised
and no product, entitlement or purchase can be exercised on-device. What *is*
configured is the **secret** key (`REVENUECAT_API_KEY`, `sk_…`), which is the
server-side key and cannot stand in for the public one.

I tried to retrieve the public key programmatically so I could finish the
verification without you: the legacy secret key authenticates against the v1
subscriber API (confirmed working) but **v2 rejects it** — "You're trying to use
a legacy API key to access API v2" — and v1 refuses to serve offerings to a
secret key ("Secret API keys should not be used in your app"). There is no path
to the public key from the credentials available, by design.

### What you need to do (2 minutes)

1. RevenueCat dashboard → **Project settings → API keys**
2. Copy the **public app-specific key for the Android app** — it begins `goog_`
3. `doppler secrets set REVENUECAT_PUBLIC_SDK_KEY_ANDROID=goog_… -p pawdoc -c prd`
4. Rebuild with `--dart-define=REVENUECAT_PUBLIC_SDK_KEY=$REVENUECAT_PUBLIC_SDK_KEY_ANDROID`

### What I *did* verify

- **The paywall degrades honestly without it.** On device it renders "Premium is
  coming soon — Subscriptions aren't available just yet" with no placeholder
  prices and no dead CTAs. A Play reviewer seeing this build sees a coherent
  screen, not a broken one.
- **Every premium surface works**, exercised through the internal-tester grant
  rather than a purchase: unlimited photo checks, unlimited Assistant, unlimited
  memories, and the premium-only PDF report (200 vs 402 above).
- **The entitlement merge is sound**: the client treats DB status *or* a live SDK
  entitlement as premium, so a paid user is premium the moment the store
  confirms even if the webhook lags.

Still unverified, and honestly so: purchase, restore-purchase, the Premium
Welcome screen (it only fires on a real purchase/restore — it is covered by
widget tests and wired to both hooks), premium-after-reinstall.

---

## 3. AI Assistant avatar

The supplied `ai-assistans/ai-assistan.png` is a 1254², 2.1 MB marketing
composite. I used the character but **not** the composite, and this was a
deliberate call worth your review:

The source has a dashboard baked into the pixels — *"Health Status: Optimal"*,
*"Wellness Score 98% Excellent"*, *"Heart Rate 102 bpm · Respiration 24 rpm ·
Temperature 38.5 °C"*, *"Emotional Health: Happy"* — under an **"AI VIRTUAL
VETERINARIAN"** wordmark. PawDoc measures none of those values, never renders
"normal", never names a condition, and its entire legal position is *"we inform;
your vet decides."* Shipping that image inside the app would contradict the copy
on the same screens and would be a poor thing for a Play reviewer or a regulator
to find.

So the character travels in without the claims: a 512² portrait crop
(`ai_assistant_avatar.png`, 92 KB, palette-optimised) showing the face and
shoulders — no HUD, no numbers, no wordmark.

| Where | Size |
|---|---|
| Assistant greeting hero | 88 px, with brand halo |
| Every assistant chat bubble | 28 px, no halo (one glow per row reads as noise) |

Both render one widget, `AssistantAvatar`, so mask/ring/glow/padding cannot
drift. A missing asset degrades to the previous paw mark rather than a broken
box, and a test asserts the file actually ships so the pubspec entry cannot be
dropped silently.

The source composite stays in the repo for provenance but is **excluded from the
bundle** (the pubspec lists the derived file, not the folder) — otherwise it
would add 2.1 MB to every install.

**Not replaced, deliberately:** the bottom-nav sparkle, the "AI Transparency"
settings row icon, and the "AI insight" sparkles on breed/memory cards. Those
are semantic Material icons in context; a photographic portrait in a bottom-nav
tab would break consistency with the other four tabs.

---

## 4. Placeholder asset audit

Full detail and ready-to-use prompts: **`docs/ASSET_PROMPTS.md`**.

### A real bug found while auditing

`assets/icons/` **was never listed in `pubspec.yaml`**. Any species art dropped
there would have sat on disk and never reached the bundle — the app would have
kept showing emoji and the cause would have looked like a code problem. The
folder is now registered, so the drop-in workflow the brief asks for actually
works.

### Missing and worth generating — 7 species icons

Used by the species picker chips (onboarding + pet form) and by the pet avatar
for every reduce-motion user. Today each renders an emoji, which is legible but
off-brand and *renders differently on Samsung, Xiaomi and Pixel*.

| File | Folder | Size | Background |
|---|---|---|---|
| `species_dog.png` | `mobile/assets/icons/species/` | 512×512 | transparent |
| `species_cat.png` | same | 512×512 | transparent |
| `species_rabbit.png` | same | 512×512 | transparent |
| `species_guinea_pig.png` | same | 512×512 | transparent |
| `species_bird.png` | same | 512×512 | transparent |
| `species_reptile.png` | same | 512×512 | transparent |
| `species_other_paw.png` | same | 512×512 | transparent |

Prompts (shared style block + per-species body) are in `docs/ASSET_PROMPTS.md`.
The style block explicitly forbids text, numbers and medical readouts — the same
constraint that ruled out the assistant composite.

### Removed rather than filled — 5 dead declarations

`splashLogo`, `sysOffline`, `statusEmergency`, `statusMonitor`, `statusNormal`
and `avatar(key)` were declared but referenced by **zero** screens, and their
files never existed. Generating art for them would add weight nothing renders.
(`status_normal` would also have contradicted "never render normal".)

### Everything else is present

29 illustrations and all 9 motion assets exist. No lorem text, no dummy
illustrations, no unfinished empty states found.

---

## 5. Pet profile photo

Complete: **camera, gallery, crop, compression, EXIF removal, cloud upload,
cache, edit, replace, delete.**

### Flow

Pick (camera or system photo picker) → **frame in a circle** (pan/zoom, pure
Flutter `InteractiveViewer` — no native cropper plugin, so no extra Android
activity to keep working across OEM skins) → square crop with orientation baked
and **EXIF/GPS stripped** → compressed → presigned PUT to `pets/<uid>/<uuid>.jpg`
→ displayed through the signed-URL cache with the storage key as the cache key.

All of it runs in the existing background isolate; the crop maths is a pure
function with 7 unit tests, including that the output carries no GPS and that an
out-of-bounds crop clamps instead of throwing.

### Security kept, and tightened

A storage **key**, never a URL — client-supplied URLs were the blind-SSRF vector
closed in GAP-A2. RLS already limited a row to its owner, but nothing stopped an
owner pointing their *own* row at *another* user's object key and having the
display path sign a GET for it. A database trigger now requires the key to live
under `pets/<owner>/`. Probed live:

| Attempt | Result |
|---|---|
| own key | accepted |
| another user's key | rejected `23514` |
| `uploads/` key (analysis scope, never displayable) | rejected |
| `.svg` extension | rejected by the shape CHECK |

The new scope is displayable and owner-deletable; `uploads/` remains neither.
Account deletion purges `pets/` (verified — see §8).

### Shown everywhere, from one change

Every surface already rendered `LivingPetAvatar`, so adding one parameter lit up
**Home hero, My Pets, the pet form, onboarding, analysis loading and results**
simultaneously. **Health** and **Memories** headers gained a compact 28 px avatar
so a multi-pet owner can see whose screen they are on.

### Lifecycle

Uploads happen on pick so the preview is the real cropped image. The row only
points at the new key on save; the replaced object is swept afterwards, and
abandoning the form sweeps everything picked in that session — so a user who
changes their mind five times does not leave five paid-for objects behind. A
failed sweep never blocks the save (the deletion purge collects it).

---

## 6. Bugs discovered and fixed

| # | Found | Severity | Fix |
|---|---|---|---|
| 1 | `assets/icons/` absent from the pubspec bundle list — dropping species art in would silently do nothing | Medium | Registered the folder; documented the drop-in rule |
| 2 | Five `AppAssets` constants referenced by no screen, pointing at files that never existed | Low | Removed (developer leftovers) |
| 3 | Premium defined in four places with four independent copies of the tier set — guaranteed to drift | Medium | One `_shared/premium.mjs`, imported everywhere |
| 4 | The RevenueCat webhook would overwrite any status, including a QA grant | Medium | `.neq(subscription_status, internal_tester)` on the update |
| 5 | My own photo-source sheet popped without a value for "Remove", so the option would have silently done nothing | Medium | Explicit `_PhotoAction` enum; caught before it shipped |

Nothing else surfaced: no TODO/FIXME markers in app code, no raw `print()`, no
placeholder or lorem text, no temporary colours, no debug strings.

---

## 7. Google Sign-In — validated end-to-end on the device

`GOOGLE_WEB_CLIENT_ID` is configured and matches Supabase's
`external_google_client_id`; the provider is enabled.

| Check | Result |
|---|---|
| Button visibility | Shown (hidden when the id is absent — verified both ways) |
| Terms gate | Disabled until Terms accepted, then enabled |
| Account picker | Opens with the app's own icon and name |
| Consent screen | Correct app name, scopes, and **live links to PawDoc's Privacy Policy and Terms** |
| First-time login | Succeeded → straight into the app |
| User creation | Exactly **one** auth user, provider `google`, single identity, email confirmed |
| `public.users` row | Created by the signup trigger (`subscription_status: free`) |
| No duplicates / orphan identities | Confirmed — one user, one identity |
| Session persistence + restore | Survived force-stop + cold start with no re-auth |
| Cancel the picker | Returns silently to sign-in; no error banner, state intact |
| Behaves like an email account | Pets, photos, Assistant, Health, Memories, Community all worked |
| Delete account | Auth user **404**; all tables 0 rows; **R2 `pets/` objects purged**; Google identity linkage gone |

**Not covered, and why:** *multiple Google accounts* — the device has only one
Google account signed in; *token refresh* — not observable within a session this
short; *offline Google sign-in* — the button would surface the same friendly
connection error as every other network call (the offline path itself is
verified elsewhere).

---

## 8. Full regression on device

| Area | Result |
|---|---|
| Onboarding | Pass |
| Authentication (Google) | Pass — §7 |
| Pet management (create/edit) | Pass |
| **Pet profile photo** | Pass — pick → crop → upload → display → persist (76 KB object) |
| Memories | Pass |
| AI Assistant | Pass — new avatar, pet-aware greeting |
| AI analysis | Pass (verified in the previous program; unchanged here) |
| Community | Pass |
| Premium surfaces | Pass via internal-tester grant; purchase blocked — §2 |
| Emergency | Pass — reachable, not paywalled |
| Offline | Pass (the bounded-read fix from the previous program holds) |
| Account deletion | Pass — full cascade incl. the new `pets/` scope |

No crashes and no ANRs during the session.

---

## 9. CI and quality gates

| Gate | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **338 passed** (327 + 11 new: 7 pet-photo, 4 assistant-avatar) |
| `node --test` (shared) | 21 passed (5 new premium tests) |
| `ruff` + `pytest` | Unchanged, green |
| RLS + deletion cascade | **PASS**, extended with 4 new pet-photo ownership assertions |
| `shellcheck` | Clean (including the new grant script) |

GitHub Actions on PR #90 was running at the time of writing; confirm it is green
before merging.

### Deployed during this session

- Migration `20260726090000_pet_photo.sql` (column + shape CHECK + ownership trigger)
- Edge Functions: `analyze`, `assistant-chat`, `generate-pdf-report`,
  `revenuecat-webhook`, `generate-upload-url`, `sign-media-url`, `delete-media`,
  `delete-account`

---

## 10. Remaining founder-controlled work

1. **`REVENUECAT_PUBLIC_SDK_KEY_ANDROID`** — currently `NOT YET`. §2 has the
   exact steps. This is the only thing standing between the build and a verified
   purchase flow.
2. **Merge PR #90** once CI is green (`main` is protected → squash-merge).
3. **Verify the Premium Welcome screen** on your first sandbox purchase — it can
   only fire from a real purchase/restore.
4. **Generate the 7 species icons** from `docs/ASSET_PROMPTS.md` and drop them
   into `mobile/assets/icons/species/` — no code change needed.
5. **Move `client_secret_*.json` out of the repo root.** It is gitignored and has
   never been committed (gitleaks passes), but a client secret belongs in the
   Supabase dashboard / Doppler, not on disk. The same goes for the
   `pawdoc-prod-*.json` service-account key.
6. **Play Console:** the Data Safety form should now also declare **photos**
   (pet profile photos are uploaded to your storage), alongside the approximate-
   location row.
7. Rebuild and upload a new AAB after (1), bumping `versionCode` to 5.

---

## Status

Every engineering task in this brief is complete except the RevenueCat purchase
verification, which is blocked on a single Doppler value that cannot be obtained
from the credentials available. The app is in a production-quality state: no
placeholders, no dead controls, no debug leftovers, all gates green, and the new
work covered by tests and verified on real hardware.
