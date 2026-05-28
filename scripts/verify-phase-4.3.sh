#!/usr/bin/env bash
# =============================================================================
# verify-phase-4.3.sh — Web Presence & Paid Acquisition (Phase 4.3).
# Structural checks (static-export config, landing page, MDX blog + SEO metadata,
# paid-acquisition runbook) and — when deps are installed — a REAL `next build`
# static export, asserting the article HTML carries a canonical link.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$ROOT/web"
ART_MDX="$W/app/blog/when-to-take-your-dog-to-the-vet-for-vomiting/page.mdx"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qiE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 4.3 — Web Presence & Paid Acquisition"; hr

# --- Files present -----------------------------------------------------------
have "$W/package.json"                    "web package.json"
have "$W/next.config.mjs"                 "Next config"
have "$W/mdx-components.tsx"              "MDX components (App Router)"
have "$W/app/layout.tsx"                  "Root layout (+ metadataBase)"
have "$W/app/page.tsx"                    "Landing page"
have "$W/app/blog/page.tsx"               "Blog index"
have "$ART_MDX"                           "SEO article (MDX)"
have "$W/README.md"                       "Cloudflare Pages deploy README"
have "$ROOT/docs/runbooks/20-paid-acquisition.md" "Paid-acquisition runbook"

# --- Static export config (no Node server) -----------------------------------
check "Static export: output: 'export'"   "output: \"export\"" "$W/next.config.mjs"
check "images unoptimized (export-safe)"   'unoptimized: true' "$W/next.config.mjs"
check "MDX pages enabled"                   'mdx' "$W/next.config.mjs"
check "README documents Pages (build/output dir)" 'Build output directory' "$W/README.md"

# --- Landing page ------------------------------------------------------------
check "Landing: value prop above the fold" 'Know when to call the vet' "$W/app/page.tsx"
check "Landing: App Store badge"           'Download on the App Store' "$W/app/page.tsx"
check "Landing: Google Play badge"         'Get it on Google Play' "$W/app/page.tsx"
check "Landing: social proof / testimonials" 'testimonials' "$W/app/page.tsx"

# --- MDX article SEO ---------------------------------------------------------
check "Article exports metadata"           'export const metadata' "$ART_MDX"
check "Article has a canonical URL"         'canonical' "$ART_MDX"
check "Article has a description"           'description:' "$ART_MDX"
# phrase is hard-wrapped in the MDX, so normalize newlines before matching
if tr '\n' ' ' < "$ART_MDX" | grep -qi 'a veterinary diagnosis'; then
  pass "Article keeps the not-a-diagnosis framing"
else
  fail "Article missing the not-a-diagnosis framing"
fi

# --- Paid-acquisition runbook ------------------------------------------------
check "Runbook: Apple Search Ads"          'Apple Search Ads' "$ROOT/docs/runbooks/20-paid-acquisition.md"
check "Runbook: 5 exact-match keywords"    'exact-match' "$ROOT/docs/runbooks/20-paid-acquisition.md"
check "Runbook: TikTok 500 hard cap"        '500 hard cap' "$ROOT/docs/runbooks/20-paid-acquisition.md"
check "Runbook: CPI / LTV:CAC in PostHog"  'LTV:CAC' "$ROOT/docs/runbooks/20-paid-acquisition.md"

# --- Real static build (when deps installed) ---------------------------------
if [ -d "$W/node_modules" ] && command -v npm >/dev/null 2>&1; then
  if (cd "$W" && npm run build >/tmp/pawdoc_web43.log 2>&1); then
    pass "next build (static export) succeeds"
    art="$W/out/blog/when-to-take-your-dog-to-the-vet-for-vomiting/index.html"
    if [ -f "$art" ] && grep -q 'rel="canonical"' "$art"; then
      pass "exported article HTML has a canonical link (SEO renders)"
    else
      fail "exported article missing or has no canonical link"
    fi
  else
    fail "next build failed (see /tmp/pawdoc_web43.log)"
  fi
else
  manual "Run 'npm install && npm run build' in web/ (node_modules not present here)."
fi

# --- MANUAL (founder) --------------------------------------------------------
manual "Deploy web/ to Cloudflare Pages (build 'npm run build', output 'out', root 'web')."
manual "Verify Google Search Console for pawdoc.app; drop real screenshots/badges + store URLs."
manual "Write the remaining SEO articles (content task) — one ships here to prove the infra."
manual "Run the Apple Search Ads + TikTok test per runbook 20; gate scaling on LTV:CAC > 3."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 4.3 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
