#!/usr/bin/env bash
# =============================================================================
# verify-phase-5.2.sh — Web Symptom Checker (Phase 5.2).
# Asserts the anonymous AI path is hard-gated (Turnstile + Upstash IP limit,
# fail-closed, simplified result) and that the web /check page honors the
# static-export constraint (Client Component fetch; no Next API route). Runs the
# node helper tests + a real `next build` when deps are present.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FN="$ROOT/supabase/functions"
EDGE="$FN/analyze-anonymous/index.ts"
W="$ROOT/web"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qiE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 5.2 — Web Symptom Checker"; hr

# --- Files -------------------------------------------------------------------
have "$FN/_shared/web_checker.mjs"        "Web-checker shared helpers"
have "$FN/_shared/web_checker.test.mjs"   "Web-checker helper tests"
have "$EDGE"                              "/analyze-anonymous Edge Function"
have "$W/app/check/page.tsx"              "/check page (server, SEO)"
have "$W/app/check/symptom-checker.tsx"   "/check client component"
have "$W/.env.example"                    "web env example"
have "$ROOT/docs/runbooks/21-web-checker.md" "Web-checker runbook"

# --- Anonymous endpoint is hard-gated ----------------------------------------
check "analyze-anonymous is verify_jwt=false" '\[functions.analyze-anonymous\]' "$ROOT/supabase/config.toml"
check "Turnstile verified server-side"        'siteverify' "$EDGE"
check "Upstash IP rate limit (INCR)"          '"incr"' "$EDGE"
check "24h window (EXPIRE)"                    '"expire"' "$EDGE"
check "clean 429 on rate limit"               'rate_limit' "$EDGE"
check "FAILS CLOSED (503) if controls unconfigured" 'temporarily_unavailable' "$EDGE"
check "returns ONLY the simplified result"    'simplifyResult' "$EDGE"
check "calls the AI service"                  '/analyze' "$EDGE"
check "main /analyze stays authenticated (not anon)" '\[functions.analyze-anonymous\]' "$ROOT/supabase/config.toml"

# --- Simplifier withholds the detailed guidance ------------------------------
check "simplifyResult keeps only triage + concern" 'triage_level' "$FN/_shared/web_checker.mjs"

# --- Static-export constraint (no API route; client fetch) -------------------
check "checker is a Client Component"         'use client' "$W/app/check/symptom-checker.tsx"
check "client fetches the anonymous Edge fn"  'analyze-anonymous' "$W/app/check/symptom-checker.tsx"
if [ -d "$W/app/api" ]; then
  fail "web/app/api exists — Next API routes can't be statically exported"
else
  pass "no Next API route (static-export-safe)"
fi

# --- Conversion funnel + emergency safety ------------------------------------
check "detailed steps gated behind a blur"    'blur\(' "$W/app/check/symptom-checker.tsx"
check "store CTA on the result"               'App Store' "$W/app/check/symptom-checker.tsx"
check "EMERGENCY message is NOT gated"        'may be an emergency' "$W/app/check/symptom-checker.tsx"

# --- node helper tests -------------------------------------------------------
if command -v node >/dev/null 2>&1; then
  if node --test "$FN"/_shared/web_checker.test.mjs >/tmp/pawdoc_node52.log 2>&1; then
    pass "node --test (web_checker) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node52.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/web_checker.test.mjs"
fi

# --- Real static build (when deps installed) ---------------------------------
if [ -d "$W/node_modules" ] && command -v npm >/dev/null 2>&1; then
  if (cd "$W" && npm run build >/tmp/pawdoc_web52.log 2>&1); then
    pass "next build (static export) succeeds with /check"
    if [ -f "$W/out/check/index.html" ] && grep -q 'rel="canonical"' "$W/out/check/index.html"; then
      pass "/check exported as static HTML with SEO metadata"
    else
      fail "/check not exported or missing canonical"
    fi
  else
    fail "next build failed (see /tmp/pawdoc_web52.log)"
  fi
else
  manual "Run 'npm install && npm run build' in web/."
fi

# --- MANUAL ------------------------------------------------------------------
manual "Set TURNSTILE_SECRET_KEY + UPSTASH_* on analyze-anonymous; deploy it (verify_jwt=false)."
manual "Set NEXT_PUBLIC_SUPABASE_URL/ANON_KEY/TURNSTILE_SITE_KEY in Cloudflare Pages; redeploy web."
manual "Set a global AI spend alarm (CR #5/#13). Verify: 4th request/IP -> 429; no token -> 403."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 5.2 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
