# Runbook 28 — Observability & Alert Thresholds (GAP-D2)

> What is watched, the alert thresholds, and the channels. The degraded-MONITOR
> design *masks* outages, so these alarms are the only way an outage becomes
> visible. Wire the founder-side pieces (DSN, uptime monitor, spend caps) before beta.

## Signals & thresholds

| Signal | Source | Alert threshold | Channel |
|--------|--------|-----------------|---------|
| AI-service uncaught error | Sentry (ai-service, `_init_sentry`) | any unhandled exception | Sentry → founder email/phone |
| Edge Function error | `console.error` in analyze/webhook/upload/delete | any error spike (≥5/5min) | `_shared/alert.mjs` → Sentry/ntfy *(remaining)* |
| **Degraded-analysis rate** | server-side `analysis_completed{degraded}` | **> 10% over 1h** | PostHog insight + alert *(remaining)* |
| Moderation-reject rate | `analysis_completed{moderation_rejected}` | > 20% over 1h (possible moderator outage) | PostHog *(remaining)* |
| Service uptime | Better Stack on `/health` + Supabase REST | 2 consecutive failures | SMS/push *(founder, F-11-adjacent)* |
| P95 analysis latency | PostHog / Fly metrics | > 10s sustained | dashboard |
| Spend (Anthropic/Google/OpenAI/Fly/R2) | each console budget | 50% / 80% / 100% of monthly cap | console email *(founder F-11)* |
| Mobile crash | Sentry (Flutter, env+release tagged) | crash-free users < 99% | Sentry release health |

## Status of D2 implementation
- ✅ **ai-service Sentry** — `_init_sentry()` (env=`prod`/`dev`, `release=VERSION`,
  `send_default_pii=False`, `mask_secrets` before_send). No-op without `SENTRY_DSN`.
- ✅ **Mobile env/release tags** — `SentryFlutter.init` sets `environment` + `release`.
- ⏳ **Remaining (next pass):** `_shared/alert.mjs` for Edge `console.error`; server-side
  `analysis_completed{tier_used,degraded,moderation_rejected}` capture in `analyze`
  (pairs with the A2/A3 analyze changes — kept off this branch to avoid a conflict).
- 🚩 **Founder-gated:** `SENTRY_DSN` secret + Sentry project; Better Stack uptime; spend
  caps (F-11). The acceptance ("kill a provider key in dev → two independent alerts")
  is verifiable only once the DSN + uptime monitor are live.

## Drill (run once after DSN is live)
Unset `GOOGLE_AI_API_KEY` (or set an invalid one) on a **dev** machine → trigger one
photo analysis → expect (a) a Sentry event tagged `environment=dev` and (b) the
degraded-rate insight to tick. Both must reach the founder within minutes.
