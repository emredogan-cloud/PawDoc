# SUB-PR Report — Phase 0.1: Accounts, Domains & Secrets Backbone

**Status:** Engineering scaffolding complete; human-gated account actions handed off via runbooks.
**Branch:** `phase-0.1-accounts-secrets`
**Date:** 2026-05-27

---

## 1. What was implemented

Phase 0.1 is ~90% human-gated (payments, legal identity, account logins) — an AI agent cannot create accounts or spend money. This PR therefore delivers the **AI-doable form** of the deliverables: verification of what already exists, hardened repo hygiene, an idempotent secrets backbone, a verification harness, and beginner-friendly runbooks for every manual step.

- **Domain / Cloudflare DNS** — Verified `pawdoc.app` is registered and delegated to Cloudflare (`ivy.ns.cloudflare.com`, `mark.ns.cloudflare.com`). **Deliverable met.**
- **Secrets backbone** — `scripts/doppler-bootstrap.sh` creates the `pawdoc` Doppler project + `dev`/`prod` configs + all 13 Phase 0.1 secret slots (Supabase, Anthropic, Google AI, R2) as non-destructive placeholders.
- **Secrets documentation** — `/ENVIRONMENT_VARS.md` documents every variable (purpose, required/optional, owning service, client-safety, exact acquisition steps) plus a reserved list for later phases.
- **Repo hardening** — Comprehensive `.gitignore` blocking `.env`, `*.p8`/`*.key`/keystores, service-account JSON, and tool credential caches → serves the "zero secrets in git" DoD (Phase 0.4 gate).
- **GitHub protection** — `scripts/github-branch-protection.sh` applies PR-review requirement + linear history + secret scanning/push protection on `main` via API.
- **Verification harness** — `scripts/verify-phase-0.1.sh` runs the full Validation Checklist (domain, Doppler keys, branch protection, secret scan) with PASS/FAIL/SKIP/MANUAL.
- **Runbooks** — `docs/runbooks/00–05` step-by-step for Apple, Google Play, domain, Doppler, GitHub.

## 2. Files changed

```
A  .gitignore
A  ENVIRONMENT_VARS.md
A  scripts/doppler-bootstrap.sh
A  scripts/verify-phase-0.1.sh
A  scripts/github-branch-protection.sh
A  docs/runbooks/00-phase-0.1-overview.md
A  docs/runbooks/01-apple-developer-enrollment.md
A  docs/runbooks/02-google-play-developer-account.md
A  docs/runbooks/03-domain-and-cloudflare-dns.md
A  docs/runbooks/04-doppler-secrets-backbone.md
A  docs/runbooks/05-github-repo-branch-protection.md
A  sub-pr-report/SUBPR_PHASE_0.1.md
A  roadmap/APP_EXECUTION_ROADMAP.md            (source of truth, committed to repo)
A  roadmap/APP_EXECUTION_ROADMAP_DECOMPOSED.md (source of truth, committed to repo)
```

## 3. Tests executed

| Test | Command |
|------|---------|
| Bash syntax check (all scripts) | `bash -n scripts/*.sh` |
| Validation checklist harness | `./scripts/verify-phase-0.1.sh` |
| Secret-scan false-positive guard | manual `grep` for `service_role`/key-shapes across docs |
| Domain delegation | `dig NS pawdoc.app +short` |

## 4. Test results

- `bash -n` on all 3 scripts: **OK** (no syntax errors).
- `verify-phase-0.1.sh` exit code **0** (all verifiable checks green):
  - **PASS** Domain delegated to Cloudflare.
  - **PASS** No secret value-shapes in tracked files.
  - **SKIP** Doppler (CLI present, not authenticated — needs `doppler login`).
  - **SKIP** Branch protection (no GH admin token provided this session).
  - **MANUAL** Apple enrollment / Google Play account (founder action).
- Refined the scanner to match secret **value shapes** (JWT/`sk-ant-`/PEM/AWS), not the bare word `service_role`, which appears legitimately in `roadmap/APP_EXECUTION_ROADMAP.md` (lines 393, 836).

## 5. Security checks

- `.gitignore` blocks the credential file types that cause Day-1 leaks (`.env`, `*.p8`, keystores, service-account JSON, tool caches).
- Verified **zero** real secrets / key-shapes in the tree before commit.
- `ENVIRONMENT_VARS.md` marks server-only secrets 🔒 and documents that R2 client uploads use presigned URLs (Critical Review #6), never embedded write keys.
- `doppler-bootstrap.sh` is non-destructive (never overwrites an existing value).
- `github-branch-protection.sh` enables secret scanning + push protection as the leak backstop.

## 6. Known issues

- **Doppler not authenticated** in this environment — bootstrap + the Doppler validation check cannot run until `doppler login` is done. Script is ready and idempotent.
- **No GitHub admin token** this session — branch protection not yet applied programmatically. Runbook 05 + script ready.
- **`prod` config name** = Doppler's default `prd`; override with `DOPPLER_CONFIGS` if you prefer a literal `prod`.

## 7. Risks

- **Apple enrollment delay** (24–48h, longer on D-U-N-S/identity) — must be *initiated Day 1* to stay off the critical path (runbook 01).
- **Solo-founder branch protection**: required-reviews=1 has no second approver; runbook 05 documents the `REVIEW_COUNT=0` fallback (still PR-required).
- Real secret values are still absent — every dependent service in 0.2/0.3 must populate Doppler before use.

## 8. Git branch

`phase-0.1-accounts-secrets`

## 9. Commit hash

Implementation commit: `__IMPL_COMMIT__` (finalized in report-finalization commit; see `git log`).

## 10. Push confirmation

`__PUSH_STATUS__`

## 11. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Domain resolves through Cloudflare | ✅ DONE | `dig NS pawdoc.app` → Cloudflare NS; verify harness PASS |
| Doppler is the authoritative secret store | ⏳ READY | bootstrap script + ENVIRONMENT_VARS.md ready; **needs `doppler login`** then `./scripts/doppler-bootstrap.sh` |
| `main` is protected (no merge without review) | ⏳ READY | script + runbook ready; **needs GH admin token** then `./scripts/github-branch-protection.sh` |
| Apple account exists (or in review, initiated Day 1) | ⏳ MANUAL | runbook 01 — founder to initiate + log case number |
| Google Play account exists | ⏳ MANUAL | runbook 02 — founder to create |

**DoD met by automation:** domain. **DoD blocked on founder credentials/actions:** Doppler auth, GH token, Apple, Google Play — each has a ready script and/or runbook.
