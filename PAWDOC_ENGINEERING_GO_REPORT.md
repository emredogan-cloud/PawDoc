# PawDoc — Engineering GO Report

> **Date:** 2026-06-12 (Waves 0–1) · **Updated 2026-06-13 — Sprints 1–3 complete.** Companion to `FINAL_EXECUTION_LEDGER.md` (status/SHAs) + `PAWDOC_EXECUTION_MASTER_BLUEPRINT.md` (per-finding plans).
> **Optimized for truth, not completion.** Verdicts below are evidence-backed; nothing is claimed done without a commit + validation.

## Verdicts (up front · updated 2026-06-13)
- **ENGINEERING GO for 50-user beta: ✅ YES IN CODE — pending the founder merge.** Every agent-executable engineering finding (Waves 0–1 + Sprints 1–3) is closed, validated per-branch, and pushed as PRs **#41–#69**. The one remaining engineering step — merging into protected `main` — requires a human review the agent can neither supply (no self-approval) nor bypass (the `--admin` override was correctly refused on this safety-critical app; proof in the ledger MERGE PHASE). After the merge + CI-green-on-merged-main + on-device E2E, this becomes an unqualified GO.
- **BETA GO (store-distributed): ❌ NO** — needs the merge + founder infra (signing, dev DB/PITR, SMTP, store-metadata fill).
- **PUBLIC LAUNCH GO: ❌ NO** — attorney/E&O critical path + store review.

The critical **A-series (A1–A6) + E7** AND **all Sprint 1–3 findings**
(E1/E2/E3/E5/E6/E8b/E8c/E9/E10/E11/E12/E13/E14/E15/E16, D2/D3/D4/D5, B2/B3/B4/B5)
are **closed, validated, and pushed.** The remaining blockers are **all
founder-controlled**: the protected-`main` merge gate, CI-green-on-merged-main,
on-device validation, and external infra/legal. See SPRINT_1/2/3_EXECUTION_REPORT.md
+ PAWDOC_FINAL_RELEASE_CANDIDATE_REPORT.md. (The original 2026-06-12 table below
is Wave-0–1 history; the sprint reports carry the rest.)

---

## What was fixed this program (verified · validated · pushed)

| ID | Sev | Fix | Branch | Commit | Evidence |
|----|-----|-----|--------|--------|----------|
| **A1** | CRIT | Real image/video pixels now reach the AI + safe degrade | `fix/ai-multimodal` | `c210c31` | ruff clean · pytest **176** (+9 payload **contract** tests) |
| **A2** | CRIT | Blind SSRF killed — server-derived URLs + own-key validation | `fix/analyze-ssrf-and-quota` | `82841dc` | node **85** (+4 tests) |
| **A3** | CRIT | Photo/video emergency never paywalled (visual half) | `fix/analyze-ssrf-and-quota` | `90ee27a` | node **93** (+8 four-quadrant tests) |
| **E7** | MED | Degraded answers don't consume a free credit | `…ssrf-and-quota` | `82841dc/90ee27a` | (`countsAgainstQuota`) |
| **A4** | CRIT | Provider timeouts + input caps + fly concurrency | `fix/ai-survivability` | `f389892` | ruff clean · pytest **181** (+5) |
| **A5** | CRIT | Free-tier 402 → upgrade prompt (not a dead-end loop) | `fix/a5-402-mapping` | (head) | analyze clean · flutter suite **194** (+4) |
| **A6** | CRIT | Deletion cascade: R2 media + third-party PII + audit log | `fix/deletion-cascade` | (head) | node **85** (+4 R2 prefix-safety tests) |

**Also durable:** `PAWDOC_EXECUTION_MASTER_BLUEPRINT.md` + ledger + the (previously laptop-only) source audits — committed/pushed (partially closes GAP-E15 bus-factor).

**Net:** the 6 findings the audit called "the irreducible product/safety/security blockers" in engineering are **done in code**. They are **not yet live** — deploy is founder-gated (GAP-D1: single prod Supabase project; no dev project).

---

## Remaining ENGINEERING work (agent-executable — NOT founder-gated, NOT done)

Honest: I did not complete these this session. Each has a recipe in the blueprint/playbook; each is a `fix/*` branch + validate + push.

| ID | Sev | Remaining work | Cx |
|----|-----|----------------|----|
| E8 | HIGH | Upload hardening: server size/type verify, EXIF backstop (Pillow), client upload/analyze timeouts | M |
| E11 | MED | Service hardening: `docs_url=None` in prod, default-deny off-Fly, pin deps (max_output_tokens done in A4) | S |
| E2 | HIGH | Location permissions (Android manifest + iOS plist) — fixes an **iOS crash** on the vet-finder | S |
| E13 | MED | Localize the result-screen disclaimer (safety copy) | S |
| E14 | MED | DB hygiene migration: CHECK constraints, indexes, RPC grant revoke (dev-push first) | M |
| E16 | MED | Quota pre-gate, symptom min-length (12-char "choking"), calm error copy, referral cap | M |
| A5-tail/E10 | MED | PDF 402 upsell + family error codes via the A5 mapper | S |
| E1/E3/E6 | HIGH | Password reset; Apple-button iOS-gate + min-pw 8; OneSignal logout (FCM/SMTP founder) | M |
| E5 | HIGH | RC webhook idempotency table + constant-time compare (products founder) | M |
| E9/E12 | MED | Invite manual-code fallback; pets WITH-CHECK family re-assert; family Upgrade→paywall | M |
| E15 | MED | `.gitignore doppler.json` + commit laptop-only docs (started) | S |
| B2/B3/B5 | HIGH | Launcher icon, permission diet, truthful store/web copy + `verify-no-placeholders.sh` CI gate | M |
| D2(agent) | CRIT | ai-service Sentry + edge alerts + server-side degraded events + mobile env/release tags | M |
| D3 | HIGH | sync-secrets script, fly.toml→fra, delete auth-webhook, CLAUDE.md function list | S |
| D4(draft) | HIGH | Runbooks 22–27 (agent-draftable) + in-app Contact-support | M |
| D5 | HIGH | CI: node-tests + deno-check + nightly RLS jobs, pin actions, deploy-gated-on-CI, placeholder gate | M |
| B4 | HIGH | Fastlane lanes + fixed release.yml (validate via a dry-run tag) | L |

> Estimated remaining agent effort: **~1 focused engineering week** (per the blueprint's per-finding ETs). Resume from the blueprint, in order, fresh session.

---

## Founder-gated (cannot be done by the agent — exact actions)

- **Deploy the 7 fix branches** after a **dev Supabase project exists** (GAP-D1 / F-5: Pro + PITR + `pawdoc-dev`). Do **not** push migrations/functions to the single prod DB blind.
- **Open/squash-merge the PRs** (`gh` is unauthenticated here — branches are pushed; links in the ledger).
- **F-17 live photo smoke** on the device — the only thing that *proves* A1/A2/A3 end-to-end in production.
- **A6 third-party deletes** need `REVENUECAT_SECRET_API_KEY` / `ONESIGNAL_REST_API_KEY` / PostHog management key in the deployed env.
- **B1** keystore (F-6), **E5/E6** RevenueCat/FCM consoles (F-15/16), **E1/E3** SMTP + auth dashboard (F-13/14).
- **C1–C4 legal/E&O/domain** (F-1/2/3/4) — the external critical path (2–4+ weeks); not engineering.

---

## Path to ENGINEERING GO
1. Agent: finish the "Remaining engineering work" table (resume from the blueprint, A-series done → E8 → D2(agent)/D3 → the E/B/D batches).
2. Full validation matrix green: `flutter analyze && flutter test · ruff && pytest · node --test · test-rls.sh · verify-disclaimers.sh · verify-no-placeholders.sh`.
3. Founder: dev project + deploy the branches + F-17 live photo smoke passes.
→ **then** ENGINEERING GO. BETA GO additionally needs D1 backups, B1 signing, monitoring live, and a live privacy URL + support mailbox (C3-min). PUBLIC LAUNCH GO additionally needs the legal gate (C1/C2) — attorney-bound.

*This report is honest by construction: 7 findings are closed with commit SHAs + test counts; the rest are explicitly open. PawDoc's safety core was already the best-engineered part of the product, and the 6 critical engineering blockers are now fixed in code — but it is not ENGINEERING GO until the remaining engineering closes and the founder deploys + smoke-tests it live.*
