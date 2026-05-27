#!/usr/bin/env bash
# =============================================================================
# verify-phase-0.2.sh  —  runs the Phase 0.2 Validation Checklist.
# Local (config-as-code) checks always run. Remote checks (Supabase/R2/Doppler)
# run when credentials are present, else SKIP. Exit non-zero only on a FAIL.
# =============================================================================
set -uo pipefail

PROJECT="${DOPPLER_PROJECT:-pawdoc}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLACEHOLDER_RE='^SET_IN_PHASE'

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
skip()   { printf '\033[0;33mSKIP\033[0m  %s\n' "$*"; }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }

hr; echo "Phase 0.2 — Validation Checklist"; hr

# --- LOCAL: config-as-code is correct ---------------------------------------
python3 - "$ROOT/supabase/config.toml" <<'PY' && pass "config.toml parses; email+apple+google auth enabled" || fail "config.toml invalid or providers not all enabled"
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
ext = d["auth"]["external"]
assert d["auth"]["email"]["enable_signup"] is True
assert ext["apple"]["enabled"] is True
assert ext["google"]["enabled"] is True
PY

mig="$(ls "$ROOT"/supabase/migrations/*_enable_extensions.sql 2>/dev/null | head -1)"
if [ -n "$mig" ] && grep -qi 'extension if not exists "uuid-ossp"' "$mig" && grep -qi 'extension if not exists vector' "$mig"; then
  pass "extensions migration present (uuid-ossp + vector)"
else
  fail "extensions migration missing or incomplete"
fi

python3 - "$ROOT/infra/r2-cors.json" <<'PY' && pass "r2-cors.json valid; allows PUT for presigned uploads" || fail "r2-cors.json invalid or missing PUT"
import sys, json
r = json.load(open(sys.argv[1]))["CORSRules"][0]
assert "PUT" in r["AllowedMethods"]
assert any("pawdoc.app" in o for o in r["AllowedOrigins"])
PY

# --- REMOTE: Supabase extensions live on each project -----------------------
if [ -n "${SUPABASE_ACCESS_TOKEN:-}" ] && [ -n "${SUPABASE_PROJECT_REFS:-}" ]; then
  read -r -a REFS <<< "$SUPABASE_PROJECT_REFS"
  q="select extname from pg_extension where extname in ('vector','uuid-ossp')"
  body="$(python3 -c 'import json,sys;print(json.dumps({"query":sys.argv[1]}))' "$q")"
  for ref in "${REFS[@]}"; do
    out="$(curl -fsS -X POST "https://api.supabase.com/v1/projects/$ref/database/query" \
      -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" -H "Content-Type: application/json" \
      --data "$body" 2>/dev/null || true)"
    if echo "$out" | grep -q vector && echo "$out" | grep -q uuid-ossp; then
      pass "Supabase $ref: vector + uuid-ossp installed"
    else
      fail "Supabase $ref: extensions not both present (got: ${out:0:120})"
    fi
  done
else
  skip "Supabase extensions check — set SUPABASE_ACCESS_TOKEN + SUPABASE_PROJECT_REFS (docs/runbooks/06)"
fi

# --- REMOTE: R2 CORS preflight ----------------------------------------------
if [ -n "${R2_ACCOUNT_ID:-}${R2_ENDPOINT:-}" ] && [ -n "${R2_BUCKET_DEV:-}" ]; then
  EP="${R2_ENDPOINT:-https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com}"
  hdrs="$(curl -s -D - -o /dev/null -X OPTIONS \
    -H "Origin: https://pawdoc.app" -H "Access-Control-Request-Method: PUT" \
    "$EP/$R2_BUCKET_DEV/preflight-probe" 2>/dev/null || true)"
  if echo "$hdrs" | grep -qi 'access-control-allow-origin'; then
    pass "R2 CORS preflight returns Access-Control-Allow-Origin"
  else
    fail "R2 CORS preflight missing allow-origin header (run r2-bootstrap.sh)"
  fi
else
  skip "R2 CORS preflight — set R2_ACCOUNT_ID + R2_BUCKET_DEV (docs/runbooks/07)"
fi

# --- REMOTE: Doppler holds non-placeholder values ---------------------------
if command -v doppler >/dev/null 2>&1 && doppler me >/dev/null 2>&1; then
  pend=0
  for k in SUPABASE_URL SUPABASE_ANON_KEY R2_ACCOUNT_ID R2_ACCESS_KEY_ID; do
    v="$(doppler secrets get "$k" --project "$PROJECT" --config dev --plain 2>/dev/null || echo MISSING)"
    if [ "$v" = "MISSING" ] || echo "$v" | grep -qE "$PLACEHOLDER_RE"; then pend=$((pend+1)); fi
  done
  if [ "$pend" -eq 0 ]; then
    pass "Doppler dev holds real (non-placeholder) Supabase + R2 values"
  else
    fail "Doppler dev still has $pend placeholder/missing Supabase/R2 value(s)"
  fi
else
  skip "Doppler real-value check — run 'doppler login' (values minted via runbooks 06/07)"
fi

# --- MANUAL ------------------------------------------------------------------
manual "dev + prod + EU Supabase projects created? (EU region = Frankfurt, GDPR) — docs/runbooks/06"
manual "Auth providers enabled in dashboard: email + Apple (Services ID/key) + Google — docs/runbooks/06"
manual "Confirm R2 CORS in a real BROWSER preflight, not just curl (roadmap risk) — docs/runbooks/07"

hr
if [ "$fails" -eq 0 ]; then
  echo "Verifiable checks GREEN. Confirm MANUAL items for full DoD."; exit 0
else
  echo "$fails check(s) FAILED. Resolve before declaring Phase 0.2 done."; exit 1
fi
