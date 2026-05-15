# ai-service

Python FastAPI orchestrator for PawDoc's AI triage. Runs on Fly.io in production.

## Phase 0 Status

This is the foundation. The endpoint surface today is:

| Method | Path | Description |
|--------|------|-------------|
| `GET`  | `/health` | Liveness probe (used by Fly.io + Better Uptime) |

The `/analyze` endpoint, AI provider clients, safety overrides, semantic cache,
and prompts arrive in Phase 1.

## Local Development

Requires Python 3.12 and [uv](https://docs.astral.sh/uv/).

```bash
# First-time setup
uv sync --all-extras

# Copy env template
cp .env.example .env

# Run with hot reload
./scripts/dev.sh
# or
uv run uvicorn app.main:app --reload --port 8080
```

Health check:

```bash
curl http://localhost:8080/health | jq
```

## Quality

```bash
uv run ruff format .          # Format
uv run ruff check .           # Lint
uv run mypy app               # Type check
uv run pytest                 # Tests (with coverage)
```

All four are required-to-pass in CI (`.github/workflows/ai-service-ci.yml`).

## Docker

```bash
docker build -t pawdoc-ai:dev .
docker run --rm -p 8080:8080 --env-file .env pawdoc-ai:dev
```

## Deployment

`fly.toml` ships with placeholder app name `pawdoc-ai-dev`. Real deployment
flow (Phase 0 deliverable):

```bash
fly apps create pawdoc-ai-dev --org pawdoc
fly secrets import < <(doppler secrets download --no-file --format docker)
fly deploy
```

GitHub Actions handles this on merge to `main` once `FLY_API_TOKEN` is set
in the repo secrets — see `.github/workflows/ai-service-deploy.yml`.

## Layout

```
app/
├── main.py             FastAPI entrypoint
├── core/
│   ├── config.py       Pydantic Settings (env-driven)
│   ├── logging.py      structlog + stdlib bridge
│   └── exceptions.py   Typed error hierarchy
├── routers/
│   └── health.py       /health endpoint
├── services/           Phase 1: orchestrator, provider clients, safety, cache
├── models/
│   └── schemas.py      Shared Pydantic models
└── prompts/            Phase 1: system prompts + breed context
tests/
├── conftest.py         Shared fixtures (async client, settings reset)
├── test_health.py
└── test_config.py
```

## Architectural Rules

- **No hardcoded secrets.** All sensitive values come through `app.core.config.Settings`.
- **No bare `except` clauses.** Catch specific exceptions; use `PawDocError` subclasses.
- **Structured logs only.** Use `get_logger(__name__)`; never `print` or stdlib `logging` directly.
- **No mutating module-level state at import time.** App is built via `create_app()`.
- **Async-first.** All route handlers and service functions are `async def`.
