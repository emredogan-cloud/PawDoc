# PAWDOC REMEDIATION PLAYBOOK

> **Date:** 2026-06-12 · Companion to `PAWDOC_LAUNCH_GAP_ANALYSIS.md` (IDs match) and `PAWDOC_GO_LIVE_MASTER_PLAN.md` (sequencing).
> Every entry: Problem → Why it matters → Solution → atomic tasks → files → validation → rollback → acceptance criteria. Founder entries add contact/sequence/timeline/cost.
> **Process rule (per CLAUDE.md):** each engineering fix = one `phase-`/`fix-` branch → PR → CI green → squash-merge. Group as suggested in the wave plan. Nothing here is auto-applied; this is the execution manual.

---

# PART 1 — ENGINEERING FIXES

## GAP-A1 — Attach real pixels to AI calls (THE product fix)

**Problem.** `GeminiProvider.analyze` and `ClaudeProvider.analyze` never fetch or attach `image_url`/`frame_urls`; triage of photos/videos is text-only while the prompt claims an image is present (`ai-service/app/providers.py:63-72,148`).
**Why.** Flagship feature non-functional; "confident NORMAL on an unseen image" is the exact false negative the business is built to avoid. Also invalidates the cost model and the golden-set's meaning for visual cases.
**Solution.** Fetch media bytes server-side (bounded), attach as real multimodal parts to both providers, and add contract tests that assert the parts exist in the outgoing payload.

**Tasks**
1. Add `app/media.py`: `fetch_media(url, *, max_bytes=8_000_000, timeout=8.0) -> tuple[bytes, str]` using httpx; enforce content-type allowlist (`image/jpeg`, `image/png`, `image/webp`); reject on size/timeout/scheme≠https; raise `ProviderError` subclass `MediaFetchError`.
2. GeminiProvider: build `contents=[*parts]` where parts = `[types.Part.from_bytes(data=…, mime_type=…)] + [text]` for image; for video, one part per frame (cap 6) + text.
3. ClaudeProvider: build `messages=[{"role":"user","content":[{"type":"image","source":{"type":"base64","media_type":…,"data":…}}, …frames…, {"type":"text","text":user_prompt}]}]`.
4. On `MediaFetchError`: do **not** silently analyze text-only — degrade with `insufficient_information`-style safe MONITOR mentioning the image couldn't be read (never NORMAL), and log+metric it.
5. Update `prompts.py` so the image sentence is only included when parts are actually attached.
6. Tests: fake transport capturing the SDK payload — assert image part present for photo, N frame parts for video, none for text; assert MediaFetchError → safe degrade; assert size-cap rejection. Extend `golden_set.json` with at least 2 image cases (use checked-in fixture bytes).
7. Re-baseline cost note in `docs/` (blended $0.005–0.015/analysis with images).

**Files.** `ai-service/app/providers.py`, new `app/media.py`, `app/pipeline.py` (degrade branch), `app/prompts.py`, `tests/test_providers_payload.py` (new), `tests/golden_set.json`.
**Validation.** `ruff` + `pytest`; then a **live smoke**: one real photo analysis against deployed service via the runbook (founder, with device or curl + presigned URL) asserting the result references visible content.
**Rollback.** Revert the PR; service returns to text-only behavior (no schema change, no contract change — `AnalysisResult` untouched).
**Acceptance.** A photo of an obviously abnormal condition with neutral text yields a triage referencing the visual finding; payload tests prove parts attached; golden set green; FN-on-EMERGENCY==0 gate still green.

---

## GAP-A2 — Kill the SSRF: never trust client `image_url`

**Problem.** `analyze/index.ts:184` prefers the client-sent `image_url` over the server-presigned key; the AI service GETs it from inside Fly (`moderation.py:41`, and after A1, `media.py` too).
**Why.** Authenticated blind SSRF into Fly's internal network from a zero-cost auto-confirmed account.
**Solution.** Server derives all media URLs; defense-in-depth allowlist in the service.

**Tasks**
1. In `analyze/index.ts`: remove `image_url` from the accepted body entirely; require `input_storage_key` for photo and `frame_storage_keys` for video; `const imageUrl = body.input_storage_key ? await presignGet(...) : null;` (key already regex-validated/namespaced by `upload_key.mjs` conventions — re-validate `uploads/<auth uid>/…` prefix here too).
2. In the AI service (`media.py` + `moderation.py`): allowlist host = the R2 account endpoint (`*.r2.cloudflarestorage.com` + your account host from env); reject IP-literal hosts, non-https, redirects to other hosts (set `follow_redirects=False`).
3. Mobile: confirm the client sends only `input_storage_key` (it does — `analysis_service.dart`); remove any dead `image_url` plumbing.
4. Tests: Edge unit test (mjs) asserting a body with `image_url` is ignored/400; Python test asserting non-allowlisted host raises before any fetch.

**Files.** `supabase/functions/analyze/index.ts`, `ai-service/app/moderation.py`, `app/media.py`, `_shared` tests, `tests/test_media.py`.
**Validation.** `node --test`, `pytest`; deploy to functions + Fly; live negative probe (authenticated request with `image_url=http://169.254.169.254/` → 400, and nothing fetched in logs).
**Rollback.** Revert function deploy (`git checkout <sha> && supabase functions deploy analyze`) + `fly deploy -i <prev image>`.
**Acceptance.** Client-supplied URLs cannot reach the fetcher; only `uploads/<own-uid>/…`-derived presigned R2 URLs are ever fetched.

---

## GAP-A3 — Un-paywall photo/video emergencies (owner decision + fix)

**Problem.** Quota 402 fires before AI for any non-keyword text; an out-of-quota **photo** emergency is never analyzed (`analyze/index.ts:116-133`).
**Why.** Violates the project's #1 non-negotiable ("NEVER paywall an EMERGENCY result") for the visual half of the product.
**Solution (recommended of the two options surfaced).** For `input_type ∈ {photo, video}` from an out-of-quota free user: **run the analysis anyway**; if the verdict is EMERGENCY → return it fully, uncounted; otherwise return HTTP 402-equivalent JSON containing *only* `{triage_level, quota_exceeded: true}`-style minimal signal with the upgrade message (no detailed guidance), still uncounted. This keeps marginal cost bounded (~$0.005) while emergencies always surface. (Alternative — pre-AI cheap emergency-vision screen — adds a second model path; not recommended.)

**Tasks**
1. Edge: restructure the gate — compute `decision` first; if `!decision.allowed && !isEmergencyText`: for text → current 402; for photo/video → proceed to AI with a `quotaExceeded` flag.
2. After AI: if `quotaExceeded && result.triage_level !== 'EMERGENCY'` → respond 402-shaped JSON with upgrade message + `triage_level` only; do not store full guidance? (Decision: store the analysis row regardless for safety audit trail, but mark `quota_blocked: true`.) If EMERGENCY → full result, never counted (existing rule).
3. Mobile: handle the new 402 payload (pairs with GAP-A5's FunctionException mapper) — show "Upgrade" sheet with the returned triage chip.
4. Tests: mjs unit tests for the four quadrants (in/out of quota × emergency/normal × text/photo).

**Files.** `supabase/functions/analyze/index.ts`, `_shared` tests, mobile runner/paywall mapping (with A5).
**Validation.** `node --test`; live: out-of-quota test account + photo with neutral text → analysis runs; EMERGENCY photo case returns full result.
**Rollback.** Revert function deploy.
**Acceptance.** No input type can produce "emergency never evaluated due to paywall"; AI cost per blocked-free-user request ≤1 Tier-2 call unless EMERGENCY.

---

## GAP-A4 — Timeouts, concurrency, size caps (service survivability)

**Problem.** No `timeout=` on Anthropic (600 s default) / Gemini calls; SDK retries stack on pipeline retries; sync endpoints on a 40-thread pool; no fly concurrency limits; unbounded `text_description`/`frame_urls`.
**Why.** One hung provider pins the only machine's threads → health check starves → Fly restart kills all in-flight analyses; P95<10 s unenforceable; megabyte prompts = cost abuse.
**Solution & tasks**
1. `ClaudeProvider`: `anthropic.Anthropic(api_key=…, timeout=8.0, max_retries=0)`. `GeminiProvider`: `genai.Client(api_key=…, http_options=types.HttpOptions(timeout=8_000))` (ms) — verify exact param against installed SDK; add `max_output_tokens=1024` to the GenerateContentConfig.
2. `models.py`: `text_description: str = Field(max_length=4000)`; `frame_urls: list[str] = Field(max_length=6)`; mirror caps in `analyze/index.ts` (reject >6 `frame_storage_keys`, >4000-char text) so the Edge fails fast.
3. fly.toml: add `[http_service.concurrency] type="requests", soft_limit=20, hard_limit=25`; Dockerfile CMD add `--limit-concurrency 32`.
4. Wrap the whole pipeline call in `main.py` with an overall budget (e.g. `anyio.fail_after(25)` via threadpool-safe pattern or check elapsed between steps) → degrade on breach.
5. Tests: hung-provider fake (sleep > timeout) → ProviderError → failover/degrade within budget; oversized body → 422.

**Files.** `ai-service/app/providers.py`, `models.py`, `main.py`, `Dockerfile`, `fly.toml`, `supabase/functions/analyze/index.ts`, tests.
**Validation.** pytest incl. new timeout tests; deploy; `hey`/`ab` mini-burst against `/health` while one slow request runs (staging machine) — health stays green.
**Rollback.** `fly deploy -i <prev>`; fly.toml concurrency removable independently.
**Acceptance.** Max wall-clock per analysis ≤ ~25 s worst case; load test does not trigger health-restart; 422 on oversized inputs.

---

## GAP-A5 — Make non-2xx function responses visible in-app (402 first)

**Problem.** `functions_client` throws `FunctionException` on non-2xx; blind catches discard server messages: free-limit 402 (`analysis_runner.dart:109-110`), PDF 402 (`pdf_report_service.dart:36-39` dead code), family errors (`family_repository.dart:70-102` dead code).
**Why.** Free users dead-end in a retry loop (conversion killed); PDF upsell never shows; invite errors all read "try again."
**Solution & tasks**
1. Add `lib/src/core/functions_error.dart`: `T mapFunctionException<T>(Object e, {required T Function(int status, Map<String,dynamic>? details) onHttp, required T Function() onOther})` — parse `FunctionException.status` + `details`.
2. Analysis runner: on 402 with `error == 'free_limit_reached'` (or A3's new payload) → route to paywall/upgrade sheet carrying the server message; on 5xx → existing safe error copy.
3. PDF service: 402 → upsell snackbar with action; family repository: surface `details.error` codes (invite limit, expired, wrong tier) to the screens.
4. Widget tests: fake `FunctionsClient` throwing `FunctionException(status:402, details:{…})` → paywall shown; 500 → error state.

**Files.** new `functions_error.dart`, `analysis_runner.dart`, `analysis_service.dart`, `pdf_report_service.dart`, `family_repository.dart`, + 3 test files.
**Validation.** `flutter analyze` + `flutter test`; live: exhaust a test account's 3 checks → 4th opens upgrade UI (device pass).
**Rollback.** Revert PR (pure client change).
**Acceptance.** A free user's 4th check shows the upgrade path (no retry loop); PDF/family errors show specific copy.

---

## GAP-A6 — Complete the deletion cascade (R2 + third parties)

**Problem.** `delete-account` deletes only the auth user; R2 objects under `uploads/<uid>/` and RevenueCat/OneSignal/PostHog subjects persist.
**Why.** GDPR/KVKK erasure + Apple 5.1.1(v) substance; pet photos can contain people/homes/EXIF-adjacent context.
**Solution & tasks**
1. In `delete-account/index.ts`, before `deleteUser`: R2 `ListObjectsV2` on prefix `uploads/<uid>/` (paginate) → `DeleteObjects` in ≤1000 batches (reuse `_shared/r2.mjs` signing; add `listObjects`/`deleteObjects` helpers + unit tests).
2. Fire-and-collect third-party deletions (each in try/catch, logged, non-fatal): RevenueCat `DELETE /v1/subscribers/{app_user_id}`; OneSignal delete-user by external id; PostHog `POST /api/.../persons/.../delete` (or log a manual-queue row if API plan lacks it).
3. Keep response `{ok:true}` fast: do R2+third-party work first (it's seconds), or enqueue via `pg_net` if >10 s at scale; current volumes → inline is fine within the client's 10 s timeout? Client timeout is 10 s + auth-probe fallback — measure; if list+delete exceeds ~6 s, return early and finish via a `pg_cron`-scheduled sweep table.
4. Add a `deletion_log` row (uid hash, counts, timestamps) for compliance evidence (service-role insert; no PII beyond hash).
5. mjs tests for the new R2 helpers (mock fetch); integration note in runbook 16.

**Files.** `supabase/functions/delete-account/index.ts`, `supabase/functions/_shared/r2.mjs` + tests, migration for `deletion_log` (+ RLS deny-all/service-only), runbook 16.
**Validation.** `node --test`; live drill on a throwaway account with 2 uploads → bucket prefix empty, RC/OneSignal subjects gone, client completes <15 s.
**Rollback.** Revert function deploy (old behavior = auth-only deletion).
**Acceptance.** Post-deletion: zero R2 objects under the uid prefix; third-party deletion attempts logged; client UX unchanged.

---

## GAP-B1 — Real Android release signing (+R8)

**Problem.** `release { signingConfig = signingConfigs.getByName("debug") }`; no keystore exists; no minify.
**Why.** Play upload impossible; CI AAB green is false confidence.
**Tasks**
1. Founder generates keystore (see PART 2 F-6) → `mobile/android/key.properties` (gitignored; template committed as `key.properties.example`).
2. `build.gradle.kts`: load `key.properties` if present; `signingConfigs.create("release")`; `buildTypes.release { signingConfig=…; isMinifyEnabled=true; isShrinkResources=true; proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro") }`; keep debug fallback ONLY when key.properties absent **and** print a loud warning, or better: fail release builds without it (`error("release signing not configured")`) so CI can't silently debug-sign — CI then uses a CI-provisioned keystore secret or builds `--debug` APK only + `bundle` with `--no-sign`? (Simplest: CI keeps `flutter build appbundle --release` with a dedicated **upload keystore stored as GH secret**, decoded in the workflow.)
3. Add `proguard-rules.pro` keeps for: Rive/Lottie reflection, OneSignal, RevenueCat, Sentry (consult each plugin's docs); smoke the release APK on-device (paywall, rive rig, push init paths are the classic R8 victims).
4. CI: after build, assert signature is NOT debug: `apksigner verify --print-certs build/.../app-release.aab`… (apksigner works on APK; for AAB use `jarsigner -verify` or build a release APK too) — gate on cert CN ≠ "Android Debug".
**Files.** `mobile/android/app/build.gradle.kts`, `mobile/android/key.properties(.example)`, `proguard-rules.pro`, `.github/workflows/ci.yml`.
**Validation.** Local `flutter build appbundle --release` + device install of release APK + full smoke (motion, paywall, capture); CI green incl. signature assertion.
**Rollback.** Revert gradle changes (debug-signed builds again — never ship them).
**Acceptance.** `bundletool`/Play console accepts the AAB; release APK runs the full device smoke without R8 crashes.

## GAP-B2 — Launcher icon + app label (30 min)
Run `dart run flutter_launcher_icons` (config exists, `assets/icon/app_icon.png` tracked); set `android:label="PawDoc"`, iOS `CFBundleDisplayName="PawDoc"`; verify adaptive icon on device launcher + Play asset preview. Files: generated mipmaps, both manifests. Acceptance: real icon on device; no default-F anywhere.

## GAP-B3 — Permission diet
Remove `READ_MEDIA_IMAGES` (and add `tools:node="remove"` for merged `READ_EXTERNAL_STORAGE`, `RECORD_AUDIO`) **or** ship the gallery-upload feature (product call — recommended post-launch; users often already have the photo). Remove iOS `NSPhotoLibraryUsageDescription` if no gallery. Re-generate merged manifest and re-check (`build/.../merged_manifests`). Acceptance: merged manifest contains only camera/internet/notification(+location after E2) permissions actually used.

## GAP-B4 — Wire release automation (Fastlane)
1. Move/instantiate per-platform: `mobile/android/fastlane/{Appfile,Fastfile}` (lane `play_internal`: `upload_to_play_store(track:'internal', aab:…, rollout:'0.1' for prod lane later)`), `mobile/ios/fastlane` + `Gemfile` + `Gemfile.lock` committed.
2. Fix `release.yml`: working-directory to the right dirs; `bundler-cache: true` now works; Android job (build AAB with release signing from secrets → `play_internal`); iOS job gated on `secrets.APP_STORE_CONNECT_KEY` presence.
3. Secrets per runbook 11 (match repo, ASC API key, Play service-account JSON — founder, PART 2 F-7/F-8).
4. Document rollback: Play = halt staged rollout/promote previous; iOS = Phased Release pause; ai-service = `fly releases` + `fly deploy -i <image>` (add to runbooks).
**Validation.** Tag `v0.9.0-beta1` on a branch → both lanes green to internal/TestFlight (first run will surface console-side gaps — budget half a day).
**Acceptance.** One git tag produces installable store-track builds with no manual steps besides store review.

## GAP-B5 — Truthify store metadata + web copy (with founder sign-off)
Replace in `docs/store_metadata/ios_app_store.md` + `google_play.md`: "Reviewed by veterinary experts" / "Built with veterinary input and reviewed for quality" → provable phrasing ("Built on published veterinary triage guidelines", or secure a real named DVM advisor — founder option F-10). Delete fabricated testimonials + the false footer claim from `web/app/page.tsx`; rebuild `web/out`. Add CI guard: `scripts/verify-no-placeholders.sh` greping `docs/store_metadata docs/legal web/app` for `\[(DATE|LEGAL ENTITY|ADDRESS)|TODO\(cms\)|Sarah M\.|Diego R\.|Priya K\.|Reviewed by veterinary experts` → wire into ci.yml. Acceptance: grep clean; founder signed off on final copy (record in PAST_DECISIONS).

## GAP-B6 — Submission asset pack
Engineering: export 6.7"/6.5"/5.5" + tablet screenshots from the device (real screens, caption overlays), 1024×500 feature graphic, 512 icon; write `docs/store_metadata/privacy_labels.md` (Apple) + `data_safety.md` (Play) mapping every SDK: collected={email, user-content photos/videos+health text, identifiers uid, usage PostHog, diagnostics Sentry}, tracking=No, encryption in transit, deletion in-app+URL. Founder: demo account creds, content-rating questionnaire, health-apps declaration (PART 2). Acceptance: a dry-run fill of both consoles hits zero unknown fields.

---

## GAP-C4/C5 — Privacy & paywall compliance engineering

1. **Consent gate:** first-run (pre-PostHog) lightweight consent screen (or settings-level analytics toggle + EU default-off by locale) — store boolean in shared_prefs; `Posthog().setup` only after opt-in; add `optOut()` toggle in Account. Files: `main.dart`, new `consent_screen.dart`, `account_screen.dart`.
2. **ToS acceptance:** signup screen checkbox "I agree to the Terms and Privacy Policy" (links) — block submit until checked; record `accepted_tos_at` (users table column migration; set via authenticated update policy extension or during first profile touch server-side).
3. **Paywall:** footer row with Terms + Privacy links (live URLs), auto-renew sentence ("Subscription renews automatically until cancelled in your store account settings."); Restore button: await → success/failure snackbar + `ref.invalidate(userProfileProvider)`; special-case `PurchaseCancelledError` → no error UI.
4. **Fonts:** commit Inter + the display font under `assets/fonts/`, add `fonts:` block in pubspec, `GoogleFonts.config.allowRuntimeFetching=false` in main, delete dead untracked ttf confusion (track it properly).
5. **Processor list + EU wording:** hand attorney the verified list (Supabase/Fly/Cloudflare R2/Anthropic/Google/OpenAI/Resend/RevenueCat/OneSignal/PostHog/Sentry/Upstash) and the true residency ("hosted in EU (Frankfurt); AI sub-processors in US").
6. **OneSignal logout** (`OneSignal.logout()` on sign-out) + **allowBackup=false** (or dataExtractionRules excluding auth prefs) — pair with E6/M-3.
Validation: flutter test additions (consent gating, paywall links present, restore feedback); manual GDPR walkthrough. Acceptance: no network call to PostHog before consent; paywall passes Apple 3.1.2 checklist; signup stores acceptance timestamp.

---

## GAP-D1 — Database isolation + backups (with founder console work)

1. Founder creates `pawdoc-dev` Supabase project (any region) + upgrades prod to **Pro ($25/mo) + PITR add-on**; record IDs in ENVIRONMENT_VARS (F-9).
2. Engineering: point local/dev tooling at dev project (`supabase link --project-ref <dev>`); `supabase db push` all 18 migrations to dev; add `scripts/assert-prod-guard.sh` (refuses `db push`/`functions deploy` when ref==prod unless `PAWDOC_PROD_DEPLOY=1`).
3. Restore drill (founder+agent): create throwaway table in dev, PITR-restore to timestamp, document in new runbook 22 `restore-from-backup.md`.
**Acceptance.** Prod has daily backups + PITR enabled (screenshot in runbook); dev work demonstrably hits dev; one successful documented restore.

## GAP-D2 — Minimum observability (1 day total)

1. **ai-service Sentry:** `sentry-sdk[fastapi]` pinned; init in `main.py` with `environment=("prod" if IS_PRODUCTION else "dev")`, `send_default_pii=False`, before_send scrubber reusing `mask_secrets`; alert rule → founder email/phone.
2. **Edge Functions:** tiny `_shared/alert.mjs` posting to Sentry (store DSN as function secret) or ntfy topic on `console.error` in analyze / revenuecat-webhook / generate-upload-url / delete-account.
3. **Degraded-rate signal:** in `analyze/index.ts`, server-side PostHog capture (`analysis_completed` with `tier_used`, `degraded: tier_used===0`, `moderation_rejected`) — PostHog insight + alert at degraded>10%/h.
4. **Uptime:** Better Stack (free) monitors: `pawdoc-ai.fly.dev/health`, Supabase REST root, (later) pawdoc.app — SMS/push to founder. **Note** `/health` is shallow: also add a weekly synthetic real-analysis check (script in runbook, or Better Stack POST with the service token from Doppler — acceptable since founder-side).
5. **Mobile Sentry tags:** `environment`/`release` in `SentryFlutter.init` options.
6. **Spend caps (founder console, F-11):** Anthropic, Google AI billing budget, OpenAI hard limit, Fly spend notification, Cloudflare R2 alert.
**Acceptance.** Kill the Gemini key in dev → founder gets an alert within minutes from two independent channels (Sentry + degraded-rate).

## GAP-D3 — Config drift closure
1. `scripts/sync-secrets.sh`: `doppler run -c prd -- bash` exporting → `fly secrets import` + `supabase secrets set --env-file` (explicit name allowlist per target; prints a diff of digests first; requires `PAWDOC_PROD_DEPLOY=1`).
2. Fix `fly.toml`: `primary_region = "fra"` + comment the 2-machine reality; (optional) commit `fly.toml` concurrency from A4 in same PR.
3. **auth-webhook decision (recommended: delete).** The DB trigger (#30) is strictly more robust; `supabase functions delete auth-webhook` + remove from config.toml + note in PAST_DECISIONS. (Alternative: set `SUPABASE_AUTH_WEBHOOK_SECRET` and wire the Auth hook — adds nothing now.)
4. Update CLAUDE.md function list (13) + ENVIRONMENT_VARS path.
**Acceptance.** `sync-secrets.sh --check` exits 0 (no drift); auth-webhook either gone or returns 401 (not 500) to garbage.

## GAP-D4 — Ops runbooks + support channel
Write runbooks (half-day, agent-draftable, founder-reviewed): 22-restore-drill, 23-provider-outage (decision tree incl. kill-switch flip + comms), 24-key-rotation (one dry-run rotating AI_SERVICE_TOKEN for real), 25-breach-72h (KVKK/GDPR steps, attorney contact, user-notice template), 26-rollback (fly -i image / functions redeploy sha / Play halt / iOS phased pause), 27-refunds+abuse. Support: Cloudflare Email Routing `support@pawdoc.app` → founder Gmail (F-4); add Account-screen "Contact support" tile (`mailto:` + app/version prefill); pg_cron daily digest of new `analysis_feedback` rows → ntfy/email. Acceptance: rotation dry-run completed once; test mail round-trips; feedback digest arrives.

## GAP-D5 — CI sovereignty
1. ci.yml: add `node-tests` job (`node --test supabase/functions/_shared/*.test.mjs`) + `deno check supabase/functions/**/index.ts` (setup-deno) + nightly `test-rls.sh` job (services: docker).
2. Pin all `uses:` to commit SHAs (shellcheck action, flyctl action, the rest are @vN-major — pin those too).
3. `scripts/github-branch-protection.sh`: set `required_status_checks: {strict:true, contexts:["AI service — ruff + pytest","Flutter analyze + test + build","Secret scan (gitleaks)","ShellCheck (scripts)","node-tests"]}` → founder runs it (F-12).
4. deploy.yml: `on: workflow_run: workflows:["CI"], types:[completed], branches:[main]` + `if: success()` (plus keep path filter via a guard step).
5. Add `verify-no-placeholders.sh` job (from B5).
**Acceptance.** A deliberately red PR cannot merge; a main push with failing CI does not deploy; node/deno/placeholder gates visible in checks.

---

## GAP-E fixes (grouped, smaller)

- **E1 password reset:** `supabase.auth.resetPasswordForEmail(email, redirectTo:'pawdoc://auth/recovery')` + "Forgot password?" on sign-in + recovery screen consuming the deep link (router already handles `pawdoc://`); requires SMTP — Supabase built-in mailer OK for beta, move to Resend SMTP for prod (F-13). Tests: widget test for the form; manual round-trip once domain email works. **Note:** requires turning email sending on — coordinate with E3 decision.
- **E2 location permissions:** add `ACCESS_COARSE_LOCATION`+`ACCESS_FINE_LOCATION` to AndroidManifest, `NSLocationWhenInUseUsageDescription` ("Find nearby veterinary clinics in an emergency.") to Info.plist. Acceptance: vet-finder GPS works on Android; iOS no crash.
- **E3 auth posture (founder decision + 30 min):** Recommended: turn **email confirmations ON** in Supabase dashboard (F-14) + raise min password to 8 in config + dashboard; remove Apple button on Android (`if (Platform.isIOS)`); either add Google button (supabase OAuth flow, server already configured) or turn the Google provider off — decide by launch scope. Update tests. Acceptance: settings endpoint shows `mailer_autoconfirm:false`; sign-in screen matches enabled providers per platform.
- **E4 Turkish keywords (decision):** if TR in scope: add `tr` blocks to `safety.py` + `emergency_keywords.mjs` (vetted translations incl. species-specific), parametrized tests + mirror-parity test, locale plumbed from app (`preferred_locale='tr'`). If not: document EN/DE-only scope in store listing + ToS.
- **E5 RevenueCat:** founder creates products/offerings + real Android SDK key (F-15); webhook idempotency: `processed_rc_events(event_id pk, processed_at)` migration + skip-if-exists before credit; constant-time compare reuse `cronSecretValid` pattern. Tests: duplicate event → single credit.
- **E6 push:** founder adds Firebase project + `google-services.json` (F-16) + OneSignal FCM key; client `OneSignal.logout()` on sign-out; device test = receive one reminder push.
- **E7 degraded ≠ credit:** in `analyze/index.ts` increment only when `meta.tier_used > 0 && !cacheHit===false-degrade` (i.e., real result); mjs test. Acceptance: degraded response leaves quota unchanged.
- **E8 upload hardening:** (a) founder 2-min live check: authed `generate-upload-url` returns URL + PUT succeeds (F-17 — also closes the 6/9 unknown); (b) presign with `Content-Type` fixed + `Content-Length` condition (R2 supports content-length-range via POST policy; for PUT, enforce max via `x-amz-content-sha256`? simplest: keep PUT but verify object size/type server-side in `analyze` before presignGet — HEAD the object, reject >10 MB or wrong type); (c) server EXIF backstop: in analyze, for images, fetch→strip→re-upload? cheaper: do the strip inside ai-service `media.py` after fetch (bytes already in hand — re-encode via Pillow, drop metadata) — closes M-2 with zero extra round-trips; (d) client `.timeout(60s/30s)` on invoke/PUT + error state.
- **E9 deep links:** once domain live — host `/.well-known/assetlinks.json` (web/public) with release cert SHA-256 + add `autoVerify` https intent-filter for `/invite/*`,`/r/*`,`/auth/*`; add manual invite-code entry fallback screen (parity with referral); decide+document email-binding for invites (recommend: bind when invited_email set).
- **E10 PDF:** covered by A5 mapper + add purchase CTA wiring to the add-on product (post-E5); fix silent no-op by surfacing generate errors.
- **E11 service hardening:** `FastAPI(docs_url=None, redoc_url=None, openapi_url=None)` when IS_PRODUCTION; config default-deny (`AUTH_REQUIRED unless AI_ENV==dev`); pin `anthropic==`, `google-genai==`, `openai==`, `httpx==` (+ hash lock via pip-tools later); deploy runbook step: `scripts/smoke-models.sh` calling both models with 1-token ping before traffic.
- **E12 family decisions:** entitlement — recommended: keep per-user for launch, document in paywall copy ("Family plan covers analyses by all members" only when implemented — verify current copy doesn't promise it); fix pets UPDATE WITH CHECK (`and (family_group_id is null or public.is_family_member(family_group_id))`) — migration + RLS test; route family Upgrade → paywall.
- **E13 l10n decision:** EN-only launch (recommended): set store locales EN, remove DE claim, keep DE emergency strings (harmless); OR finish extraction (~2–3 days). Localize the result-screen disclaimer string either way (it's safety copy).
- **E14 DB hygiene migration:** one migration adding CHECK constraints (`triage_level in ('EMERGENCY','MONITOR','LIKELY_NORMAL')`, `input_type in (…)`, `species in (…)`, `subscription_status in (…)` — verify exact value sets against code first), btree indexes (`health_events(pet_id)`, `analysis_feedback(analysis_id)`, `reminders(user_id)`, `reminders(pet_id)`, `referrals(referrer_user_id)`, `pets(user_id)` full), `alter view … set (security_invoker=on)` ×2, `revoke execute on function count_shared_group_memberships from authenticated`, guarded PDF decrement (`update … set pdf_reports_remaining = pdf_reports_remaining-1 where id=… and pdf_reports_remaining>0 returning …`). Validation: test-rls.sh + dev-project push first + verify app paths unaffected (esp. species values vs UI list).
- **E15 hygiene (10 min, founder):** `chmod 600 .env prd_secrets.env temp_prod.env doppler.env`; add `doppler.json` to .gitignore (the working-tree .gitignore edit already pending adds `runtime/` — fold in); commit the laptop-only reports/ + playbooks + fonts (none are secret) or move to a private docs repo; quarterly `doppler secrets download` → password manager.
- **E16 UX batch:** client quota pre-gate (read `freeRemaining` before capture sheet → upgrade sheet); drop symptom min to 8 chars OR client-side emergency-keyword bypass of the min; replace 6 raw `$e` snackbars with calm copy + `Sentry.captureException`; cap referral lifetime bonus (migration: `bonus_analyses <= 30` check or claim-side guard).

---

# PART 2 — FOUNDER ACTIONS (the external critical path)

> Sequence key: **F-1/F-2/F-3 start TODAY** (longest external lead times). Costs are estimates; all amounts USD unless noted.

| # | Action | How / who to contact | Depends on | Lead time | Cost |
|---|---|---|---|---|---|
| **F-1** | **Engage attorney** (health-tech/consumer; must cover: ToS+Privacy finalization, CR #24 vet-practice/VCPR review for launch jurisdictions, CR #9 retention decision, KVKK + GDPR, entity advice). Contact 2–3 in parallel: TR tech-startup firms + a US/EU-savvy one (or Termly/iubenda + limited counsel review as budget fallback — counsel still needed for CR #24). Hand them: the verified processor list (C4.5), data-flow summary, `docs/legal/*` templates, this audit's §C. | Email/intro calls this week | — | **2–4 weeks** (the critical path) | $1.5k–5k fixed-fee typical; KVKK add ~$500–1k |
| **F-2** | **E&O / professional liability insurance** ≥$100K (project hard gate). Brokers for tech E&O: Embroker, Vouch, Founder Shield (US-entity-friendly); TR: Allianz/AXA via broker if TR entity. Underwriting will probe the "information-not-diagnosis" framing — send them §F of the gap analysis (safety controls). | Start quotes now; bind effective pre-launch | entity decision (F-3) helps but quotes can start | **1–3 weeks** | $500–2,000/yr premium |
| **F-3** | **Entity decision** (with F-1): US LLC (Stripe-Atlas-style, $300–500 + ~$100/yr agent) vs TR şahıs/limited vs personal. Drives store seller name, tax, insurance party. | Decide within attorney kickoff week | F-1 advice | days (LLC formation 1–5 d) | $0–600 |
| **F-4** | **Domain + email live**: Cloudflare DNS — apex A/AAAA (or CNAME flattening) → Cloudflare Pages deploy of `web/` (after B5 copy fix + /privacy /terms pages exist); Email Routing: `support@pawdoc.app` → Gmail; SPF/DKIM/DMARC; verify `dig MX` + round-trip mail. | Cloudflare dashboard, ~1–2 h | B5/C-pages built | same day | ~$0 (Pages free) |
| **F-5** | **Supabase production hardening**: upgrade to Pro + PITR add-on; **turn email confirmations ON** (with E3); raise password min to 8; create `pawdoc-dev` project. | Supabase dashboard, ~1 h | — | same day | $25/mo + PITR ~$10/mo |
| **F-6** | **Android upload keystore**: `keytool -genkeypair -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`; store passwords in password manager + offline copy; **enroll in Play App Signing** at first upload (Google escrows the app key). | local machine, 30 min | — | same day | $0 |
| **F-7** | **Google Play developer account**: register ($25 one-time), identity verification (1–3 days), then create app record, accept Health declarations, content rating questionnaire, data-safety form (from B6 doc), add the web deletion URL (F-4 page), upload service-account JSON for Fastlane. | play.google.com/console | F-3 (seller name), F-4 | **2–5 days** | $25 once |
| **F-8** | **Apple Developer Program**: enroll ($99/yr; org needs DUNS ~1–2 wk — individual is faster), App Store Connect app record, ASC API key for Fastlane, match certs repo (`pawdoc-certs` private), TestFlight setup. iOS build work needs a Mac (H7) — schedule. | developer.apple.com | F-3 | **2 days (individual) – 3 wks (org)** | $99/yr |
| **F-9** | **Record/verify infra state in ENVIRONMENT_VARS.md** after F-4/F-5 (single source of truth refresh; mark each live value's location: Doppler key name only, never values). | 30 min | F-4/5 | — | — |
| **F-10** | **Veterinary advisor (optional but high-leverage):** one consulting DVM reviewing emergency keyword lists (+TR set), golden-set cases, and lending a *real* name for "veterinary-informed" claims. Find via local clinic / vet-school network / Upwork DVM consultants. | outreach | — | 1–2 weeks | $200–500 one-off |
| **F-11** | **Spend caps**: Anthropic console budget alert; Google AI Studio→billing budget; OpenAI hard limit ($20/mo is plenty); Fly spend notification; Cloudflare R2 alert; **confirm Gemini is on paid tier** (the 10k-user cliff). | each console, ~1 h total | — | same day | $0 |
| **F-12** | **Apply branch protection with required checks** (run updated `scripts/github-branch-protection.sh` after D5). | 5 min | D5 merged | — | — |
| **F-13** | Resend domain verify (after F-4) → use as Supabase SMTP for auth emails (confirmations/reset) so they don't land in spam. | Resend + Supabase dashboards, 30 min | F-4 | same day | free tier OK |
| **F-14** | Flip auth settings (with E3): confirmations ON + test one real signup→confirm→reset-password round-trip on device. | dashboard + device, 30 min | F-13, E1 merged | — | — |
| **F-15** | **RevenueCat**: create Play (and later iOS) products: monthly $9.99 / annual $59.99 (fix the ~$5 vs $4.99 copy at the same time — pick one), family $24.99, PDF add-on $4.99; paste real `REVENUECAT_PUBLIC_SDK_KEY_ANDROID` into Doppler; configure entitlement `premium` + offering; sandbox-test one purchase + webhook delivery. | RC dashboard + Play console | F-7 | 0.5 day | RC free <$2.5k MTR |
| **F-16** | **Firebase/FCM**: create project, add Android app (`app.pawdoc`), download `google-services.json` → commit (it's not secret); upload FCM service credentials to OneSignal; device push test. | Firebase + OneSignal consoles | — | 1 h | $0 |
| **F-17** | **2-minute live check**: photo upload + analyze on device (closes the 6/9 unknown after A1/A2/E8 deploy); also the untethered 10-min battery soak from the motion audit. | device | Wave 0 deployed | 15 min | — |
| **F-18** | **Beta recruitment**: 50 testers (pet-owner communities, friends/family, local vet clinic clients with F-10's blessing); prep TestFlight external group / Play closed track email list; feedback form + the in-app feedback already built. | ongoing during waves | Tier-2 beta gate | 1–2 weeks overlap | $0 |
| **F-19** | **Tax/payout setup** in both consoles (banking, tax forms — W-8BEN if TR individual on US stores). | consoles | F-3, F-7/F-8 | days | — |
| **F-20** | **TalkBack full-app accessibility pass** + screenshot capture session for B6 (one sitting, device + agent script). | device, 2 h | Wave 1 UI fixes | — | — |

---

# PART 3 — VALIDATION MATRIX (run after each wave; all must be green before store submission)

1. `flutter analyze && flutter test` · `ruff && pytest` · `node --test …` · `./scripts/test-rls.sh` · `./scripts/verify-disclaimers.sh` · `./scripts/verify-no-placeholders.sh` (new)
2. CI green on main incl. new jobs; required checks enforced (try a red PR — must be blocked).
3. Live read-only probes: `/analyze` 401s; functions 401s; `auth/v1/settings` shows confirmations ON; `dig pawdoc.app` resolves; `/privacy` `/terms` 200; MX present.
4. Live device pass (founder): signup w/ email confirm → onboarding → pet → **photo** check (verify result references image content) → text check → EMERGENCY text (instant, un-paywalled, uncounted) → out-of-quota photo behavior (A3) → 402 upgrade UI (A5) → PDF 402 upsell → restore purchases feedback → push received → delete account (<15 s, then R2 prefix empty).
5. Burst smoke vs staging machine (A4): health stays green during one slow request + 30 quick ones.
6. Kill-switch drill + key-rotation dry-run (D4) once each.

*End of playbook.*
