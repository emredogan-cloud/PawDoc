# PawDoc

> AI-native pet health triage. Photo, video, or text → instant guidance: **EMERGENCY**, **MONITOR**, or **LIKELY NORMAL**.

This is the PawDoc monorepo. It contains the Flutter mobile app, the Supabase backend (database + edge functions), the Python AI orchestration service, and shared infrastructure.

The complete product strategy, architecture, and phase plan live in [`roadmaps/APP_EXECUTION_ROADMAP.md`](roadmaps/APP_EXECUTION_ROADMAP.md). That document is the source of truth — this README is the on-ramp.

---

## Repository Layout

```
mobile/           Flutter 3.x app (iOS + Android)
supabase/         Database migrations + Edge Functions (Deno/TypeScript)
ai-service/       Python FastAPI orchestrator (Fly.io)
docs/             Architecture, dev, deploy, CI/CD docs + per-phase reports
.github/          CI/CD workflows
roadmaps/         Authoritative product + technical roadmap
reports/          Strategy analysis (market, growth, monetization, risk, tech decisions)
```

## Current Status

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Foundation & infrastructure | **In progress** — scaffold and CI/CD only |
| 1 | MVP core: camera → AI → result + auth + paywall | Pending |
| 2 | App Store launch | Pending |
| 3+ | Growth & scale | Pending |

See [`docs/reports/phase0-foundation-plan.md`](docs/reports/phase0-foundation-plan.md) for the active scope.

---

## Quick Start

Prerequisites:
- Flutter 3.22+ (`flutter --version`)
- Python 3.12 (`python3 --version`)
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- Docker + Docker Compose
- [Supabase CLI](https://supabase.com/docs/guides/cli) (`supabase --version`)
- Git

```bash
# Clone (skip if you already have it locally)
git clone <repo-url> pawdoc && cd pawdoc

# One-time local setup
make setup

# Run AI service locally (FastAPI on :8080)
make ai-dev

# Run mobile app locally (against dev env)
make mobile-dev

# Start local Supabase (Postgres + Auth + Storage + Studio)
make supabase-up
```

Detailed setup: [`docs/local-development.md`](docs/local-development.md).

---

## Make Targets

```
make help              Print all targets
make setup             Bootstrap all services for first run
make lint              Run linters across all services
make test              Run tests across all services
make format            Auto-format all code
make ai-dev            Start AI service (uvicorn --reload)
make mobile-dev        Run Flutter app on connected device
make supabase-up       Start local Supabase stack
make supabase-down     Stop local Supabase stack
make clean             Remove generated artifacts
```

---

## Core Principles (Non-Negotiable)

These come from the roadmap and the risk analysis. They hold from day one:

1. **Server-side validation of everything.** Free-tier limits, rate limits, ownership checks — never trust the client.
2. **RLS on every table.** Application-level bugs cannot leak cross-user data.
3. **Emergency override runs BEFORE any AI call.** Hardcoded keyword detection in `ai-service`.
4. **Disclaimer injected at API level.** UI changes cannot remove it.
5. **EMERGENCY analyses are NEVER paywalled.** Both unethical and trust-destroying.
6. **Structured JSON output from every AI call.** Free-text responses are rejected.
7. **Secrets via Doppler.** Never hardcoded. Never in version control.

---

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — System architecture
- [`docs/local-development.md`](docs/local-development.md) — Laptop setup
- [`docs/environment-setup.md`](docs/environment-setup.md) — Cloud account runbook
- [`docs/deployment.md`](docs/deployment.md) — Release pipelines
- [`docs/ci-cd.md`](docs/ci-cd.md) — GitHub Actions workflows

## License

Proprietary. All rights reserved. © PawDoc 2026.
