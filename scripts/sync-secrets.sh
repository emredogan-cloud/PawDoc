#!/usr/bin/env bash
# GAP-D3 — sync secrets from Doppler (the source of truth) to Fly + Supabase,
# with a digest diff and a hard guard, so the manual copy-paste that caused the
# June outage becomes one auditable command.
#
#   scripts/sync-secrets.sh --check        # report drift only; exit 1 if any
#   PAWDOC_PROD_DEPLOY=1 scripts/sync-secrets.sh   # actually push (guarded)
#
# Founder-run (needs Doppler/Fly/Supabase auth + prod access). Values are never
# printed — only 16-char SHA-256 digests are shown for the drift report.
set -euo pipefail

DOPPLER_PROJECT="${DOPPLER_PROJECT:-pawdoc}"
DOPPLER_CONFIG="${DOPPLER_CONFIG:-prd}"
FLY_APP="${FLY_APP:-pawdoc-ai}"
SUPABASE_REF="${SUPABASE_REF:-}"

# Explicit per-target allowlists — never blast every secret at every service.
FLY_KEYS="AI_SERVICE_TOKEN ANTHROPIC_API_KEY GOOGLE_AI_API_KEY OPENAI_API_KEY \
SENTRY_DSN UPSTASH_REDIS_REST_URL UPSTASH_REDIS_REST_TOKEN \
R2_ACCOUNT_ID R2_BUCKET R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY"

SUPABASE_KEYS="AI_SERVICE_TOKEN R2_ACCOUNT_ID R2_BUCKET R2_ACCESS_KEY_ID \
R2_SECRET_ACCESS_KEY REVENUECAT_WEBHOOK_SECRET CRON_SECRET RESEND_API_KEY"

mode="push"
if [ "${1:-}" = "--check" ]; then
  mode="check"
fi

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" >&2
    exit 2
  fi
}

digest() {
  # 16-char digest of stdin (never prints the value).
  sha256sum | cut -c1-16
}

doppler_digest() {
  # $1 = key. Empty digest if the secret is absent.
  local v
  v="$(doppler secrets get "$1" --project "$DOPPLER_PROJECT" \
        --config "$DOPPLER_CONFIG" --plain 2>/dev/null || true)"
  if [ -z "$v" ]; then
    echo "<absent>"
  else
    printf '%s' "$v" | digest
  fi
}

report_drift() {
  local target="$1"
  shift
  echo "== $target (doppler:$DOPPLER_PROJECT/$DOPPLER_CONFIG) =="
  local k
  for k in "$@"; do
    printf '  %-28s %s\n' "$k" "$(doppler_digest "$k")"
  done
}

need doppler

if [ "$mode" = "check" ]; then
  echo "Drift report — digests only, no writes."
  # shellcheck disable=SC2086
  report_drift "Fly ($FLY_APP)" $FLY_KEYS
  # shellcheck disable=SC2086
  report_drift "Supabase ($SUPABASE_REF)" $SUPABASE_KEYS
  echo "Re-run with PAWDOC_PROD_DEPLOY=1 (no --check) to push to the targets."
  exit 0
fi

if [ "${PAWDOC_PROD_DEPLOY:-}" != "1" ]; then
  echo "Refusing to write prod secrets without PAWDOC_PROD_DEPLOY=1." >&2
  echo "Run 'scripts/sync-secrets.sh --check' first to review drift." >&2
  exit 1
fi

need fly
need supabase

echo "Pushing Fly secrets ($FLY_APP)…"
# shellcheck disable=SC2086
doppler run --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" -- \
  bash -c 'for k in '"$FLY_KEYS"'; do v="${!k:-}"; [ -n "$v" ] && printf "%s=%s\n" "$k" "$v"; done' \
  | fly secrets import --app "$FLY_APP"

echo "Pushing Supabase secrets (${SUPABASE_REF:-linked project})…"
ref_arg=""
if [ -n "$SUPABASE_REF" ]; then
  ref_arg="--project-ref $SUPABASE_REF"
fi
# shellcheck disable=SC2086
doppler run --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" -- \
  bash -c 'for k in '"$SUPABASE_KEYS"'; do v="${!k:-}"; [ -n "$v" ] && printf "%s=%s\n" "$k" "$v"; done' \
  | supabase secrets set $ref_arg --env-file /dev/stdin

echo "Done. Re-run with --check to confirm no drift remains."
