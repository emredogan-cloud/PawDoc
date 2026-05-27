# 14 — Wire up `/analyze` (AI service + Edge Function)

Phase 1.3 ships the triage brain. Deploying it is founder-side (needs API keys).

## 1. AI service secrets (Fly)

```bash
cd ai-service
fly secrets set \
  ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  GOOGLE_AI_API_KEY="$GOOGLE_AI_API_KEY"
# optional cache + dynamic kill-switch:
fly secrets set UPSTASH_REDIS_REST_URL="..." UPSTASH_REDIS_REST_TOKEN="..."
fly deploy            # builds the new /analyze image
curl -X POST https://pawdoc-ai.fly.dev/analyze \
  -H 'content-type: application/json' \
  -d '{"input_type":"text","text_description":"my dog has a small scratch","pet":{"species":"dog","age_years":3}}'
```
You should get `{ "result": { "triage_level": ... }, "meta": { "tier_used": 2|3, ... } }`.

## 2. Edge Function

```bash
supabase functions deploy analyze --project-ref <ref>
supabase secrets set AI_SERVICE_URL="https://pawdoc-ai.fly.dev" --project-ref <ref>
```
(`SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` are injected automatically.)

## 3. Verify the safety guarantees (DoD)

- **Emergency override (pre-AI):** `text_description:"my dog is having a seizure"` → `triage_level: EMERGENCY`, `meta.emergency_override_applied: true`, with **no** provider call.
- **Tiering:** low-confidence Tier-2 escalates to Tier-3 (`meta.tier_used: 3`); EMERGENCY is cross-verified (`meta.cross_verified`).
- **Confidence gate:** ambiguous input returns the "Not enough information" MONITOR result, never a fabricated answer.
- **Free tier (CR #10):** the 4th analysis in a month returns HTTP 402 `free_limit_reached`; the counter resets next month automatically.
- **Latency:** Tier 2 P50 < 3s, Tier 3 P50 < 6s.

## 4. Kill-switch (CR #19) — disable AI without a redeploy

```bash
# dynamic (instant): set the Redis flag
#   redis> SET pawdoc:ai_kill_switch 1
# or static fallback: fly secrets set AI_KILL_SWITCH=1 (requires restart)
```
While active, `/analyze` returns the safe degraded response ("can't analyze now — if urgent, contact a vet"), never a fabricated NORMAL.

## Cost note (surfaced)
Set provider budget alerts (CR #12) on Anthropic + Google AI before opening real traffic.
