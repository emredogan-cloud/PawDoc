# PawDoc — Final Execution Ledger

> Source of truth: `PAWDOC_LAUNCH_GAP_ANALYSIS.md` + `PAWDOC_REMEDIATION_PLAYBOOK.md` + `PAWDOC_GO_LIVE_MASTER_PLAN.md`.
> Process: verify finding still exists → fix on `fix/<name>` → validate (local suites) → commit/push → PR link → update this row.
> Deploys (Fly/Supabase **prod**) stay founder-gated (GAP-D1: single prod project; no dev project yet). Code fixes land on branches, validated by the local test suites.
> `gh` is installed but unauthenticated here → PRs are pushed branches + links; founder opens/squash-merges.

**Started:** 2026-06-12 · **Base for fixes:** `main` @ `e1aed76`

## Wave 0 — stop-the-bleeding criticals

| ID | Sev | Finding (short) | Status | Branch | Commit | Evidence |
|----|-----|-----------------|--------|--------|--------|----------|
| A1 | CRIT | Photo/video pixels never reach AI | ✅ **FIXED** (push) | `fix/ai-multimodal` | `c210c31` | ruff clean; pytest **176** (+9 payload contract tests); MediaFetchError→safe MONITOR. Live photo smoke = F-17 founder. |
| A2 | CRIT | SSRF via client `image_url` | ✅ **FIXED** (push) | `fix/analyze-ssrf-and-quota` | `82841dc` | node --test **85** (+4 isOwnUploadKey SSRF tests); image_url no longer accepted; own-namespace key validation. Deno check + live probe = CI/founder. |
| A3 | CRIT | Photo/video emergency paywalled | ✅ **FIXED** (push) | `fix/analyze-ssrf-and-quota` | `90ee27a` | node --test **93** (+8 four-quadrant tests); visual emergency always runs/surfaces uncounted. Mobile 402 UI pairs with A5. Live = F-17. |
| E7 | MED | Degraded analysis consumes credit | ✅ **FIXED** (push) | `fix/analyze-ssrf-and-quota` | `82841dc` | increment now gated on `meta.tier_used > 0` |
| A4 | CRIT | No provider timeouts/concurrency/caps | ✅ **FIXED** (push) | `fix/ai-survivability` (stacked on A1) | `f389892` | ruff clean; pytest **181** (+5: oversize→422, Claude timeout=8/retries=0, Gemini http_options). fly/Docker concurrency = deploy-time. |
| A5 | CRIT | Free-tier 402 renders as generic error | ✅ **FIXED** (push) | `fix/a5-402-mapping` | (a5 head) | flutter analyze clean; suite **194** (+4 mapper tests); 402→upgrade sheet w/ A3 teaser chip. Device "4th check shows upgrade" = founder. |
| A6 | CRIT | Deletion leaves R2 + 3rd-party PII | ✅ **FIXED** (push) | `fix/deletion-cascade` | (a6 head) | node --test **85** (+4 R2 prefix-safety tests); R2 purge + 3rd-party (env-gated) + deletion_log. Live drill + 3rd-party keys = founder. |
| E8 | HIGH | Upload hardening (size/type/EXIF/timeout) | pending | `fix/upload-hardening` | — | — |
| D2 | CRIT | Zero alerting/observability | pending | `ops/observability-min` | — | — (much is founder console) |
| D3 | HIGH | Config/secret drift, auth-webhook 500 | pending | `ops/drift-and-guards` | — | — |

## Wave 1 — release mechanics & product completeness

| ID | Sev | Finding (short) | Status | Branch | Commit | Evidence |
|----|-----|-----------------|--------|--------|--------|----------|
| B1 | CRIT | Android debug signing | pending (needs F-6 keystore) | `release/android-signing` | — | — |
| B2 | HIGH | Default launcher icon + label | pending | `release/store-surface` | — | — |
| B3 | HIGH | Permission diet | pending | `release/store-surface` | — | — |
| B4 | HIGH | Release automation broken | pending | `release/fastlane` | — | — |
| B5 | HIGH | Overclaims in store/web metadata | pending | `release/store-surface` | — | — |
| B6 | HIGH | Submission asset pack | pending (FND-heavy) | — | — | — |
| E1 | HIGH | No password reset | pending | `feat/auth-lifecycle` | — | — |
| E2 | HIGH | Location permissions missing | pending | `feat/compliance-ui` | — | — |
| E3 | HIGH | Auth posture (Apple/Google/confirm) | pending | `feat/auth-lifecycle` | — | — |
| E5 | HIGH | RevenueCat webhook idempotency | pending | `feat/ux-batch` | — | — |
| E6 | HIGH | Push dead (FCM) + OneSignal logout | pending (needs F-16) | `feat/auth-lifecycle` | — | — |
| E10 | MED | PDF 402 dead-code | pending (with A5) | `fix/client-402-mapping` | — | — |
| E12 | MED | Family decisions | pending | `fix/db-hygiene` | — | — |
| E14 | MED | DB hygiene (CHECKs/indexes/grants) | pending | `fix/db-hygiene` | — | — |
| E16 | MED | Quota/emergency UX batch | pending | `feat/ux-batch` | — | — |
| D4 | HIGH | Runbooks + support channel | pending (FND-heavy) | `ops/runbooks-support` | — | — |
| D5 | HIGH | CI sovereignty | pending | `ops/ci-sovereignty` | — | — |

## Wave 2 — founder/legal only (prepare action lists, do NOT execute)
C1/C2/C3/C4 (legal, E&O, domain, KVKK), F-1..F-20 — see master plan. Agent prepares exact steps; founder executes.

## Activity log
- 2026-06-12: Read all 3 source docs. Created ledger.
- 2026-06-12: **A1 FIXED** — `fix/ai-multimodal` `c210c31` (real pixels to AI + safe degrade; ruff clean, pytest 176, +9 payload contract tests). Pushed.
- 2026-06-12: **A2 + E7 FIXED** — `fix/analyze-ssrf-and-quota` `82841dc` (SSRF killed: server-derived URLs + own-key validation; degraded ≠ credit; node --test 85, +4 tests). Pushed.
- Next: A3 (same branch) → A4 → A5 → A6/E8 → D2/D3 → Wave 1. Deploys + console work founder-gated (D1/F-series); PRs need `gh auth` (links below).

## Open PR links (founder opens/squash-merges; `gh` here is unauthenticated)
- A1: https://github.com/emredogan-cloud/PawDoc/pull/new/fix/ai-multimodal
- A2/E7: https://github.com/emredogan-cloud/PawDoc/pull/new/fix/analyze-ssrf-and-quota
- (UI translation + launch hardening — prior missions): https://github.com/emredogan-cloud/PawDoc/pull/new/ui-translation
