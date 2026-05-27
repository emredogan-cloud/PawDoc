#!/usr/bin/env bash
# =============================================================================
# verify-phase-3.3b.sh — Engagement, Reminders & Push (Phase 3.3 Part 2).
# Structural checks (cron query funcs + lockdowns, the pg_cron schedule, the
# secret-header guard, timezone handling, reminders CRUD, analytics) plus the
# real batteries: node --test, the engagement pg test + RLS test (Docker),
# ruff/pytest, flutter analyze/test. Applying the pg_cron migration + live
# OneSignal sending are founder/Supabase-side (MANUAL).
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGA="$ROOT/supabase/migrations/20260527040000_reminders_engagement.sql"
MIGB="$ROOT/supabase/migrations/20260527040001_schedule_reminders_cron.sql"
FN="$ROOT/supabase/functions"
M="$ROOT/mobile/lib/src"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qiE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 3.3 Part 2 — Engagement, Reminders & Push"; hr

# --- Files present -----------------------------------------------------------
have "$MIGA"                              "Engagement migration (funcs + column)"
have "$MIGB"                              "pg_cron schedule migration"
have "$ROOT/supabase/tests/reminders.sql" "Engagement pg test"
have "$ROOT/scripts/test-reminders.sh"    "Engagement test harness"
have "$FN/process-reminders/index.ts"     "/process-reminders Edge Function"
have "$FN/_shared/reminders.mjs"          "Push helpers"
have "$M/reminders/reminder.dart"         "Flutter Reminder model"
have "$M/reminders/reminders_screen.dart" "Flutter reminders screen"

# --- Cron query funcs + no-spam + timezone -----------------------------------
check "due_reminders() defined"                'function public.due_reminders' "$MIGA"
check "users_to_reengage() defined"            'function public.users_to_reengage' "$MIGA"
check "Timezone: due compared in UTC"          "now\(\) at time zone 'utc'" "$MIGA"
check "No-spam column last_reengagement_sent_at" 'last_reengagement_sent_at' "$MIGA"
check "Re-engage respects the cooldown"        'cooldown_days' "$MIGA"
check "Cron funcs locked to service_role"      'grant execute on function' "$MIGA"
check "Cron funcs revoked from clients"        'revoke all on function' "$MIGA"

# --- pg_cron / pg_net schedule (founder-applied) -----------------------------
check "pg_cron enabled"                        'create extension if not exists pg_cron' "$MIGB"
check "pg_net enabled"                         'create extension if not exists pg_net' "$MIGB"
check "Hourly cron schedule (0 * * * *)"       "'0 \* \* \* \*'" "$MIGB"
check "Calls /process-reminders"               '/functions/v1/process-reminders' "$MIGB"
check "Secret + URL from Vault (no committed secret)" 'vault.decrypted_secrets' "$MIGB"
check "Sends the x-cron-secret header"         'x-cron-secret' "$MIGB"

# --- Edge Function security + behavior ---------------------------------------
check "Edge verifies the cron secret"          'cronSecretValid' "$FN/process-reminders/index.ts"
check "Edge processes due reminders"           'rpc\("due_reminders"' "$FN/process-reminders/index.ts"
check "Edge processes re-engagement"           'rpc\("users_to_reengage"' "$FN/process-reminders/index.ts"
check "Edge marks reminders sent"              'is_sent: true' "$FN/process-reminders/index.ts"
check "Edge stamps last_reengagement_sent_at"  'last_reengagement_sent_at' "$FN/process-reminders/index.ts"
check "Edge pushes via OneSignal"              'onesignal.com/api/v1/notifications' "$FN/process-reminders/index.ts"
check "Secret guard fails closed (empty -> reject)" 'length === 0' "$FN/_shared/reminders.mjs"
check "process-reminders is verify_jwt=false"  '\[functions.process-reminders\]' "$ROOT/supabase/config.toml"

# --- Flutter CRUD + analytics ------------------------------------------------
check "Reminders write to the reminders table" "from\('reminders'\)" "$M/reminders/reminders_repository.dart"
check "Reminder form sets a due_date"          'due_date' "$M/reminders/reminder.dart"
check "Analytics: reminder_set"                'reminder_set' "$M/analytics/analytics.dart"
check "History screen opens reminders"         'open_reminders' "$M/health/history_timeline_screen.dart"

# --- node --test -------------------------------------------------------------
if command -v node >/dev/null 2>&1; then
  if node --test "$FN"/_shared/*.test.mjs >/tmp/pawdoc_node33b.log 2>&1; then
    pass "node --test (_shared) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node33b.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

# --- pg tests (Docker) -------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  if "$ROOT/scripts/test-reminders.sh" >/tmp/pawdoc_rem33b.log 2>&1; then
    pass "engagement pg test green (due_reminders + users_to_reengage + lockdown)"
  else
    fail "engagement pg test failed (see /tmp/pawdoc_rem33b.log)"
  fi
  if "$ROOT/scripts/test-rls.sh" >/tmp/pawdoc_rls33b.log 2>&1; then
    pass "RLS test green (incl. reminders insert controls)"
  else
    fail "RLS test failed (see /tmp/pawdoc_rls33b.log)"
  fi
else
  manual "Run ./scripts/test-reminders.sh and ./scripts/test-rls.sh (need Docker)."
fi

# --- AI service (unaffected; run for safety) ---------------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_rp33b.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_rp33b.log 2>&1); then
    pass "ruff + pytest green"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_rp33b.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

# --- Flutter -----------------------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an33b.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an33b.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt33b.log 2>&1); then
    pass "flutter test green"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt33b.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL (founder / live infra) -------------------------------------------
manual "Apply the pg_cron schedule migration on Supabase (pg_cron + pg_net + Vault present there)."
manual "Set CRON_SECRET (Edge) + Vault secrets project_url & cron_secret to the SAME secret."
manual "Set ONESIGNAL_APP_ID + ONESIGNAL_REST_API_KEY (Fly/Doppler) for live sends; verify a test push."
manual "Deno typecheck of process-reminders (supabase CI) — deno not run here."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 3.3 Part 2 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
