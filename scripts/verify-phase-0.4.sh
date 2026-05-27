#!/usr/bin/env bash
# =============================================================================
# verify-phase-0.4.sh  —  Phase 0.4 + Phase 0 EXIT-GATE checklist.
# Local checks (workflows, fastlane, ai-service lint/tests, secret scan) run
# always. CI/observability/TestFlight outcomes are MANUAL (need live runs).
# Exit non-zero only on a FAIL.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AISVC="$ROOT/ai-service"
REPO="${GH_REPO:-emredogan-cloud/PawDoc}"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
skip()   { printf '\033[0;33mSKIP\033[0m  %s\n' "$*"; }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }

hr; echo "Phase 0.4 — CI/CD, Observability & Verification (Phase 0 exit gate)"; hr

# --- LOCAL: workflows parse + CI has the required jobs -----------------------
if python3 - "$ROOT" <<'PY'
import sys, glob, yaml
root = sys.argv[1]
files = sorted(glob.glob(f"{root}/.github/workflows/*.yml"))
assert len(files) >= 3, f"expected >=3 workflows, found {len(files)}"
for f in files:
    yaml.safe_load(open(f))  # raises on bad YAML
ci = yaml.safe_load(open(f"{root}/.github/workflows/ci.yml"))
need = {"ai-service", "shell-lint", "secret-scan", "flutter"}
missing = need - set(ci["jobs"])
assert not missing, f"ci.yml missing jobs: {missing}"
PY
then pass "3 workflows parse; ci.yml has ai-service/shell-lint/secret-scan/flutter jobs"
else fail "workflow YAML invalid or CI jobs missing"
fi

# --- LOCAL: Fastlane scaffolding present -------------------------------------
if [ -f "$ROOT/fastlane/Fastfile" ] && [ -f "$ROOT/fastlane/Appfile" ] && [ -f "$ROOT/fastlane/Matchfile" ]; then
  pass "Fastlane Fastfile + Appfile + Matchfile present"
else
  fail "Fastlane config incomplete (need Fastfile, Appfile, Matchfile)"
fi

# --- LOCAL: ai-service ruff + pytest (the CI checks, run locally) ------------
if [ -x "$AISVC/.venv/bin/ruff" ]; then
  if "$AISVC/.venv/bin/ruff" check "$AISVC" >/dev/null 2>&1; then
    pass "ruff: ai-service clean"
  else
    fail "ruff issues in ai-service"
  fi
else
  skip "ruff — set up ai-service/.venv (pip install -r requirements-dev.txt ruff)"
fi
if [ -x "$AISVC/.venv/bin/python" ]; then
  if ( cd "$AISVC" && .venv/bin/python -m pytest -q >/tmp/pawdoc_p04.log 2>&1 ); then
    pass "pytest: $(grep -oE '[0-9]+ passed' /tmp/pawdoc_p04.log | head -1)"
  else
    fail "pytest failed — see /tmp/pawdoc_p04.log"
  fi
else
  skip "pytest — ai-service/.venv not set up"
fi

# --- LOCAL: zero secrets (DoD) ----------------------------------------------
if command -v gitleaks >/dev/null 2>&1; then
  if gitleaks detect --no-banner >/dev/null 2>&1; then
    pass "gitleaks: clean"
  else
    fail "gitleaks flagged secrets"
  fi
else
  pat='sk-ant-[A-Za-z0-9_-]{20}|-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{12,}\.eyJ[A-Za-z0-9_-]{12,}\.'
  if git grep -nIE "$pat" -- . ':(exclude)ENVIRONMENT_VARS.md' ':(exclude)scripts/*' ':(exclude)docs/*' >/dev/null 2>&1; then
    fail "possible secret value in tracked files"
  else
    pass "no secret value-shapes in tracked files (CI runs gitleaks for the full check)"
  fi
fi

# --- REMOTE: GitHub Actions secret FLY_API_TOKEN -----------------------------
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [ -n "$TOKEN" ]; then
  if curl -fsS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
       "https://api.github.com/repos/$REPO/actions/secrets" 2>/dev/null | grep -q 'FLY_API_TOKEN'; then
    pass "GitHub Actions secret FLY_API_TOKEN present"
  else
    fail "FLY_API_TOKEN not set in GitHub Actions secrets (deploy.yml needs it)"
  fi
else
  skip "GitHub Actions secret check — set GH_TOKEN (docs/runbooks/10)"
fi

# --- MANUAL (need live runs) -------------------------------------------------
manual "CI is green on a PR and completes in < 5 minutes (Actions tab)."
manual "Merge to main touching ai-service/ deploys to Fly + /health smoke passes."
manual "Tagged commit (v*) produces a TestFlight build < 24h (needs 1.1 iOS + runbook 11)."
manual "Sentry + PostHog each receive a test event; Better Uptime monitors all green (runbook 12)."
manual "Make the CI jobs REQUIRED status checks on main (runbook 10 step 2)."

hr
if [ "$fails" -eq 0 ]; then
  echo "Verifiable checks GREEN. Confirm MANUAL items to close the Phase 0 exit gate."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
