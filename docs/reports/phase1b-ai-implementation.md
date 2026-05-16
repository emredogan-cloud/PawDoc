# Phase 1B — Analyze Flow Backend + AI Service Integration — IMPLEMENTATION

**Project:** PawDoc
**Phase:** 1B
**Plan reference:** [`phase1b-ai-plan.md`](phase1b-ai-plan.md)
**Predecessors:** Phase 0 foundation, Phase 1A schema + RLS + edge scaffolds

---

## 1. Summary

The analyze flow is wired end-to-end. The Supabase Edge Function authenticates
the user, verifies pet ownership, gates on rate-limit + free-tier quota,
forwards a typed request to the FastAPI AI service, and persists the
returned structured result to the append-only `analyses` table. The AI
service runs the canonical emergency-keyword override first, then routes
through Gemini Flash (Tier 2) → Claude Sonnet (Tier 3) with confidence
gating and cross-verify on EMERGENCY classifications.

Phase 0 + 1A architecture is preserved entirely. No frameworks added. No
repository restructure.

### Verification (all run locally)

| Command | Result |
|---------|--------|
| `make lint` (Phase 0 gates) | ✅ ruff/mypy/dart/flutter analyze clean |
| `make test` (Phase 0 gates) | ✅ 105 ai-service + 4 mobile, **92% coverage** |
| `supabase test db` (Phase 1A RLS) | ✅ 48/48 pgTAP assertions |
| `deno fmt --check`, `deno lint`, `deno check **/*.ts` | ✅ all green |
| `deno test --allow-env --allow-net` | ✅ **27/27** edge-function tests |
| Live smoke — emergency override path | ✅ returned EMERGENCY at tier 1 in 0ms (no AI calls) |
| Live smoke — graceful degradation path | ✅ returned MONITOR at tier 0 when no provider keys configured |
| Live smoke — auth rejection (missing/wrong token) | ✅ 401 |
| Live smoke — body validation | ✅ 422 |

### Live trace from the smoke run

```
analyze_received  request_id=smoke-emergency-1  input_type=text  pet_species=dog  pet_breed=Golden Retriever  text_len=45
emergency_override_triggered  request_id=smoke-emergency-1  keyword=seizure
analyze_completed  request_id=smoke-emergency-1  tier_used=1  triage_level=EMERGENCY  confidence=1.0  ai_latency_ms=0
```

```
analyze_received  request_id=smoke-graceful-1  input_type=text  pet_species=cat  pet_breed=Maine Coon  text_len=55
tier2_failed_escalating_to_tier3  request_id=smoke-graceful-1  reason=gemini_upstream: Gemini API key not configured.
tier3_failed_graceful           request_id=smoke-graceful-1  reason=claude_upstream: Anthropic API key not configured.
stage_timing                    request_id=smoke-graceful-1  stage=orchestrator_total  latency_ms=0
analyze_completed               request_id=smoke-graceful-1  tier_used=0  triage_level=MONITOR  confidence=0.0  model_used=graceful_degradation
```

---

## 2. Implemented Flows

### 2.1 AI Service (`ai-service/`)

```
                    POST /analyze
                          │
                          ▼
            X-PawDoc-Internal-Token verified (constant-time)
                          │
                          ▼
              X-Request-ID bound to structlog contextvars
                          │
                          ▼
                  Orchestrator.analyze
                          │
        ┌─────────────────┴─────────────────┐
        │                                   │
   emergency keyword?                       no
        │                                   │
        ▼ YES                               ▼
   tier_used = 1                    Gemini Flash (Tier 2)
   return EMERGENCY result          │
   (no AI calls)                    ▼
                              confidence ≥ 0.85
                              AND not EMERGENCY?
                                    │
                            ┌───────┴───────┐
                          YES               NO
                            │                │
                            ▼                ▼
                       tier_used=2     Claude Sonnet (Tier 3)
                       return                │
                                              ▼
                                       confidence < 0.60?
                                              │
                                      ┌───────┴───────┐
                                    YES               NO
                                      │                │
                                      ▼                ▼
                                 graceful         triage == EMERGENCY?
                                 (tier 0)              │
                                                ┌──────┴───────┐
                                              YES              NO
                                                │                │
                                                ▼                ▼
                                         cross-verify     return Tier 3
                                         (second Sonnet
                                          call)
                                                │
                                       ┌────────┴────────┐
                                     both                disagree
                                  EMERGENCY                 │
                                       │                   ▼
                                       ▼            downgrade to MONITOR
                                  return Tier 3     + cross_verify_disagreement=true
                                  EMERGENCY
```

### 2.2 Edge Function (`supabase/functions/analyze/`)

Twelve steps, each instrumented and observable:

1. CORS preflight handling
2. `requireUser(req)` → JWT validated via Supabase Auth admin client
3. Body parsed + validated via hand-rolled type guards (`asUuid`, `asOneOf`, etc.)
4. Pet ownership check — RLS-gated SELECT under the user's JWT; **does not leak existence** on cross-user pet (returns 404)
5. Emergency keyword scan via `_shared/emergency.ts` (advisory for quota bypass)
6. Daily rate limit via `getDailyLimiter().check(userId)` — Upstash REST if configured, in-memory fallback otherwise — **skipped when emergency matched**
7. Free-tier quota consume via `attempt_consume_free_analysis(user_id)` RPC (Phase 1A function) — **skipped when emergency matched**
8. Pet context loaded via service-role read
9. AI service called with `X-PawDoc-Internal-Token` and `X-Request-ID` headers; 30s timeout, abortable
10. Response validated via `validateAiServiceResult` — rejects unknown triage_level, missing fields, type mismatches
11. Service-role INSERT into `analyses` — RLS enforces append-only for users; service role bypasses
12. Structured JSON response with `X-Request-ID` echoed back

---

## 3. Latency Estimates

Measured directly where possible (smoke + unit-test timings); modelled
where it depends on provider responses we haven't yet exercised against
real keys.

| Stage | Best case | Typical | Worst case (in-budget) | Notes |
|-------|-----------|---------|-------------------------|-------|
| Edge function overhead (auth + body + RLS + Redis + RPC) | ~80 ms | ~150 ms | ~350 ms | Roundtrip-bound; Supabase region matters |
| Emergency override (no AI) | <5 ms | <5 ms | <5 ms | All in-process |
| Gemini Flash | 800 ms | 1.5 s | 3 s | Per roadmap §10 |
| Claude Sonnet | 1.5 s | 3 s | 6 s | Per roadmap §10 |
| Cross-verify (second Sonnet) | 1.5 s | 3 s | 6 s | Only on EMERGENCY |
| AI service overhead (FastAPI + parser) | ~10 ms | ~30 ms | ~80 ms | Pydantic + httpx |
| AI service ↔ DB insert (edge function) | ~30 ms | ~80 ms | ~200 ms | service-role write |
| **End-to-end happy Tier 2** | ~900 ms | **~1.7 s** | ~3.6 s | Within roadmap P95 < 10 s |
| **End-to-end Tier 3 (escalated)** | ~1.6 s | **~3.5 s** | ~6.5 s | Within budget |
| **End-to-end Tier 3 + cross-verify** | ~3 s | **~6.5 s** | ~12 s | EMERGENCY path; user expects intensity |
| **End-to-end emergency override** | ~80 ms | **~200 ms** | ~400 ms | The fastest path; latency *and* cost minimum |

All routes well within the roadmap P95 < 10 s SLO except the cross-verify
worst case at 12 s. Phase 1C should add an explicit timeout on the
orchestrator-wide budget that downgrades to single-call Sonnet if
cross-verify is on the slow tail.

---

## 4. Safety Guarantees

| Guarantee | How it's enforced | Verified by |
|-----------|-------------------|-------------|
| Emergency keyword override runs BEFORE any AI call | `Orchestrator._analyze_inner` calls `safety.check_emergency_override` as step 1; returns early on match | `test_safety.py` (all keywords); `test_orchestrator.py::test_emergency_keyword_short_circuits_all_ai_calls`; live smoke (no AI calls invoked) |
| EMERGENCY analyses are never paywalled | Edge function skips both rate-limit and free-tier consume when `checkEmergencyOverride` matches | `analyze/index.ts` source review; the conditional gates rate-limit + RPC |
| Cross-verify on every Tier-3 EMERGENCY | Orchestrator runs a second Claude call; disagreement downgrades to MONITOR | `test_orchestrator.py::test_tier2_emergency_always_escalates_to_tier3_then_cross_verify`; `test_orchestrator.py::test_cross_verify_disagreement_downgrades_to_monitor` |
| Structured output only — free text rejected | Gemini: `responseSchema`; Claude: `tool_choice` forcing `submit_analysis` tool; parser validates Pydantic on the way out | `test_parser.py` (8 assertions including missing fields, extra fields, out-of-range, bad enums); `test_gemini_client.py`; `test_claude_client.py::test_response_missing_tool_block_raises` |
| Confidence floor of 0.60 | Orchestrator downgrades to graceful when Tier-3 confidence < 0.60 | `test_orchestrator.py::test_tier3_below_confidence_floor_returns_graceful` |
| Temperature 0.1 across all health calls | Hardcoded in Gemini + Claude clients | `test_claude_client.py::test_happy_path_returns_tool_input` asserts `body["temperature"] == 0.1` |
| Disclaimer at API level | `AnalysisResult.disclaimer_required = True` (default); `disclaimer_text` field is part of the schema; never null | Pydantic model declaration in `app/models/schemas.py` |
| `analyses` table is user-append-only | Phase 1A RLS — only service role writes | Phase 1A pgTAP suite (48/48) |
| Service-role key never reaches mobile | mobile receives `anon` key only; service role lives only in ai-service + edge function env | Architecture; environment-setup.md documents discipline |
| Free-tier counter not client-trusted | `attempt_consume_free_analysis()` SQL function — atomic, service-role-only EXECUTE | Phase 1A function GRANT |
| AI service `/analyze` not publicly callable | Constant-time `INTERNAL_API_TOKEN` check | `test_analyze_router.py::test_rejects_request_without_internal_token`; live smoke (401 on missing/wrong) |
| No PII in AI service logs | The AI service receives `pet_id` (opaque uuid) but NOT `user_id`; emails are masked at edge function side via `maskEmail` | Module review; `test_safety.py` and `_shared/logger.ts` design |
| Anti-hallucination prompt rules | System prompt §"Anti-hallucination" + safety rules; never name conditions with certainty; downgrade NORMAL <0.65 to MONITOR | `test_prompts.py::test_system_prompt_anti_hallucination_present`; manual prompt review |
| Provider failure → graceful degradation, never 500 | Orchestrator catches `_ProviderFailure` at each tier; falls through to `_graceful_degradation` returning MONITOR | `test_orchestrator.py::test_tier3_provider_failure_returns_graceful`; live smoke (graceful path) |

---

## 5. Files Added / Modified

### Added (AI service)

```
ai-service/app/core/observability.py
ai-service/app/services/safety.py
ai-service/app/services/parser.py
ai-service/app/services/gemini_client.py
ai-service/app/services/claude_client.py
ai-service/app/services/orchestrator.py
ai-service/app/prompts/system_prompt.py
ai-service/app/prompts/breed_context.py
ai-service/app/routers/analyze.py
ai-service/tests/test_safety.py
ai-service/tests/test_parser.py
ai-service/tests/test_gemini_client.py
ai-service/tests/test_claude_client.py
ai-service/tests/test_orchestrator.py
ai-service/tests/test_analyze_router.py
ai-service/tests/test_prompts.py
```

### Modified (AI service)

```
ai-service/app/core/config.py        + internal token, model versions, timeouts, confidence floors
ai-service/app/main.py               + register analyze router
ai-service/app/models/schemas.py     + AnalysisRequest/Result, PetContext, AnalysisProviderOutput
ai-service/.env.example              + new env vars
ai-service/pyproject.toml            + per-file ignores for FastAPI Depends + orchestrator returns
```

### Added (edge functions)

```
supabase/functions/_shared/emergency.ts        canonical mirror of Python EMERGENCY_KEYWORDS
supabase/functions/_shared/rate-limit.ts       Upstash + in-memory limiter (replaces 1A stub)
supabase/functions/_shared/ai-service.ts       typed client + response validator
supabase/functions/_shared/emergency.test.ts
supabase/functions/_shared/rate-limit.test.ts
supabase/functions/_shared/ai-service.test.ts
```

### Modified (edge functions)

```
supabase/functions/analyze/index.ts            replaces Phase 1A 501 with full flow
```

### Documentation

```
docs/reports/phase1b-ai-plan.md
docs/reports/phase1b-ai-implementation.md      (this file)
```

### Not Touched

`mobile/`, all Phase 0 + 1A artifacts (config, migrations, RLS policies, tests).

---

## 6. Known Limitations

1. **No real provider call exercised in CI.** Unit tests mock `httpx`
   transports; integration with real Anthropic + Google AI keys is
   manual / staging-only. Phase 1C should add a nightly job that runs a
   small canary against real keys.

2. **Cross-verify uses Sonnet, not Opus.** Roadmap §3 mentions Opus as
   Tier 4 for EMERGENCY verification. Phase 1B uses Sonnet for both
   primary + cross-verify; Opus promotion is deferred to Phase 2 once we
   have data on real EMERGENCY frequency.

3. **No semantic cache writes.** `analyses.embedding` is null on every
   row. Phase 3 wires the embedding pipeline + similarity lookup. The
   schema and ivfflat index are ready.

4. **Image/video flows not yet exercised end-to-end.** The orchestrator
   accepts `input_storage_url` but Phase 1B testing covered text-only
   paths. Phase 1C ships the R2 upload flow + image-capable provider
   calls. The AI service code path is identical; the change is on the
   mobile side (capture + upload).

5. **`presignedR2Url` returns the public base URL, not a signed URL.**
   Phase 1B forwards the storage key with `R2_PUBLIC_BASE_URL` prefix.
   This is fine for public-read buckets; private buckets require a real
   presigned-URL minter (Phase 1C).

6. **Fail-open on Upstash outage.** When Upstash is unreachable, the
   edge function logs `rate_limit_upstash_5xx` / `rate_limit_upstash_error`
   and proceeds. This is documented behaviour (plan §7) — the DB-backed
   free-tier counter is the harder limit. SREs must watch for the
   degraded-mode log in production.

7. **No retry on free-tier RPC failure.** A DB outage during the RPC
   surfaces as 502 to the caller. This is correct — we don't want to
   double-charge quota on transient errors, and DB outages are rare and
   not retry-friendly.

8. **Local AI service env vars persist across tests.** The router test
   sets `INTERNAL_API_TOKEN` via `os.environ` for fixtures; this is
   intentional but means a developer running pytest after manually
   editing `.env` may see different behaviour. Documented but not
   automated.

9. **No request-body size limit on the AI service.** A 50KB JSON body
   today is accepted. FastAPI defaults are generous. Phase 1C should
   add explicit `Content-Length` limits as a defence-in-depth measure.

10. **Anthropic prompt caching not yet measured.** The `cache_control`
    header is sent on every Claude call; the cost reduction is
    documented in roadmap §10 ("50-70% reduction") but our metering
    happens once real traffic lands.

---

## 7. Production Risks

| Risk | Mitigation in 1B | Phase to address |
|------|-------------------|------------------|
| AI provider produces hallucinated condition names | Anti-hallucination rules in system prompt + confidence floor + structured output validation | ✅ shipped |
| Cross-verify disagreement = 100% (model never confirms its own EMERGENCY) | Downgrade-to-MONITOR keeps the user signal alive; visible in `cross_verify_disagreement` field; analytics in 2 will surface this | Phase 2 (metrics) |
| Cost runaway from a malicious user | Rate limiter (10/day) + free-tier counter (3/month) + provider org-level limits | ✅ shipped |
| Pet ownership bug exposes another user's data | RLS prevents cross-user reads; pet ownership check via user JWT, not service role; Phase 1A pgTAP suite verifies | ✅ shipped |
| Internal token leaked | Constant-time compare; rotated via Doppler; ai-service rejects with 401; **but** rotation requires deploy of both ai-service and edge function | Phase 2 (zero-downtime rotation) |
| `pet_id` not found vs. wrong owner — leaks existence | Both cases return 404, not 403; an attacker cannot probe pet IDs | ✅ shipped |
| AI service overloaded | Fly.io can autoscale; `min_machines_running=1` keeps warm; provider-level latency caps prevent runaway compute | ✅ shipped |
| Embedding pipeline crash later corrupts JSONB | `analyses.full_response` is JSONB; bad payloads would fail INSERT or JSONB validation; the row is append-only so no in-place corruption | ✅ shipped |
| Free-tier counter race | `attempt_consume_free_analysis` uses `SELECT ... FOR UPDATE` — atomic per Postgres | ✅ shipped (Phase 1A) |
| User-on-user denial-of-service via rate limit | Limiter is per-user-keyed; one user cannot exhaust another's quota | ✅ shipped |
| Edge function timeout | 30s default; we set 30s on AI service call too; Supabase Edge defaults work | Phase 2 (tuning) |

---

## 8. Phase 1C Recommendations

In priority order. Each item is a single PR-sized scope.

1. **Image/video upload flow.** Mobile (Phase 1D) captures and uploads to
   R2; edge function mints a presigned read URL with short TTL; AI
   service fetches the image and invokes Gemini vision + Claude vision
   APIs. The schema and code path are ready; this is **provider integration
   + R2 presigning + mobile capture**.

2. **revenuecat-webhook subscription state mapping.** Wire RevenueCat
   event types → `users.subscription_status` updates. The handler exists;
   Phase 1A logs + acks. Phase 1C maps:
   - `INITIAL_PURCHASE`, `RENEWAL`, `PRODUCT_CHANGE` → `premium` / `family`
   - `CANCELLATION`, `EXPIRATION`, `BILLING_ISSUE` → `free`

3. **Anthropic Opus on cross-verify.** Once we have data on EMERGENCY
   frequency in real traffic, promote the second call from Sonnet to
   Opus per roadmap §3. Cost ceiling justifies it: false-negative
   reduction on the highest-stakes path.

4. **Real-key canary in CI.** A nightly GitHub Actions job that:
   - hits a private staging Supabase + ai-service
   - runs 5 known fixture analyses
   - asserts triage outcomes match expectations
   - opens a GH issue if drift detected
   - cost: ~$0.05/night

5. **Sentry SDK integration in ai-service + edge functions.** The
   DSNs are configured (Phase 0); the SDKs aren't wired. Add
   `sentry-sdk[fastapi]` to ai-service deps and call `sentry_sdk.init`
   in lifespan. For edge functions, use `https://deno.land/x/sentry`.

6. **Latency budgets enforced at the orchestrator.** Add an explicit
   `asyncio.wait_for` around the whole orchestrator pipeline (e.g. 9s)
   so a tail-latency cross-verify path doesn't blow the P95 SLO.

7. **Rate-limit metrics emitted to PostHog.** Capture `rate_limit_check`
   events so we can see the daily-limit hit rate per user segment.

8. **Free-tier upgrade UX.** A 402 from the edge function should drive
   the mobile paywall. The error code (`payment_required`) is already
   ergonomic; mobile (Phase 1D) just needs to handle it.

---

## 9. Operational Notes

### Running the full smoke locally

```bash
# Boot supabase (Phase 1A schema + RLS)
supabase start
supabase db reset --local

# Boot ai-service (in another terminal)
cd ai-service
INTERNAL_API_TOKEN=local-secret APP_ENV=local uv run uvicorn app.main:app --port 8080 --reload

# Emergency path (no provider keys needed)
curl -X POST http://127.0.0.1:8080/analyze \
  -H "Content-Type: application/json" \
  -H "X-PawDoc-Internal-Token: local-secret" \
  -H "X-Request-ID: $(uuidgen)" \
  -d '{
    "request_id": "test-1",
    "pet": {"pet_id": "p1", "name": "Luna", "species": "dog"},
    "input_type": "text",
    "text_description": "My dog had a seizure"
  }'

# Graceful path (no provider keys → falls back to MONITOR)
curl -X POST http://127.0.0.1:8080/analyze \
  -H "Content-Type: application/json" \
  -H "X-PawDoc-Internal-Token: local-secret" \
  -d '{
    "request_id": "test-2",
    "pet": {"pet_id": "p1", "name": "Luna", "species": "dog"},
    "input_type": "text",
    "text_description": "She is sleepy today"
  }'
```

### Configuring real provider keys

In `ai-service/.env`:

```
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_AI_API_KEY=AIza...
INTERNAL_API_TOKEN=<random 32+ byte hex>
```

In Supabase edge function secrets (`supabase secrets set ...`):

```
AI_SERVICE_URL=https://pawdoc-ai-dev.fly.dev
INTERNAL_API_TOKEN=<same value as above>
UPSTASH_REDIS_REST_URL=https://...upstash.io
UPSTASH_REDIS_REST_TOKEN=...
R2_PUBLIC_BASE_URL=https://uploads.pawdoc.app
```

### CI

`supabase-ci.yml` already runs deno fmt/lint/check/test plus the pgTAP
RLS suite (Phase 1A). `ai-service-ci.yml` runs ruff/mypy/pytest plus a
Docker image smoke. No CI changes needed for 1B.

---

## 10. Definition of Done — Verified

- ✅ `make lint` + `make test` pass (Phase 0 gates).
- ✅ `supabase test db` passes (Phase 1A pgTAP, 48/48).
- ✅ `deno test --allow-env --allow-net` passes (Phase 1A + 1B, 27/27).
- ✅ `pytest` in `ai-service/` passes (105 tests, 92% coverage).
- ✅ Each emergency keyword has a passing test.
- ✅ Cross-verify disagreement scenario has a passing test.
- ✅ Graceful degradation scenario has a passing test.
- ✅ Live smoke confirms emergency path and graceful path return correct
  payloads with correct tier_used values.
- ✅ Live smoke confirms auth and validation failure modes return correct
  status codes.
- ✅ Architecture decisions from Phase 0 + 1A preserved.

---

*End of Phase 1B implementation report.*
