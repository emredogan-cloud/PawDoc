#!/usr/bin/env bash
# =============================================================================
# verify-phase-0.1.sh  —  runs the Phase 0.1 Validation Checklist.
# Verifiable checks PASS/FAIL; human-gated items are reported SKIP/MANUAL.
# Exit code is non-zero only if a *verifiable* check FAILS.
# =============================================================================
set -uo pipefail

PROJECT="${DOPPLER_PROJECT:-pawdoc}"
DOMAIN="pawdoc.app"
REPO="${GH_REPO:-emredogan-cloud/PawDoc}"
EXPECTED_KEYS=(SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY SUPABASE_JWT_SECRET \
  SUPABASE_DB_URL ANTHROPIC_API_KEY GOOGLE_AI_API_KEY R2_ACCOUNT_ID R2_ACCESS_KEY_ID \
  R2_SECRET_ACCESS_KEY R2_ENDPOINT R2_BUCKET_DEV R2_BUCKET_PROD)

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
skip()   { printf '\033[0;33mSKIP\033[0m  %s\n' "$*"; }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }

hr; echo "Phase 0.1 — Validation Checklist"; hr

# 1) Domain resolves through Cloudflare ---------------------------------------
ns="$(dig NS "$DOMAIN" +short 2>/dev/null)"
if echo "$ns" | grep -qi 'cloudflare'; then
  pass "Domain '$DOMAIN' is delegated to Cloudflare NS:"; echo "        ${ns//$'\n'/$'\n'        }"
else
  fail "Domain '$DOMAIN' does not resolve to Cloudflare nameservers (got: ${ns:-none})"
fi

# 2) Doppler: configs + expected keys present --------------------------------
if ! command -v doppler >/dev/null 2>&1; then
  skip "Doppler CLI not installed — see docs/runbooks/04-doppler-secrets-backbone.md"
elif ! doppler me >/dev/null 2>&1; then
  skip "Doppler not authenticated — run 'doppler login' then './scripts/doppler-bootstrap.sh'"
else
  for cfg in dev prd; do
    if ! doppler secrets --project "$PROJECT" --config "$cfg" --only-names >/dev/null 2>&1; then
      fail "Doppler config '$cfg' not found in project '$PROJECT' (run doppler-bootstrap.sh)"
      continue
    fi
    names="$(doppler secrets --project "$PROJECT" --config "$cfg" --only-names 2>/dev/null)"
    missing=()
    for k in "${EXPECTED_KEYS[@]}"; do echo "$names" | grep -qx "$k" || missing+=("$k"); done
    if [ ${#missing[@]} -eq 0 ]; then
      pass "Doppler '$cfg' holds all ${#EXPECTED_KEYS[@]} expected keys (placeholders allowed)"
    else
      fail "Doppler '$cfg' missing keys: ${missing[*]}"
    fi
  done
fi

# 3) Branch protection on main ------------------------------------------------
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [ -z "$TOKEN" ]; then
  skip "No GH_TOKEN/GITHUB_TOKEN — cannot query branch protection. See docs/runbooks/05-github-repo-branch-protection.md"
else
  code="$(curl -s -o /tmp/bp.json -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/branches/main/protection" || echo 000)"
  if [ "$code" = "200" ] && grep -q 'required_pull_request_reviews' /tmp/bp.json; then
    pass "main is protected (required_pull_request_reviews present)"
  else
    fail "main not protected (HTTP $code). Run ./scripts/github-branch-protection.sh"
  fi
fi

# 4) No obvious secrets in tracked files -------------------------------------
if command -v gitleaks >/dev/null 2>&1; then
  if gitleaks detect --no-banner -r /tmp/gitleaks.json >/dev/null 2>&1; then
    pass "gitleaks: no secrets detected in repo"
  else
    fail "gitleaks flagged potential secrets — inspect /tmp/gitleaks.json"
  fi
else
  # Match secret VALUE shapes (real keys/JWTs/PEM), not bare words like "service_role"
  # which legitimately appear in documentation/prose.
  pat='sk-ant-[A-Za-z0-9_-]{20}|-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{12,}\.eyJ[A-Za-z0-9_-]{12,}\.'
  if git grep -nIE "$pat" -- . ':(exclude)ENVIRONMENT_VARS.md' ':(exclude)scripts/*' ':(exclude)docs/*' >/dev/null 2>&1; then
    fail "Possible secret VALUE found in tracked files — review 'git grep' hits"
  else
    pass "No obvious secret patterns in tracked files (gitleaks not installed — basic scan)"
  fi
fi

# 5) Human-gated accounts -----------------------------------------------------
manual "Apple Developer enrollment INITIATED Day 1? Confirm email/case number (docs/runbooks/01)."
manual "Google Play Developer account created? (docs/runbooks/02)."

hr
if [ "$fails" -eq 0 ]; then
  echo "Verifiable checks: ALL GREEN. Confirm MANUAL items above for full DoD."
  exit 0
else
  echo "Verifiable checks: $fails FAILED. Resolve before declaring Phase 0.1 done."
  exit 1
fi
