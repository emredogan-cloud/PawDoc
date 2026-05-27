#!/usr/bin/env bash
# =============================================================================
# verify-phase-0.3.sh  —  runs the Phase 0.3 Validation Checklist.
# Local checks (code, Docker, fly.toml, pytest, fly validate) run always.
# Deployed /health is checked when FLY_APP_URL is set, else SKIP.
# Exit non-zero only on a FAIL.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AISVC="$ROOT/ai-service"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
skip()   { printf '\033[0;33mSKIP\033[0m  %s\n' "$*"; }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }

hr; echo "Phase 0.3 — Validation Checklist"; hr

# --- LOCAL: service code defines GET /health (and nothing more, this phase) --
if grep -q '@app.get("/health")' "$AISVC/app/main.py"; then
  pass "FastAPI app defines GET /health"
else
  fail "GET /health not found in ai-service/app/main.py"
fi

# --- LOCAL: Dockerfile hardening ---------------------------------------------
if grep -q 'USER appuser' "$AISVC/Dockerfile" && grep -q 'app.main:app' "$AISVC/Dockerfile"; then
  pass "Dockerfile runs uvicorn as non-root appuser"
else
  fail "Dockerfile missing non-root USER or uvicorn CMD"
fi

# --- LOCAL: fly.toml always-warm config --------------------------------------
python3 - "$AISVC/fly.toml" <<'PY' && pass "fly.toml: min_machines_running=1, auto_stop=off, /health check" || fail "fly.toml always-warm config wrong"
import sys, tomllib
hs = tomllib.load(open(sys.argv[1], "rb"))["http_service"]
assert hs["min_machines_running"] == 1, "min_machines_running must be 1"
assert hs["auto_stop_machines"] == "off", "auto_stop_machines must be off"
assert any(c.get("path") == "/health" for c in hs["checks"]), "missing /health check"
PY

# --- LOCAL: fly CLI schema validation ----------------------------------------
if command -v fly >/dev/null 2>&1; then
  if fly config validate --config "$AISVC/fly.toml" >/dev/null 2>&1; then
    pass "fly config validate: configuration is valid"
  else
    fail "fly config validate failed"
  fi
else
  skip "fly CLI not installed — fly.toml schema unchecked"
fi

# --- LOCAL: pytest (runtime contract) ----------------------------------------
if [ -x "$AISVC/.venv/bin/python" ]; then PY="$AISVC/.venv/bin/python"
elif python3 -c "import fastapi" >/dev/null 2>&1; then PY="python3"
else PY=""; fi
if [ -n "$PY" ]; then
  if ( cd "$AISVC" && "$PY" -m pytest -q >/tmp/pawdoc_pytest.log 2>&1 ); then
    pass "ai-service pytest green ($(grep -oE '[0-9]+ passed' /tmp/pawdoc_pytest.log | head -1))"
  else
    fail "ai-service pytest failed — see /tmp/pawdoc_pytest.log"
  fi
else
  skip "pytest — create venv & 'pip install -r ai-service/requirements-dev.txt'"
fi

# --- REMOTE: deployed /health ------------------------------------------------
URL="${FLY_APP_URL:-}"
if [ -n "$URL" ]; then
  code="$(curl -s -o /dev/null -w '%{http_code}' "$URL/health" 2>/dev/null || echo 000)"
  [ "$code" = "200" ] && pass "deployed /health → 200 ($URL)" || fail "deployed /health → HTTP $code"
else
  skip "deployed /health — set FLY_APP_URL after deploy (docs/runbooks/08)"
fi

# --- MANUAL ------------------------------------------------------------------
manual "After deploy: 'fly status' shows exactly ONE always-on machine (no cold start)."
manual "RevenueCat project created with iOS + Android app identifiers — docs/runbooks/09"

hr
if [ "$fails" -eq 0 ]; then
  echo "Verifiable checks GREEN. Confirm MANUAL items for full DoD."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
