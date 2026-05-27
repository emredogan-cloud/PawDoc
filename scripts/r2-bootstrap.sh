#!/usr/bin/env bash
# =============================================================================
# r2-bootstrap.sh  —  Phase 0.2
# Creates the dev + prod Cloudflare R2 buckets and applies the CORS policy
# (infra/r2-cors.json) via the S3-compatible API. Idempotent.
#
# Needs R2 S3 credentials (create an R2 API token: see docs/runbooks/07).
# Easiest: pull them from Doppler at runtime —
#   doppler run --project pawdoc --config dev -- ./scripts/r2-bootstrap.sh
# or export manually:
#   export R2_ACCOUNT_ID=... R2_ACCESS_KEY_ID=... R2_SECRET_ACCESS_KEY=...
# =============================================================================
set -euo pipefail

ACCOUNT_ID="${R2_ACCOUNT_ID:?set R2_ACCOUNT_ID (Cloudflare → R2 → Account ID)}"
ENDPOINT="${R2_ENDPOINT:-https://${ACCOUNT_ID}.r2.cloudflarestorage.com}"
export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:?set R2_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:?set R2_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="auto"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORS_FILE="$SCRIPT_DIR/../infra/r2-cors.json"
BUCKETS=("${R2_BUCKET_DEV:-pawdoc-uploads-dev}" "${R2_BUCKET_PROD:-pawdoc-uploads-prod}")

command -v aws >/dev/null 2>&1 || { echo "aws CLI not found (needed for the R2 S3 API)."; exit 1; }
[ -f "$CORS_FILE" ] || { echo "Missing $CORS_FILE"; exit 1; }

s3() { aws s3api "$@" --endpoint-url "$ENDPOINT"; }

for b in "${BUCKETS[@]}"; do
  echo "→ bucket: $b"
  if s3 head-bucket --bucket "$b" >/dev/null 2>&1; then
    echo "  · already exists"
  else
    s3 create-bucket --bucket "$b" >/dev/null
    echo "  ✓ created"
  fi
  s3 put-bucket-cors --bucket "$b" --cors-configuration "file://$CORS_FILE" >/dev/null
  echo "  ✓ CORS applied (origins: pawdoc.app + localhost; methods: GET/PUT/HEAD)"
done

echo "Done. Verify a real browser-origin preflight with ./scripts/verify-phase-0.2.sh"
echo "Reminder: client uploads use presigned PUT URLs (Phase 1.2) — never ship these keys."
