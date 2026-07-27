# PawDoc

AI-native pet-health triage. Photo / video / text plus pet context goes in; a
structured triage record comes out with an action and a timeframe —
**GET HELP NOW · CALL TODAY · BOOK A VISIT · WATCH AND RECHECK**.

Safety-critical by design: a false negative is the product's single biggest risk,
so the emergency path is offline-capable, model-free, and never paywalled.

**Status:** Android closed testing on Google Play.

## Repository layout

| Path | What it is |
| --- | --- |
| `mobile/` | Flutter app (Dart 3.11, Riverpod 3, go_router 17, Material 3) |
| `ai-service/` | Python FastAPI triage pipeline — Tier 2 Gemini → Tier 3 Claude; deploys to Fly.io |
| `supabase/` | PostgreSQL with RLS, Auth, Edge Functions (Deno/TS), migrations |
| `web/`, `web-legal/` | Marketing site and the public legal portal |
| `scripts/` | Phase verifiers, RLS tests, disclaimer checks |
| `docs/` | Runbooks, contracts, legal, store metadata, archive |
| `roadmap/` | Execution roadmap (source of truth for sequencing) |
| `memory/` | Standing decisions and profile notes |
| `sub-pr-report/` | One report per merged sub-PR |
| `infra/`, `fastlane/`, `ASO-image/` | Infrastructure, release automation, store art |

## Documentation

Start here:

- **`CLAUDE.md`** — architecture, conventions, and the non-negotiable safety gates
- **`ENVIRONMENT_SETUP.md`** — local setup and required configuration
- **`FINAL_RELEASE_READY_REPORT.md`** — current release status and verdict
- **`IMPLEMENTATION_CHANGELOG.md`** — per-phase implementation log
- **`docs/runbooks/`** — founder operations (Play Console, RevenueCat, Supabase, incident response)
- **`docs/contracts/ANALYSIS_RESULT.md`** — the frozen AI output contract (Dart ≡ Python ≡ TS)
- **`memory/PAST_DECISIONS.md`** — approved decisions that must not be reverted
- **`docs/archive/`** — historical reports and superseded roadmaps

## Common commands

```bash
# Flutter (from mobile/)
flutter analyze
flutter test

# AI service (from ai-service/, venv active)
.venv/bin/ruff check . && .venv/bin/python -m pytest -q

# Edge Function / shared JS tests
node --test supabase/functions/_shared/*.test.mjs

# RLS + account-deletion cascade (needs Docker)
./scripts/test-rls.sh

# Disclaimer injection guard
./scripts/verify-disclaimers.sh
```

Runtime configuration is supplied at build time via `--dart-define`, sourced from
Doppler. Never hardcode secrets; only `*.example` placeholders belong in git.

## Safety invariants

These are enforced in code and CI, and are not negotiable:

- The action ladder has **no "do nothing" rung** — no output may end without an action and a timeframe.
- Emergency keyword override runs **before any AI call**, and the keyword lists are triplicated and parity-tested across Python, TypeScript, and Dart.
- A `GET_HELP_NOW` result is **never** paywalled or quota-blocked, server-side or client-side.
- Nothing may be added to the emergency screens beyond help contacts, first aid, the disclaimer, and the acknowledgment gate.
- Disclaimers are **API-injected**; the UI only gates on the server-set flag.
- RLS on every user table, with `USING` **and** `WITH CHECK`.
