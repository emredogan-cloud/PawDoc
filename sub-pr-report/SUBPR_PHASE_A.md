# SUB-PR Report — Phase A: AI-Service Trust-Boundary Hardening & Production Secrets Sync

**Branch:** `fix/ai-service-auth-boundary`
**PR:** https://github.com/emredogan-cloud/PawDoc/pull/29 → `main`
**Date:** 2026-06-09
**Status:** Code complete + validated green. **Production secret-sync + deploy NOT executed** — the prescribed commands are non-functional and the rollout needs founder action (details + corrected commands below). **Stopped for approval per the brief. Did not start Phase B.**

---

## 1. What shipped (code — in this PR)

### AI service (`ai-service/`)
- **`app/main.py`** — new `require_service_auth` FastAPI dependency on `/analyze`, `/embed`, `/generate_journal`:
  - Reads `Authorization: Bearer <AI_SERVICE_TOKEN>`; compares **constant-time** (`hmac.compare_digest`).
  - **Fails CLOSED in production**: if `AI_SERVICE_TOKEN` is unset on a prod runtime → **503** (refuses traffic) instead of serving open.
  - **Dev/test stay open** (no token + not prod → allowed), so local runs and the unit suite need no token.
  - `/health` deliberately **left open** (Fly machine health checks).
- **`app/config.py`** — `AI_SERVICE_TOKEN` + `IS_PRODUCTION` (detected via Fly's auto-set `FLY_APP_NAME`, or explicit `AI_ENV`).

### Edge Functions (`supabase/functions/`)
- **`_shared/ai_service.mjs`** — pure, node-testable `aiServiceHeaders(requestId, token)` helper (attaches the bearer only when the token is set).
- Wired into **all three** AI-service callers (not just `/analyze`, or the other two would 401 once the boundary is live):
  - `analyze` → `/embed` **and** `/analyze`
  - `analyze-anonymous` → `/analyze`
  - `generate-journals` → `/generate_journal`

### Docs / tests
- `reports/ENVIRONMENT_VARS.md` — `AI_SERVICE_TOKEN` slot (🔒, prod-required, both runtimes, fail-closed note).
- `ai-service/tests/test_auth.py` (7 cases: open `/health`, 401 missing/wrong/malformed, 200 correct token, 503 prod-fail-closed, dev-open).
- `_shared/ai_service.test.mjs` (3 cases).

## 2. Validation (all green)

| Gate | Command | Result |
|---|---|---|
| Lint | `.venv/bin/ruff check .` | **All checks passed** |
| Python | `.venv/bin/python -m pytest -q` | **159 passed** |
| Edge/shared | `node --test supabase/functions/_shared/*.test.mjs` | **81 passed**, 0 fail |

*Caveat:* no `deno` on the validation host → Edge TS not type-checked locally (changes are minimal; shared helper is unit-tested). Edge deploy is founder-side.

## 3. Production secret sync — STATUS: prepared, **NOT executed**

The brief's commands **do not perform a sync** and were **not run against production**:

```bash
doppler run --project pawdoc --config prd -- supabase secrets set         # ❌
doppler run --project pawdoc --config prd -- fly secrets set --app pawdoc-ai  # ❌
```

**Why they fail (verified against the CLIs):**
- `doppler run -- CMD` runs `CMD` with the secrets exported as **environment variables**. It does **not** turn them into CLI arguments.
- `supabase secrets set` usage is `set [flags] <NAME=VALUE...>` and `fly secrets set` is `set NAME=VALUE …` — both **require NAME=VALUE arguments** and **ignore the environment**. With none supplied, they error / no-op.
- The `xargs: unmatched double quote` you hit is shell word-splitting of values containing quotes/spaces. The fix is a tool that reads `NAME=VALUE` from a **file/stdin** (no shell splitting) — *not* `doppler run -- <no-arg cmd>`.

**Two more blockers a blind sync would hit:**
1. `AI_SERVICE_TOKEN` **doesn't exist in Doppler yet** — it must be minted and set to the **same value** on both runtimes.
2. A "sync everything" into Supabase **errors**: `supabase secrets set` rejects names starting with `SUPABASE_` (reserved), and Doppler also carries `DOPPLER_*` metadata vars. The sync **must be scoped**.

### Corrected, quote-safe, scoped commands (keep your `doppler run` intent; wrap the set in `bash -c` so the injected env becomes properly-quoted args — no `xargs`, no on-disk `.env`)

```bash
# 0) Mint the shared token (local only):
TOKEN=$(openssl rand -hex 32)

# 1) Store it in Doppler prd (source of truth):
doppler secrets set AI_SERVICE_TOKEN="$TOKEN" --project pawdoc --config prd

# 2) Supabase Edge Functions — scoped, non-reserved keys only:
doppler run --project pawdoc --config prd -- bash -c '
  supabase secrets set --project-ref zbxrvfunaylkscgvsllm \
    AI_SERVICE_TOKEN="$AI_SERVICE_TOKEN" \
    R2_ACCOUNT_ID="$R2_ACCOUNT_ID" R2_BUCKET="$R2_BUCKET" R2_ENDPOINT="$R2_ENDPOINT" \
    R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
'   # (also fixes upload Bug #3 — generate-upload-url "storage not configured")

# 3) Fly (AI service) — token + provider keys (fixes AI Bug #2):
doppler run --project pawdoc --config prd -- bash -c '
  fly secrets set --app pawdoc-ai \
    AI_SERVICE_TOKEN="$AI_SERVICE_TOKEN" \
    GOOGLE_AI_API_KEY="$GOOGLE_AI_API_KEY" \
    ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
    OPENAI_API_KEY="$OPENAI_API_KEY"
'
# (Alternative, fully quote-safe via stdin import:
#  doppler secrets download --project pawdoc --config prd --no-file --format env-no-quotes \
#    | grep -E '^(AI_SERVICE_TOKEN|GOOGLE_AI_API_KEY|ANTHROPIC_API_KEY|OPENAI_API_KEY)=' \
#    | fly secrets import --app pawdoc-ai )
```

### Required deploy ordering (avoid a self-inflicted outage)
The new AI-service code **requires** the token once `AI_SERVICE_TOKEN` is set on Fly. If that happens before the Edge Functions send the header, every analysis → 401. Safe order:

1. **Merge PR #29.**
2. **Edge first:** run step 2, then `supabase functions deploy analyze analyze-anonymous generate-journals --project-ref zbxrvfunaylkscgvsllm` (now they send the bearer — harmless even before the AI service requires it).
3. **AI service next:** run step 3, then `fly deploy` from `ai-service/` (new image enforces auth **and** finally has provider keys).
4. **Verify** (see §4).

## 4. Validation to run after the rollout (founder)

```bash
fly status --app pawdoc-ai          # expect a healthy rolling deploy, machines passing /health
fly logs --app pawdoc-ai            # expect NO "AI_SERVICE_TOKEN unset ... fail closed" errors
```
- `curl https://pawdoc-ai.fly.dev/health` → 200 (open).
- `curl -XPOST https://pawdoc-ai.fly.dev/analyze -d '…'` **without** a bearer → **401** (boundary closed). With the correct bearer → real triage (`tier_used: 2`, not `degraded`).
- In-app: a text/photo check returns a **real** EMERGENCY/MONITOR/NORMAL (not "we can't analyze this right now"), and a photo upload succeeds (Bug #3).

## 5. Notes / out of scope
- This PR is intentionally **code-only**; no production system was mutated. Pairs with my live-E2E report (`PAWDOC_LIVE_E2E_VALIDATION_REPORT.md`), which root-caused Bugs #2/#3 as **secrets present in Doppler but never synced to the deployed runtimes**.
- Separate, already-applied prod change that still needs committing to avoid schema drift: `supabase/migrations/20260609150000_auth_user_profile_trigger.sql` (the profile-provisioning fix from the prior session). Recommend committing it on its own PR.

**STOP — awaiting founder approval. Phase B not started.**
