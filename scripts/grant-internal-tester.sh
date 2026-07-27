#!/usr/bin/env bash
# Grant (or revoke) PawDoc's permanent internal-QA premium status.
#
# Premium normally comes from a RevenueCat purchase, which the webhook writes
# into users.subscription_status. This script writes the one exception:
# `internal_tester`, a service-role-only status that every premium gate accepts
# (supabase/functions/_shared/premium.mjs + the client mirror in
# mobile/lib/src/account/user_profile.dart).
#
# It is not a bypass. `authenticated` holds no UPDATE grant on public.users, so
# no client can award this to itself; only the service role — i.e. this script,
# run by the founder — can. The purchase flow is untouched for every other user.
#
#   doppler run -p pawdoc -c dev -- ./scripts/grant-internal-tester.sh grant  test.tester@pawdoc.app
#   doppler run -p pawdoc -c dev -- ./scripts/grant-internal-tester.sh revoke test.tester@pawdoc.app
#   doppler run -p pawdoc -c dev -- ./scripts/grant-internal-tester.sh status test.tester@pawdoc.app
#
# Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment.
set -euo pipefail

ACTION="${1:-status}"
EMAIL="${2:-test.tester@pawdoc.app}"
STATUS_VALUE="internal_tester"

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
  echo "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set (use: doppler run -- ...)" >&2
  exit 1
fi

auth_hdrs=(-H "apikey: $SUPABASE_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY")

find_uid() {
  # The admin list endpoint has no email filter, so page through it.
  local page=1
  while [ "$page" -le 20 ]; do
    local body
    body=$(curl -sS "$SUPABASE_URL/auth/v1/admin/users?page=$page&per_page=200" "${auth_hdrs[@]}")
    local hit
    hit=$(printf '%s' "$body" | EMAIL="$EMAIL" python3 -c '
import json, os, sys
users = json.load(sys.stdin).get("users", [])
if not users:
    sys.exit(0)
target = os.environ["EMAIL"].lower()
for u in users:
    if (u.get("email") or "").lower() == target:
        print(u["id"]); break
else:
    print("__MORE__")
')
    case "$hit" in
      "") return 1 ;;
      __MORE__) page=$((page + 1)) ;;
      *) printf '%s' "$hit"; return 0 ;;
    esac
  done
  return 1
}

show_status() {
  local uid="$1"
  curl -sS "$SUPABASE_URL/rest/v1/users?select=id,subscription_status&id=eq.$uid" "${auth_hdrs[@]}" \
    | python3 -c '
import json, sys
rows = json.load(sys.stdin)
if not rows:
    print("  no public.users row (the signup trigger creates it on first sign-in)")
else:
    print("  subscription_status =", rows[0]["subscription_status"])
'
}

set_status() {
  local uid="$1" value="$2"
  curl -sS -o /dev/null -w "  write -> HTTP %{http_code}\n" \
    -X PATCH "$SUPABASE_URL/rest/v1/users?id=eq.$uid" \
    "${auth_hdrs[@]}" -H "Content-Type: application/json" \
    -d "{\"subscription_status\":\"$value\"}"
}

UID_FOUND=$(find_uid) || { echo "No auth user for $EMAIL — create it first." >&2; exit 1; }
echo "$EMAIL -> $UID_FOUND"

case "$ACTION" in
  grant)
    set_status "$UID_FOUND" "$STATUS_VALUE"
    show_status "$UID_FOUND"
    ;;
  revoke)
    set_status "$UID_FOUND" "free"
    show_status "$UID_FOUND"
    ;;
  status)
    show_status "$UID_FOUND"
    ;;
  *)
    echo "usage: $0 {grant|revoke|status} [email]" >&2
    exit 1
    ;;
esac
