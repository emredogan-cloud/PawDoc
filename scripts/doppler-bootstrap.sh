#!/usr/bin/env bash
# =============================================================================
# doppler-bootstrap.sh  —  Phase 0.1
# Creates the `pawdoc` Doppler project, its dev + prod configs, and every
# Phase 0.1 secret slot as a PLACEHOLDER. Idempotent and non-destructive:
#   - never overwrites a slot that already has a value (real or placeholder)
#   - safe to re-run any time
#
# Prerequisite (run yourself, it is interactive):
#   doppler login
#
# Usage:
#   ./scripts/doppler-bootstrap.sh
# =============================================================================
set -euo pipefail

PROJECT="${DOPPLER_PROJECT:-pawdoc}"
# Doppler's default prod root config is `prd`. Override with DOPPLER_CONFIGS if needed.
read -r -a CONFIGS <<< "${DOPPLER_CONFIGS:-dev prd}"

# slot name -> human hint stored as the placeholder value
declare -A SLOTS=(
  [SUPABASE_URL]="SET_IN_PHASE_0.2"
  [SUPABASE_ANON_KEY]="SET_IN_PHASE_0.2"
  [SUPABASE_SERVICE_ROLE_KEY]="SET_IN_PHASE_0.2"
  [SUPABASE_JWT_SECRET]="SET_IN_PHASE_0.2"
  [SUPABASE_DB_URL]="SET_IN_PHASE_0.2"
  [ANTHROPIC_API_KEY]="SET_IN_PHASE_0.2_OR_0.3"
  [GOOGLE_AI_API_KEY]="SET_IN_PHASE_0.2_OR_0.3"
  [R2_ACCOUNT_ID]="SET_IN_PHASE_0.2"
  [R2_ACCESS_KEY_ID]="SET_IN_PHASE_0.2"
  [R2_SECRET_ACCESS_KEY]="SET_IN_PHASE_0.2"
  [R2_ENDPOINT]="SET_IN_PHASE_0.2"
  [R2_BUCKET_DEV]="SET_IN_PHASE_0.2"
  [R2_BUCKET_PROD]="SET_IN_PHASE_0.2"
)

log()  { printf '\033[0;36m[bootstrap]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m  ✓\033[0m %s\n' "$*"; }
skip() { printf '\033[0;33m  ·\033[0m %s\n' "$*"; }

command -v doppler >/dev/null 2>&1 || { echo "doppler CLI not found. See docs/runbooks/04-doppler-secrets-backbone.md"; exit 1; }
doppler me >/dev/null 2>&1 || { echo "Not authenticated. Run: doppler login"; exit 1; }

log "Ensuring project '$PROJECT' exists…"
if doppler projects get "$PROJECT" >/dev/null 2>&1; then
  skip "project '$PROJECT' already exists"
else
  doppler projects create "$PROJECT" >/dev/null
  ok "created project '$PROJECT' (default configs: dev / stg / prd)"
fi

for cfg in "${CONFIGS[@]}"; do
  log "Config '$cfg': ensuring ${#SLOTS[@]} secret slots…"
  # Verify the config exists; create it if a non-default name was requested.
  if ! doppler configs get "$cfg" --project "$PROJECT" >/dev/null 2>&1; then
    if doppler configs create "$cfg" --project "$PROJECT" >/dev/null 2>&1; then
      ok "created config '$cfg'"
    else
      echo "Could not find/create config '$cfg' in project '$PROJECT'."; exit 1
    fi
  fi
  for name in "${!SLOTS[@]}"; do
    existing="$(doppler secrets get "$name" --project "$PROJECT" --config "$cfg" --plain 2>/dev/null || true)"
    if [ -n "$existing" ]; then
      skip "$name (already set — left untouched)"
    else
      doppler secrets set "$name=${SLOTS[$name]}" --project "$PROJECT" --config "$cfg" --silent >/dev/null
      ok "$name = ${SLOTS[$name]}"
    fi
  done
done

log "Done. Real values are minted in Phase 0.2/0.3 (see ENVIRONMENT_VARS.md)."
log "Inspect with:  doppler secrets --project $PROJECT --config dev"
