# SUB-PR Report — Phase 5.3: AI Health Journal

**Status:** Complete and fully green (ruff/pytest, node, journals pg test, flutter analyze/test, shellcheck). A weekly GPT-4o-synthesized narrative per opt-in Premium/Family pet — server-side cron, RLS-locked storage, OpenAI failures contained.
**Branch:** `phase-5.3-health-journal` (from `origin/main` = `55ef148`, contains 0.1→5.2)
**Date:** 2026-05-28

---

## 1. Files created / modified

**DB:**
```
supabase/migrations/20260527070000_health_journals.sql   table + RLS (SELECT-only for clients)
                                                          + pets.is_journal_enabled + pets_pending_journal RPC
supabase/migrations/20260527070001_schedule_generate_journals_cron.sql   Sunday 00:00 UTC cron (Supabase-managed)
supabase/tests/health_journals.sql + scripts/test-journals.sh             RPC eligibility + RLS + lockdown pg test
```
**AI service:**
```
app/journal.py                            JournalProvider + OpenAIJournalProvider (lazy, fail-safe) + prompt builder
app/models.py        (mod)                + JournalRequest
app/main.py          (mod)                + POST /generate_journal (Depends -> overridable in tests)
app/config.py        (mod)                + OPENAI_MODEL pin + OPENAI_API_KEY + journal temp/max-tokens/timeout
requirements.txt     (mod)                + openai>=1.40 (lazy-imported)
tests/test_journal.py                     prompt safety + fail-safe + endpoint (fake injected)
```
**Edge:**
```
functions/_shared/journal.mjs (+test)     mondayOfWeekUtc + analyses/events summarizers
functions/generate-journals/index.ts      CRON_SECRET-gated; chunked concurrency + soft deadline; per-pet try/catch
supabase/config.toml         (mod)        [functions.generate-journals] verify_jwt = false
```
**Flutter:**
```
lib/src/pets/pet.dart                (mod)  + isJournalEnabled (round-trips toColumns/fromJson/copyWith)
lib/src/pets/pet_form_screen.dart    (mod)  + "Weekly AI Health Journal" SwitchListTile (Premium / Family note)
lib/src/health/journal.dart                 Journal model
lib/src/health/journal_repository.dart      RLS-scoped list + latestJournalProvider
lib/src/health/journal_card.dart            latest-narrative card with "All journals" link
lib/src/health/journals_screen.dart         list of all journals for the active pet
lib/src/health/history_timeline_screen.dart (mod)  shows the JournalCard as the timeline header
lib/src/analytics/analytics.dart     (mod)  + journal_viewed
test/pet_test.dart + test/journal_test.dart  isJournalEnabled round-trip + Journal.fromJson
```
**Docs:** `ENVIRONMENT_VARS.md` (OPENAI_API_KEY + OPENAI_MODEL + resilience note), `scripts/verify-phase-5.3.sh`, this report.

## 2. How the OpenAI integration is secure + resilient

**Secure (cost + access):**
- `OPENAI_API_KEY` lives **only** on the AI service (Fly env / Doppler). It never reaches the client and never reaches the Edge Function — the Edge calls our **own** `/generate_journal` endpoint, which holds the key.
- The OpenAI SDK is **lazy-imported** inside `OpenAIJournalProvider.generate`, so unit tests don't need it installed (and a missing dependency at startup doesn't crash the service).
- The model is **pinned** (CR #17): `OPENAI_MODEL` defaults to **`gpt-4o-mini`** to keep weekly-per-pet spend tiny; the env var lets the founder swap models without redeploy.
- Runbook reminds the founder to set a **billing alarm**.

**Resilient (CR #5 — "if OpenAI fails, move on"):**
- `OpenAIJournalProvider.generate` is wrapped in `try/except Exception`: a missing/invalid key, timeout (`JOURNAL_TIMEOUT_SECONDS=30`), SDK error, or empty completion all return **`None`**. There is no partial-write path.
- `/generate_journal` then returns `{"narrative": null, "model": null}`.
- The cron Edge Function inspects the narrative; **null → log + skip that pet**, no `health_journals` row written. **`UNIQUE (pet_id, week_start_date)`** means the next weekly run safely retries.
- Each pet is processed in its **own** `try/catch` in `processOne` — one pet's failure (OpenAI or DB) never blocks the others or crashes the function.

Unit-tested: prompt carries `DO NOT diagnose` / `DO NOT override` / `not a veterinary diagnosis`; the provider returns `None` with no key / on errors; the endpoint defaults to `narrative: null` when unconfigured (FastAPI dependency override injects a fake to test the success path).

## 3. How the 60s Edge timeout is honored (batching)

The Edge Function intentionally does **not** try to write every pet in one invocation. Instead:

- **Chunked concurrency:** pets are processed in groups of `CONCURRENCY = 5` via `Promise.all` — five OpenAI calls run in parallel per chunk (≈ chunk latency ≈ slowest single call).
- **Soft deadline:** before each chunk, the function checks `Date.now() - start > DEADLINE_MS` (50 000 ms = **50s, 10s headroom under the 60s Edge cap**) and breaks the loop, returning a partial summary with what was written + how many remain.
- **Idempotent retries:** the deferred pets are picked up on the next weekly cron — `UNIQUE (pet_id, week_start_date)` prevents duplicate rows even if a pet partially processed; an insert hitting `23505` (Postgres `unique_violation`) is treated as a no-op.
- **Per-pet isolation:** `processOne(pet)` has its own `try/catch`, so one failure never aborts the chunk or the loop.

This comfortably handles tens of pets per weekly slot (5 in parallel × ~5s/OpenAI call ≈ ~25–50s for ~25–50 pets). The runbook + verifier flag a Fly background worker as the next-step at higher scale (the strict-rule constraint is "without hitting a 60-second timeout" — this approach satisfies it for the v1 cohort and degrades gracefully via idempotency above it).

## 4. Tier + opt-in enforcement (proven)

The `pets_pending_journal(week_start)` SQL function (SECURITY DEFINER, locked to `service_role`) filters:
- `pets.is_journal_enabled = true` (per-pet opt-in toggle, set in the pet form),
- `users.subscription_status in ('premium', 'family', 'trial')`,
- `NOT EXISTS health_journals` row for that week (idempotency).

`test-journals.sh` (Docker pgvector) seeds A premium-opt-in, B free-opt-in, C premium-opt-out, D premium-opt-in-already-done, E family-opt-in, F trial-opt-in — and asserts the RPC returns exactly **A, E, F** (no tier leak, no opt-out leak, no idempotency leak). Per-user RLS row visibility + RPC/table lockdowns are also asserted.

## 5. Tests executed & results

| Test | Result |
|------|--------|
| `ruff check .` | **clean** |
| `pytest -q` | **120 pass** (+8 journal: prompt safety, providers, endpoint w/ fake) |
| `node --test _shared/*.mjs` | **49 pass** (+3 mondayOfWeekUtc + summarizers) |
| `./scripts/test-journals.sh` (Docker) | **PASS** — eligibility + RLS visibility + lockdowns |
| `flutter analyze` | **No issues found** |
| `flutter test` | **77 pass** (+2 isJournalEnabled / Journal.fromJson) |
| `./scripts/verify-phase-5.3.sh` | **exit 0** — incl. resilience + batching assertions; 3 MANUAL |
| `shellcheck` (verifier + harness) | **clean** |

## 6. MANUAL (founder)

- Set `OPENAI_API_KEY` on Fly (`fly secrets set OPENAI_API_KEY=...`) + a billing alarm. Optionally set `OPENAI_MODEL`.
- Apply the weekly cron migration on Supabase (`supabase db push`); deploy `generate-journals`; reuse the existing `CRON_SECRET` + Vault `project_url`/`cron_secret` (set up in 3.3 P2).
- On device: toggle the opt-in for a Premium/Family pet and verify a narrative arrives on the next Sunday.
- Deno typecheck of `generate-journals` runs in Supabase CI; the `_shared` logic is node-tested.

## 7. Git branch / commit / push

- Branch: `phase-5.3-health-journal`
- Implementation commit (deliverables): `ba4789b3147669da6d9ede1934c29bab35fc7ddf`
- Push: pushed to `origin/phase-5.3-health-journal`; open PR at https://github.com/emredogan-cloud/PawDoc/pull/new/phase-5.3-health-journal

## 8. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| `health_journals` table + RLS (own-row read; service-only write) | ✅ DONE | migration; pg test |
| GPT-4o integration with safety prompt (no diagnose / no override) | ✅ DONE | `journal.py`; pytest |
| Resilient on OpenAI failure (no crash, no partial data) | ✅ DONE | try/except → None; cron logs+skips |
| Weekly cron over opt-in + Premium/Family + idempotent | ✅ DONE | RPC + UNIQUE + Vault-secret cron schedule |
| Edge respects the 60s timeout | ✅ DONE | CONCURRENCY=5 + DEADLINE_MS=50s + per-pet try/catch |
| In-app surface (history card + journals screen) | ✅ DONE | `JournalCard` + `JournalsScreen` + analytics |
| Opt-in toggle on the pet form | ✅ DONE | `pet_journal_toggle` SwitchListTile |
| Set live key + deploy + first Sunday run | ⏳ MANUAL | §6 |

**Verified now:** the journal pipeline is OpenAI-fail-safe (test-proven), the eligibility query is tier+opt-in+idempotent (DB-proven), the cron handles ≤60s via chunked concurrency + a soft deadline + idempotent retries, and the client has the opt-in toggle + the read-only journal surface. Stopping for approval.
