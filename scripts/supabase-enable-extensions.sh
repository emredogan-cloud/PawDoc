#!/usr/bin/env bash
# =============================================================================
# supabase-enable-extensions.sh  —  Phase 0.2
# Applies the canonical extensions migration (pgvector + uuid-ossp) to each
# Supabase project via the Management API query endpoint. Idempotent
# (`create extension if not exists`).
#
# This is a convenience for flipping extensions on immediately in 0.2. The
# migration file remains the source of truth and is also applied by
# `supabase db push` during Phase 1.1.
#
# Needs a Supabase personal access token:
#   https://supabase.com/dashboard/account/tokens
#   export SUPABASE_ACCESS_TOKEN=sbp_...
#
# Usage (project refs = the 20-char id in the dashboard URL):
#   ./scripts/supabase-enable-extensions.sh <dev-ref> <prod-ref> <eu-ref>
#   # or set SUPABASE_PROJECT_REFS="ref1 ref2 ref3"
# =============================================================================
set -euo pipefail

TOKEN="${SUPABASE_ACCESS_TOKEN:?set SUPABASE_ACCESS_TOKEN (dashboard → Account → Access Tokens)}"
REFS=("$@")
if [ ${#REFS[@]} -eq 0 ]; then read -r -a REFS <<< "${SUPABASE_PROJECT_REFS:-}"; fi
[ ${#REFS[@]} -gt 0 ] || { echo "Provide project refs as args or via SUPABASE_PROJECT_REFS."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="$(ls "$SCRIPT_DIR/../supabase/migrations/"*_enable_extensions.sql 2>/dev/null | head -1)"
[ -n "${SQL_FILE:-}" ] || { echo "Could not find *_enable_extensions.sql migration."; exit 1; }

# Encode the SQL as a JSON {"query": "..."} body without relying on jq.
BODY="$(python3 -c 'import json,sys; print(json.dumps({"query": sys.stdin.read()}))' < "$SQL_FILE")"

for ref in "${REFS[@]}"; do
  echo "→ enabling extensions on project: $ref"
  curl -fsS -X POST "https://api.supabase.com/v1/projects/$ref/database/query" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    --data "$BODY" >/dev/null
  echo "  ✓ uuid-ossp + vector enabled"
done

echo "Done. Confirm with ./scripts/verify-phase-0.2.sh (SUPABASE_ACCESS_TOKEN + refs set)."
