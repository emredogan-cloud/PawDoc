# SUB-PR Report — Phase 1.3: AI Orchestration & Safety Core

**Status:** Built and **verified headless** — safety core, routing, and all five approved CRs are unit-tested; live provider calls are founder-side (need API keys).
**Branch:** `phase-1.3-ai-orchestration` (stacked on `phase-1.1-app-skeleton-auth-data`)
**Date:** 2026-05-27

---

## 1. Part 1 — Phase 1.1 CI ShellCheck fix (confirmed)

The 1.1 PR's `CI / ShellCheck` job failed on **15 `note`/style findings** (zero warning/error-level — verified with `shellcheck -S warning`, exit 0). Fixed in the **scripts** (no severity suppression): converted the `cmd && pass || fail` idiom (SC2015) to `if/then/else`, `ls | head` (SC2012) to glob arrays, and `echo | sed` (SC2001) to parameter expansion. `shellcheck scripts/*.sh` now exits **0** at default severity (matches the CI action). Committed `66c90a1` on the 1.1 branch; with `flutter analyze`/`test` already green, the 1.1 CI goes green.

## 2. Files created/modified (Phase 1.3)

```
ai-service/app/config.py          model IDs (CR #17), temp 0.1, thresholds, kill-switch
ai-service/app/models.py          Pydantic AnalysisResult (contract) + strict parser
ai-service/app/safety.py          emergency override (23 keywords) + CR #4 re-check
ai-service/app/prompts.py         system prompt v1 + anti-hallucination guards
ai-service/app/providers.py       Gemini (T2) + Claude (T3, tool_use + prompt caching), lazy SDKs
ai-service/app/cache.py           result cache + CR #19 kill-switch flag (Upstash/in-memory)
ai-service/app/pipeline.py        orchestration (override→route→cross-verify→gate→CR#4→degraded)
ai-service/app/logging_setup.py   JSON logs, key masking, request-id (CR #23)
ai-service/app/main.py            POST /analyze + request-id middleware (kept /health)
ai-service/requirements.txt       + anthropic, google-genai, httpx
ai-service/tests/                 test_emergency_override, test_parser, test_pipeline (+health updated)
supabase/functions/analyze/index.ts        Edge Function: validate, free-tier, call AI, store
supabase/functions/_shared/free_tier.mjs   pure free-tier logic (CR #10) + Node test
scripts/verify-phase-1.3.sh       phase verifier
docs/runbooks/14-analyze-wiring.md ; docs/contracts/ANALYSIS_RESULT.md (Py/TS bindings ✅)
ENVIRONMENT_VARS.md               Upstash + AI_SERVICE_URL/AI_KILL_SWITCH/model overrides
scripts/{doppler-bootstrap,supabase-enable-extensions,verify-phase-0.1..0.4,verify-phase-1.1}.sh  (Part 1 shellcheck fixes)
```

## 3. How the safety CRs were implemented (specifics)

- **CR #4 — Borderline-NORMAL re-check** (`safety.needs_normal_recheck` + `pipeline`): a NORMAL result is treated as suspicious when risk-signal keywords are present (vomiting, lethargic, bleeding, …), input was low-quality, or the pet is sensitive (age <1 or ≥10, or an exotic). The pipeline then **escalates a Tier-2 NORMAL to Tier-3**, and if Tier-3 still says NORMAL, **biases to MONITOR** (`bias_to_monitor`). Directly defends the #1 false-negative risk.
- **CR #19 + #5 — Kill-switch + degraded fallback** (`cache.is_ai_disabled`, `pipeline._degraded_result`): a dynamic Redis flag (`pawdoc:ai_kill_switch`) OR env fallback short-circuits the pipeline to a **safe, non-reassuring MONITOR** ("can't analyze now — if urgent, contact a vet"). Any provider/parse failure (after one retry) degrades the same way — never a fabricated NORMAL, never a crash.
- **CR #10 — Free-tier monthly reset** (`_shared/free_tier.mjs` `evaluateFreeTier`): check-on-read reset when `now ≥ reset_at`, rolling `reset_at` to the next month — so free users get 3/month, not 3 ever. The Edge Function enforces it server-side (HTTP 402 on the 4th) and increments only after a successful analysis.
- **CR #23 — Request-ID tracing** (`logging_setup`, `main.middleware`, Edge Function): a request-id is read from `x-request-id` or minted, bound to every JSON log line, propagated Edge Function → AI service, and echoed in responses.
- **CR #17 — Model IDs**: `config.TIER2_MODEL="gemini-2.0-flash"`, `TIER3_MODEL="claude-sonnet-4-6"` — no marketing names.
- *(CR #3 semantic cache deferred to 3.2 as planned. CR #11 localized keywords noted for 5.4/8.3.)*

## 4. Tests executed & results

| Test | Result |
|------|--------|
| `ruff check ai-service` | clean |
| `pytest` (ai-service) | **43 passed** — emergency override (all 23 keywords), parser (valid/invalid/malformed/out-of-range), pipeline (routing, pre-AI override, EMERGENCY cross-verify, <0.60 gate, CR #4 bias-to-MONITOR, CR #19 kill-switch, CR #5 degrade) |
| `node --test free_tier.test.mjs` | **5 passed** — 3-ok/4th-blocked + CR #10 reset + premium-unlimited |
| `shellcheck scripts/*.sh` | exit 0 (Part 1) |
| `./scripts/verify-phase-1.3.sh` | exit 0 — 13 checks green |
| provider SDKs install (`anthropic`, `google-genai`, `httpx`) | verified (CI pip install will pass) |

## 5. Security checks

- **Emergency override runs BEFORE any AI call** and is AI-independent (hardcoded).
- **Temperature is 0.1** on every health call (asserted in tests).
- **Disclaimer is forced `True` at the API level** in the pipeline (UI cannot suppress).
- **Structured JSON logs mask** `sk-ant-…`, `AIza…`, and JWT shapes; no PII keys leak.
- `service_role` used only server-side (Edge Function) for the counter + storing results; reads are RLS-scoped to the user.
- Webhook/secret values never committed (scan clean).

## 6. Known issues / scope notes

- **Live provider behavior is founder-side** (needs `ANTHROPIC_API_KEY` + `GOOGLE_AI_API_KEY`): real Tier-2/3 latency (P50 targets), real Gemini JSON / Claude tool_use parsing, and the deployed end-to-end `/analyze` store. Providers are lazy-imported and unit-tested via fakes; runbook 14 covers deploy + live verification.
- **"EMERGENCY never paywalled"** (an explicit free-tier/paywall bypass) is sequenced to **Phase 1.4** per the roadmap; the 1.3 free-limit response is already safety-worded ("if urgent, contact a vet").
- Edge Function (Deno/TS) is type-checked/served by the founder on deploy (no local Deno here); the pure free-tier logic is Node-tested.

## 7. Risks

- Gemini self-confidence is uncalibrated (CR #4/#5 mitigate via the NORMAL re-check + cautious defaults).
- Single AI machine remains a SPOF until Phase 7 (CR #5) — degraded fallback limits blast radius; redundancy still pending.
- Provider cost: set budget alerts (CR #12) before real traffic (noted in runbook 14).

## 8. Git branch

`phase-1.3-ai-orchestration` (stacked on `phase-1.1-app-skeleton-auth-data`).

## 9. Commit hash

Implementation commit: `__IMPL_COMMIT__` (finalized in report-finalization commit; see `git log`).

## 10. Push confirmation

`__PUSH_STATUS__`

## 11. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Emergency override on all hardcoded keywords, pre-AI | ✅ DONE | test (23/23); pipeline order; no provider call |
| Temperature 0.1; <0.60 → insufficient info | ✅ DONE | config + pipeline; tests |
| EMERGENCY cross-verification | ✅ DONE | pipeline + test (2 Tier-3 calls) |
| Off-schema rejected + logged | ✅ DONE | `parse_analysis_result` + parser tests |
| Free tier: 4th blocked server-side (+ CR #10 reset) | ✅ DONE | free_tier Node test; Edge Function 402 |
| Tier 2 P50 < 3s / Tier 3 P50 < 6s | ⏳ MANUAL | needs live keys (runbook 14) |
| Logs mask keys / no PII | ✅ DONE | `logging_setup` + masking regex |

**Verified now:** the safety core and all five approved CRs, by unit tests on real logic. **Founder-side:** live provider latency/quality and the deployed end-to-end flow.
