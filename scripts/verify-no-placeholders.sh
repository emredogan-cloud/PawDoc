#!/usr/bin/env bash
# GAP-D5 / GAP-B5 — fail if launch-surface files still contain placeholders,
# fabricated names, or known overclaims. Wired into CI so a placeholder can never
# ship silently (the way "Reviewed by veterinary experts" + fake testimonials did).
set -euo pipefail

ROOTS="docs/store_metadata docs/legal web/app"

# Bracketed placeholders, TODO(cms), the fabricated testimonial names, and the
# unsubstantiated veterinary claims.
PATTERN='\[(DATE|LEGAL ENTITY|ADDRESS|to be drafted|TEMPLATE)|TODO\(cms\)|Sarah M\.|Diego R\.|Priya K\.|Reviewed by veterinary experts|reviewed for quality'

found=0
for root in $ROOTS; do
  if [ ! -e "$root" ]; then
    continue
  fi
  if grep -rEIn "$PATTERN" "$root" 2>/dev/null; then
    found=1
  fi
done

if [ "$found" -ne 0 ]; then
  echo "verify-no-placeholders: FAIL — launch-surface placeholders/overclaims listed above (GAP-B5)." >&2
  exit 1
fi
echo "verify-no-placeholders: OK — no placeholders/overclaims in: $ROOTS"
