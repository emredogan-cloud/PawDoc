# Local Development

This is the runbook for going from a clean machine to a working PawDoc dev
environment. Target: under 15 minutes.

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Git | 2.40+ | `apt install git` / `brew install git` |
| Python | 3.12 | [python.org](https://www.python.org/downloads/) or pyenv |
| uv | 0.4+ | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| Flutter | 3.41+ | [flutter.dev/docs/get-started/install](https://docs.flutter.dev/get-started/install) |
| Docker | 24+ | [docker.com/get-docker](https://www.docker.com/get-docker) |
| Supabase CLI | 1.200+ | [supabase.com/docs/guides/cli](https://supabase.com/docs/guides/cli/getting-started) |
| Node | 20+ | for Supabase functions (Deno is bundled by Supabase CLI) |

Verify after install:

```bash
python3 --version          # >= 3.12
uv --version
flutter --version          # >= 3.41
docker --version
supabase --version
git --version
```

## First-Time Setup

```bash
# 1. Clone (or `cd` into your existing clone)
cd PawDoc

# 2. Install Python + Flutter deps
make setup

# 3. Copy env templates and fill in values from Doppler
cp ai-service/.env.example ai-service/.env
cp mobile/env/dev.json.example mobile/env/dev.json
# Edit both files with real values.

# 4. (Optional) install pre-commit hooks
make pre-commit
```

For Phase 0, the env files can stay with placeholder values — the AI service
runs locally without provider keys, and the mobile app boots to a splash screen
without backend wiring. Phase 1 makes real values necessary.

## Running Each Service

### AI Service

```bash
make ai-dev
# Equivalent: cd ai-service && ./scripts/dev.sh
# Or via Docker: docker compose up ai-service

curl http://localhost:8080/health   # expect {"status":"ok",...}
```

### Mobile App

```bash
# Ensure a simulator/device is running.
make mobile-dev
# Equivalent: cd mobile && flutter run --dart-define-from-file=env/dev.json
```

### Supabase

```bash
make supabase-up
# Studio: http://127.0.0.1:54323
# Postgres: postgresql://postgres:postgres@127.0.0.1:54322/postgres
# Auth + Storage: http://127.0.0.1:54321
```

To wipe local DB state and re-apply migrations + seed:

```bash
make supabase-reset
```

## Day-to-Day Loop

```bash
# Make changes ...

# Format + lint everything
make format
make lint

# Run tests
make test

# Commit on a feature branch and open a PR
git checkout -b feat/your-thing
git add ...
git commit
git push -u origin feat/your-thing
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `flutter analyze` shows "Target SDK" mismatch | Newer Flutter than the constraint in pubspec.yaml | Bump `environment.sdk` or downgrade Flutter |
| `uv sync` fails on a clean machine | uv not on PATH | Re-source shell or restart terminal after install |
| `supabase start` hangs | Docker daemon not running | `systemctl --user start docker` |
| Mobile app says "Supabase anon key missing" | `env/dev.json` not populated or wrong path | Re-check the `--dart-define-from-file=env/dev.json` flag |
| Docker build fails on `uv sync` | `uv.lock` out of sync with pyproject | `cd ai-service && uv lock` then commit |
| Pre-commit hook fails on dart format | Newer Dart added trailing comma fixes | `make format-mobile` then re-stage |

## What Phase 0 Does NOT Include

- Real cloud accounts (Supabase remote, Fly.io, Cloudflare, etc.) — see [`environment-setup.md`](environment-setup.md)
- Anthropic / Gemini integration — Phase 1
- Auth flows — Phase 1
- Camera capture — Phase 1
- Anything you'd see as a user — Phase 1+

If you're trying to test an actual feature, you're probably looking for Phase 1.
