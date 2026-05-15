# Phase 0 — Foundation & Infrastructure Plan

**Project:** PawDoc — AI-Native Pet Health Triage App
**Phase:** 0 — Foundation & Infrastructure
**Owner:** Solo founder + AI engineering agent
**Plan Date:** 2026-05-15
**Authoritative Architecture Source:** `roadmaps/APP_EXECUTION_ROADMAP.md`

---

## 1. Repository Analysis

### 1.1 Current State

The working directory at `/home/emre/Downloads/PawDoc/` is a documentation-only workspace:

| Path | Purpose | Status |
|------|---------|--------|
| `startup_idea_template.md` | Original brainstorming template | Reference only |
| `roadmaps/APP_EXECUTION_ROADMAP.md` | **Authoritative** 14-section roadmap | Source of truth |
| `reports/TECH_DECISIONS.md` | Stack rationale + migration paths | Reference |
| `reports/GROWTH_STRATEGY.md` | Onboarding/retention/viral strategy | Reference |
| `reports/MONETIZATION_ANALYSIS.md` | Pricing, LTV/CAC analysis | Reference |
| `reports/RISK_ANALYSIS.md` | Failure modes, mitigation strategy | Reference |

No git repository, no application code, no infrastructure files, no CI/CD, no environment management exist yet. This is a **true greenfield** starting point.

### 1.2 Existing Configuration Files

None. The repository contains only Markdown documents.

### 1.3 Local Toolchain Available

| Tool | Version | Location | Used For |
|------|---------|----------|----------|
| Flutter | (system) | `/home/emre/dev/flutter/bin/flutter` | Mobile app |
| Dart | (system) | `/home/emre/dev/flutter/bin/dart` | Flutter language |
| Python | 3.12.3 | `/usr/bin/python3` | AI service |
| uv | (system) | `/home/emre/.local/bin/uv` | Python package + venv manager |
| Docker | (system) | `/usr/bin/docker` | Local containers, AI service image |
| Git | 2.43 | `/usr/bin/git` | VCS |
| Node | 24.13.1 | nvm-managed | Supabase CLI deps, web (Phase 4+) |
| Supabase CLI | (system) | `/usr/bin/supabase` | Migrations, edge functions, local Postgres |

Not yet installed locally (acceptable for Phase 0 — these are CI/CD-only or remote tools):
- `flyctl` — needed once AI service is deployed to Fly.io
- `gh` — convenient but not required (any browser works for PRs)
- `doppler` CLI — needed only when wiring real secrets

---

## 2. Architecture Analysis

### 2.1 Authoritative Architecture (from roadmap §3-§4)

**Client:** Flutter 3.x · Riverpod 2.x · go_router · Material 3 · Hive cache · CoreML/TFLite on-device pre-filter
**Backend (BaaS):** Supabase — Postgres 16 + pgvector + Auth + Storage + Edge Functions (Deno/TS)
**AI service:** Python 3.12 FastAPI on Fly.io · Pydantic v2 · httpx · Upstash Redis cache
**Storage:** Cloudflare R2 (zero-egress S3-compatible)
**Payments:** RevenueCat · **Analytics:** PostHog (self-hosted) · **Push:** OneSignal · **Errors:** Sentry · **Secrets:** Doppler · **CI/CD:** GitHub Actions + Fastlane

**AI tier topology** (roadmap §3): on-device → Gemini 2.0 Flash → Claude Sonnet 4.6 → Claude Opus 4.7 (EMERGENCY verification). Phase 0 only requires the service shell, not the routing logic.

### 2.2 Core Architectural Invariants (must hold from day one)

| Invariant | Why | Phase 0 Implication |
|-----------|-----|--------------------|
| RLS-first data access | Mass data-isolation bug = catastrophic; defense at DB layer | Supabase scaffold prepared with `auth.uid()` policy patterns; migrations directory ready |
| Server-side rate limiting | Free-tier abuse + AI cost runaway | Edge Function structure prepared, app code never trusts client |
| Emergency override BEFORE AI | Cannot let probabilistic model gate life-critical paths | AI service folder has a dedicated `services/safety.py` slot (Phase 1 fills it) |
| Structured AI output only | Free-text from LLM is unparseable + unsafe in health | Pydantic v2 in AI service from the start |
| Secrets via Doppler, never in code | Compromise of repo ≠ compromise of prod | `.env.example` everywhere; real `.env` files git-ignored; secret-scan workflow on every push |
| Disclaimer injected at API level | UI changes cannot remove legal protection | Schema design reserves `disclaimer_required: bool` (Phase 1) |
| Append-only analysis log | Legal record of every triage decision | Migration patterns designed for immutability (Phase 1) |

### 2.3 Architectural Risks Identified Now

| Risk | Description | Phase 0 Mitigation |
|------|-------------|--------------------|
| Monorepo vs. multi-repo drift | Three deployables (mobile, supabase, ai-service) need coordinated env + secrets | Single monorepo; per-service CI workflows; shared `.env.example` pattern |
| Doppler not yet provisioned | Real secret injection unavailable | Build all configs to read from env vars; document Doppler integration in `docs/environment-setup.md`; CI workflows reference GH Action secrets that Doppler can later sync into |
| Flutter native projects not yet generated | iOS/Android folders need real Xcode/Gradle config | Phase 0 plan calls `flutter create . --org com.pawdoc --platforms=ios,android` against the scaffolded `mobile/` after pubspec is in place |
| Deno edge function tooling diverges from Python/Dart workflow | Three lint/test toolchains to maintain | Separate but parallel CI workflow per service; consistent naming and structure |
| Cost overrun on AI service cold starts | Fly.io `min_machines_running=1` adds baseline cost | Documented in deployment doc + fly.toml comments |
| RLS misconfiguration shipped silently | Bug only visible at user-vs-user data leak | Plan reserves RLS lint scaffolding now (Phase 1 adds policy tests) |
| Drift between roadmap and code | A monorepo with no anchoring doc loses fidelity | Top-level `README.md` + `docs/architecture.md` link to roadmap as source of truth |

---

## 3. Folder Structure Plan

Final Phase 0 layout. `web/` is deferred to Phase 4+ and not created.

```
/home/emre/Downloads/PawDoc/
├── .editorconfig
├── .env.example                          # Orientation only — real secrets in Doppler
├── .git/                                 # Initialized in Phase 0
├── .github/
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   ├── pull_request_template.md
│   └── workflows/
│       ├── ai-service-ci.yml
│       ├── ai-service-deploy.yml         # Scaffold; activates once Fly.io is provisioned
│       ├── mobile-ci.yml
│       ├── mobile-release.yml            # Scaffold; activates once Fastlane is configured
│       ├── secret-scan.yml
│       └── supabase-ci.yml
├── .gitignore
├── .gitleaks.toml
├── .pre-commit-config.yaml
├── Makefile
├── README.md
├── ai-service/
│   ├── .dockerignore
│   ├── .env.example
│   ├── .python-version
│   ├── Dockerfile
│   ├── README.md
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                       # FastAPI entrypoint, lifespan, middleware
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── config.py                 # Pydantic Settings from env
│   │   │   ├── exceptions.py             # Typed app exceptions + handlers
│   │   │   └── logging.py                # structlog JSON config
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   └── schemas.py                # Shared Pydantic models
│   │   ├── prompts/
│   │   │   └── __init__.py               # Phase 1 fills this
│   │   ├── routers/
│   │   │   ├── __init__.py
│   │   │   └── health.py                 # GET /health
│   │   └── services/
│   │       └── __init__.py               # Phase 1 fills this
│   ├── fly.toml
│   ├── pyproject.toml
│   ├── scripts/
│   │   └── dev.sh
│   └── tests/
│       ├── __init__.py
│       ├── conftest.py
│       └── test_health.py
├── docker-compose.yml                    # Local ai-service + Supabase orchestration
├── docs/
│   ├── architecture.md
│   ├── ci-cd.md
│   ├── deployment.md
│   ├── environment-setup.md
│   ├── local-development.md
│   └── reports/
│       ├── phase0-foundation-implementation.md   # Written after impl
│       └── phase0-foundation-plan.md             # This file
├── mobile/
│   ├── .gitignore
│   ├── README.md
│   ├── analysis_options.yaml
│   ├── env/
│   │   ├── dev.json.example
│   │   └── prod.json.example
│   ├── lib/
│   │   ├── app/
│   │   │   ├── app.dart
│   │   │   ├── config.dart
│   │   │   ├── router.dart
│   │   │   └── theme.dart
│   │   ├── features/
│   │   │   ├── analysis/.gitkeep
│   │   │   ├── auth/.gitkeep
│   │   │   ├── history/.gitkeep
│   │   │   ├── home/.gitkeep
│   │   │   ├── onboarding/.gitkeep
│   │   │   ├── paywall/.gitkeep
│   │   │   ├── pets/.gitkeep
│   │   │   ├── reminders/.gitkeep
│   │   │   └── settings/.gitkeep
│   │   ├── main.dart                     # Single entrypoint, env via --dart-define-from-file
│   │   ├── platform/
│   │   │   ├── android/.gitkeep
│   │   │   └── ios/.gitkeep
│   │   └── shared/
│   │       ├── models/.gitkeep
│   │       ├── providers/.gitkeep
│   │       ├── services/
│   │       │   ├── logger.dart
│   │       │   └── supabase_client.dart
│   │       └── widgets/.gitkeep
│   ├── pubspec.yaml
│   └── test/
│       └── smoke_test.dart
├── reports/                              # (existing — strategy docs preserved)
├── roadmaps/                             # (existing — APP_EXECUTION_ROADMAP.md preserved)
├── startup_idea_template.md              # (existing — preserved)
└── supabase/
    ├── .gitignore
    ├── README.md
    ├── config.toml
    ├── functions/
    │   └── _shared/
    │       └── cors.ts
    ├── migrations/
    │   └── .gitkeep
    └── seed.sql
```

**Decisions explained:**

- **Monorepo** — Roadmap §4 prescribes it; the three deployables share env + auth + types; the alternative (3 repos) would force premature cross-repo contract management for a solo founder.
- **`docs/` at repo root** — Architectural docs cross-cut all services; living next to a single deployable would create discoverability rot.
- **`docs/reports/`** — Per-phase implementation reports live here so they stay versioned alongside code; the existing top-level `reports/` is preserved as the *strategy* archive (distinct domain).
- **`web/` deferred** — Phase 4+ deliverable per roadmap §10; creating it now would be dead weight.
- **Native iOS/Android projects generated by `flutter create` rather than hand-rolled** — gives correct Xcode + Gradle structure; Phase 0 step explicitly runs this.
- **No global virtualenv at repo root** — Each service owns its own toolchain; cross-service deps go through HTTP, not Python imports.

---

## 4. Infrastructure Setup Plan

### 4.1 Local Development Infrastructure (in-scope for Phase 0)

| Component | Mechanism | Lives In |
|-----------|-----------|----------|
| AI service container | `Dockerfile` + `docker-compose.yml` | `ai-service/Dockerfile`, root `docker-compose.yml` |
| Local Postgres + Auth + Storage | `supabase start` (CLI) | `supabase/config.toml` |
| Flutter dev | `flutter run --dart-define-from-file=env/dev.json` | `mobile/env/dev.json` (gitignored) |
| Common commands | `Makefile` | Repo root |

### 4.2 Cloud Infrastructure (out-of-scope, but DOCUMENTED for Phase 0)

Phase 0 of the roadmap calls for creating cloud accounts and projects. Those require human action (billing details, 2FA, domain registration). My deliverable is a runbook at `docs/environment-setup.md` covering:

1. Apple Developer enrollment (24-48h lead time, start Day 1)
2. Google Play Console account ($25 one-time)
3. Supabase project creation (dev + prod, both with `pgvector` + `uuid-ossp` extensions enabled)
4. Cloudflare R2 bucket creation with CORS for Flutter app origins
5. Fly.io organization + app creation (`pawdoc-ai-dev`, `pawdoc-ai-prod`)
6. Doppler workspace + project + config setup
7. Sentry org + project (Flutter DSN)
8. PostHog self-hosted on Fly.io (separate app)
9. OneSignal app
10. RevenueCat app (iOS + Android identifiers)

These remain TODOs that the founder must execute against the provided runbook. I will not create cloud resources from the local environment.

### 4.3 Environment Configuration Strategy

Three logical environments, each with its own set of secrets:

| Env | Use | Source of Truth |
|-----|-----|-----------------|
| `local` | Developer laptop | `*.env` files (gitignored) seeded from `*.env.example` |
| `dev` | Shared staging (Fly.io + Supabase dev projects) | Doppler `dev` config |
| `prod` | Production | Doppler `prod` config |

**Secret loading rule:** all services read secrets from process env (`os.environ` in Python, `String.fromEnvironment` / `--dart-define-from-file` in Dart, `Deno.env.get` in edge functions). No service ever reads from a `.env` file in production — `.env` is a local-development convenience only. Doppler injects env vars at runtime in CI/CD and at deploy time on Fly.io. This is the **only** secret-loading pattern; it has zero divergence from local to prod.

### 4.4 Doppler-Ready Architecture

Phase 0 does not require Doppler to be live. It requires the codebase to be ready for it:

- All env vars consumed by services are documented in the corresponding `.env.example`.
- No service has any code path that reads secrets from a config file, hardcoded literal, or other side channel.
- GitHub Actions workflows reference secrets via `${{ secrets.* }}`. Doppler's GitHub integration syncs into those secrets.
- Fly.io deploy step uses `fly secrets set` from CI (sourced from Doppler) or Doppler's Fly integration (recommended).

Done. No code changes required when Doppler activates.

---

## 5. CI/CD Strategy

### 5.1 Pipeline Topology

Six workflows, each scoped to one concern. Path filters keep each fast and only triggered when its code changes.

| Workflow | Triggers | Purpose |
|----------|----------|---------|
| `mobile-ci.yml` | PR or push touching `mobile/**` | `dart format --set-exit-if-changed` + `flutter analyze` + `flutter test` |
| `ai-service-ci.yml` | PR or push touching `ai-service/**` | `ruff format --check` + `ruff check` + `mypy` + `pytest` |
| `supabase-ci.yml` | PR or push touching `supabase/**` | `supabase db lint` + `deno fmt --check` + `deno lint` |
| `secret-scan.yml` | Every push | Gitleaks scan of full diff against `main` |
| `ai-service-deploy.yml` | Push to `main` touching `ai-service/**` (or manual) | `flyctl deploy --remote-only` |
| `mobile-release.yml` | Manual or version tag | Fastlane TestFlight + Play Store upload (scaffold) |

### 5.2 Speed & Reliability

- **Pub/uv/cache** restored on every run to keep mobile CI under 5 minutes and ai-service CI under 2 minutes.
- **Concurrency groups** cancel superseded runs on rapid pushes.
- **`fail-fast: false`** in matrix jobs so one platform failure doesn't mask another.
- **Required status checks** (configured in GitHub branch protection — instruction in `docs/ci-cd.md`): the three CI workflows + secret scan must pass before merge to `main`.

### 5.3 Deployment Gates

| Stage | Gate |
|-------|------|
| Edge Function deploy | Migration lint passes, peer-reviewed PR, merged to `main`. Supabase CLI deploys from the `supabase/functions/` directory. |
| AI service deploy | CI green on `main`, Docker image builds, Fly.io health check passes within 60s of release. |
| Mobile release | Version tag pushed; Fastlane authenticates via App Store Connect API key + Play Service Account JSON (both sourced from Doppler/GH secrets). |

Phase 0 ships the workflow scaffolds but the *deploy* workflows (`ai-service-deploy`, `mobile-release`) remain marked as `workflow_dispatch` + path-filtered. They activate the moment the corresponding secrets are populated.

---

## 6. Secrets Management Strategy

### 6.1 Inventory (Phase 0 surface)

Even before Phase 1 features ship, the foundation needs:

| Secret | Owner Service | Phase Required |
|--------|---------------|----------------|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | mobile, ai-service | Phase 1 (placeholder in `.env.example`) |
| `SUPABASE_SERVICE_ROLE_KEY` | ai-service, edge fns | Phase 1 |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ACCOUNT_ID`, `R2_BUCKET` | ai-service, mobile (for presigned uploads) | Phase 1 |
| `ANTHROPIC_API_KEY` | ai-service | Phase 1 |
| `GOOGLE_AI_API_KEY` | ai-service | Phase 1 |
| `SENTRY_DSN` (mobile + ai-service separate DSNs) | both | Phase 1 |
| `POSTHOG_API_KEY`, `POSTHOG_HOST` | mobile | Phase 1 |
| `FLY_API_TOKEN` | GitHub Actions | Phase 0 (for deploy workflow) |
| `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_KEY_ISSUER`, `APP_STORE_CONNECT_KEY_CONTENT` | GitHub Actions | Phase 2 |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | GitHub Actions | Phase 2 |

### 6.2 Controls

- `.gitignore` excludes `.env`, `.env.*` (except `.env.example`), `env/*.json` (mobile), `*.pem`, `*.p8`, `*.p12`, `*.jks`, `*.keystore`, `**/secrets/**`.
- `.gitleaks.toml` enables default rules + custom denylist for `ANTHROPIC_API_KEY`-style patterns.
- Pre-commit hook runs gitleaks locally so secrets are caught before push.
- GitHub Action `secret-scan.yml` is the belt to the gitleaks suspenders.

### 6.3 Rotation Posture

Doppler supports per-secret rotation. The architecture assumes any secret could be rotated at any time without code changes (no caching, no module-level reads outside `core/config.py`). This is enforced by Pydantic Settings being instantiated per-request — no global singletons holding secret values.

---

## 7. Deployment Strategy

### 7.1 AI Service (Fly.io)

- Docker image built in CI on every merge to `main`.
- Pushed to Fly.io's registry; `flyctl deploy --remote-only` triggers a rolling release.
- `min_machines_running = 1` (no cold starts — required for sub-10s P95 latency target).
- Two apps: `pawdoc-ai-dev` and `pawdoc-ai-prod`; same Dockerfile, different secret sets.
- Health check on `/health`; Fly waits for it before releasing traffic.
- `fly.toml` ships in repo with placeholder app name; the deployer fills in real name.

### 7.2 Supabase (Edge Functions + Migrations)

- `supabase db push` (idempotent) on merge to `main`.
- `supabase functions deploy` for each function.
- Same workflow runs against dev project on PR (preview-like behavior).
- Migrations are SQL files in `supabase/migrations/`. The naming convention `YYYYMMDDHHMMSS_<slug>.sql` is enforced by `supabase migration new` (and a CI check that file names match).

### 7.3 Mobile (TestFlight + Google Play Internal)

- Triggered by a Git tag `v*` (e.g., `v0.1.0`).
- Fastlane lanes: `ios_beta`, `android_beta`.
- Certificates via Fastlane Match (Git-backed encrypted cert repo) — TODO once Apple Developer enrollment completes.
- The workflow scaffold exists; activation is gated on Apple Developer + Play Console accounts.

### 7.4 Rollback

- **AI service:** `flyctl releases rollback`.
- **Supabase:** Migrations are forward-only in production. Bad migration → forward fix migration. Edge Functions rollback via redeploy of previous source.
- **Mobile:** Phased rollout in App Store Connect / Play Console; halt rollout if Sentry crash-free sessions drop.

---

## 8. Risk Analysis

### 8.1 Phase 0 Execution Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| `flutter create` clobbers hand-written files | Low | Medium | Run `flutter create` FIRST against an empty `mobile/` skeleton, then layer scaffold on top |
| Native iOS/Android folders generated with wrong bundle ID | Medium | Low | Pass `--org com.pawdoc` to `flutter create`; document in README |
| Doppler-less local dev gets stuck | Low | Low | `.env.example` is copy-paste-ready; `make setup` shortcuts the work |
| Pre-commit hook chain too slow → developer disables it | Medium | Medium | Keep hooks fast (<10s total); leave the heavy scans for CI |
| Lint config too strict → false positives stall PRs | Medium | Low | Start with `flutter_lints` + `ruff`'s recommended ruleset, not maximal strictness |
| Docker image too large → slow Fly.io deploys | Low | Low | Multi-stage Dockerfile; `python:3.12-slim` base; only runtime deps in final stage |
| CI cache invalidates every run | Medium | Low | Pin lockfile hashes as cache key; verify cache hits in first runs |

### 8.2 Phase 1+ Risks Surfaced by Phase 0 Decisions

| Decision | Future Risk | Acknowledgment |
|----------|-------------|----------------|
| Riverpod (not Bloc) | Future hire learning curve | Accepted per roadmap §3 |
| Self-hosted PostHog | Maintenance overhead | Accepted; managed Cloud is escape hatch |
| Monorepo | Per-team coordination as team grows | Acceptable for solo founder; revisit at 3+ engineers |
| Fly.io (not AWS) | Vendor risk | Accepted per roadmap §3; Docker = portable |
| pgvector (not Pinecone) | Performance ceiling at 1M+ embeddings | Documented migration path |

### 8.3 Security Posture (Phase 0 Baseline)

| Control | Phase 0 Status |
|---------|---------------|
| `.gitignore` blocks secret files | ✅ Will ship |
| Gitleaks pre-commit + CI | ✅ Will ship |
| `.env.example` files mark every secret name | ✅ Will ship |
| Pydantic Settings validates all env at boot | ✅ Will ship |
| Pydantic strict mode (`extra="forbid"`) | ✅ Will ship |
| Dart strong mode, no `dynamic` | ✅ Will ship (lint enforced) |
| HTTPS-only in non-local configs | ✅ Will ship (`fly.toml` `force_https=true`) |
| Branch protection on `main` | 📋 Documented in `docs/ci-cd.md`; user-applied |
| Doppler integration | 📋 Documented; user-applied |
| RLS policies | ⏳ Phase 1 (foundation has the migrations directory ready) |
| Rate limiting | ⏳ Phase 1 |
| Emergency override | ⏳ Phase 1 |

---

## 9. Implementation Order

Strict order. Each step is a coherent commit-sized unit.

1. **Initialize git** + write top-level `.gitignore`, `.editorconfig`, `.gitleaks.toml`, `README.md`. Establish the safety net before any other file lands.
2. **Repo root tooling** — `.pre-commit-config.yaml`, `.env.example`, `Makefile`, `docker-compose.yml`. Enables `make help` for everything that follows.
3. **AI service scaffold** — `pyproject.toml`, `Dockerfile`, `fly.toml`, FastAPI `app/` tree, `tests/`, structured logging, `/health` endpoint. **Verify with `uv run pytest` + `docker build`.**
4. **Flutter scaffold** — run `flutter create .` in `mobile/` with `--org com.pawdoc`, then layer scaffold (`pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `lib/app/*`, `lib/shared/services/*`, feature `.gitkeep` files). **Verify with `flutter pub get` + `flutter analyze` + `flutter test`.**
5. **Supabase scaffold** — `config.toml`, `migrations/.gitkeep`, `functions/_shared/cors.ts`, `seed.sql`, `.gitignore`. (Local `supabase start` is documented but optional during Phase 0.)
6. **GitHub Actions workflows** — six YAMLs, `CODEOWNERS`, `dependabot.yml`, `pull_request_template.md`. **Verify YAML with `yamllint` or `actionlint` if available.**
7. **Documentation** — five docs in `docs/`. Cross-link from `README.md`.
8. **Final QA** — run all lint/format/type/test checks; build the AI service Docker image; ensure repo is clean (`git status`).
9. **Implementation report** — `docs/reports/phase0-foundation-implementation.md` summarizing what shipped.

---

## 10. Expected File Modifications

### 10.1 New Files (estimated count: ~70)

| Group | Count | Notes |
|-------|-------|-------|
| Repo root configs | 9 | `.gitignore`, `.editorconfig`, `.gitleaks.toml`, `.pre-commit-config.yaml`, `.env.example`, `README.md`, `Makefile`, `docker-compose.yml`, `LICENSE` deferred |
| `.github/` | 9 | 6 workflows + CODEOWNERS + dependabot + PR template |
| `mobile/` Dart files | ~10 | `pubspec.yaml`, `analysis_options.yaml`, `main.dart`, `app/{app,router,theme,config}.dart`, `shared/services/{logger,supabase_client}.dart`, `test/smoke_test.dart`, README |
| `mobile/` placeholders | ~12 | `.gitkeep` in each feature + shared + platform folder |
| `mobile/` generated by `flutter create` | ~50 | iOS Xcode project, Android Gradle project, web/macos/linux/windows folders (web kept for V2; rest removed) |
| `mobile/env/*.json.example` | 2 | dev + prod templates |
| `ai-service/` | ~22 | `pyproject.toml`, `Dockerfile`, `.dockerignore`, `fly.toml`, `app/` Python tree (~15 files), `tests/`, `scripts/dev.sh`, README |
| `supabase/` | 6 | `config.toml`, `seed.sql`, `migrations/.gitkeep`, `functions/_shared/cors.ts`, `.gitignore`, README |
| `docs/` | 7 | architecture, ci-cd, deployment, environment-setup, local-development + 2 reports |

### 10.2 Modified Files

None. Phase 0 is purely additive. Existing `roadmaps/`, `reports/`, `startup_idea_template.md` are not touched.

### 10.3 Deleted Files

None.

### 10.4 Platforms Removed Post `flutter create`

- `mobile/macos/`, `mobile/linux/`, `mobile/windows/` — Out of scope; deleting trims maintenance surface.
- `mobile/web/` — Retained for Phase 4+ Flutter Web option per `TECH_DECISIONS.md` §1 ("Flutter Web exists for V2 web symptom checker").

---

## 11. Open Questions / Deferred Decisions

These don't block Phase 0 but should be resolved before Phase 1 starts:

1. **Doppler config naming convention** — `dev_local`, `dev_shared`, `prod`? Defer to founder; document a recommendation.
2. **GitHub org/repo name** — Repo will be initialized locally as `pawdoc` (root folder retains name `PawDoc` per current directory).
3. **Web bucket for `pawdoc.app`** — Cloudflare Pages or Vercel? Defer to Phase 4; not blocking.
4. **`com.pawdoc` vs. `app.pawdoc`** as the iOS/Android bundle prefix — Going with `com.pawdoc` as the conservative default; user can rebrand before App Store submission.
5. **Apple/Google account ownership** — Personal vs. business entity. Out of scope here, but the runbook in `docs/environment-setup.md` flags this.

---

## 12. Out of Scope (Explicit Non-Goals)

To stay rigorous, these are **NOT** part of Phase 0:

- No business logic in any service (no analyze pipeline, no auth flow, no paywall, no onboarding screens).
- No database schema (migrations directory exists but is empty save for `.gitkeep`).
- No AI provider integrations (no `anthropic`, no `google-generativeai` SDK calls; just the FastAPI shell).
- No on-device ML models (CoreML/TFLite is Phase 1+).
- No Sentry/PostHog/RevenueCat SDK initialization in the app shell (just placeholders in `.env.example`).
- No web symptom checker (Phase 4+).
- No real cloud resource creation (founder action; runbook only).
- No code commits to a remote (local git repo only; user can `git remote add` and push when ready).

---

## 13. Definition of Done for Phase 0

- `git status` is clean after implementation.
- `make lint` runs all linters across all services and passes.
- `make test` runs all tests across all services and passes.
- `cd ai-service && docker build .` succeeds.
- `cd mobile && flutter analyze` exits 0.
- `cd mobile && flutter test` exits 0.
- Every workflow YAML is syntactically valid.
- `docs/reports/phase0-foundation-implementation.md` documents the result.
- A new engineer following `docs/local-development.md` can reach a working `/health` 200 OK from the AI service in under 15 minutes on a clean machine.

---

*End of Phase 0 Foundation Plan. Implementation begins after this document is committed.*
