# PawDoc — Past Decisions (Phase 0–2)

Durable architectural decisions already made and **approved**. These are settled —
preserve them; do not silently revert. If new work would change one, **surface it
first** for an explicit owner decision. `CR #n` = Critical-Review item from the roadmap.

## Architecture & platform
- **Riverpod 3.x** (3.3) for state, **not** 2.x. go_router 17, Material 3, Dart 3.11.
- **AI service is Python/FastAPI on Fly.io**, separate from Supabase Edge Functions. The free-tier quota check and the analysis call are **server-side**, never trusted to the client.
- **AnalysisResult contract is frozen across three languages** (Dart / Python / TS). Any field change touches all three at once (`docs/contracts/ANALYSIS_RESULT.md`).

## Security & data isolation
- **RLS on every user table with `USING` AND `WITH CHECK`**, explicit per-operation policies (CR #2). Verified by `scripts/test-rls.sh` in an ephemeral pgvector container — not by inspection.
- **`ON DELETE CASCADE` on all user-owned FKs** (CR #20) so a user row deletion cleans up children deterministically.
- **Account deletion = hard delete via `ON DELETE CASCADE`** through a dedicated `delete-account` Edge Function (CR #9). Honors store/GDPR "delete my data".
- **No `service_role` for user-data reads.** Reads use the user JWT + RLS; `service_role` is confined to server-side writes/admin.
- **Secrets only in Doppler.** Git holds placeholders/`*.example` only; gitleaks runs in CI.

## Media pipeline
- **R2 uploads use short-lived presigned PUT URLs** minted by an Edge Function (CR #6). Client never holds R2 write credentials.
- **EXIF/GPS stripped client-side before upload** (CR #7) — location/privacy leak prevention.
- **Upload moderation fails CLOSED** (CR #8): on NSFW/unsafe or moderation error, reject the analysis **and delete the R2 object**. Safety beats convenience.

## AI safety (the product's core risk surface)
- **Emergency override runs BEFORE any AI call** — hardcoded keyword set; an emergency is never gated behind a model decision.
- **EMERGENCY is NEVER paywalled / free-tier-blocked** — enforced server-side (Edge Function) AND client-side (`paywall_policy`).
- **Temperature 0.1** on all health-analysis calls; **confidence floor 0.60** → "insufficient information" rather than a fabricated verdict; **EMERGENCY verdicts cross-verified**.
- **Tiered routing:** Gemini 2.0 Flash (Tier 2) → escalate to Claude `claude-sonnet-4-6` (Tier 3); accept Tier 2 only at confidence > 0.85. **Kill-switch** + graceful degraded fallback.
- **Disclaimers injected at the API layer** (`disclaimer_required` forced server-side); UI only renders based on the flag — it can't suppress it. Verified by `scripts/verify-disclaimers.sh`.

## Process / engineering rules (in force every session)
- **Roadmap is the source of truth.** Execute **one SUB-PR at a time**, strictly in order: re-read sub-phase → implement only its scope → validate → write `sub-pr-report/SUBPR_PHASE_X.Y.md` → **STOP at the human approval gate**.
- **One branch per sub-PR** (`phase-X.Y-slug`), commit (Co-Authored-By), push, PR. `main` requires **linear history + review** ⇒ **squash-merge**; never add merge commits to `main`.
- **Validate before claiming done** — run `flutter analyze`/`test`, `ruff`/`pytest`, `node --test`, `test-rls.sh`, phase verifier; show output, don't assume.
- **Surface, don't silently apply** Critical-Review items and gaps — they are proposals for owner decision.
- **Security/safety additions are always in scope**; new *product* features are not (those wait for their roadmap slot).
- **No regressions / no silent reversions** of decisions on this page.
- **Maintain `ENVIRONMENT_VARS.md`** every sub-PR that introduces config.

## 2026-07 Final Evolution Program (approved product reframe — PR #80)
The three strategy reports (`PAWDOC_PRODUCT_EVOLUTION_MASTERPLAN.md` etc.) were declared the product vision and executed. These decisions supersede conflicting lines above; do not revert without founder sign-off:
- **Verdicts → record + plan.** Contract v2: `action ∈ GET_HELP_NOW|CALL_TODAY|BOOK_VISIT|WATCH_AND_RECHECK`; `LIKELY NORMAL`/`NORMAL` and `differential` DELETED; `observation` replaces `primary_concern`; `confidence` is internal-only (never rendered). **The invariant: no output path — including every failure path — ends without an action + timeframe** (tested at Python/Edge/Dart layers).
- **Emergency = offline red button, not an AI feature.** Client-side keyword router (157 EN/DE triplicated `safety.py` ≡ `emergency_keywords.mjs` ≡ `emergency_keywords.dart`, 3-way parity-tested) → `EmergencyHelpScreen` (maps deep link, poison-control dial, bundled first-aid cards). NOTHING may be added to that screen (no AI/meter/monetization/analytics CTA — CLAUDE.md NEVER rule). Server override remains authoritative. Cross-verify on GET_HELP_NOW is now **async telemetry** (amends "cross-verified" above — it no longer blocks the response).
- **Free = safety, paid = memory.** Text guidance unmetered; photo logs metered PRE-AI (5/mo). One plan: `PREMIUM_STATUSES = {premium, trial}`.
- **DELETED end-to-end** (re-adding requires founder + catalog case): referral, family sharing, emergency-screen affiliates (telehealth/insurance), video capture, AI journals (+OpenAI vendor), A/B experiments, re-engagement push, b2b_lite/sitter, PDF add-on, semantic cache, training export, 2-pet cap, OneSignal (→ local notifications), Google Places vet finder (→ OS maps deep link).
- **RLS harness applies ALL migrations** (curated subset banned) and runs as a required CI job; Flutter CI builds APK+AAB; overclaim guard bans `never wonder`/`LIKELY NORMAL`/video-consult claims across app+store+web copy.
- Full record: `PAWDOC_FINAL_EVOLUTION_REPORT.md` + `IMPLEMENTATION_CHANGELOG.md` + `FUTURE_FEATURE_CATALOG.md`.
