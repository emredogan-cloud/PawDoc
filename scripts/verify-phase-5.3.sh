#!/usr/bin/env bash
# =============================================================================
# verify-phase-5.3.sh — AI Health Journal (Phase 5.3).
# Asserts the journal pipeline is resilient (OpenAI provider fails to None) and
# the cron Edge Function handles batching/per-pet failure safely. Runs the real
# batteries: pytest + node + journals pg test (Docker) + flutter analyze/test.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI="$ROOT/ai-service/app"
MIG="$ROOT/supabase/migrations/20260527070000_health_journals.sql"
MIG_CRON="$ROOT/supabase/migrations/20260527070001_schedule_generate_journals_cron.sql"
EDGE="$ROOT/supabase/functions/generate-journals/index.ts"
MJS="$ROOT/supabase/functions/_shared/journal.mjs"
M="$ROOT/mobile/lib/src"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qiE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 5.3 — AI Health Journal"; hr

# --- DB layer ----------------------------------------------------------------
have "$MIG"                                "health_journals migration"
have "$MIG_CRON"                           "weekly cron schedule migration"
have "$ROOT/supabase/tests/health_journals.sql" "journals pg test"
have "$ROOT/scripts/test-journals.sh"      "journals test harness"

check "health_journals UNIQUE (pet_id, week_start_date) (idempotent cron)" 'unique \(pet_id, week_start_date\)' "$MIG"
check "RLS: SELECT-only for clients"       'health_journals_select_own' "$MIG"
check "client writes revoked"              'revoke insert, update, delete on public.health_journals' "$MIG"
check "pets.is_journal_enabled added"      'is_journal_enabled' "$MIG"
check "RPC: tier + opt-in + idempotent filter" 'subscription_status in' "$MIG"
check "RPC locked to service_role"         'grant execute on function' "$MIG"
check "Cron schedule (Sunday 00:00 UTC)"    "'0 0 \* \* 0'" "$MIG_CRON"
check "Cron secret/url from Vault"          'vault.decrypted_secrets' "$MIG_CRON"

# --- AI service: OpenAI integration (resilient) ------------------------------
have "$AI/journal.py"                      "Journal pipeline"
have "$ROOT/ai-service/tests/test_journal.py" "Journal pytest"
check "OPENAI_MODEL pinned (CR #17)"        'OPENAI_MODEL' "$AI/config.py"
check "OPENAI_API_KEY env"                  'OPENAI_API_KEY' "$AI/config.py"
check "openai dep present (lazy import)"    'openai' "$ROOT/ai-service/requirements.txt"
check "Anti-hallucination: DO NOT diagnose" 'DO NOT diagnose' "$AI/journal.py"
check "Anti-hallucination: DO NOT override" 'DO NOT override' "$AI/journal.py"
check "Resilient: returns None on any error" 'return None' "$AI/journal.py"
check "/generate_journal endpoint"          '/generate_journal' "$AI/main.py"

# --- Edge Function: secret + batching + per-pet try/catch --------------------
have "$EDGE"                               "/generate-journals Edge Function"
check "Edge verifies the cron secret"      'cronSecretValid' "$EDGE"
check "verify_jwt = false for the cron fn" '\[functions.generate-journals\]' "$ROOT/supabase/config.toml"
check "Edge calls eligibility RPC"          'pets_pending_journal' "$EDGE"
check "Edge calls /generate_journal"        '/generate_journal' "$EDGE"
check "Concurrency batching"                'CONCURRENCY' "$EDGE"
check "Soft deadline under 60s Edge cap"    'DEADLINE_MS' "$EDGE"
check "Per-pet try/catch (one failure can't block others)" 'processOne' "$EDGE"
check "Idempotent insert (UNIQUE handled)"  '23505' "$EDGE"

# --- Edge shared helpers + node tests ----------------------------------------
have "$MJS"                                "journal.mjs (date + summarizer helpers)"
have "${MJS%.mjs}.test.mjs"                "journal.test.mjs"
check "mondayOfWeekUtc"                    'mondayOfWeekUtc' "$MJS"

# --- Flutter UI + opt-in + analytics -----------------------------------------
check "Pet.isJournalEnabled field"          'isJournalEnabled' "$M/pets/pet.dart"
check "Pet toColumns includes is_journal_enabled" "'is_journal_enabled'" "$M/pets/pet.dart"
check "Pet form has the journal opt-in toggle" 'pet_journal_toggle' "$M/pets/pet_form_screen.dart"
have "$M/health/journal.dart"              "Flutter Journal model"
have "$M/health/journal_repository.dart"   "Flutter journal repository"
have "$M/health/journal_card.dart"         "Journal card (latest narrative)"
have "$M/health/journals_screen.dart"      "Journals list screen"
check "Health History shows the journal card" 'JournalCard' "$M/health/history_timeline_screen.dart"
check "Analytics: journal_viewed"          'journal_viewed' "$M/analytics/analytics.dart"

# --- Batteries ---------------------------------------------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_rp53.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_rp53.log 2>&1); then
    pass "ruff + pytest green"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_rp53.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

if command -v node >/dev/null 2>&1; then
  if node --test "$ROOT/supabase/functions"/_shared/*.test.mjs >/tmp/pawdoc_node53.log 2>&1; then
    pass "node --test (_shared incl. journal helpers) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node53.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

if command -v docker >/dev/null 2>&1; then
  if "$ROOT/scripts/test-journals.sh" >/tmp/pawdoc_jpg53.log 2>&1; then
    pass "journals pg test green (eligibility + RLS + lockdown)"
  else
    fail "journals pg test failed (see /tmp/pawdoc_jpg53.log)"
  fi
else
  manual "Run ./scripts/test-journals.sh (needs Docker)."
fi

if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an53.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an53.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt53.log 2>&1); then
    pass "flutter test green"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt53.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL (founder) --------------------------------------------------------
manual "Set OPENAI_API_KEY on the AI service (Fly). Set a BILLING ALARM on the key."
manual "Apply the weekly cron migration on Supabase; deploy /generate-journals; reuse the existing CRON_SECRET + Vault secrets (runbook 18/21)."
manual "On device: toggle the journal opt-in on a Premium/Family pet; verify a narrative appears the following Sunday."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 5.3 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
