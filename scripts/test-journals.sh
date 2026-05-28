#!/usr/bin/env bash
# =============================================================================
# test-journals.sh — verifies the Phase 5.3 health_journals migration:
#   * pets_pending_journal() eligibility (tier + opt-in + idempotency),
#   * RLS row visibility (per-user), and
#   * the RPC/table lockdowns.
# Applies the shim + schema + RLS + the journals migration + the test.
# (The Sunday pg_cron schedule is Supabase-managed; NOT applied here.)
# =============================================================================
set -uo pipefail

IMG="pgvector/pgvector:pg16"
CT="pawdoc-journals-test"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v docker >/dev/null 2>&1 || { echo "docker not available"; exit 1; }
cleanup() { docker rm -f "$CT" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

echo "→ starting $IMG ..."
docker run -d --name "$CT" -e POSTGRES_PASSWORD=postgres -v "$ROOT:/repo:ro" "$IMG" >/dev/null

echo "→ waiting for Postgres full init ..."
ready=0
for _ in $(seq 1 200); do
  if [ "$(docker logs "$CT" 2>&1 | grep -c 'ready to accept connections')" -ge 2 ]; then ready=1; break; fi
done
if [ "$ready" = 1 ]; then
  for _ in $(seq 1 40); do
    docker exec "$CT" psql -U postgres -tAc 'select 1' >/dev/null 2>&1 && break
  done
fi
if [ "$ready" != 1 ]; then
  echo "Postgres never became ready"; docker logs "$CT" 2>&1 | tail -20; exit 1
fi

echo "→ applying shim + migrations + journals test ..."
docker exec -i "$CT" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /repo/supabase/tests/_local_shim.sql \
  -f /repo/supabase/migrations/20260527000000_enable_extensions.sql \
  -f /repo/supabase/migrations/20260527010000_initial_schema.sql \
  -f /repo/supabase/migrations/20260527010001_rls_policies.sql \
  -f /repo/supabase/migrations/20260527070000_health_journals.sql \
  -f /repo/supabase/tests/health_journals.sql
rc=$?

echo "----------------------------------------------------------------"
if [ "$rc" -eq 0 ]; then
  echo "HEALTH JOURNAL: PASS (eligibility + per-user RLS + lockdowns verified)"
else
  echo "HEALTH JOURNAL: FAIL (rc=$rc)"
fi
exit "$rc"
