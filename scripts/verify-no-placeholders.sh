#!/usr/bin/env bash
# GAP-B5 / GAP-D5 — truthfulness gate for launch-surface copy.
#
# Fails if any user-facing launch surface (store listings, legal docs, the
# marketing site source) still contains a fabricated claim ("overclaim") or an
# unfilled placeholder. Wired into CI (see GAP-D5) so neither can ship silently
# — the way "Reviewed by veterinary experts" and "built with veterinary input"
# nearly did.
#
# Two concern groups, reported separately:
#   OVERCLAIMS   — fabricated / unsubstantiated claims. Engineering MUST keep
#                  these at zero; any hit is a hard ship-blocker that this repo
#                  can fix directly.
#   PLACEHOLDERS — bracketed fill-ins the FOUNDER / attorney completes at launch
#                  (legal entity, address, effective date, App Review demo
#                  creds). Expected to remain until the legal/launch gate
#                  clears — they hard-gate PUBLIC launch by design.
#
# Exit non-zero if EITHER group has a hit (the surface is not launch-ready).
# Build artifacts and dependencies (.next, node_modules) are excluded so the
# gate only sees authored copy.
set -euo pipefail

# Default run blocks only on OVERCLAIMS (the engineering ship-blocker). Pass
# --strict for the founder's pre-launch gate, which ALSO fails on remaining
# founder-fill placeholders (legal entity, real store URLs, App Review creds) —
# so day-to-day CI isn't red forever on fill-ins only the founder can complete.
STRICT=0
if [ "${1:-}" = "--strict" ]; then
  STRICT=1
fi

ROOTS=(docs/store_metadata docs/legal web/app)

# Fabricated / unsubstantiated claims — must never appear in launch copy.
OVERCLAIMS='reviewed by veterinary experts|veterinary input|reviewed for quality|vet-approved|vet approved|vet-reviewed|vet reviewed|approved by (a )?vet|clinically (proven|tested|validated)|\bFDA\b|[0-9]{1,3}% accura|guaranteed (diagnosis|accuracy|results?)|never wrong|100% (accurate|reliable)|Sarah M\.|Diego R\.|Priya K\.|trusted by [0-9]'

# Placeholders / fill-ins — founder/attorney completes these before launch.
PLACEHOLDERS='\[(DATE|LEGAL ENTITY|ADDRESS|COMPANY|NAME|TBD|TEMPLATE|PLACEHOLDER|REVIEWER_DEMO_[A-Z]+)|to be drafted|\bTODO\b|\bTBD\b|lorem ipsum|XXXX'

# scan <pattern>: print matches across ROOTS; return 0 if ANY match was found.
scan() {
  local pattern="$1" found=1
  for root in "${ROOTS[@]}"; do
    if [ ! -e "$root" ]; then
      continue
    fi
    # -a: treat files as text. The launch copy contains emoji / em-dashes /
    # middots; without it grep flags those files "binary" and SKIPS them — a
    # silent false-clean (GAP-B5: the gate must never pass by not looking).
    if grep -raEn --exclude-dir=node_modules --exclude-dir=.next "$pattern" "$root" 2>/dev/null; then
      found=0
    fi
  done
  return "$found"
}

overclaims_found=0
placeholders_found=0

echo "== OVERCLAIMS (engineering ship-blocker — must be zero) =="
if scan "$OVERCLAIMS"; then
  overclaims_found=1
else
  echo "  none ✓"
fi

echo "== PLACEHOLDERS (founder-fill before public launch) =="
if scan "$PLACEHOLDERS"; then
  placeholders_found=1
else
  echo "  none ✓"
fi

if [ "$overclaims_found" -ne 0 ]; then
  echo "verify-no-placeholders: FAIL — OVERCLAIMS present (engineering ship-blocker; fix the copy above)." >&2
  exit 1
fi
if [ "$placeholders_found" -ne 0 ]; then
  if [ "$STRICT" -eq 1 ]; then
    echo "verify-no-placeholders: FAIL (--strict) — founder-fill PLACEHOLDERS remain; PUBLIC LAUNCH is gated on legal/submission." >&2
    exit 1
  fi
  echo "verify-no-placeholders: OK on overclaims — founder-fill placeholders remain (listed above; launch-gated). Run with --strict to enforce."
  exit 0
fi
echo "verify-no-placeholders: OK — no overclaims or placeholders in: ${ROOTS[*]}"
