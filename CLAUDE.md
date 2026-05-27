# PawDoc

AI-native pet-health triage app: photo/video/text + pet context → AI triage
(EMERGENCY / MONITOR / LIKELY NORMAL). Safety-critical — a **false negative is the
#1 business risk**, so correctness and defensive coding always beat speed.

## Stack
- **mobile/** — Flutter (Dart 3.11). Riverpod 3, go_router 17, Material 3.
- **ai-service/** — Python FastAPI (`/health`, `/analyze`); Tier 2 Gemini → Tier 3 Claude. Deploys to Fly.io.
- **supabase/** — PostgreSQL (RLS), Auth, Edge Functions (Deno/TS), migrations.
- **Cloudflare R2** — image/video object storage (S3-compatible).
- Secrets in **Doppler**; analytics PostHog; errors Sentry; subs RevenueCat; push OneSignal.

## File layout
- `mobile/lib/src/{auth,onboarding,pets,capture,analysis,monetization,account,notifications,core}/`
- `ai-service/app/` (pipeline, providers, safety, moderation) + `ai-service/tests/`
- `supabase/migrations/`, `supabase/functions/{analyze,auth-webhook,revenuecat-webhook,generate-upload-url,delete-account}`, `supabase/tests/`
- `roadmap/APP_EXECUTION_ROADMAP_DECOMPOSED.md` — execution source of truth
- `docs/runbooks/` (founder ops), `docs/legal/`, `docs/contracts/ANALYSIS_RESULT.md`
- `scripts/verify-phase-*.sh`, `scripts/test-rls.sh`, `scripts/verify-disclaimers.sh`
- `memory/PAST_DECISIONS.md`, `memory/USER_PROFILE.md`, `ENVIRONMENT_VARS.md`

## Common commands
```bash
# Flutter (run from mobile/)
flutter analyze
flutter test
flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…   # + POSTHOG/REVENUECAT/ONESIGNAL/SENTRY
# AI service (run from ai-service/, venv active)
.venv/bin/ruff check . && .venv/bin/python -m pytest -q
# Edge Function / shared JS tests
node --test supabase/functions/_shared/*.test.mjs
# RLS + account-deletion cascade (Docker)
./scripts/test-rls.sh
# Per-phase verifier
./scripts/verify-phase-<X.Y>.sh
# Deploy (founder / gated)
fly deploy                                  # from ai-service/
supabase functions deploy <name> --project-ref <ref>
```

## Conventions (non-negotiable)
- **RLS on EVERY user table**, with `USING` **and** `WITH CHECK` + explicit per-op policies. Verify with `scripts/test-rls.sh`.
- **AI output is structured JSON only** (Pydantic `AnalysisResult` / Claude tool_use / Gemini JSON). Off-schema → reject + log + retry/degrade.
- **Temperature = 0.1** on every health-analysis call.
- **Emergency override runs BEFORE any AI call** (hardcoded keywords); EMERGENCY is cross-verified; confidence < 0.60 → "insufficient information", never fabricate.
- **Disclaimers are API-injected** (`disclaimer_required` forced server-side; UI only gates on the flag). Verify with `scripts/verify-disclaimers.sh`.
- Model IDs only (`claude-sonnet-4-6`, `gemini-2.0-flash`) — never marketing names.
- The `AnalysisResult` contract (`docs/contracts/ANALYSIS_RESULT.md`) is frozen across Dart/Python/TS — change all three together.
- Conventional, lint-clean code: `flutter analyze` + `ruff` must be green; bash scripts must pass `shellcheck` (warning gate: `if/then/else`, not `cmd && a || b`).

## NEVER do these (safety/security gates)
- **NEVER ship R2 write keys in the client.** Uploads use short-lived **presigned PUT URLs** from an Edge Function.
- **NEVER paywall / free-tier-block an EMERGENCY result.** Enforced server-side (Edge Function bypasses the gate on emergency text) AND client-side (`paywall_policy`).
- **NEVER use `service_role` for user-data reads.** Reads go through the user's JWT + RLS; `service_role` is server-only for writes/admin.
- **NEVER commit secrets.** Real values live in Doppler; only `*.example`/placeholders in git. `.gitignore` + gitleaks CI guard this.
- **NEVER strip the disclaimer** or weaken the emergency/safety path to ship faster.
- Strip EXIF/GPS from images before upload; moderate uploads (fail closed).

## Verification discipline (mandatory)
- After any meaningful change, **run the relevant checks before claiming done** — `flutter analyze`/`flutter test`, `ruff`/`pytest`, `node --test`, `test-rls.sh`, and the phase verifier. Never assume success; show the output.
- If something fails: diagnose → fix → re-test → only then proceed. Treat failures as engineering work, not blockers to hide.
- Headless env has no device/simulator and (usually) no live infra — those checks are founder-side; mark them MANUAL, don't fake them.

## Execution discipline (this project's working agreement)
- The decomposed roadmap is the **source of truth** for sequencing and scope. Work **one SUB-PR at a time**: re-read the sub-phase, implement only its scope, validate, write `sub-pr-report/SUBPR_PHASE_X.Y.md`, then **STOP for explicit human approval** before the next.
- **Git:** branch `phase-X.Y-slug` per sub-PR → commit (Co-Authored-By) → push → PR. `main` is protected (**linear history + review**) ⇒ **squash-merge** PRs. Don't introduce merge commits to `main`.
- **Surface, don't silently apply.** Critical-Review items and any gap are raised as proposals for owner decision — never folded in quietly. Approved decisions (see `memory/PAST_DECISIONS.md`) are **preserved, not reverted**; if a change would alter one, flag it first.
- **Security & safety > speed.** Add necessary security/compliance even if unlisted, but don't invent product features.
- Keep this file ≤ ~200 lines; lazy-load detail from `docs/`, `roadmap/`, `ENVIRONMENT_VARS.md`, and `memory/`.
