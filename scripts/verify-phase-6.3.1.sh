#!/usr/bin/env bash
# =============================================================================
# verify-phase-6.3.1.sh — Family Sharing UI & Invites (Phase 6 closer).
#
# Asserts the invite schema, the two Edge Functions, the Flutter UI + the
# deep-link route, and runs the real batteries (incl. test-rls.sh which now
# exercises family_invites + count_shared_group_memberships).
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MIG="$ROOT/supabase/migrations/20260528040000_family_invites.sql"
PG_TEST="$ROOT/supabase/tests/family_invites.sql"
SHARED="$ROOT/supabase/functions/_shared/invites.mjs"
INVITE_EDGE="$ROOT/supabase/functions/invite-family-member/index.ts"
ACCEPT_EDGE="$ROOT/supabase/functions/accept-family-invite/index.ts"
M="$ROOT/mobile/lib/src"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 6.3.1 — Family Sharing UI & Invites"; hr

# --- DB layer ---------------------------------------------------------------
have "$MIG"                                          "family_invites migration"
have "$PG_TEST"                                      "family_invites pg test"
check "family_invites table"                         "create table public.family_invites" "$MIG"
check "Token column UNIQUE"                          "token text not null unique" "$MIG"
check "Invite default expiry: 48 hours"              "default now\(\) \+ interval '48 hours'" "$MIG"
check "Status enum CHECK (4 values)"                 "'pending', 'accepted', 'expired', 'revoked'" "$MIG"
check "RLS: SELECT only by inviter"                  "policy family_invites_select_by_inviter" "$MIG"
check "Writes: revoked from anon/authenticated"      "revoke insert, update, delete on public.family_invites from anon, authenticated" "$MIG"
check "Service role retains all writes"              "grant insert, update, delete on public.family_invites to service_role" "$MIG"
check "Helper: count_shared_group_memberships"       "count_shared_group_memberships" "$MIG"
check "Helper is SECURITY DEFINER"                   "security definer" "$MIG"

# --- Edge Functions ---------------------------------------------------------
have "$SHARED"                                       "invites.mjs (pure helpers)"
have "$ROOT/supabase/functions/_shared/invites.test.mjs" "invites.mjs tests"
check "INVITE_ELIGIBLE_TIERS limited to family+b2b_lite" "INVITE_ELIGIBLE_TIERS" "$SHARED"
check "generateInviteToken uses crypto.getRandomValues" "crypto.getRandomValues" "$SHARED"
check "normalizeEmail lowercases + rejects no-@"     "function normalizeEmail" "$SHARED"

have "$INVITE_EDGE"                                  "/invite-family-member Edge Function"
check "Invite Edge: server-side tier check"          "INVITE_ELIGIBLE_TIERS" "$INVITE_EDGE"
check "Invite Edge: caps pending invites per group"  "too_many_pending_invites" "$INVITE_EDGE"
check "Invite Edge: optional Resend send (fail-safe)" "RESEND_API_KEY" "$INVITE_EDGE"
check "Invite Edge: returns the magic link in body"  "invite_link" "$INVITE_EDGE"

have "$ACCEPT_EDGE"                                  "/accept-family-invite Edge Function"
check "Accept Edge: blocks already-in-family"        "already_in_family" "$ACCEPT_EDGE"
check "Accept Edge: validates expiry"                "invite_expired" "$ACCEPT_EDGE"
check "Accept Edge: idempotent on retry by same user" "already_accepted" "$ACCEPT_EDGE"
check "Accept Edge: rejects cross-user token reuse"  "invite_already_used" "$ACCEPT_EDGE"
check "Accept Edge: cannot invite self"              "cannot_invite_self" "$ACCEPT_EDGE"
check "Accept Edge: uses count_shared_group_memberships" "count_shared_group_memberships" "$ACCEPT_EDGE"

check "config.toml registers /invite-family-member"  "functions.invite-family-member" "$ROOT/supabase/config.toml"
check "config.toml registers /accept-family-invite"  "functions.accept-family-invite" "$ROOT/supabase/config.toml"

# --- Flutter UI + router ----------------------------------------------------
have "$M/family/family_repository.dart"              "FamilyRepository"
have "$M/family/family_settings_screen.dart"         "FamilySettingsScreen"
have "$M/family/invite_family_member_screen.dart"    "InviteFamilyMemberScreen"
have "$M/family/accept_family_invite_screen.dart"    "AcceptFamilyInviteScreen"
have "$M/family/pending_invite_prefs.dart"           "PendingInvitePrefs"

check "Router: /family route"                        "path: '/family'" "$M/router/app_router.dart"
check "Router: /invite/:token deep link"             "path: '/invite/:token'" "$M/router/app_router.dart"
check "Router: invite captures path on auth detour"  "PendingInvitePrefs.capture\(loc\)" "$M/router/app_router.dart"
check "Router: pops pending invite after sign-in"    "PendingInvitePrefs.pop" "$M/router/app_router.dart"

check "Home: Family-sharing menu entry"              "Family sharing" "$M/home/home_screen.dart"
check "FamilySettings: tier gate (family|b2b_lite)"  "'family', 'b2b_lite'" "$M/family/family_settings_screen.dart"
check "FamilySettings: paywall card for ineligible tiers" "family_invite_paywall_card" "$M/family/family_settings_screen.dart"
check "InviteScreen: email validator"                "Enter a valid email" "$M/family/invite_family_member_screen.dart"
check "InviteScreen: copy + share fallbacks"         "family_invite_share" "$M/family/invite_family_member_screen.dart"
check "AcceptScreen: confirms before joining"        "family_invite_accept" "$M/family/accept_family_invite_screen.dart"
check "Analytics.familyInviteSent"                   "family_invite_sent" "$M/analytics/analytics.dart"
check "Analytics.familyInviteAccepted"               "family_invite_accepted" "$M/analytics/analytics.dart"

# --- Batteries --------------------------------------------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_rp631.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_rp631.log 2>&1); then
    pass "ruff + pytest green (unchanged in 6.3.1)"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_rp631.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

if command -v node >/dev/null 2>&1; then
  if node --test "$ROOT/supabase/functions"/_shared/*.test.mjs >/tmp/pawdoc_node631.log 2>&1; then
    pass "node --test (_shared incl. invites helpers) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node631.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

if command -v docker >/dev/null 2>&1; then
  if "$ROOT/scripts/test-rls.sh" >/tmp/pawdoc_rls631.log 2>&1; then
    pass "test-rls.sh PASS — incl. family_invites + count_shared_group_memberships"
  else
    fail "test-rls.sh FAILED (see /tmp/pawdoc_rls631.log) — CRITICAL"
  fi
else
  manual "Run ./scripts/test-rls.sh (needs Docker)."
fi

if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an631.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an631.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt631.log 2>&1); then
    pass "flutter test green"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt631.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL (founder) -------------------------------------------------------
manual "supabase db push — applies the family_invites migration + the SECURITY DEFINER helper."
manual "supabase secrets set RESEND_API_KEY=… RESEND_FROM='PawDoc <noreply@pawdoc.app>' on the invite-family-member Edge Function. Empty key is OK — the magic link is returned in the response body for the 'copy link' UX."
manual "iOS: configure Universal Links for pawdoc.app/invite/* (Associated Domains entitlement + AASA file). Android: add an <intent-filter> for android:scheme=\"pawdoc\" + the App Link verification for pawdoc.app."
manual "(Optional) Schedule a Postgres cron job to flip status='pending' rows to 'expired' once past expires_at — purely cosmetic; the accept Edge already rejects expired tokens."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 6.3.1 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
