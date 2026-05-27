#!/usr/bin/env bash
# =============================================================================
# verify-disclaimers.sh
# Asserts the result disclaimer's PRESENCE is governed by the backend payload
# flag `disclaimer_required` — forced server-side and surfaced via the API
# contract — NOT a removable, hardcoded-only UI decision.
#   (Roadmap §1.4: "disclaimers injected at the API level, not removable by UI".)
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fails=0
pass() { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail() { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
hr()   { printf -- '----------------------------------------------------------------\n'; }
check() { if grep -q "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }

hr; echo "Disclaimer source verification (API-injected, not UI-hardcoded)"; hr

# 1. Backend FORCES the flag on every result (cannot be turned off downstream).
check "AI pipeline forces disclaimer_required at the API level" \
  '"disclaimer_required": True' "$ROOT/ai-service/app/pipeline.py"
check "AnalysisResult (Pydantic) defaults disclaimer_required to True" \
  'disclaimer_required: bool = True' "$ROOT/ai-service/app/models.py"

# 2. The flag travels on the PAYLOAD and the Dart client PARSES it (not a constant).
check "Dart AnalysisResult parses disclaimer_required from the JSON payload" \
  "json\['disclaimer_required'\]" "$ROOT/mobile/lib/src/models/analysis_result.dart"

# 3. The UI GATES the disclaimer on the payload flag (so a UI change can't remove it
#    while the backend still requires it).
check "standard result screen gates the disclaimer on the payload flag" \
  'r.disclaimerRequired' "$ROOT/mobile/lib/src/analysis/result_screen.dart"
check "emergency result screen gates the disclaimer on the payload flag" \
  'r.disclaimerRequired' "$ROOT/mobile/lib/src/analysis/emergency_result_screen.dart"

# 4. Guard: the disclaimer must not be a stray always-on UI string. We assert the
#    disclaimer copy in the result screen sits inside a disclaimerRequired guard by
#    checking the flag is referenced at least as many times as the disclaimer copy.
copy_count=$(grep -c 'not a veterinary diagnosis' "$ROOT/mobile/lib/src/analysis/result_screen.dart" 2>/dev/null || echo 0)
flag_count=$(grep -c 'disclaimerRequired' "$ROOT/mobile/lib/src/analysis/result_screen.dart" 2>/dev/null || echo 0)
if [ "$flag_count" -ge "$copy_count" ] && [ "$flag_count" -ge 1 ]; then
  pass "disclaimer copy is gated by the flag (flag refs $flag_count >= copy $copy_count)"
else
  fail "disclaimer copy may be shown unconditionally (flag $flag_count < copy $copy_count)"
fi

hr
if [ "$fails" -eq 0 ]; then
  echo "Disclaimers are API-injected (backend-forced flag, payload-driven, UI-gated)."; exit 0
else
  echo "$fails check(s) FAILED — disclaimer is not strictly API-governed."; exit 1
fi
