# 12 — Observability (Sentry, PostHog, Better Uptime)

Stand up error tracking, product analytics, and uptime monitoring, and prove each receives data.

## Sentry (crashes/errors)

1. <https://sentry.io> → create project, platform **Flutter**.
2. Copy the **DSN** → Doppler:
   ```bash
   doppler secrets set SENTRY_DSN="https://…@…ingest.sentry.io/…" --project pawdoc --config prd
   ```
3. Wired into the Flutter app in Phase 1.1; **test event** confirms delivery (the 1.1 task throws a test exception).

## PostHog (product analytics)

The roadmap task is **self-hosted PostHog on Fly.io**. For a solo founder that is operationally heavy (ClickHouse-backed).

- **Roadmap path (self-host):** deploy via PostHog's Fly/Docker guide; capture `POSTHOG_HOST` = your instance URL.
- **Surfaced alternative — Critical Review #18:** **PostHog Cloud** has a generous free tier and removes the ops burden. Recommended for one person — *your decision; not auto-applied.*

Either way, store keys and send a test event:
```bash
doppler secrets set POSTHOG_API_KEY="phc_…"            --project pawdoc --config prd
doppler secrets set POSTHOG_HOST="https://us.i.posthog.com" --project pawdoc --config prd
```

## Better Uptime (liveness)

Create monitors and confirm green:
- `https://pawdoc-ai.fly.dev/health` (AI service)
- Supabase project health URL (dev + prod)
- Landing page / web checker (added in Phase 4.3 / 5.2)

Set an on-call alert (email/SMS) for the AI-service monitor — it is the 2am promise.

## Verify (Phase 0.4 exit gate)

- [ ] Sentry receives a test event.
- [ ] PostHog receives a test event.
- [ ] Better Uptime shows all monitors **green**.

## Surfaced proposal — Critical Review #12: budget alerts

No spend alerting is specified for metered services. **Recommended:** set budget alerts now on **Fly.io, Cloudflare R2, Anthropic, Google AI, Supabase** (and OneSignal/Google Places as added). A cost-runaway bug or abuse otherwise bills silently. Surfaced for your decision — not auto-applied.
