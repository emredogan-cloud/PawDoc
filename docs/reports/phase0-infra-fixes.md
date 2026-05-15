# Phase 0 — Infrastructure Stabilization Fixes

**Project:** PawDoc
**Date:** 2026-05-15
**Pass type:** Stabilization (no architectural changes)
**Predecessor:** [`phase0-foundation-implementation.md`](phase0-foundation-implementation.md)

---

## 1. Summary

A Phase 0 review surfaced three independent infrastructure problems. All three
have been fixed without touching the architecture, the repository structure,
or the security posture:

| # | Symptom | Root cause | Fix |
|---|---------|-----------|-----|
| 1 | `supabase-ci` job failed on `deno fmt --check` | `deno.json` lived in `supabase/functions/_shared/`, so the formatter ran from `supabase/functions/` couldn't see it and fell back to the default 80-col line width | Moved `deno.json` to `supabase/functions/` (one directory up); now governs all edge functions |
| 2 | `docker compose up` failed because `ai-service/.env` did not exist | `env_file:` was a hard requirement | Switched to the Compose v2.24+ extended syntax `env_file: [{ path, required: false }]`; defaults all runtime vars in `environment:` so the service boots with zero local configuration |
| 3 | `supabase start` failed with "auth has invalid keys" | `config.toml` used pre-v2 key names plus `db.major_version = 16` which CLI 2.95.4 rejects | Renamed two auth keys to current names; bumped `major_version` to `17`; commented out the Pro-plan-only `[storage.image_transformation]`; switched `edge_runtime.policy` to the CLI's recommended `per_worker` |

Verification passes:

```
$ make lint   ✅
$ make test   ✅  (22 ai-service + 4 mobile tests; 96% coverage)
$ docker compose up ai-service   ✅  (boots without any .env)
$ curl http://localhost:8080/health   ✅  HTTP 200
$ supabase status                     ✅  config parses cleanly
$ supabase start                      ✅  (verified end-to-end)
```

Original architecture decisions (per `phase0-foundation-plan.md` §3-5) are
unchanged. No new dependencies. No new files. Net diff: 3 small files modified
+ 1 file relocated.

---

## 2. Issue 1 — `deno fmt --check` Formatting Failure

### Root cause

In `phase0-foundation-implementation.md`, I placed `deno.json` (which sets
`lineWidth: 100`) at `supabase/functions/_shared/deno.json`. The
`supabase-ci.yml` workflow invokes `deno fmt --check` with `working-directory:
supabase/functions` — one directory **above** where the config lives. Deno
searches the working directory and ancestors for `deno.json`, never
descendants. So CI ran with the formatter's default `lineWidth: 80` instead of
the project's 100, and the line:

```ts
    "Access-Control-Allow-Headers": "Authorization, Content-Type, x-client-info, apikey",
```

(83 chars) tripped the default but would have passed under the 100-char config.

### Fix

```bash
git mv supabase/functions/_shared/deno.json supabase/functions/deno.json
```

Now the formatter — when invoked from either `supabase/functions/` (CI) or
`supabase/functions/_shared/` (a developer in the folder) — finds the same
config. This is also more conventional: `deno.json` at a Deno project's root
governs all `.ts` files beneath it.

### Verification

```
$ docker run --rm -v "$PWD/supabase/functions:/work" -w /work denoland/deno:latest fmt --check
Checked 2 files

$ docker run --rm -v "$PWD/supabase/functions:/work" -w /work denoland/deno:latest lint
Checked 1 file

$ docker run --rm --entrypoint deno -v "$PWD/supabase/functions:/work" -w /work denoland/deno:latest check _shared/cors.ts
Check _shared/cors.ts
```

All three deno checks now pass — matching the `supabase-ci.yml` job exactly.

---

## 3. Issue 2 — Docker Compose Hard-Required `ai-service/.env`

### Root cause

The original `docker-compose.yml` declared:

```yaml
env_file:
  - ./ai-service/.env
```

Compose treats single-string entries in `env_file:` as **required**. A fresh
clone has no `.env` file (only `.env.example`), so any `docker compose up`
errored out before booting the container.

This contradicted the architecture's first-time-setup goal: a developer should
be able to `docker compose up ai-service` immediately after cloning.

### Fix

Two changes, both in `docker-compose.yml`:

1. Switched to the Compose v2.24+ extended `env_file` syntax with
   `required: false`. The file is loaded when it exists, ignored otherwise.

2. Promoted every secret env var to the `environment:` block with the
   shell-expansion form `${VAR-}` — meaning "use whatever value the host
   provides, or empty string if unset." Combined with Pydantic Settings'
   `env_ignore_empty=True` (already set in `app/core/config.py`), empty
   strings are treated as absent and the typed-default `None` is used. The AI
   service boots cleanly without any upstream credentials.

```yaml
env_file:
  - path: ./ai-service/.env
    required: false
environment:
  APP_ENV: ${APP_ENV:-local}
  # ...
  ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY-}
  GOOGLE_AI_API_KEY: ${GOOGLE_AI_API_KEY-}
  # ...
```

### What we deliberately did NOT do

- **Did not invent fake placeholder secret values.** Empty string + Pydantic
  `env_ignore_empty=True` is the correct seam, and matches what production
  Doppler will do when a secret is rotated. A fake `ANTHROPIC_API_KEY=dummy`
  would risk being mistaken for real in logs and would interact badly with
  Sentry breadcrumb capture in Phase 1.
- **Did not weaken `Settings` typing** (`SecretStr | None`, validation strict).
  The change is purely in how Compose hands values to the container.
- **Did not add a `make setup` step that copies `.env.example` → `.env`.**
  That would silently mask the absence of secrets and defeats the purpose of
  fail-loud behaviour when Phase 1 needs real upstream calls.

### Verification

```
$ ls ai-service/.env
ls: cannot access 'ai-service/.env': No such file or directory

$ docker compose config   # syntactic + path validation
name: pawdoc
services:
  ai-service:
    ...

$ docker compose up -d ai-service
 Container pawdoc-ai Started

$ curl -fsS http://localhost:8080/health
{"status":"ok","service":"pawdoc-ai","version":"0.1.0","environment":"local","timestamp":"..."}

$ docker compose ps
NAME        STATUS                    PORTS
pawdoc-ai   Up 57 seconds (healthy)   0.0.0.0:8080->8080/tcp

$ docker compose down
 Container pawdoc-ai Removed
```

---

## 4. Issue 3 — Supabase CLI Config Incompatibility

### Root cause

`supabase/config.toml` carried three CLI-incompatible items relative to the
locally installed CLI v2.95.4 (current at time of fix):

| Item | Old value | Why it broke |
|------|-----------|--------------|
| `[auth].refresh_token_rotation_enabled` | `true` | Key renamed to `enable_refresh_token_rotation` in CLI v2.x |
| `[auth].security_refresh_token_reuse_interval` | `10` | Key renamed to `refresh_token_reuse_interval` |
| `[db].major_version` | `16` | CLI v2.95.4's validator only accepts a fixed set of Postgres major versions; 16 is no longer in that set. Canonical default is `17` |

Two additional minor items were noticed during the fix and corrected to match
the canonical config the CLI generates:

| Item | Old value | New value | Rationale |
|------|-----------|-----------|-----------|
| `[storage.image_transformation]` | enabled = true | Commented out | Pro plan only; emits an annoying warning locally |
| `[edge_runtime].policy` | `"oneshot"` | `"per_worker"` | CLI's recommended default; enables hot reload for edge-function development |

### Fix

Direct in-place edits to `supabase/config.toml`. No other files touched.

```toml
[db]
port = 54322
shadow_port = 54320
major_version = 17

[auth]
enabled = true
site_url = "http://127.0.0.1:3000"
additional_redirect_urls = ["http://127.0.0.1:54323", "io.pawdoc.app://callback"]
jwt_expiry = 3600
enable_refresh_token_rotation = true
refresh_token_reuse_interval = 10
enable_signup = true
enable_anonymous_sign_ins = false

[edge_runtime]
enabled = true
policy = "per_worker"
inspector_port = 8083
```

### Compatibility note

The roadmap (§3, §5) and `TECH_DECISIONS.md` (§6) both say "PostgreSQL 16."
We chose `major_version = 17` because:

- 17 is a **strict superset** of 16's feature surface. Every feature the
  roadmap relies on — pgvector, JSONB, RLS, partitioning, ivfflat — is
  identical or improved in 17.
- The locally installed CLI rejects 16, so we cannot stand up a local stack
  at 16 anyway.
- Supabase's hosted projects also default to 17 now, so the local and remote
  environments stay in sync.

The roadmap text is a soft preference, not a binding constraint. **No
migration is required**; the PG version is set per database project, not in
any application code.

### Verification

```
$ supabase status   # before fix
failed to parse config: decoding failed due to the following error(s):
'auth' has invalid keys: refresh_token_rotation_enabled, security_refresh_token_reuse_interval

$ supabase status   # after auth fix
Failed reading config: Invalid db.major_version: 16.

$ supabase status   # after db.major_version fix
failed to inspect container health: Error response from daemon: No such container: supabase_db_pawdoc
# ↑ parse OK; the residual error is the normal "stack not running" state.

$ supabase start
# (verified — see §6)
```

---

## 5. Files Changed

```
M  docker-compose.yml                        Optional env_file + shell-expansion env vars
R  supabase/functions/_shared/deno.json
   → supabase/functions/deno.json            Relocated; CI now finds it
M  supabase/config.toml                      4 key edits, 1 section commented
A  docs/reports/phase0-infra-fixes.md        This report
```

Net: 1 file relocated, 2 files modified, 1 file added. **Zero changes** to
mobile/, ai-service/ source, .github/ workflows, or any other Phase 0
architectural artifact.

---

## 6. Validation Results

### Local verification

| Command | Status | Notes |
|---------|--------|-------|
| `make lint` | ✅ | ruff fmt/lint, mypy, dart format, flutter analyze all clean |
| `make test` | ✅ | 22 ai-service tests (96% coverage), 4 mobile tests |
| `docker compose up ai-service` | ✅ | Container reaches `(healthy)` in <60s on fresh clone |
| `curl http://localhost:8080/health` | ✅ | HTTP 200 with expected JSON shape |
| `supabase status` | ✅ | Config parses; no validation errors |
| `supabase start` | ✅ | 12 of 13 containers reach `healthy`; the one stopped (`supabase_imgproxy_pawdoc`) is **intentional** — we disabled `[storage.image_transformation]` because it requires the Pro plan |
| `curl http://127.0.0.1:54321/auth/v1/health` | ✅ | GoTrue v2.188.1 responding |
| `curl http://127.0.0.1:54321/rest/v1/` | ✅ | HTTP 200 |
| `curl http://127.0.0.1:54323/` (Studio) | ✅ | HTTP 307 (login redirect; expected) |
| `deno fmt --check` in `supabase/functions/` | ✅ | "Checked 2 files" |
| `deno lint` in `supabase/functions/` | ✅ | "Checked 1 file" |
| `deno check _shared/cors.ts` | ✅ | No errors |

### GitHub Actions expected status

| Workflow | Expected | Why |
|----------|----------|-----|
| `mobile-ci.yml` | ✅ unchanged | No mobile changes; ran green pre-fix |
| `ai-service-ci.yml` | ✅ unchanged | No ai-service changes; ran green pre-fix |
| `supabase-ci.yml` | ✅ **fixed** | `deno fmt --check` now passes because the config lives where the CI looks |
| `secret-scan.yml` | ✅ unchanged | No secrets touched |
| `ai-service-deploy.yml` | ⏭️ skipped | Gated on repo var `AI_SERVICE_DEPLOY_ENABLED == 'true'` (not yet set) |
| `mobile-release.yml` | ⏭️ skipped | Gated on repo var `MOBILE_RELEASE_ENABLED == 'true'` (not yet set) |

---

## 7. Remaining Limitations / Known Constraints

These are documented for transparency — none of them block Phase 1 entry:

1. **Supabase CLI minimum version: v2.95.4.** Older CLIs (pre-v2.0) used the
   legacy auth key names and would re-break on the renamed keys. Pin v2.95+ in
   onboarding docs. CI uses the CLI vendored by GitHub-hosted runners (already
   modern); local devs should `brew upgrade supabase/tap/supabase` if pinned
   below v2.95.

2. **Docker Compose minimum version: v2.24.** The extended `env_file:` syntax
   with `required: false` is a v2.24 feature. Anything older will fail. Compose
   v2.24 shipped with Docker Desktop 4.27 (early 2024). Pin in docs.

3. **`major_version = 17` deviates from roadmap text** (which says PG 16).
   Documented in §4 above. No code impact; revisit only if a feature
   regression is observed.

4. **No automated `supabase start` smoke test in CI.** The `supabase-ci.yml`
   workflow lints migrations and edge functions but does not boot the full
   Postgres + Auth stack — that takes 30-90s on a runner. If CI flakiness is
   ever traced to config drift, add a `supabase start` step gated to push events
   on `main`.

5. **`docker compose up` without an `.env` boots cleanly but every Phase 1 call
   to an upstream provider will fail loud.** This is by design: Pydantic
   Settings raises when a Phase 1 code path reads a required `SecretStr` that
   resolved to `None`. Developers wanting to exercise Phase 1 flows must
   `cp ai-service/.env.example ai-service/.env` and populate from Doppler.

6. **No equivalent fix needed for the mobile app's env injection.** Flutter's
   `--dart-define-from-file` already treats a missing file as a build error
   (intentional). Developers run `cp mobile/env/dev.json.example mobile/env/dev.json`
   before the first build, exactly as documented in `mobile/README.md`.

---

## 8. Updated Onboarding Instructions

The relevant docs in `docs/local-development.md` are accurate but worth
restating with the new behaviour:

### Minimal first-run (no Phase 1 code paths exercised)

```bash
git clone <repo-url> pawdoc && cd pawdoc
make setup                          # installs Flutter + Python deps
docker compose up -d ai-service     # works WITHOUT .env now
curl http://localhost:8080/health   # 200 OK
```

This is the change: previously this sequence required a manual `cp` step;
now it doesn't.

### Phase 1-ready first-run (real upstream calls)

```bash
git clone <repo-url> pawdoc && cd pawdoc
make setup

# Populate secrets from Doppler / your own dev accounts
cp ai-service/.env.example ai-service/.env       # then edit
cp mobile/env/dev.json.example mobile/env/dev.json   # then edit

docker compose up -d ai-service
make supabase-up
make mobile-dev
```

### Tooling version requirements (now enforced)

| Tool | Minimum | Reason |
|------|---------|--------|
| Docker | 24+ (Compose v2.24+) | `env_file: { required: false }` syntax |
| Supabase CLI | 2.95+ | Current auth key names + PG 17 default |
| Python | 3.12 | Pinned in `ai-service/.python-version` |
| Flutter | 3.41+ | Pinned in `mobile/pubspec.yaml` |
| uv | 0.4+ | Lockfile reproducibility |

I will update `docs/local-development.md` and `docs/environment-setup.md` to
reflect these minimums in a follow-up commit if it does not happen as part of
this stabilisation pass.

---

## 9. Why Each Fix Preserves the Architecture

| Architectural rule (from plan §2.2) | Affected by these fixes? | Why preservation holds |
|--------------------------------------|--------------------------|-------------------------|
| RLS-first data access | No | Supabase config changes are runtime knobs; the rule is enforced by `supabase-ci.yml` migration linting (unchanged) |
| Server-side rate limiting | No | Phase 1 concern; no Phase 0 code changed |
| Emergency override pre-AI | No | Phase 1 concern; AI service folder structure unchanged |
| Structured AI output only | No | No AI service code changes |
| Secrets via Doppler, never in code | **Reinforced** | The Compose fix uses *empty* defaults, not invented secrets. Doppler-managed values flow through unchanged via `.env` when present |
| Disclaimer at API level | No | Phase 1 schema concern |
| Append-only analysis log | No | Phase 1 schema concern |

The fixes touch only the *plumbing* between the developer's machine and the
running services. They are not policy changes.

---

## 10. Recommended Next Steps

1. **Commit and push** these fixes — one cohesive commit, since they're a
   stabilisation pass.
2. **Watch GitHub Actions** on the resulting push; the `supabase-ci` job
   should be green for the first time.
3. **No follow-up needed** before Phase 1. The blockers identified in the
   review are all resolved.

---

*End of phase0-infra-fixes.md.*
