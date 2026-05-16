# Phase 1C — Mobile Authentication + Onboarding + Camera Pipeline — PLAN

**Project:** PawDoc
**Phase:** 1C (Mobile auth + onboarding + camera + analyze)
**Date:** 2026-05-16
**Authoritative source:** [`roadmaps/APP_EXECUTION_ROADMAP.md`](../../roadmaps/APP_EXECUTION_ROADMAP.md) §6, §10 Phase 1
**Predecessors:** Phase 0 mobile scaffold, Phase 1A schema, Phase 1B analyze backend

---

## 1. Scope

Wire the mobile app from "splash screen" to "user sees a triage result." No
business polish, no paywall, no push notifications, no referrals — just the
critical user path that lets us validate the analyze flow end-to-end against
real users.

Phase 0/1A/1B architecture preserved entirely.

## 2. Navigation Architecture

### 2.1 Routes

```
/                            Splash (decides where to send the user)
/auth                        Email-OTP sign-in
/auth/verify                 Enter OTP code
/onboarding/pet              Create first pet
/home                        Pet card + "Check Luna" CTA
/analysis/new                Capture/describe screen
/analysis/loading            Rotating "AI analyzing..." messages
/analysis/result/:id         Triage result
/settings                    Sign out, basic info
```

### 2.2 Router redirect contract

go_router's `redirect` callback resolves the user's state on every navigation
and route based on two inputs: `authState` and `petCount`.

| authState | petCount | Allowed routes |
|-----------|----------|----------------|
| initializing | — | `/` (splash spins) |
| unauthenticated | — | `/auth`, `/auth/verify` |
| authenticated | 0 (or loading) | `/onboarding/pet` |
| authenticated | ≥1 | `/home`, `/analysis/*`, `/settings` |

The redirect always sends users to the correct screen; we **never** flash a
protected screen before auth resolves. Splash holds the user while
`authState` is `initializing`.

### 2.3 Why router-level guards (not widget-level)

Widget-level guards mean every protected widget has to defensively check
auth. That's where data leaks happen. Router-level redirect is a single
chokepoint that the type system + tests can verify.

## 3. Auth State Strategy

### 3.1 Riverpod auth stream

```dart
@Riverpod(keepAlive: true)
Stream<AuthState> authState(AuthStateRef ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => AuthState.from(event));
}
```

`AuthState` is a sealed Dart class with `Initializing`, `Unauthenticated`,
`Authenticated(user)` variants. The router subscribes to it and re-resolves
on every change.

### 3.2 Email OTP flow

Roadmap §10 Phase 1 calls for "email auth + Apple Sign In." Apple Sign In
requires the App Store provisioning (Phase 2). For 1C we ship email OTP:

```
User enters email
  ↓
client.auth.signInWithOtp(email: '...', shouldCreateUser: true)
  ↓
Supabase sends 6-digit code (local: Inbucket; prod: real SMTP)
  ↓
User enters code
  ↓
client.auth.verifyOTP(email, token, type: OtpType.email)
  ↓
Session created → router redirects → onboarding or home
```

OTP over magic-link: codes are easier to test, work in test devices without
deep-link config, and avoid the "user lost the email" failure mode.

### 3.3 Session restore

`supabase_flutter` persists the session in secure platform storage by
default. On cold start the client emits `INITIAL_SESSION` from
`onAuthStateChange`; our provider maps that to `Authenticated` (if a session
exists) or `Unauthenticated`. No custom restore code.

### 3.4 Sign-out

`client.auth.signOut()` clears the session locally and revokes the refresh
token server-side. The auth stream emits `Unauthenticated` → router pushes
to `/auth`.

### 3.5 Cold-start: no protected flash

The router starts at `/` (splash). Splash subscribes to `authState`:
- `Initializing` → keep showing brand logo
- `Unauthenticated` → push to `/auth`
- `Authenticated` → wait for `petsStream` to resolve; then either
  `/onboarding/pet` or `/home`

The router NEVER renders `/home` before the auth + pets queries finish.
Tests assert this behaviour with a delayed-resolution mock.

## 4. Onboarding Strategy

### 4.1 Scope decision

The roadmap §6 specifies 5 onboarding screens (value hook → pet setup →
trust signal → push permission → activation). The task brief simplifies to
"species, name, age, weight, breed, notes." I'm shipping a 2-screen flow:

1. **Welcome** (reused Phase 0 splash branding with a "Get started" CTA)
2. **Pet setup** — single screen with all fields

Reasons:
- Trust signal: defer to Phase 2 (real vet advisor photo + credentials)
- Push permission: out of scope for 1C (no OneSignal yet)
- Activation: the "Check Luna Now" CTA lives on the home screen after pet creation

This trims onboarding from 5 screens to 2 without losing the 3 *load-bearing*
moments (value hook, pet info, first analysis CTA).

### 4.2 Form fields

| Field | Required | Default | Validation |
|-------|----------|---------|------------|
| Species | Yes | (none) | Single-choice tap grid (🐶🐱🐰🦜🦎) |
| Name | Yes | — | Non-empty after trim |
| Birth date | Yes | — | Date ≤ today, age ≤ 30 years |
| Sex | No | — | male / female / unknown |
| Weight (kg) | No | — | 0 < weight < 200 |
| Breed | No | — | Free text, ≤ 80 chars |
| Notes | No | — | Free text, ≤ 500 chars |

Server-side `pets` table has `CHECK` constraints (Phase 1A) — the mobile
mirrors them, plus a slightly stricter weight cap (200 kg is reasonable for
non-livestock pets).

### 4.3 Draft persistence

The form's state is auto-saved to `SharedPreferences` on every field change
(debounced 300 ms). If the user backgrounds the app mid-form, returning
shows the draft, not an empty form. The draft is cleared on successful
submission OR explicit cancel.

Why SharedPreferences instead of Hive: a single JSON-encoded draft does not
need an object store. Hive arrives in Phase 3 for the analysis history
cache.

### 4.4 Submission

```
mobile validates locally
  ↓
supabase.from('pets').insert({...}).select().single()
  ↓
  RLS allows (auth.uid() = user_id)
  ↓
  petsController invalidates → router re-resolves → /home
```

If the insert fails (network, RLS, validation), the form stays put with the
error displayed; the draft is NOT cleared.

## 5. Camera + Media Pipeline

### 5.1 Capture sources

Mobile uses `image_picker` with both `ImageSource.camera` and
`ImageSource.gallery`. The pet's analyze screen presents both as primary CTAs:
"Take photo" and "Pick from gallery."

Video is **deferred to Phase 3** per roadmap §10 — same package supports it,
but the AI service needs the Gemini-video provider path (also Phase 3).

### 5.2 Compression

`flutter_image_compress` pipeline:
1. Read picked file
2. Decode + downscale to max 2048 px (longer edge)
3. Re-encode JPEG at quality 85
4. If still >2 MB, drop quality to 70 and retry
5. If still >2 MB, downscale to 1536 px and retry
6. Hard cap: if still >2 MB after step 5, reject with a clear error

Target: median <800 KB, P95 <1.8 MB. The AI service Gemini/Claude payload
budget tolerates 2 MB images cleanly; the compression eliminates the rare
photo-of-photo or HEIC case.

### 5.3 Upload destination

**Decision: Supabase Storage for Phase 1C; migrate to Cloudflare R2 in
Phase 2.**

Rationale:
- The roadmap (§3 + TECH_DECISIONS §5) names R2 for production due to
  zero-egress pricing.
- R2 requires AWS Signature V4 from Deno edge functions (a new framework
  in spirit, even though it's hand-rolled).
- Supabase Storage is already in our local stack, has first-class Flutter
  SDK support, supports per-user RLS, and the schema's `input_storage_key`
  is opaque — migration is a single file in the edge function.
- Phase 1C ships the *user-facing UX*. Storage backend choice is
  invisible to the user; we can swap it in Phase 2 when image traffic
  warrants the engineering investment.

The migration risk is bounded: keys are opaque + the edge function is the
only resolver. Any future flow is "read this key from storage, send to
AI." The change is local.

### 5.4 Per-user RLS on the bucket

Migration: `20260516010100_storage_bucket.sql`

- Bucket: `pet-uploads` (private, 5 MB cap, JPEG/PNG/HEIC allowed)
- INSERT policy: `(storage.foldername(name))[1] = auth.uid()::text`
- SELECT policy: same
- DELETE: deny user-facing (analyses are append-only; their referenced
  images should be too)

So users upload to `<user_id>/<uuid>.jpg`. Cross-user reads are impossible
even with the bucket misconfigured at the application level.

### 5.5 Upload UX

| State | UI |
|-------|----|
| Idle | "Take photo" / "Pick from gallery" buttons |
| Compressing | Lottie spinner + "Optimizing image..." |
| Uploading | Progress bar (0-100%) + "Uploading..." + Cancel button |
| Uploaded | Image thumbnail + "Looks good?" + Analyze button |
| Error | Error message + Retry button |

The mobile holds a single in-flight upload — no concurrent uploads, no
duplicate-submit risk. The Analyze button is disabled until upload
completes.

### 5.6 Failures

| Failure | UX |
|---------|---|
| User denies camera permission | Inline error + button to open Settings |
| User denies photo library permission | Same as above |
| Compression too aggressive (target unattainable) | Show file-size error, ask user to retake closer / different angle |
| Network drop during upload | Show retry button; existing partial upload abandoned |
| Storage RLS denial | Show generic "Couldn't upload" + log details (this should be unreachable in normal use) |

## 6. Analyze Flow

### 6.1 Pipeline

```
Capture screen
  ↓ pick + compress + upload
  storage_key obtained
  ↓
  (optional) describe text
  ↓ user taps "Analyze"
  ↓
analysis_loading screen
  ↓ POST /functions/v1/analyze
  ↓ Bearer <user JWT>, body: { pet_id, input_type, input_storage_key, text_description }
  ↓ edge function (Phase 1B): JWT → RLS → emergency → rate limit → quota → AI service → INSERT → return
  ↓
analysis_result screen
```

### 6.2 Loading-screen rotation

Per roadmap §10 Phase 1 ("4 rotating contextual messages"):
- "Examining the photo..."
- "Checking breed-specific risks..."
- "Cross-referencing common symptoms..."
- "Finalizing recommendations..."

Rotate every 2.5 s. The user feels progress; the latency is masked. The
analyze call's actual latency varies (1.7 s typical Tier 2; 6 s Tier 3
worst-case per Phase 1B implementation report). Loading messages
gracefully reach completion even on the fast path.

### 6.3 Result screen

Roadmap §10 Phase 1: "triage badge (color-coded), what-we-noticed list,
what-to-do numbered list, escalation triggers, disclaimer."

| Element | EMERGENCY | MONITOR | NORMAL |
|---------|-----------|---------|--------|
| Top bar color | Warm red `#D32F2F` | Amber `#F9A825` | Green `#2E7D32` |
| Headline | "Seek veterinary care immediately." | "Worth a vet visit soon." | "Looks routine for now." |
| Primary action | "Find an emergency vet" (Phase 3 dial-out) | "Schedule a vet visit" | "Save to health log" (Phase 3) |
| Confidence | Hidden in 1C | Hidden in 1C | Hidden in 1C |
| Disclaimer | Always visible at bottom | Always | Always |
| Cross-verify warning | "Our review prefers caution here" if `cross_verify_disagreement` | n/a | n/a |
| Graceful sentinel | n/a | If `tier_used==0`: "We couldn't analyze this clearly. Please consult a vet." | n/a |

Acknowledgement gate on EMERGENCY: the user must tap "I understand" before
the screen dismisses. Prevents accidental dismissal of life-critical info.

### 6.4 Retry-safe behavior

The analyze request is **not idempotent** server-side (each POST consumes
quota + creates a new analysis row). The mobile prevents accidental
double-submit by:
- Disabling the "Analyze" button immediately on tap
- Tracking an `inFlightRequestId` in the controller; clears on response
- A second tap is a no-op until the first finishes

On hard network failure mid-request: we show "Couldn't connect. Try again?"
The user explicitly opts into retry (which IS a new request, IS a new
quota charge). The roadmap is clear: we never trust client state for
quota.

### 6.5 Emergency override path UX

When the edge function returns `emergency_override_applied: true` (the
keyword override fired): the result screen renders identically to a
Tier-3 EMERGENCY, **with the extra note** "Detected based on your
description" near the top. The user shouldn't need to know it was a
keyword vs. AI determination — both are equally actionable.

## 7. Failure Handling

### 7.1 Error taxonomy

| Edge function returns | Mobile shows |
|-----------------------|--------------|
| 401 `unauthorized` | Force sign-out + push to `/auth` |
| 402 `payment_required` | "Free analyses used up — upgrade to continue" + paywall stub (Phase 2 wires real RevenueCat) |
| 404 `not_found` | "We can't find that pet. Try again from your home screen." |
| 429 `rate_limited` | "You've hit today's daily limit. Try again tomorrow." |
| 502 `upstream_error` | "AI service is unavailable right now. Try again in a minute." + retry button |
| 5xx other | "Something went wrong on our side. Try again shortly." + retry |
| Network unreachable | "No internet connection." Detected via `connectivity_plus`, shown before request leaves the device |
| Validation (4xx for body issues) | Should be prevented by client-side validation; if it leaks, show generic "Please check your input" |

### 7.2 What we never show

- Raw backend error messages (`"detail": "..."` text from FastAPI/Supabase)
- Internal codes (`SUPABASE_AUTH_500`, etc.)
- Stack traces
- Service-role hints

User-facing copy is owned by the mobile layer. The structured error code +
message from the backend feed into a lookup table that maps to friendly
copy.

## 8. State Management

Riverpod 2.6 with `@riverpod` codegen, established in Phase 0. Each feature
has its own controller; no giant global state.

| Provider | Scope | Lifetime |
|----------|-------|----------|
| `supabaseClientProvider` | shared/services | App-lifetime (keepAlive) |
| `authStateProvider` | shared | App-lifetime (keepAlive) |
| `petsControllerProvider` | features/pets | Auto-disposed when no listeners |
| `onboardingDraftProvider` | features/onboarding | Auto-disposed on submit |
| `analysisControllerProvider` | features/analysis | Auto-disposed when leaving screen |
| `connectivityProvider` | shared | App-lifetime |

All async work uses `AsyncValue`: `loading`, `data`, `error` are explicit
states. Widgets pattern-match these states rather than juggle booleans.

### 8.1 Cancellation safety

`Ref.onDispose` is wired wherever a controller starts long-running async
work. A user backing out of the analyze screen during loading aborts the
HTTP request and clears the controller state.

## 9. Offline + Connectivity

`connectivity_plus` exposes a stream of connectivity changes. The
`connectivityProvider` maps it to `online: bool`. Key surfaces:

- Analyze button: disabled when offline + tooltip "No internet."
- Onboarding submit: same.
- Auth: still attempts (Supabase Auth has its own retry/queue).
- Splash: doesn't show offline UI (we can't tell if session exists offline yet).

The connectivity stream is advisory; the backend remains the source of
truth for whether a request actually succeeded.

## 10. Accessibility Baseline

| Concern | Approach |
|---------|----------|
| Color contrast | Material 3 default tokens meet WCAG AA in both light + dark themes |
| Triage colors are color-only | Always paired with text label ("EMERGENCY", "MONITOR", "NORMAL") and an icon |
| Tap target size | Material 3 minimum (48×48 dp) honored by `FilledButton` etc. |
| Dynamic type | Default Material text styles scale with system font size |
| Semantic labels | Every interactive widget gets `Semantics(label: ...)` where icon-only |
| Screen reader smoke | Manual TalkBack/VoiceOver pass before merge |

We do not yet support full RTL (Phase 5+ localisation). All copy is left-
to-right English.

## 11. Security Notes (mobile-side)

- **No service-role key** in the mobile binary. The `supabase_flutter`
  client uses the public `anon` key + per-user JWT.
- **No client-side quota counter.** The free-tier RPC (Phase 1A) is the
  authority. The mobile may *display* a "X analyses left" hint after a
  response, but it never gates on that number.
- **Upload validation server-side.** The Supabase Storage bucket has size
  + MIME constraints (Phase 1C migration). Client-side compression is an
  optimisation, not a security control.
- **JWT lifecycle.** `supabase_flutter` rotates the refresh token
  automatically. We do nothing manual here.
- **No PII logging in mobile.** `AppLogger` (Phase 0) goes through
  `dart:developer.log`; in release builds it never reaches OS logs.
- **No fingerprinting of users via logs.** We log user ids (UUIDs) but
  not emails or IPs.

## 12. Test Plan

### 12.1 Unit tests (provider-level)

| Provider | Tests |
|----------|-------|
| `authControllerProvider` | initial state is loading; signInWithOtp success → state becomes "code sent"; verifyOTP success → authenticated; verifyOTP wrong code → error state |
| `petsControllerProvider` | empty list, create success, RLS failure handled |
| `analysisControllerProvider` | submit success → result; submit network error → error state; quota 402 → maps to friendly error; emergency response renders with `emergency_override_applied: true` |
| `onboardingDraftProvider` | persist + restore round-trip |

Mocking via `mocktail`. Each controller has a fake `SupabaseClient` /
fake services injected via ProviderScope override.

### 12.2 Widget tests

| Widget | Tests |
|--------|-------|
| `AuthScreen` | renders email field; submit fires controller; loading state shows spinner; error state shows banner |
| `OnboardingPetScreen` | renders all fields; validation gates submit; draft restores on remount |
| `AnalysisResultScreen` | renders EMERGENCY in red with acknowledgement gate; MONITOR in amber; NORMAL in green; cross-verify warning visible when set; graceful sentinel rendered correctly |
| `HomeScreen` | renders pet name; "Check Luna" CTA navigates correctly |

### 12.3 Integration tests

`integration_test` package is Phase 1D scope (needs a connected device).
For 1C we lean on widget tests + the per-controller unit tests, which is
sufficient for catching regressions in the critical paths.

### 12.4 Manual smoke

Documented as `mobile/SMOKE.md`:
1. Boot supabase + ai-service locally
2. `make mobile-dev`
3. Sign up with `test@example.com`; retrieve OTP from `http://127.0.0.1:54324` (Inbucket)
4. Onboard with "Luna" / dog
5. Tap "Check Luna" → analyze with text "had a seizure" → EMERGENCY result
6. Sign out, back to /auth

## 13. Files Added / Modified

### Added

```
mobile/lib/shared/models/pet.dart
mobile/lib/shared/models/user_profile.dart
mobile/lib/shared/models/analysis_result.dart
mobile/lib/shared/providers/auth_provider.dart
mobile/lib/shared/providers/connectivity_provider.dart
mobile/lib/shared/services/storage_service.dart
mobile/lib/shared/services/image_service.dart
mobile/lib/shared/services/analyze_service.dart
mobile/lib/shared/widgets/loading_view.dart
mobile/lib/shared/widgets/error_view.dart
mobile/lib/shared/widgets/triage_badge.dart
mobile/lib/features/auth/auth_screen.dart
mobile/lib/features/auth/verify_otp_screen.dart
mobile/lib/features/auth/auth_controller.dart
mobile/lib/features/onboarding/welcome_screen.dart
mobile/lib/features/onboarding/onboarding_pet_screen.dart
mobile/lib/features/onboarding/onboarding_controller.dart
mobile/lib/features/home/home_screen.dart
mobile/lib/features/analysis/analysis_capture_screen.dart
mobile/lib/features/analysis/analysis_loading_screen.dart
mobile/lib/features/analysis/analysis_result_screen.dart
mobile/lib/features/analysis/analysis_controller.dart
mobile/lib/features/pets/pets_controller.dart
mobile/lib/features/settings/settings_screen.dart
mobile/test/auth_controller_test.dart
mobile/test/pets_controller_test.dart
mobile/test/analysis_controller_test.dart
mobile/test/onboarding_widget_test.dart
mobile/test/result_widget_test.dart
mobile/SMOKE.md
supabase/migrations/20260516010000_user_provisioning_trigger.sql
supabase/migrations/20260516010100_storage_bucket.sql
docs/reports/phase1c-mobile-plan.md
docs/reports/phase1c-mobile-implementation.md       (post-impl)
```

### Modified

```
mobile/pubspec.yaml                + image_picker, flutter_image_compress,
                                     shared_preferences, connectivity_plus, intl, mocktail
mobile/lib/main.dart               + initialize Supabase, init logger
mobile/lib/app/app.dart            unchanged structurally
mobile/lib/app/router.dart         full route table + redirect logic
mobile/lib/app/config.dart         (no change expected)
mobile/lib/shared/services/supabase_client.dart   + Supabase.initialize wrapper
mobile/test/smoke_test.dart        update to reflect new entry behaviour
```

### Not Touched

`ai-service/`, `.github/`, Phase 1A/1B migrations, `docs/architecture.md`.

## 14. Open Questions

1. **Real R2 presigning timeline.** Tracked in §5.3. Phase 2 absorbs this
   as part of the App Store launch hardening.
2. **OneSignal push consent screen.** Roadmap §6 Screen 4. Out of scope
   for 1C; lands when OneSignal SDK is integrated (Phase 1D / 2).
3. **Apple Sign-In.** Roadmap §10 Phase 1; required by App Store rules
   when any other social auth is offered. Email-only in 1C is acceptable
   for beta TestFlight; Apple Sign In ships before public submission.
4. **Photo capture from real camera in tests.** Flutter's CI doesn't have
   a physical camera; widget tests stub `ImagePicker.pickImage`. Manual
   smoke on a device validates the real path.

## 15. Definition of Done

- `flutter analyze --fatal-infos --fatal-warnings` exits 0.
- `flutter test` passes (all new tests green + existing smoke).
- `make lint && make test` pass (Phase 0 ai-service + mobile gates).
- `supabase test db` passes (1A pgTAP suite + new storage RLS).
- No protected-route flash during cold start (verified via delayed-resolution test).
- Email OTP sign-in completes against local Supabase (Inbucket).
- Onboarding produces a pets row, draft restored after backgrounding.
- Image picker + compression keeps median upload under 800 KB.
- Analyze flow returns a structured result; result screen renders correctly
  for EMERGENCY, MONITOR, NORMAL, and graceful-degradation cases.
- `phase1c-mobile-implementation.md` documents the result.

---

*End of Phase 1C plan. Implementation follows.*
