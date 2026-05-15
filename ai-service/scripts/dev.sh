#!/usr/bin/env bash
# Convenience wrapper for `make ai-dev`. Use either; this is what most
# developers reach for inside ai-service/.
set -euo pipefail
cd "$(dirname "$0")/.."

# Auto-create .env from example if missing — first-run convenience.
if [[ ! -f .env ]]; then
  echo "No .env found; creating from .env.example."
  cp .env.example .env
fi

exec uv run uvicorn app.main:app \
  --host 0.0.0.0 \
  --port "${PORT:-8080}" \
  --reload \
  --log-level "${LOG_LEVEL:-debug}"
