# PAWDOC LAUNCH GAP ANALYSIS — Final Go-Live Readiness Audit

> **Date:** 2026-06-12 · **Auditor:** autonomous full-stack audit (7 parallel domain audits + fresh test runs + live production probes)
> **Method:** evidence over documentation. Every prior report was treated as a *claim* and re-verified against code (`main` @ `e1aed76`), fresh test executions, and the **live production backend**. Where reports conflicted with reality, reality won.
> **Companion documents:** `PAWDOC_REMEDIATION_PLAYBOOK.md` (per-issue fixes) · `PAWDOC_GO_LIVE_MASTER_PLAN.md` (execution waves + verdict).

---

## 0. VERDICT UP FRONT

### Can PawDoc launch tomorrow? **NO.**

**The four reasons, in one paragraph each:**

1. **The flagship feature does not work.** Photo/video triage never sends a single pixel to any AI model. Both `GeminiProvider.analyze` and `ClaudeProvider.analyze` (`ai-service/app/providers.py:55-90,125-153`) accept `image_url`/`frame_urls` but use them only to *pick a model name*; the actual API call contains text only, while the prompt falsely tells the model "An image is provided." A photo-only check is decided on zero visual input — the exact false-negative engine the project names as its #1 business risk. Verified independently three times (AI-service audit, ops audit, and line-by-line by the lead auditor).
2. **The app cannot be submitted to a store.** Android release builds are signed with the **debug** keystore (`mobile/android/app/build.gradle.kts:35-37`, the template TODO is still there); no upload keystore exists anywhere; the launcher icon is still Flutter's default "F"; `release.yml` is broken (Fastlane never wired into the platform dirs); store metadata still contains the unsubstantiated claim "Reviewed by veterinary experts."
3. **The legal gate is fully open.** Privacy Policy and ToS are bracketed templates (`docs/legal/*.md` literally say "TEMPLATE — NOT LEGAL ADVICE", `[DATE]`, `[LEGAL ENTITY]`); E&O insurance is not bound; the vet-practice-law review (CR #24) and retention decision (CR #9) never happened; **pawdoc.app does not resolve** (no apex A record; `/privacy` and `/terms` 404 even on www; no MX record, so `support@pawdoc.app` cannot receive mail). Every legal/referral/invite link the shipped app contains points at a dead domain.
4. **Nobody would know if it broke.** No Sentry in the AI service or Edge Functions, no uptime monitor, no spend caps, no degraded-rate metric — and the architecture *masks* outages by design (every failure degrades to a calm MONITOR result). This blind spot is proven, not theoretical: the AI path was dead in production for days in early June and looked "up" the whole time.

**What is genuinely strong** (verified, not assumed): the text-triage safety pipeline, the RLS isolation model, the emergency-never-paywalled dual enforcement for text, server-forced disclaimers, the presigned-upload design, webhook auth, clean git history, and a CI that blocks on analyze/test/build/gitleaks/shellcheck. The skeleton is launch-grade. The gaps are concentrated in (a) the multimodal path, (b) release/store mechanics, (c) legal/ops/founder work.

**Shortest path to launch:** ~1 engineering week (Wave 0+1) running **in parallel with** the founder's legal/insurance critical path (2–6 weeks, external) → store-distributed beta → submission. Detail in `PAWDOC_GO_LIVE_MASTER_PLAN.md`.

---

## 1. WHAT WAS VERIFIED, AND HOW (evidence chain)

### 1.1 Fresh test executions (2026-06-12, this audit)
| Suite | Result |
|---|---|
| `flutter analyze` | ✅ No issues |
| `flutter test` | ✅ **190 passed** (+1 documented skip) |
| `ruff check` (ai-service) | ✅ clean |
| `pytest` (ai-service) | ✅ **167 passed** |
| `node --test` (edge shared) | ✅ **81 passed** |
| `./scripts/test-rls.sh` (Docker, real Postgres) | ✅ **PASS** — cross-user isolation, family sharing, invites, Phase-B deletion cascade |
| `./scripts/verify-disclaimers.sh` | ✅ 6/6 (run during legal audit) |

### 1.2 Live production probes (2026-06-12, read-only)
| Probe | Result | Meaning |
|---|---|---|
| `GET https://pawdoc-ai.fly.dev/health` | 200, v3.2.0, 315 ms | AI service deployed & healthy |
| `POST /analyze` no token / bad token | **401 / 401** | **Bearer auth enforced LIVE** — playbook RF-1 resolved in production |
| `GET /docs`, `/openapi.json` | 200 | Schema publicly exposed (finding E11) |
| `fly status / releases` | 2× shared-1x-512MB in **fra**, v11 (Jun 10), checks passing | Deployed; fly.toml says iad/1 — drift |
| Supabase functions ×5 unauthenticated | 401 (analyze, upload-url, delete-account, revenuecat-webhook) | Auth gates live |
| `POST functions/v1/auth-webhook` | **500 "server misconfigured"** | Deployed function missing its secret env (impact neutralized by DB trigger #30, but live misconfig) |
| `GET /auth/v1/settings` | **`mailer_autoconfirm: true`**, `google: true`, `apple: false`, signup open | Email verification OFF in prod; Google enabled server-side (no client button); Apple disabled server-side (client ships the button) |
| REST anon probe `analyses` | `[]` 200 | RLS holds against anon |
| `supabase functions list` | **13 functions ACTIVE** (CLAUDE.md documents 5) | incl. `analyze-anonymous` (unauth, Turnstile+3/day/IP) |
| `dig pawdoc.app` | **No A/AAAA record** (NS = Cloudflare) | Domain registered, nothing served; www = parked placeholder; /privacy /terms 404; **no MX** |
| `adb devices` | **No device attached** | On-device walkthrough not re-runnable today (see 1.3) |

### 1.3 Device-pass evidence (most recent available)
No Android device was attached during this audit and no emulator exists on this host, so the Phase-1 on-device walkthrough relies on the **2026-06-11 live device pass** (Xiaomi 22095RA98C, Doppler **prd** build, evidence in `runtime/motion_validation/`): fresh in-app signup → real AI **MONITOR** result → live **EMERGENCY** (AI-returned, cross-verified, instant-cut, un-paywalled) → quota tick 3→2→1→0 → **delete-account ~14 s with Cancel usable** (bug F-1 fixed and verified live) → account deleted server-side. That pass was **text-path only** — it does not cover photo upload (see GAP-A1/E8-upload) — and a live **write** probe by this audit (signup→analyze→delete) was permission-denied by the operator's tooling policy, so the text-path E2E stands on 6/11 evidence and the photo-path E2E stands on the 6/9 evidence (**broken**: `generate-upload-url` returned "storage not configured"). **No newer evidence exists that photo upload works in production.**

### 1.4 Claims vs. reality (report reconciliation)
The 2026-06-07 playbook and 2026-06-09 E2E report were mined for every claimed-open item and re-verified:

| Prior claim (newest source) | Reality today (verified) |
|---|---|
| RF-1 AI service unauthenticated | ✅ **RESOLVED** — PR #29 merged AND live-verified (401s) |
| RF-4 family deletion cascade | ✅ RESOLVED — PR #32 + RLS suite "PHASE B FAMILY-DELETION CASCADE OK" |
| RF-5 provisioning SPOF | ✅ RESOLVED — DB trigger (PR #30) live since 6/9; auth-webhook now redundant (and misconfigured live — GAP-D3) |
| RF-7 video keyframes unmoderated | ✅ RESOLVED — PR #33, fail-closed per frame (pytest-verified) |
| RF-8 moderation silently disabled | ✅ RESOLVED — prod refuses to boot without key (`main.py:77-91`) |
| RF-3 fabricated social proof in app | ✅ RESOLVED in-app (UI cycle A+B merged) — ❌ **STILL PRESENT in store metadata + web landing source** (GAP-B5) |
| E2E Bug #1 (no profile row) | ✅ RESOLVED (trigger, live-verified 6/11 signup) |
| E2E Bug #2 (AI degraded, no creds) | ✅ RESOLVED — live AI results 6/11; Fly secrets present |
| E2E Bug F-1 (delete hang) | ✅ RESOLVED — M0/M4 fix, ~14 s live, 8 regression tests |
| E2E Bug #3 (upload broken) | ⚠️ **UNVERIFIED** — no live evidence since the 6/9 failure; functions redeployed 6/8–6/9 but R2 env state unconfirmable read-only (GAP-E8a) |
| E2E Bug #4 (RevenueCat "NOT YET") | ❌ **OPEN** — Android SDK key placeholder, products unconfigured (GAP-E5) |
| E2E Bug #5 (push FCM) | ❌ **OPEN** — `google-services.json` absent (verified today) (GAP-E6) |
| E2E Bug #6 (PDF silent no-op) | ❌ OPEN — root cause now identified (402/error mapping dead code, GAP-E10) |
| E2E Bug #7 (degraded consumes credit) | ❌ OPEN — confirmed in `analyze/index.ts` (increment not gated on `tier_used>0`) (GAP-E7) |
| RF-6 Fastlane not wired | ❌ OPEN — release.yml broken (GAP-B4) |
| RF-10 no provider timeouts | ❌ OPEN — verified, Anthropic default 600 s (GAP-A4) |
| RF-11 CI gates not required checks | ❌ OPEN — protection script PUTs `required_status_checks: null` (GAP-D5) |
| RF-12 missing CHECK constraints | ❌ OPEN — verified zero CHECKs on enum columns (GAP-E14) |
| RF-2 legal/insurance gate | ❌ OPEN — nothing started (GAP-C1/C2) |
| Memory note "M0–M4 awaiting approval" | ❌ STALE — M0–M4 merged (#35–#40) and device-validated |

---

## 2. FINDINGS REGISTER (complete, with evidence)

Severity: **CRITICAL** = must fix before *any* external user · **HIGH** = blocks public launch / store submission (※ = also blocks a 50-user beta) · **MEDIUM** = fix during beta · **LOW** = backlog.

### A. Product-breaking & safety (engineering)

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| **GAP-A1** | **CRITICAL ※** | **Photo/video pixels never reach any AI model.** `image_url`/`frame_urls` only select the model name; Gemini gets a concatenated text string, Claude gets a plain-text message. Prompt claims an image is attached. Photo-only check → model sees nothing → "confident" triage on zero visual input, or (best case) sub-0.60 confidence "insufficient information" for every photo. Flagship feature is non-functional; direct false-negative risk. Masked until now because prod uploads were also broken and all device passes were text-path. | `ai-service/app/providers.py:63-72` (contents = text join), `:148` (messages = text), `prompts.py:187`; tests only assert URL plumbing (`tests/test_pipeline.py:17`, `test_video.py:19`) |
| **GAP-A2** | **CRITICAL ※** | **Authenticated blind SSRF via client-controlled `image_url`.** Edge Function forwards the client's `image_url` verbatim (takes precedence over the server-presigned key) to the AI service, whose moderator GETs it from inside Fly's network (6PN/.internal/localhost/metadata). Safe/unsafe boolean + latency = oracle. Signups auto-confirm, so attacker cost is ~zero. | `supabase/functions/analyze/index.ts:92,184-185` (verified line-level); `ai-service/app/moderation.py:41` |
| **GAP-A3** | **CRITICAL** | **Out-of-quota photo/video emergency is paywalled.** The "EMERGENCY is never paywalled" bypass keys solely off **text** keywords; a free user past 3/month submitting a photo emergency (pale gums, bloat) with neutral text gets `402 free_limit_reached` **before any AI runs** — the image-based emergency can never be detected. Violates the project's own non-negotiable. (Compounded by GAP-A5: the 402 renders as a generic error.) | `analyze/index.ts:116-133` (verified); CLAUDE.md trust rule |
| **GAP-A4** | **CRITICAL ※** | **No timeouts on triage provider calls + unbounded concurrency + unbounded request size.** Anthropic SDK default timeout 600 s (verified in vendored SDK); Gemini no per-request cap; endpoints are sync `def` on a 40-thread pool; no `--limit-concurrency`, no fly.toml concurrency block; `text_description` and `frame_urls` uncapped. Failure mode under provider hang/burst: threads pin → `/health` (same pool) stops answering → Fly 2 s check fails → machine restarts, killing all in-flight analyses. P95<10 s budget unenforceable. | `providers.py:136` (no `timeout=`), `models.py:26-46`, `Dockerfile:24`, `fly.toml`; contrast: journal has 30 s timeout (`journal.py:80`), moderation 5 s |
| **GAP-A5** | **CRITICAL ※** | **Free-tier 402 renders as a generic "couldn't analyze… try again" error.** `functions_client` throws `FunctionException` on non-2xx; the runner's blind `catch (_)` discards the server's upgrade message → free users hit a retry loop that can never succeed. Every 4th check by every free user dead-ends; conversion path broken. Same dead-code pattern kills PDF 402 upsell and family-invite error detail. | `mobile/lib/src/analysis/analysis_runner.dart:109-110`, `analysis_service.dart:39-46`, `pdf_report_service.dart:36-39`, `family_repository.dart:70-102`; `functions_client-2.5.0/.../functions_client.dart:186` |
| **GAP-A6** | **CRITICAL** | **Account deletion leaves all R2 media + third-party PII.** `delete-account` only calls `auth.admin.deleteUser`; DB rows cascade but `uploads/<userId>/*` in R2, RevenueCat subscriber, OneSignal device, PostHog person are never deleted. Breaks GDPR/KVKK erasure and Apple 5.1.1(v) in substance. (Server returns fast; the old client hang F-1 is fixed.) | `supabase/functions/delete-account/index.ts:32` |

### B. Release & store mechanics

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| **GAP-B1** | **CRITICAL ※(Play-distributed beta)** | Android release signs with **debug keys**; no upload keystore on disk; no `key.properties`; no R8/minify. CI's AAB "validation" is debug-signed false confidence. Play upload impossible. | `mobile/android/app/build.gradle.kts:34-39` |
| **GAP-B2** | HIGH ※ | App ships **default Flutter launcher icon**; label is lowercase `pawdoc` (iOS `Pawdoc`). `flutter_launcher_icons` configured but never run. | `mobile/android/.../mipmap-*` (May-27 template files), `AndroidManifest.xml:8`, `pubspec.yaml:166-171` |
| **GAP-B3** | HIGH | `READ_MEDIA_IMAGES` (+merged `READ_EXTERNAL_STORAGE`) declared with **no gallery feature in the app**; `RECORD_AUDIO` merged while audio disabled. Play "permissions without core usage" rejection class. iOS declares photo-library string for the same nonexistent feature. | Manifest + zero `image_picker` hits |
| **GAP-B4** | HIGH | **Release automation broken.** `release.yml` cd's into `mobile/ios` where no Fastfile/Gemfile exists (files live at repo root, never relocated); no `Gemfile.lock`; no Android release workflow; match repo existence unverified. A `v*` tag = red run. No staged-rollout/halt design. | `.github/workflows/release.yml:40-43`, `fastlane/Fastfile` comment |
| **GAP-B5** | HIGH ※(if store-listed beta) | **Overclaims still in store metadata + web:** screenshot caption "Reviewed by veterinary experts", "Built with veterinary input and reviewed for quality"; fabricated testimonials (Sarah M./Diego R./Priya K.) live in `web/app/page.tsx` and the compiled `web/out/`; web footer claims terms/privacy "are published" (false). FTC/store-deception class — the exact copy already removed from the app, surviving in the storefront surfaces. | `docs/store_metadata/ios_app_store.md:66,90`, `google_play.md:57,78`, `web/app/page.tsx:10-15,52-60,76` |
| **GAP-B6** | HIGH | Submission assets missing: captioned screenshots ×slots, 1024×500 feature graphic, Apple privacy-label mapping, Play data-safety mapping (PostHog/Sentry/OneSignal/RC/AI sub-processors), reviewer demo account, **Play web account-deletion URL** (required; currently impossible — domain dead). | `docs/store_metadata/*`, `images/old-image/` raw captures only |

### C. Legal, privacy & compliance (founder + attorney)

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| **GAP-C1** | **CRITICAL ※** | Privacy Policy & ToS are **templates**: "TEMPLATE — NOT LEGAL ADVICE", `[DATE]`, `[LEGAL ENTITY]`, §8 governing law "[to be drafted by counsel]", liability cap bracketed. No legal entity exists/decided (personal liability for a health-adjacent product). | `docs/legal/privacy-policy.md:3-9`, `terms-of-service.md:3-9,52-69` |
| **GAP-C2** | **CRITICAL** | **E&O insurance not bound** (project's own ≥$100K hard gate); **CR #24** vet-practice-law review (US VCPR states, EU, Turkey) not done; **CR #9** retention-vs-erasure undecided (privacy policy §6 literally says "DECISION REQUIRED"). Weeks-long external critical path; nothing started. | runbook 18, playbook RF-2, `privacy-policy.md:55-61` |
| **GAP-C3** | **CRITICAL ※** | **pawdoc.app is dead.** No apex A/AAAA (NS on Cloudflare); www = parked 200 placeholder; `/privacy`, `/terms`, `/check`, `/delete-account` 404/000; **no MX → support@pawdoc.app cannot receive mail**. Dead surfaces shipped in-app: legal links (sign-in + account screens), referral `pawdoc.app/r/CODE`, family invites `pawdoc.app/invite/TOKEN`, store privacy-URL fields, Play deletion URL. `web/` (Next.js static export) is built but has **no /privacy or /terms routes** and was never deployed. | dig/curl 2026-06-12; `web/app/` listing; `invite-family-member/index.ts:111` |
| **GAP-C4** | HIGH | Privacy engineering: **PostHog fires pre-consent** (boot-time setup+identify, no banner/toggle, US host) — EU/GDPR + KVKK exposure; privacy policy's EU-residency claim is **currently false** (single Frankfurt project, no EU routing — actually fine if reworded: data IS in Frankfurt); processor list missing **Fly.io, OpenAI (journals), Resend**; **no affirmative ToS acceptance at signup** (ToS asserts it exists); **KVKK zero coverage** (founder is TR-based); google_fonts runtime fetch (LG München class); no data-export path beyond per-pet report. | `main.dart:59-74`, `onboarding_flow.dart:60`, `privacy-policy.md:38-45`, `env.dart`, grep-verified absence |
| **GAP-C5** | HIGH | Paywall missing Terms/Privacy links + auto-renew disclosure (Apple 3.1.2 / Play subs policy); Restore Purchases gives zero feedback and doesn't refresh entitlements; user-cancelled purchase shows an error snackbar. | `paywall_screen.dart` (entire, :173-180, :84-88) |
| GAP-C6 | MED | Affiliate CTAs (telehealth + insurance) on the EMERGENCY screen lack compensation disclosure (FTC endorsement guides; optics of monetizing emergencies). Not a paywall, so the trust rule holds. | `emergency_result_screen.dart:90-96`, `insurance_affiliate_cta.dart:50-51` |
| GAP-C7 | MED | Age policy: ToS says 18+, no in-app age gate, store ratings 4+/Everyone — permitted but flag to counsel. Result-screen disclaimer hardcoded EN while app ships DE strings. | `terms-of-service.md:27-29`; `result_screen.dart:265` |

### D. Infrastructure, ops, CI/CD

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| **GAP-D1** | **CRITICAL ※** | **One Supabase project total** (Frankfurt) — dev work runs against the production DB; runbook-06's dev/prod/EU split never executed. Tier/PITR/backup state unverifiable read-only; no restore drill has ever run. A bad migration or dev `db push` destroys real health data with no undo. | `supabase projects list` (1 project); runbook 06 |
| **GAP-D2** | **CRITICAL ※** | **Zero alerting.** No Sentry in ai-service (no sentry-sdk dep) or Edge Functions; mobile Sentry has no environment/release tagging; no uptime monitor (runbook-12 item unchecked); no spend caps on Anthropic/Google/OpenAI/Fly/Places; no degraded-rate or moderation-reject metrics (PostHog has no `analysis_failed`/`analysis_degraded` events). Degraded-MONITOR design **masks** outages — proven live blind spot (early-June outage looked healthy for days). | requirements.txt, grep, `analytics.dart` event list |
| **GAP-D3** | HIGH | **Config/secret drift is systemic:** Doppler→Fly/Supabase sync is manual (the proven root cause of the 6/9 outage); `fly.toml` says iad/1-machine vs live fra/2-machines; **auth-webhook live-500s "server misconfigured"** (its secret never set in deployed env — function is redundant since trigger #30: either configure or delete it); CLAUDE.md documents 5 functions, 13 are deployed. | live probes 2026-06-12; `fly.toml` |
| **GAP-D4** | HIGH ※(minimal set) | **No operational runbooks** (22 exist, all setup-oriented): nothing for provider outage decision tree, key rotation/leak, **KVKK/GDPR 72 h breach procedure**, restore-from-backup drill, store takedown, refunds, abusive users, rollback (`fly deploy -i <image>` undocumented). **No support mailbox** (no MX), no in-app contact (zero `mailto` hits), feedback lands in a table nobody is alerted on. | `docs/runbooks/` inventory; grep |
| **GAP-D5** | HIGH | **CI gaps:** `node --test` (free-tier/emergency-keyword/RC parsing logic) not in CI; branch protection script PUTs `required_status_checks: null` (a red PR can merge); `deploy.yml` deploys on push regardless of CI state; actions pinned to `@master` (shellcheck, flyctl) — supply chain; no `deno check` of function TS; RLS suite not in CI (nightly candidate). | `.github/workflows/*`, `scripts/github-branch-protection.sh` |

### E. High/medium product & hardening

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| GAP-E1 | HIGH ※ | **No password reset** — no `resetPasswordForEmail`, no "Forgot password" UI. Week-1 lockouts unrecoverable (and support email is dead). | grep `lib/` = 0 hits |
| GAP-E2 | HIGH | **Location permissions missing** (Android manifest + iOS plist) while vet-finder calls `requestPermission()` → **iOS crash on the emergency-adjacent path**; Android silently degrades to ZIP entry. | manifests; `vet_finder_screen.dart:46-68` |
| GAP-E3 | HIGH | **Auth posture decisions:** `mailer_autoconfirm: true` live (squatting/throwaways; amplifies referral farming), min password 6; **Google enabled server-side with no client button; Apple OFF server-side while the client ships SIWA — including on Android where it always fails.** | live `/auth/v1/settings`; `sign_in_screen.dart:179-184` |
| GAP-E4 | HIGH(TR launch) | **No Turkish emergency keywords** (EN 23 + DE full set only; unknown locale silently falls back to EN). A Turkish "nefes alamıyor" gets no pre-AI override. Decide launch locales explicitly. | `ai-service/app/safety.py:25-123` |
| GAP-E5 | HIGH(monetized launch) | **RevenueCat:** Android SDK key placeholder ("NOT YET"), products/offerings unconfigured (paywall correctly shows safe "coming soon"); webhook add-on credits **non-idempotent** (RC retries ⇒ double credit); secret compare non-constant-time. | E2E 6/9; `revenuecat-webhook/index.ts:17,42-73` |
| GAP-E6 | HIGH(public) | **Push dead:** no `google-services.json` (verified absent today) → FCM/OneSignal cannot deliver; OneSignal external-id never cleared on logout (shared-device cross-user pushes). | fs check; `onesignal_service.dart` |
| GAP-E7 | MED | **Degraded analyses consume free credits** (E2E Bug #7): increment guards on thrown errors only, not `tier_used==0`. Users pay quota for non-answers. | `analyze/index.ts:311-318` (verified) |
| GAP-E8 | HIGH ※(photo path) | **Upload path:** (a) live R2-env state unverified since the 6/9 "storage not configured" failure — needs a 2-minute live check; (b) presigned PUT has no Content-Length/Type constraint (cost abuse); (c) no server-side EXIF backstop (client-only strip); (d) no client timeouts on upload/analyze (stalled = infinite spinner — same class as fixed F-1). | `generate-upload-url/index.ts:56-65`; security M-2; `upload_service.dart:24,36` |
| GAP-E9 | MED | **Deep links:** only `pawdoc://` custom scheme (hijackable; invite/auth token interception); https App Links blocked on the dead domain; family invite links dead-end (no manual-code fallback, unlike referral); invite accept not bound to `invited_email` (conscious MVP choice — record it). | manifest:32-40; `accept-family-invite/index.ts` |
| GAP-E10 | MED | **PDF report:** 402-upsell path is dead code (same FunctionException class as A5), no purchase path even after fix, silent no-op UX (Bug #6). | `pdf_report_service.dart:32-41`, `history_timeline_screen.dart:60-68` |
| GAP-E11 | MED | **AI service hardening:** `/docs`+`/openapi.json` public; non-Fly host silently fails open (default-deny instead); Gemini no `max_output_tokens`; SDK retries stack on pipeline retries (set `max_retries=0`); provider deps floor-only unpinned; model IDs (`claude-sonnet-4-6`, `gemini-2.0-flash`) never smoke-tested at deploy; prompt-cache comment wrong (prefix below 2048-token minimum — silent no-op, cost-neutral). | `main.py:31`, `config.py:58`, `providers.py:81-84`, requirements.txt |
| GAP-E12 | MED | **Family/product decisions:** premium entitlement is per-user (free family member still gated on shared pets — decide if Family tier should extend); `pets` UPDATE WITH CHECK doesn't re-assert family membership (group-injection nuisance); family "Upgrade" button routes to onboarding instead of paywall. | `analyze/index.ts:107-111`; `family_sharing.sql:246-248`; `family_settings_screen.dart:69` |
| GAP-E13 | MED | **Localization is a shell:** only ~8 ARB keys (emergency/result strings) localized; rest hardcoded EN → mixed-language app for DE users; analyze call carried `en` from a DE device in the 6/11 pass (server received no DE locale → keyword override language mismatch). Decide: EN-only launch (remove DE claim) or finish l10n. | grep `AppLocalizations` (4 files); motion audit Honesty Ledger #5 |
| GAP-E14 | MED | **DB hygiene:** zero CHECK constraints on enum-ish columns (`triage_level`, `species`, `subscription_status`, `input_type` — RF-12, verified); missing indexes on hot RLS predicates (`health_events.pet_id`, `analysis_feedback.analysis_id`, `referrals.referrer_user_id`, …); accuracy views not `security_invoker`; `count_shared_group_memberships` executable by any authenticated user (info leak, service-role-only caller); PDF credit decrement race; service-role used for 3 own-profile *reads* (convention deviation, no exposure). | migrations grep (verified); supabase audit L-1..L-6 |
| GAP-E15 | MED | **Local secret hygiene:** `.env`/`prd_secrets.env`/`temp_prod.env` are mode **664 with real prod secrets** (service-role key, Fly token, R2, Anthropic) — world-readable on this host; `doppler.json` (encrypted Doppler fallback) **not gitignored** — one `git add -A` from history; launch-critical docs (playbook, reports) + `Inter-Regular.ttf` exist only on this laptop (bus factor). | `stat` outputs; `git check-ignore` |
| GAP-E16 | MED | **Quota/emergency UX:** no client pre-gate (free user with 0 left completes camera→upload before the broken 402); 20-char minimum blocks "he's choking" (12 chars) before the server keyword check can run; raw `$e` exception strings in 6 user-facing snackbars; referral bonus uncapped (farming with auto-confirm, ties E3). | `home_screen.dart:41-89`, `symptom_text_screen.dart:20`, grep; `referrals.sql:97-102` |
| GAP-E17 | LOW | Misc: permission-denied screens lack an Open-Settings button; `userProfileProvider` bang on `currentUser!`; landscape enabled on iOS untested; `Pawdoc` display-name casing; invite magic-link logged when Resend unset; `analyze-anonymous` CORS `*` (acceptable — no credentials — but lock to pawdoc.app once live). | various (see audits) |

### F. Verified SOLID (do not touch; cite to insurer/Apple)

Text-path safety chain end-to-end (hardcoded pre-AI emergency override EN/DE → cross-verified EMERGENCY kept on disagreement → confidence <0.60 → insufficient-information → degraded fallback never NORMAL → borderline-NORMAL re-biased to MONITOR) · temp 0.1 everywhere · structured-JSON-only with reject/retry/degrade · **disclaimer structurally always true** (`_outcome` forces it; UI gates on the flag) · EMERGENCY never paywalled for text at **both** layers + uncounted + instant-cut/no-motion/ack-gated UI · moderation fail-closed (prod refuses to boot keyless; every frame checked) · auth boundary constant-time, fail-closed in prod, live-verified · RLS on all 11 user tables with per-op USING+WITH CHECK (Docker suite green; live anon probe blocked) · presigned uploads with per-user namespacing + ext allowlist (R2 write keys server-only) · webhook/cron auth (HMAC, constant-time, fail-closed) · `delete-account`/`claim-referral` identity from JWT only (no IDOR) · referral claim atomic/race-safe/self-block · **git history clean across 140 commits + dangling objects** · CI fully blocking (analyze/test/APK/AAB/gitleaks-full-history/shellcheck/ruff/pytest) · kill-switch without redeploy · request-id propagation + secret-masking logs · client EXIF strip on every path · PII-clean analytics (UID-only identify, metadata-only events) · graceful no-config/no-key boot degradation · delete-account UX (F-1) fixed with 8 regression tests + live 14 s pass.

---

## 3. PER-DIMENSION LAUNCH VERDICTS

| Dimension | Verdict | Driving findings |
|---|---|---|
| Auth (email) | **CONDITIONAL GO** | works live; no password reset (E1); autoconfirm decision (E3) |
| Auth (social) | **NO-GO** | server/client matrix inverted both ways (E3) |
| Onboarding | **GO** | device-validated 6/11; honest copy in-app |
| Capture→AI (text) | **GO** (engineering) | strongest part of the product; live-verified |
| Capture→AI (photo/video) | **NO-GO** | A1 (no pixels), A2 (SSRF), E8 (upload unverified live, no caps) |
| EMERGENCY handling | **CONDITIONAL GO** | text path exemplary; A3 (photo quota paywall) must be fixed; TR keywords decision (E4) |
| History / Pets / Journal | **GO** | tested, device-validated |
| Family sharing | **CONDITIONAL GO** | invites dead-end on domain (C3/E9); entitlement decision (E12) |
| Referral | **CONDITIONAL GO** | links dead (C3); farming exposure (E3/E16) |
| Paywall / monetization | **NO-GO** | A5 (402 invisible), E5 (RC unconfigured), C5 (3.1.2) |
| Push notifications | **NO-GO** | E6 (no FCM config) |
| Delete account | **CONDITIONAL GO** | UX fixed; A6 (R2/third-party purge) required for compliance |
| Offline/error states | **GO** | banner, skeletons, retries verified; add client timeouts (E8d) |
| Accessibility | **CONDITIONAL GO** | reduce-motion exemplary; TalkBack full sweep = founder ritual pre-store |
| Localization | **CONDITIONAL GO** | ship EN-only honestly (E13) or finish DE |
| Mobile release path | **NO-GO** | B1 signing, B2 icon, B3 permissions, B4 automation |
| AI service ops | **NO-GO** | A4 (timeouts/concurrency/caps), D2 (no telemetry), E11 |
| Database | **CONDITIONAL GO** | model solid; D1 (single project/backups) is the blocker; E14 hygiene |
| Security | **CONDITIONAL GO** | A2 SSRF is the one hard blocker; rest is hardening (E8/E9/E15) |
| Legal/Privacy | **NO-GO** | C1–C4 in full |
| App Store (Apple) | **BLOCKED** | B-series + C5 + E2 (location string crash) + accounts/assets |
| Play Store | **BLOCKED** | B1/B3/B5/B6 + C3 (deletion URL) |
| Monitoring/DR | **NO-GO** | D1/D2/D4 |
| Support | **NO-GO** | dead mailbox, no in-app contact (D4/C3) |
| Beta (50 users) | **NO — see §5** | |

---

## 4. SCALE & OPERATIONS ANALYSIS (what breaks first)

Cost baseline (verified prompt sizes; Sonnet 4.6 $3/$15 per MTok, Gemini 2.0 Flash ≈$0.10/$0.40): text analysis blended **$0.002–0.006**; after GAP-A1 is fixed (images attached) **$0.005–0.015**, video 2–4×. Worst-case retry fan-out today is ~6 upstream calls per request (pipeline retry × SDK retries × failover) — fix with `max_retries=0` + timeouts (A4/E11).

- **1,000 users (~70–130 analyses/day):** infrastructure is fine (2× Fly machines idle; ~$35–100/mo all-in with Supabase Pro). **What breaks first is operations**: no alerting (D2) means the first provider incident is invisible; **Gemini free-tier quota** (if billing was never enabled — 5-minute console check) would silently fail over everything to Claude at ~30× cost or fail moderation closed (all photos rejected).
- **10,000 users (~700–1,300/day):** in order — Gemini unpaid tier (hard daily cap) → OneSignal free subscriber cap (~10k) → Supabase Free limits if never upgraded (D1 forces this anyway) → Anthropic Tier-1 RPM/ITPM during evening escalation bursts (429s masked by retries as latency) → RevenueCat free tier ends ≈$2.5k MTR (good problem).
- **100,000 users (~7–13k/day, evening peaks 30–60/min):** the **sync service architecture** is the real wall — threads held 8–20 s each with no timeouts ⇒ pool exhaustion ⇒ health-check restart storms. Needs async providers + timeouts + 3–5 machines or performance CPU (the only genuine re-engineering in the stack, 2–4 days). Then Anthropic Tier-2/3, PostHog 1M events, Upstash free tier, Google Places bill (uncached `find-vets`).

**Founder blind spots today (would not notice):** AI down at 3 am (health stays green, results degrade politely) · moderation failing closed for everyone (= every photo rejected) · RevenueCat webhook failures (paid users not premium) · cron death (reminders/journals stop) · cost runaway · Doppler↔runtime drift · OneSignal misconfig. All seven map to GAP-D2/D3 fixes.

---

## 5. BETA READINESS (50 users)

**Verdict: NO today.** Two beta tiers, with honest gating:

- **Tier 1 — sideload/friends-and-family beta (~10–20 users, APK by hand):** requires Wave 0 only (fix A1/A2/A4/A5 + upload verify + Supabase Pro/backups + minimal monitoring + interim honest privacy text served at a live URL + support mailbox). Achievable in **~1 engineering week + 1 founder day**.
- **Tier 2 — store-distributed beta (TestFlight external / Play closed, the playbook's "50-user beta"):** additionally requires B1 signing, B2 icon, B5 metadata truthification, C1 attorney-final legal docs at live URLs, store accounts, and C3 domain/email — i.e., Waves 0–2. The long pole is the attorney (legal docs must be real for a public store listing), **not** engineering.

Hard beta blockers (any tier): GAP-A1 (the product must actually analyze photos — or photo capture must be honestly disabled for beta), A2 (SSRF), A4 (one hung provider melts the service), A5 (free users dead-end), D1 (real users' health data with no restore path), D2-minimal (uptime monitor + ai-service Sentry + spend caps), C3-minimal (live privacy URL + working support mailbox), E8a (verify upload live).

---

## 6. ROOT-CAUSE ANALYSIS (why these were missed)

1. **Tests assert plumbing, not payloads.** The image bug survived 167 green tests because every fake provider *accepts and ignores* `image_url`; no test ever asserted pixels appear in the outgoing API call. Same class: 402-handling dead code (no test drives a real `FunctionException`). → *Prevention:* payload-capture contract tests; a deploy-time live multimodal smoke test; golden-set cases with images.
2. **Verifier scripts check declared invariants, not feature truth.** `verify-disclaimers.sh` exists and passes; nothing verifies "the model received an image" or "a release AAB is release-signed." → *Prevention:* add verifiers for the two new invariants; CI signing assertion (`apksigner verify --print-certs` ≠ debug CN).
3. **Headless-first development with founder-gated infra** meant the first true live E2E happened 2026-06-09, months into the build — and it immediately found what every prior report couldn't. The photo path has *still* never been exercised live. → *Prevention:* a standing weekly live-config device ritual (runbook 15 exists; schedule it).
4. **Manual secret sync** (Doppler→Fly/Supabase) caused the silent June outage and still drifts (auth-webhook 500 today). → *Prevention:* scripted sync + a drift-check script + post-deploy smoke that exercises one real analysis.
5. **Documentation drifted from git truth** (playbook said Phases A–F "no evidence" while PRs #29–#33 were merged; memory said M0–M4 "awaiting approval" after merge). Audits that trust reports inherit their staleness. → *Prevention:* status lives in git (PR labels/milestones), reports cite commit SHAs.
6. **CI is green but not sovereign:** required status checks were never enforced (`required_status_checks: null`), node tests never added, deploy decoupled from CI, release.yml never executed end-to-end. → *Prevention:* GAP-D5 fixes; "every workflow must have run green at least once" rule.
7. **Store/legal surfaces were scaffolded with placeholders** ("Reviewed by veterinary experts", `[LEGAL ENTITY]`, parked domain) and placeholder-ness was tracked in prose, not enforced. → *Prevention:* a `verify-no-placeholders.sh` gate over `docs/store_metadata/ docs/legal/ web/` (grep for `[`-brackets, TODO(cms), known fabricated names) wired into CI.
8. **Solo-founder concentration:** every external gate (attorney, insurer, store accounts, DNS, mailboxes) is single-threaded behind one person — the playbook said it, and it is still the schedule's dominant term.

---

*End of gap analysis. Fix plans: `PAWDOC_REMEDIATION_PLAYBOOK.md`. Sequencing: `PAWDOC_GO_LIVE_MASTER_PLAN.md`.*
