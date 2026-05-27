#!/usr/bin/env bash
# =============================================================================
# github-branch-protection.sh  —  Phase 0.1
# Protects `main` (require PR + review) and enables secret scanning + push
# protection, via the GitHub REST API. Idempotent.
#
# Needs a token with Administration: Read/Write on the repo:
#   export GH_TOKEN=github_pat_xxx        # fine-grained PAT
#   ./scripts/github-branch-protection.sh
#
# Tunables:
#   REVIEW_COUNT  required approving reviews (default 1).
#                 Solo founders with no second reviewer may set REVIEW_COUNT=0
#                 to keep "PR required" without a hard approval block.
# =============================================================================
set -euo pipefail

REPO="${GH_REPO:-emredogan-cloud/PawDoc}"
BRANCH="${GH_BRANCH:-main}"
REVIEW_COUNT="${REVIEW_COUNT:-1}"
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

[ -n "$TOKEN" ] || { echo "Set GH_TOKEN (or GITHUB_TOKEN) first. See docs/runbooks/05."; exit 1; }
api() { curl -fsS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

echo "→ Applying branch protection to $REPO@$BRANCH (required reviews: $REVIEW_COUNT)…"
api -X PUT "https://api.github.com/repos/$REPO/branches/$BRANCH/protection" \
  -d @- >/dev/null <<JSON
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": $REVIEW_COUNT,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
echo "  ✓ branch protection applied"

echo "→ Enabling secret scanning + push protection…"
if api -X PATCH "https://api.github.com/repos/$REPO" -d @- >/dev/null 2>&1 <<JSON
{ "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" } } }
JSON
then
  echo "  ✓ secret scanning + push protection enabled"
else
  echo "  ! could not enable secret scanning automatically."
  echo "    Private repos need GitHub Advanced Security; otherwise enable in:"
  echo "    Settings → Code security and analysis. (Free for public repos.)"
fi

echo "→ Current protection state:"
api "https://api.github.com/repos/$REPO/branches/$BRANCH/protection" \
  | grep -E '"required_approving_review_count"|"required_linear_history"|"required_conversation_resolution"' || true
echo "Done. Verify with: ./scripts/verify-phase-0.1.sh"
