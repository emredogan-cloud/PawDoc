<!--
Thanks for the PR. Keep this template short and honest — every field below
serves a specific reviewer need.
-->

## Summary

<!-- 1-3 sentences. WHY, not WHAT. The diff covers the what. -->

## Phase / Area

- [ ] Phase 0 — Foundation
- [ ] Phase 1 — MVP Core
- [ ] Phase 2 — App Store Launch
- [ ] Phase 3+ — Growth

Service touched:
- [ ] mobile
- [ ] ai-service
- [ ] supabase
- [ ] infra / CI

## Risk

- [ ] No risk (docs / tests only)
- [ ] Low — local-only or behind feature flag
- [ ] Medium — production behavior changes, well-covered by tests
- [ ] High — touches auth, billing, RLS, AI safety, or migrations

## Checklist

- [ ] Tests added / updated and pass locally (`make test`)
- [ ] Lint + type checks pass (`make lint`)
- [ ] No secrets committed (check `.env*` is gitignored)
- [ ] No `print` / `console.log` left in (use logger)
- [ ] Any new env var documented in `*.env.example`
- [ ] Migration (if any): includes `ENABLE ROW LEVEL SECURITY` for new tables
- [ ] AI prompt change (if any): tested across all 3 triage levels

## Out of Scope

<!-- Things you noticed but deliberately didn't change in this PR. -->

## Screenshots / Demo

<!-- Required for UI changes. Drag-and-drop. -->
