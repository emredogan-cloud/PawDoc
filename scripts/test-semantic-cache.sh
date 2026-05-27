#!/usr/bin/env bash
# =============================================================================
# test-semantic-cache.sh — verifies the Phase 3.2 semantic-cache RPC against a
# real Postgres + pgvector. Spins an ephemeral pgvector container, applies the
# shim + extensions + schema + RLS + the semantic-cache migration + the safety
# test, then tears down. Proves: same-user/same-species matching, the Dog↛Bird
# species guard, NULL-embedding handling, the similarity threshold, and the
# service-role lockdown. No live Supabase needed.
#
#   ./scripts/test-semantic-cache.sh
# =============================================================================
set -uo pipefail

IMG="pgvector/pgvector:pg16"
CT="pawdoc-semcache-test"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v docker >/dev/null 2>&1 || { echo "docker not available"; exit 1; }
cleanup() { docker rm -f "$CT" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

echo "→ starting $IMG ..."
docker run -d --name "$CT" -e POSTGRES_PASSWORD=postgres -v "$ROOT:/repo:ro" "$IMG" >/dev/null || {
  echo "could not start container"; exit 1; }

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

echo "→ applying shim + migrations + semantic-cache test ..."
docker exec -i "$CT" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /repo/supabase/tests/_local_shim.sql \
  -f /repo/supabase/migrations/20260527000000_enable_extensions.sql \
  -f /repo/supabase/migrations/20260527010000_initial_schema.sql \
  -f /repo/supabase/migrations/20260527010001_rls_policies.sql \
  -f /repo/supabase/migrations/20260527020000_semantic_cache.sql \
  -f /repo/supabase/tests/semantic_cache.sql
rc=$?

echo "----------------------------------------------------------------"
if [ "$rc" -eq 0 ]; then
  echo "SEMANTIC CACHE: PASS (species/user/threshold/NULL guards + lockdown verified)"
else
  echo "SEMANTIC CACHE: FAIL (rc=$rc)"
fi
exit "$rc"
