#!/usr/bin/env bash
# =============================================================================
# test-rls.sh — verifies the RLS policies (CR #2) against a real Postgres.
# Spins an ephemeral pgvector container, applies the local shim + the actual
# migrations + the isolation test, then tears down. No live Supabase needed.
#
#   ./scripts/test-rls.sh
# =============================================================================
set -uo pipefail

IMG="pgvector/pgvector:pg16"
CT="pawdoc-rls-test"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v docker >/dev/null 2>&1 || { echo "docker not available"; exit 1; }
cleanup() { docker rm -f "$CT" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

echo "→ starting $IMG ..."
docker run -d --name "$CT" -e POSTGRES_PASSWORD=postgres -v "$ROOT:/repo:ro" "$IMG" >/dev/null || {
  echo "could not start container"; exit 1; }

echo "→ waiting for Postgres full init (the real server, not the init-phase one) ..."
# The official image starts a temp server for initdb, then restarts the real
# one. Wait for the SECOND "ready to accept connections", then confirm a query.
ready=0
for _ in $(seq 1 200); do
  if [ "$(docker logs "$CT" 2>&1 | grep -c 'ready to accept connections')" -ge 2 ]; then ready=1; break; fi
done
if [ "$ready" = 1 ]; then
  for _ in $(seq 1 40); do
    docker exec "$CT" psql -U postgres -tAc 'select 1' >/dev/null 2>&1 && break
  done
fi
[ "$ready" = 1 ] || { echo "Postgres never became ready"; docker logs "$CT" 2>&1 | tail -20; exit 1; }

echo "→ applying shim + ALL migrations + RLS/cascade tests ..."
# RLS-02/INF-04 fix: apply EVERY migration in order — a curated subset once let
# a deletion-blocking FK (RLS-01) ship unverified. The glob is lexicographic,
# which matches the timestamped filename order Supabase itself applies.
MIGRATION_ARGS=()
for m in "$ROOT"/supabase/migrations/*.sql; do
  # pg_cron/pg_net are Supabase-managed and don't exist in the local image; the
  # *_schedule_*_cron migrations contain ONLY job registrations (no schema), so
  # they are the one class the harness may skip. Everything else must apply.
  case "$(basename "$m")" in
    *_schedule_*cron*.sql) continue ;;
  esac
  MIGRATION_ARGS+=(-f "/repo/supabase/migrations/$(basename "$m")")
done
docker exec -i "$CT" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /repo/supabase/tests/_local_shim.sql \
  "${MIGRATION_ARGS[@]}" \
  -f /repo/supabase/tests/rls_isolation.sql \
  -f /repo/supabase/tests/followup.sql \
  -f /repo/supabase/tests/accuracy_views.sql \
  -f /repo/supabase/tests/account_deletion.sql
rc=$?

echo "----------------------------------------------------------------"
if [ "$rc" -eq 0 ]; then
  echo "RLS ISOLATION: PASS (CR #2 verified — cross-user read/write blocked)"
else
  echo "RLS ISOLATION: FAIL (rc=$rc)"
fi
exit "$rc"
