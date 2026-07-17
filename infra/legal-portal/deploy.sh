#!/usr/bin/env bash
# Build + deploy the PawDoc legal portal to AWS (S3 + CloudFront).
# Reproducible: no console steps. Requires awscli creds + terraform + node.
#
#   ./deploy.sh                         # build (canonical = SITE_BASE_URL or default) + apply
#   SITE_BASE_URL=https://pawdoc.app ./deploy.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB="$HERE/../../web-legal"

echo "==> Building static site (web-legal)"
( cd "$WEB" && node build.mjs )

echo "==> terraform init"
terraform -chdir="$HERE" init -input=false

echo "==> terraform apply"
terraform -chdir="$HERE" apply -auto-approve -input=false

echo
echo "==> Deployed. Portal URL:"
terraform -chdir="$HERE" output -raw portal_url
echo
