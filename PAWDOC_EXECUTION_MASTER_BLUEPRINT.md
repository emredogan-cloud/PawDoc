# PawDoc — Execution Master Blueprint

> Authoritative execution guide. Precedence: **live code > current evidence > FINAL_EXECUTION_LEDGER > GO_LIVE_MASTER_PLAN > REMEDIATION_PLAYBOOK > GAP_ANALYSIS > history/memory.** Reality overrides docs.
> Companion: `FINAL_EXECUTION_LEDGER.md` (per-finding status/SHAs), `PAWDOC_REMEDIATION_PLAYBOOK.md` (code-level recipes — not duplicated here).
> **Date:** 2026-06-12 · **Base for fixes:** `main` @ `e1aed76`.

---

## Executive Summary

- **Verified state:** the text-triage safety core, RLS isolation, emergency-never-paywalled (text), forced disclaimers, presigned uploads, webhook auth, and a blocking CI are **launch-grade** (gap analysis §F). The gaps cluster in (a) the multimodal path, (b) release/store mechanics, (c) ops/observability, (d) legal/founder.
- **Closed this program (verified, validated, pushed):**
  - **A1** — real image/video pixels now reach the AI + safe degrade (`fix/ai-multimodal` `c210c31`; pytest 176, +9 payload contract tests).
  - **A2** — blind SSRF killed; server-derived URLs + own-key validation (`fix/analyze-ssrf-and-quota` `82841dc`; node 85, +4 tests).
  - **E7** — degraded answers no longer consume a free credit (same `82841dc`).
- **Remaining engineering findings (post-Sprint-3, 2026-06-13): NONE agent-executable.** Sprint 3 closed E8b/E8c (was E8), B4, D4; E2 closed earlier. All A-wave + E7, **Sprint 1** (E11/E13/E14/E15/D2/D3/D5), **Sprint 2** (E16/E1/E3/E5/E6/E9/E10/E12/B2/B3/B5) and **Sprint 3** (E8b/E8c/B4/D4) findings are CLOSED — see FINAL_EXECUTION_LEDGER.md. The only remaining engineering step is the **founder merge of PRs #41–#69 into protected main** (required-review gate; agent can't self-approve/bypass). Founder-only: merge gate, CI-on-merged-main, device E2E, A6-thirdparty-keys, B1, B6, C1–C7, D1, E4(decision), F-1..F-20.
- **Readiness scores (honest, evidence-based):**
  - **Engineering-for-beta:** **~90%** (was ~78%) — every agent-executable finding closed + validated per-branch + pushed as PRs. The gap to 100% is the founder merge + CI green on integrated main (the agent cannot merge into protected `main`). *Not* gated on legal.
  - **Beta-50 (store-distributed):** **~40%** (was ~35%) — needs the merge + founder infra (dev DB/PITR, monitoring, domain, signing) + SMTP + store-listing fill.
  - **Public launch:** **~12%** (was ~10%) — still dominated by the attorney/E&O external critical path + store review; the legal/store fill is enforced by `verify-no-placeholders.sh --strict` (B5).
- **Verdict today:** **NOT ENGINEERING-GO yet.** Reaching "ENGINEERING GO FOR 50-USER BETA" requires Wave-0 code complete (A3, A4, A5, A6, E8b/c/d, D2-agent, D3) **and** the founder infra minimum (D1 dev+backups, D2 consoles, C3 live privacy URL + support mailbox, F-17 live photo smoke).

---

## Finding Inventory (every remaining finding)

Sev: CRIT/HIGH/MED/LOW. FND = founder dependency. DEP = deploy dependency. Cx = complexity (S/M/L). ET = est. agent execution time.

| ID | Sev | Status | Why it matters / impact (user · safety · business · technical) | Deps | FND | DEP | Cx | ET |
|----|-----|--------|----------------------------------------------------------------|------|-----|-----|----|----|
| A1 | CRIT | ✅ FIXED | Flagship works · false-neg engine closed · cost model valid · multimodal payloads | — | F-17 smoke | Fly | L | done |
| A2 | CRIT | ✅ FIXED | No SSRF · internal-network safe · abuse-cost up · server-derived URLs | A1 | — | functions | M | done |
| E7 | MED | ✅ FIXED | Fair quota · — · conversion honesty · increment guard | A2 | — | functions | S | done |
| **A3** | CRIT | OPEN | Out-of-quota **photo emergency never analyzed** · **direct false-neg** · violates #1 rule · Edge gate restructure | A2 | — | functions | M | ~2h |
| **A4** | CRIT | OPEN | One hung provider melts service · health-restart kills analyses · P95 unenforceable · timeouts/caps | — | — | Fly | M | ~2h |
| **A5** | CRIT | OPEN | Free 4th check dead-ends (retry loop) · — · **conversion broken** · FunctionException mapper | A3 payload | — | mobile | M | ~2h |
| **A6** | CRIT | OPEN | Deletion leaves R2+3rd-party PII · privacy/erasure breach · GDPR/KVKK/Apple 5.1.1(v) · cascade | — | RC/OS/PH keys | functions | M | ~3h |
| **E8** | HIGH | OPEN | Upload abuse/cost · stalled spinner · EXIF backstop · size/type/timeout | A1 | F-17 | functions/mobile | M | ~2h |
| **E10** | MED | OPEN | PDF upsell never shows · — · revenue · same 402 dead-code as A5 | A5 | E5 product | mobile | S | ~1h |
| **E11** | MED | OPEN | `/docs` public, no max_output_tokens, unpinned deps, open-by-default off-Fly · hardening | — | — | Fly | S | ~1h |
| **E16** | MED | OPEN | Quota pre-gate, 20-char blocks "he's choking", raw `$e` snackbars, referral cap · UX/safety | A5 | — | mobile/db | M | ~2h |
| **E2** | HIGH | OPEN | Vet-finder **iOS crash** (no location string) · safety-adjacent · manifest/plist | — | — | mobile | S | ~30m |
| **E1** | HIGH | OPEN | No password reset → week-1 lockouts unrecoverable · auth · UI+logic | — | F-13 SMTP | mobile | M | ~1h |
| **E3** | HIGH | OPEN | Apple btn on Android always fails; min-pw 6 · auth · agent: iOS-gate+config | — | F-14 dash | mobile | S | ~1h |
| **E5** | HIGH | OPEN | RC webhook **double-credits** on retry · billing integrity · idempotency migration | — | F-15 products | functions/db | M | ~1h |
| **E6** | HIGH | OPEN | OneSignal external-id not cleared on logout (cross-user push) · privacy · agent part | — | F-16 FCM | mobile | S | ~30m |
| **E9** | MED | OPEN | Invite links dead-end (no manual code) · UX · agent: fallback screen | C3 | F-4 domain | mobile | M | ~1h |
| **E12** | MED | OPEN | `pets` UPDATE WITH CHECK gap (group-injection); family Upgrade→onboarding not paywall · data/UX | — | decision | db/mobile | M | ~1h |
| **E13** | MED | OPEN | Result disclaimer hardcoded EN on DE app · safety copy · localize string | — | decision | mobile | S | ~30m |
| **E14** | MED | OPEN | Zero CHECK constraints, missing indexes, RPC over-grant · integrity/perf · migration | — | — | db (dev) | M | ~2h |
| **E15** | MED | OPEN | Local secrets 664; `doppler.json` not gitignored · secret hygiene · local | — | (founder chmod prod) | local | S | ~20m |
| **D2** | CRIT | OPEN | Zero alerting → outages invisible · ops · agent: ai-svc Sentry+edge alerts+degraded events | — | F-11 caps | Fly/funcs | M | ~3h |
| **D3** | HIGH | OPEN | Config drift; auth-webhook live-500 · ops · agent: sync script, fly.toml, delete webhook | — | — | funcs | S | ~1h |
| **D4** | HIGH | OPEN | No outage/breach/rollback runbooks; no support mailbox · ops · agent-draftable | — | F-4 email | docs | M | ~2h |
| **D5** | HIGH | OPEN | CI not sovereign (red PR can merge; node/deno not gated) · process · ci.yml | — | F-12 apply | ci | M | ~1h |
| **B2** | HIGH | OPEN | Default Flutter "F" icon + lowercase label · store · run launcher-icons | — | — | mobile | S | ~30m |
| **B3** | HIGH | OPEN | Unused media/audio permissions → Play rejection class · store · manifest diet | — | — | mobile | S | ~30m |
| **B4** | HIGH | OPEN | release.yml broken (Fastlane unwired) · release · automation | — | F-7/F-8 | ci | L | ~3h |
| **B5** | HIGH | OPEN | "Reviewed by veterinary experts" + fake testimonials in store/web · FTC/store-deception · copy+CI gate | — | sign-off | docs/web | M | ~1h |
| **B1** | CRIT(Play) | FND | Debug release signing · store-block · needs keystore | — | **F-6** | mobile/ci | M | (gated) |
| **B6** | HIGH | FND | Submission asset pack · store · agent exports, founder consoles | B2 | **F-7/8** | — | M | (partial) |
| **D1** | CRIT | FND | One prod DB, no backups/PITR, dev=prod · data-loss · console | — | **F-5** | supabase | — | (gated) |
| **E4** | HIGH(TR) | DECISION | No Turkish emergency keywords · safety(TR) · add or scope-out | — | decision | ai | M | (decision) |
| **C1–C7** | CRIT/HIGH | FND | Legal/privacy/domain/E&O · launch-block · attorney/founder | — | **F-1/2/3/4** | — | — | (gated) |
| E17 | LOW | OPEN | Misc polish (open-settings btn, casing, etc.) · backlog | — | — | — | S | backlog |

---

## Priority Matrix (why each belongs)

**PHASE 0 — Critical Safety** (an external user could be harmed / a safety promise is false): **A3** (image emergency can't be evaluated when out of quota), **E13** (safety disclaimer wrong-language). *A1 already done sits here.*

**PHASE 1 — Critical Stability** (service survives real traffic / failures degrade safely): **A4** (timeouts/concurrency/caps), **D2** (you'd never know it broke), **D3** (drift caused the June outage).

**PHASE 2 — Security & Data** (no abuse / no data-loss / erasure honored): *A2 done*, **A6** (deletion cascade), **E8** (upload hardening), **E11** (service hardening), **E14** (DB constraints/grants), **E15** (secret hygiene). *D1 (backups) lives here but is founder.*

**PHASE 3 — Product Completeness** (flows work end-to-end / conversion not broken): **A5** (402→paywall), **E10** (PDF), **E16** (quota UX/min-length), **E1** (password reset), **E2** (location/iOS-crash), **E3** (auth posture), **E5** (RC idempotency), **E6** (OneSignal logout), **E9** (invite fallback), **E12** (family/pets RLS).

**PHASE 4 — Release Readiness** (store-grade, truthful, supportable): **B2** (icon), **B3** (permissions), **B5** (truthful copy + CI gate), **B4** (release automation), **D4** (runbooks+support), **D5** (CI sovereignty). *B1/B6 need founder.*

**PHASE 5 — Founder-Controlled** (external/console/legal): **D1, B1, B6, C1–C7, E4 decision, F-1..F-20.** Agent prepares exact action lists; founder executes.

---

## Detailed Resolution Plans

> Format per finding: Problem · Root cause · Detection · Solution · Acceptance · Tests · Risks · Evidence. Code-level recipes live in `PAWDOC_REMEDIATION_PLAYBOOK.md` (referenced, not duplicated).

### PHASE 0

**A3 — Un-paywall photo/video emergency** *(branch `fix/analyze-ssrf-and-quota`, next commit)*
- **Problem:** an out-of-quota free user submitting a photo/video emergency with neutral text gets `402` before any AI runs → image emergency never detected.
- **Root cause:** the free-tier gate keys only off text emergency keywords (`analyze/index.ts:116-133`).
- **Detection:** out-of-quota test account + photo, neutral text → 402 today; should run AI.
- **Solution:** restructure the gate — for `input_type ∈ {photo,video}` when `!allowed && !isEmergencyText`: run the analysis with a `quotaExceeded` flag; if verdict EMERGENCY → return full, **uncounted**; else return 402-shaped JSON `{triage_level, quota_exceeded:true, message}` (no detailed guidance), uncounted; store the row marked `quota_blocked` for audit. Mobile half pairs with **A5**.
- **Acceptance:** no input type yields "emergency never evaluated due to paywall"; cost per blocked-free request ≤1 Tier-2 call unless EMERGENCY.
- **Tests:** mjs four-quadrant (in/out quota × emergency/normal × text/photo); E2E out-of-quota photo runs.
- **Risks:** cost on abusive out-of-quota photo spam → bounded by one Tier-2 call + A4 caps; mitigation: `quota_blocked` analytics + later per-IP cap.
- **Evidence:** node --test green; live out-of-quota photo returns a result (founder F-17).

**E13 — Localize the result disclaimer**
- **Problem/root:** result-screen disclaimer hardcoded EN (`result_screen.dart:265`) while DE strings ship.
- **Solution:** move the disclaimer into ARB (`AppLocalizations`); keep EN fallback. **Decision (record):** EN-only launch recommended (set store locales EN, drop DE claim) — but localize this safety string regardless.
- **Acceptance/Tests/Evidence:** disclaimer renders in device locale; flutter test asserts key present; analyze/test green.

### PHASE 1

**A4 — Timeouts, concurrency, size caps** *(branch `fix/ai-survivability`)*
- **Problem:** Anthropic 600s default timeout, no Gemini cap, sync 40-thread pool, no fly concurrency, unbounded text/frames.
- **Root cause:** providers constructed without `timeout=`/`max_retries=0`; no caps in `models.py`/Edge; no `--limit-concurrency`.
- **Solution:** Claude `Anthropic(timeout=8.0, max_retries=0)`; Gemini `HttpOptions(timeout=8000)` + `max_output_tokens=1024`; `models.py` `text_description Field(max_length=4000)`, `frame_urls Field(max_length=6)`; Edge rejects >6 frames / >4000 chars (fail-fast); `fly.toml` concurrency `soft=20/hard=25`; Dockerfile `--limit-concurrency 32`.
- **Acceptance:** worst-case ≤~25s; burst doesn't trigger health-restart; 422 on oversize.
- **Tests:** hung-provider fake (sleep>timeout)→ProviderError/failover; oversized body→422; ruff/pytest.
- **Risks:** too-tight timeout cuts slow-but-valid calls → 8s chosen vs observed P95<10s; degrade is safe.
- **Evidence:** pytest green; founder burst smoke (`hey` vs staging while one slow request).

**D2 — Minimum observability (agent part)** *(branch `ops/observability-min`)*
- **Problem:** no Sentry in ai-service/edge; no degraded-rate metric; outages masked by calm-degrade design.
- **Solution (agent):** `sentry-sdk[fastapi]` pinned + init in `main.py` (env/release, `send_default_pii=False`, mask_secrets before_send); `_shared/alert.mjs` posting on `console.error` in analyze/webhook/upload/delete; server-side PostHog `analysis_completed{tier_used,degraded,moderation_rejected}`; mobile Sentry `environment`/`release` tags. **Founder:** Better Stack uptime, spend caps (F-11).
- **Acceptance:** killing a provider key in dev raises two independent alerts within minutes.
- **Tests:** unit for alert.mjs; pytest for before_send scrubber; manual kill-key drill (founder).
- **Evidence:** alert screenshots (founder); code + tests merged.

**D3 — Config drift closure** *(branch `ops/drift-and-guards`)*
- **Problem:** manual Doppler→Fly/Supabase sync (June outage cause); `fly.toml` region drift; auth-webhook live-500.
- **Solution:** `scripts/sync-secrets.sh` (digest-diff, `PAWDOC_PROD_DEPLOY=1` guard); `fly.toml primary_region="fra"`; **delete auth-webhook** (DB trigger #30 supersedes) + remove from config.toml + PAST_DECISIONS; update CLAUDE.md function list (13).
- **Acceptance:** `sync-secrets --check` exit 0; auth-webhook gone or 401 (not 500).
- **Tests:** shellcheck; script `--check` dry-run.
- **Evidence:** script output; (founder) function delete.

### PHASE 2

**A6 — Deletion cascade (R2 + third parties)** *(branch `fix/deletion-cascade`)*
- **Problem:** `delete-account` deletes only auth user; R2 `uploads/<uid>/*` + RC/OneSignal/PostHog subjects persist.
- **Solution:** R2 `ListObjectsV2`+`DeleteObjects` (new `_shared/r2.mjs` helpers + tests); fire-and-collect RC/OneSignal/PostHog deletes (try/catch, non-fatal, logged); `deletion_log` migration (service-only RLS); keep `{ok:true}` fast (measure; sweep table if >6s).
- **Acceptance:** post-deletion zero R2 objects under uid prefix; third-party attempts logged; client UX unchanged.
- **Tests:** mjs r2 helper tests (mock fetch); live drill (founder) on throwaway with 2 uploads.
- **Risks:** third-party API/plan gaps → log-and-queue fallback; **needs RC/OneSignal/PostHog API keys (founder)** for the live deletes.
- **Evidence:** node tests; live bucket-empty drill (founder).

**E8 — Upload hardening** *(branch `fix/upload-hardening`)*
- **Solution (agent):** server-side size/type verify (HEAD the object in analyze before presignGet, reject >10MB/wrong type) OR Content-Type-pinned presign; server EXIF backstop inside `media.py` (re-encode via Pillow, drop metadata — closes M-2 with zero extra round-trips; add Pillow dep); client `.timeout()` on invoke/PUT + error state. **Founder:** F-17 live R2 check.
- **Acceptance:** oversize/wrong-type rejected server-side; stalled upload shows error not infinite spinner; images stripped server-side.
- **Tests:** pytest EXIF-strip; mobile widget timeout test; node size-check.

**E11 — AI service hardening** *(fold into `fix/ai-survivability`)*
- **Solution:** `FastAPI(docs_url=None, redoc_url=None, openapi_url=None)` when prod; default-deny auth off-Fly; pin `anthropic==/google-genai==/openai==/httpx==`; `smoke-models.sh` deploy step.
- **Acceptance/Tests/Evidence:** `/docs` 404 in prod; pinned reqs; ruff/pytest.

**E14 — DB hygiene migration** *(branch `fix/db-hygiene`, push to **dev** first — gated on D1)*
- **Solution:** one migration — CHECK constraints (`triage_level`,`input_type`,`species`,`subscription_status` — verify exact value sets vs code first), btree indexes (hot RLS predicates), `security_invoker` views, revoke execute on `count_shared_group_memberships`, guarded PDF decrement.
- **Acceptance:** test-rls green; app paths unaffected (esp. species values vs UI).
- **Risks:** a CHECK with wrong value set breaks inserts → verify enums against code + dev push first.
- **Evidence:** test-rls.sh; dev push log.

**E15 — Secret hygiene (local, agent)**
- **Solution:** add `doppler.json` to `.gitignore`; commit laptop-only docs/fonts (non-secret); document `chmod 600` for founder's prod secret files.
- **Acceptance/Evidence:** `git check-ignore doppler.json` = match; no secret files tracked.

### PHASE 3

**A5 — FunctionException → paywall mapper** *(branch `fix/client-402-mapping`)*
- **Solution:** `lib/src/core/functions_error.dart` mapper (status+details); analysis runner 402→upgrade sheet (carries A3 payload), 5xx→safe error; PDF 402→upsell; family errors→specific copy.
- **Acceptance:** free 4th check shows upgrade (no retry loop); PDF/family specific errors.
- **Tests:** widget tests faking `FunctionException(402, details)`→paywall; 500→error.
- **Evidence:** flutter test; device pass (founder creds).

**E10 — PDF 402** — covered by A5 mapper + surface generate errors (no silent no-op); purchase wiring post-E5.

**E16 — Quota/emergency UX** *(branch `fix/ux-batch`)* — client quota pre-gate (read `freeRemaining` before capture); drop symptom min 20→8 **or** client emergency-keyword bypass of the min (safety); replace 6 raw `$e` snackbars with calm copy + `Sentry.captureException`; referral lifetime cap (migration/claim guard). Tests: widget + mjs.

**E2 — Location permissions** *(branch `fix/location-perms`)* — Android `ACCESS_(COARSE|FINE)_LOCATION`; iOS `NSLocationWhenInUseUsageDescription`. Acceptance: vet-finder GPS works Android; **iOS no crash**. Test: manifest assertion.

**E1 — Password reset** *(branch `feat/auth-lifecycle`)* — `resetPasswordForEmail` + "Forgot password?" + recovery screen (router handles `pawdoc://`). FND: SMTP (F-13). Tests: widget for the form.

**E3 — Auth posture (agent part)** *(same branch)* — `if (Platform.isIOS)` around the Apple button (it always fails on Android); raise min password to 8 client-side. FND: dashboard confirmations ON + Google decision (F-14).

**E5 — RC webhook idempotency** *(branch `fix/rc-idempotency`)* — `processed_rc_events(event_id pk)` migration + skip-if-exists before credit; constant-time secret compare. Test: duplicate event → single credit. FND: products/key (F-15).

**E6 — OneSignal logout (agent part)** *(auth-lifecycle)* — `OneSignal.logout()` on sign-out; `allowBackup=false`/dataExtractionRules. FND: FCM `google-services.json` (F-16).

**E9 — Invite manual-code fallback (agent part)** — manual invite-code entry screen (parity with referral); record email-binding decision. FND: domain assetlinks (F-4).

**E12 — Family** *(fix/db-hygiene + ux)* — `pets` UPDATE WITH CHECK re-assert family membership (migration + RLS test); family Upgrade→paywall (not onboarding). Decision: entitlement per-user for launch (record).

### PHASE 4

**B2 — Launcher icon + label** *(branch `release/store-surface`)* — `dart run flutter_launcher_icons`; `android:label="PawDoc"`; iOS `CFBundleDisplayName`. Evidence: real icon on device.

**B3 — Permission diet** *(same)* — remove `READ_MEDIA_IMAGES`/`READ_EXTERNAL_STORAGE`/`RECORD_AUDIO` (no gallery/audio feature); remove iOS photo-library string. Evidence: merged-manifest check.

**B5 — Truthify store/web + CI gate** *(same)* — replace "Reviewed by veterinary experts"/"veterinary input and reviewed" with provable phrasing; delete fabricated testimonials + false footer in `web/app/page.tsx`; rebuild `web/out`; add `scripts/verify-no-placeholders.sh` → CI. FND: copy sign-off.

**B4 — Release automation** *(branch `release/fastlane`)* — per-platform Fastlane lanes; fix `release.yml` working-dirs; `Gemfile.lock`; staged-rollout params; rollback docs. FND: store accounts/secrets (F-7/8). Validate: `v0.9.0-beta1` dry-run tag.

**D4 — Runbooks + support (agent draft)** *(branch `ops/runbooks-support`)* — runbooks 22-restore, 23-outage, 24-rotation, 25-breach-72h, 26-rollback, 27-refunds/abuse; in-app "Contact support" `mailto`; feedback digest. FND: support mailbox (F-4).

**D5 — CI sovereignty** *(branch `ops/ci-sovereignty`)* — add `node-tests` + `deno check` + nightly RLS jobs; pin actions to SHAs; deploy gated on CI; placeholder gate. FND: apply required checks (F-12).

### PHASE 5 — Founder-controlled (agent prepares action lists only)
D1 (dev DB + Pro/PITR), B1 (keystore F-6), B6 (consoles), C1–C4 (attorney/privacy/E&O/domain), E4 (TR decision), F-1..F-20. **No legal drafting, attorney decisions, E&O procurement, tax, or entity choices** — exact step lists only (already in playbook PART 2).

---

## Execution Graph

```
PARALLEL TRACK A (AI service / Python):   A4+E11  ──►  E8(EXIF)            [branch fix/ai-survivability, fix/upload-hardening]
PARALLEL TRACK B (Edge / Deno):           A3  ──►  A6  ──►  D3             [analyze gate, deletion, drift]
PARALLEL TRACK C (Mobile / Flutter):      E2 ──► A5 ──► E10 ──► E16 ──► E1/E3/E6 ──► B2/B3   [client]
PARALLEL TRACK D (DB):                    E14 + E12 + E5 (one or grouped migrations; push DEV first — gated on D1)
PARALLEL TRACK E (Ops/CI/docs):           D2(agent) , D5 , D4(draft) , B5 , E15
```
- **Sequential within a track** where a fix consumes another's output: **A5 depends on A3's 402 payload**; **E10 depends on A5**; **E14/E12/E5 migrations depend on D1 (dev project)** before any prod push.
- **Critical path to ENGINEERING-GO-beta:** A3 → A5 (so emergencies surface AND the client shows them) ‖ A4 (survivability) ‖ A6 (erasure) ‖ D2/D3 (observability). Everything else is parallelizable.
- **Founder critical path (longer, external):** F-1 attorney → legal pages live → store beta.

---

## Final Closure Checklist

**ENGINEERING GO (code complete, validated):**
- [ ] A3, A4, A5, A6 fixed + validated (pytest/node/flutter green; payload + 4-quadrant + mapper tests)
- [ ] E8(b/c/d), E11, E14, E16, E2, E1, E3(agent), E5(agent), E6(agent), E12 fixed/validated
- [ ] D2(agent), D3, D5 merged; B2, B3, B5 merged; D4 drafted
- [ ] Full validation matrix green: `flutter analyze && flutter test` · `ruff && pytest` · `node --test` · `test-rls.sh` · `verify-disclaimers.sh` · `verify-no-placeholders.sh`
- [ ] CI green incl. new jobs

**BETA GO (50-user, on top of ENGINEERING GO):** D1 (dev DB + Pro/PITR), B1 (keystore), monitoring live (D2 founder consoles), C3-minimal (live privacy URL + support mailbox), **F-17 live photo smoke passes**, release-signed AAB accepted on an internal track.

**PUBLIC LAUNCH GO (on top of BETA GO):** C1/C2 (attorney-final legal + E&O bound), C3 full domain/email, store consoles complete (B6), staged-rollout + halt criteria, day-1 dashboards.

---

*Execution proceeds in `FINAL_EXECUTION_LEDGER.md` (status/SHAs) and per-wave completion reports. This blueprint is updated as findings close.*
