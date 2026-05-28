#!/usr/bin/env bash
# =============================================================================
# test-accuracy-views.sh — verifies the Phase 6.2 accuracy_views migration.
#   * outcome CHECK constraint rejects junk values,
#   * view_accuracy_signals classifies FP / FN / TP / TN correctly,
#   * the summary view counts those classes,
#   * anon + authenticated cannot SELECT the views (lockdown).
# Applies the shim + schema + RLS + the accuracy_views migration + the test.
# =============================================================================
set -uo pipefail

IMG="pgvector/pgvector:pg16"
CT="pawdoc-accuracy-views-test"
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

echo "→ applying shim + migrations + accuracy_views test ..."
docker exec -i "$CT" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /repo/supabase/tests/_local_shim.sql \
  -f /repo/supabase/migrations/20260527000000_enable_extensions.sql \
  -f /repo/supabase/migrations/20260527010000_initial_schema.sql \
  -f /repo/supabase/migrations/20260527010001_rls_policies.sql \
  -f /repo/supabase/migrations/20260528020000_accuracy_views.sql \
  -f /repo/supabase/tests/accuracy_views.sql
rc=$?

echo "----------------------------------------------------------------"
if [ "$rc" -eq 0 ]; then
  echo "ACCURACY VIEWS: PASS (CHECK + FP/FN/TP/TN classification + lockdown verified)"
else
  echo "ACCURACY VIEWS: FAIL (rc=$rc)"
fi
exit "$rc"
