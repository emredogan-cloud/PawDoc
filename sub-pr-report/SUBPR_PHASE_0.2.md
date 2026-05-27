# SUB-PR Report — Phase 0.2: Core Data & Storage Platform

**Status:** Config-as-code + provisioning automation + verification complete; account/project creation handed off via runbooks.
**Branch:** `phase-0.2-data-storage` (stacked on `phase-0.1-accounts-secrets`)
**Date:** 2026-05-27

---

## 1. What was implemented

Like 0.1, the actual provisioning (creating Supabase projects, R2 buckets) is account-gated. This PR delivers the **executable form**: config-as-code, idempotent provisioning scripts, a verification harness, and runbooks.

- **Supabase scaffold** — `supabase init`; `supabase/config.toml` curated to enable **email + Apple + Google** auth (config-as-code) with `env()` secret substitution and the mobile redirect allow-list (`pawdoc://login-callback`).
- **Extensions migration** — `supabase/migrations/20260527000000_enable_extensions.sql` enables `uuid-ossp` + `vector` (pgvector) into the `extensions` schema. Canonical source of truth applied by `supabase db push` (and by the helper script).
- **R2 CORS policy** — `infra/r2-cors.json` (origins: pawdoc.app + localhost; methods GET/PUT/HEAD; PUT for presigned uploads).
- **Provisioning scripts:**
  - `scripts/r2-bootstrap.sh` — creates dev+prod buckets and applies CORS via the S3 API (idempotent).
  - `scripts/supabase-enable-extensions.sh` — applies the extensions migration to dev/prod/EU via the Management API.
  - `scripts/verify-phase-0.2.sh` — runs the full Validation Checklist.
- **Runbooks** — `06-supabase-projects.md` (dev/prod/**EU=Frankfurt**, extensions, auth providers, key→Doppler), `07-cloudflare-r2-buckets.md` (token, buckets, CORS, browser preflight, presigned-URL security model).
- **ENVIRONMENT_VARS.md** updated — auth provider secrets, EU project keys, R2 bucket names, `SUPABASE_ACCESS_TOKEN`.
- **Surfaced (not implemented):** Critical Review #22 (PITR/backups + restore drill at 0.2) — documented as an owner decision in runbook 06.

## 2. Files changed

```
A  supabase/config.toml                 (init + auth providers enabled)
A  supabase/.gitignore
A  supabase/migrations/20260527000000_enable_extensions.sql
A  infra/r2-cors.json
A  scripts/r2-bootstrap.sh
A  scripts/supabase-enable-extensions.sh
A  scripts/verify-phase-0.2.sh
A  docs/runbooks/06-supabase-projects.md
A  docs/runbooks/07-cloudflare-r2-buckets.md
A  sub-pr-report/SUBPR_PHASE_0.2.md
M  ENVIRONMENT_VARS.md
```

## 3. Tests executed

| Test | Command |
|------|---------|
| Bash syntax (new scripts) | `bash -n scripts/{r2-bootstrap,supabase-enable-extensions,verify-phase-0.2}.sh` |
| Validation checklist | `./scripts/verify-phase-0.2.sh` |
| config.toml parse + provider state | `python3 -c "import tomllib…"` |
| CORS JSON parse | `python3 -c "import json…"` |

## 4. Test results

- `bash -n` on all 3 new scripts: **OK**.
- `config.toml`: parses; `auth.external` → `{apple: True, google: True}`, email signup enabled.
- `r2-cors.json`: valid; allows `PUT`.
- `verify-phase-0.2.sh` exit **0**:
  - **PASS** config.toml (email+apple+google), **PASS** extensions migration (uuid-ossp+vector), **PASS** R2 CORS valid/PUT.
  - **SKIP** Supabase extensions (needs `SUPABASE_ACCESS_TOKEN`+refs), **SKIP** R2 preflight (needs R2 creds), **SKIP** Doppler real-value check (needs `doppler login`).
  - **MANUAL** project creation, dashboard auth providers, browser CORS preflight.
- Fixed a shell-quoting bug pre-commit: SQL single quotes (`'vector'`) were breaking the `--data` string; now the JSON body is built via `python3`.

## 5. Security checks

- **No secrets committed** — `config.toml` uses `env()` substitution only; verified no key-shapes in the tree.
- R2 buckets documented **private**; client access via **presigned PUT URLs** (Critical Review #6) — keys never shipped to the client.
- CORS origins are **explicit** (no `*` wildcard); `service_role` + all secrets marked 🔒 server-only.
- EXIF/GPS stripping noted as a Phase 1.2 client task (Critical Review #7).
- EU project mandated for data residency before any EU data exists.

## 6. Known issues

- **Project/bucket creation pending** — founder action via runbooks 06/07; remote verify checks SKIP until then.
- **Apple Sign In blocked on Apple Developer enrollment** (Phase 0.1, currently in review) — the Services ID + `.p8` key cannot be created until Apple approves. Email + Google are unblocked.
- `psql` not installed locally — the verify harness uses the Management API (no psql needed); local `supabase db` flows would need Docker.

## 7. Risks

- **R2 CORS** must be confirmed with a **real browser preflight**, not just `curl` (roadmap's #1 direct-upload failure mode) — runbook 07 includes the browser snippet.
- **EU region choice locks residency** — `eu-central-1` (Frankfurt) chosen per GDPR; changing later is a migration.
- Auth provider secret JWT generation for Apple is fiddly; budget time when Apple enrollment clears.

## 8. Git branch

`phase-0.2-data-storage` (stacked on `phase-0.1-accounts-secrets`; rebase onto `main` after 0.1 squash-merges).

## 9. Commit hash

Implementation commit: `9ae981a397fd18969d341426304010153511a1a8`.

## 10. Push confirmation

Pushed to `origin/phase-0.2-data-storage`. Open PR: https://github.com/emredogan-cloud/PawDoc/pull/new/phase-0.2-data-storage

## 11. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| dev + prod + EU Supabase live | ⏳ MANUAL | runbook 06 — founder creates 3 projects |
| Extensions `pgvector`+`uuid-ossp` on | ⏳ READY | canonical migration + `supabase-enable-extensions.sh`; verify check ready |
| Auth providers (email/Apple/Google) | ⏳ READY/MANUAL | declared in config.toml; dashboard config per runbook 06 (Apple needs 0.1 approval) |
| R2 buckets accept CORS-valid uploads | ⏳ READY | `r2-bootstrap.sh` + `infra/r2-cors.json`; browser preflight to confirm |
| All creds flow from Doppler | ⏳ READY | exact `doppler secrets set` commands in runbooks; verify checks non-placeholder values |

**Closable by automation once founder authenticates:** extensions, R2 buckets+CORS, Doppler population. **Irreducibly manual:** project creation (dashboard), Apple Services ID/key (gated on Apple enrollment).
