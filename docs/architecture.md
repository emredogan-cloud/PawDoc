# PawDoc — System Architecture

> **Source of truth:** [`roadmaps/APP_EXECUTION_ROADMAP.md`](../roadmaps/APP_EXECUTION_ROADMAP.md) — sections 3, 4, 5, 9.
> This document is the operator-friendly summary; the roadmap is binding when they disagree.

---

## High-Level Topology

```
   ┌──────────────────────────────────────────────────────────┐
   │                Flutter App (iOS + Android)                │
   │                                                            │
   │   Riverpod state · go_router · Material 3 · Hive cache    │
   │      └── On-device pre-filter (CoreML / TFLite)           │
   └──────┬─────────────────────────────────────────┬─────────┘
          │ JWT-auth'd API calls                    │ Image upload
          │                                          ▼
          │                              ┌───────────────────────┐
          │                              │  Cloudflare R2 + WAF  │
          │                              └───────────────────────┘
          ▼
   ┌──────────────────────────────────────────────────────────┐
   │                       Supabase                            │
   │   Auth (JWT) · Postgres 16 + pgvector · Edge Functions    │
   │   ────────────────────────────────────────────────────    │
   │   Every table: RLS enabled. auth.uid() gates user data.   │
   └──────┬─────────────────────────────────────────┬─────────┘
          │ Edge Function "/analyze" forwards        │
          ▼                                           │
   ┌──────────────────────────┐                       │
   │  AI Service (Fly.io)     │                       │
   │  Python FastAPI          │                       │
   │  ─────────────────────   │                       │
   │  emergency override      │                       │
   │  Tier 2 — Gemini Flash   │     stores results    │
   │  Tier 3 — Claude Sonnet  ├───────────────────────┘
   │  Tier 4 — Claude Opus    │
   │  Upstash Redis cache     │
   └──────────────────────────┘
```

## Service Boundaries

| Service | Owns | Doesn't Own |
|---------|------|-------------|
| **mobile** | UX, on-device pre-filter, R2 upload, calling Supabase + AI service | Business rules (rate limits, paywall enforcement), data integrity |
| **supabase** | Identity, data persistence, RLS, billing webhooks, free-tier counter, edge-function routing | AI orchestration, image storage |
| **ai-service** | Tier routing, safety overrides, prompt engineering, structured-output validation, semantic cache | User data, billing, persistence |
| **R2** | Image bytes | Anything with PII directly attached |

## Hard Rules (Cross-Cutting)

1. **RLS-first.** Every Postgres table that holds user data is `ENABLE ROW LEVEL SECURITY` with an `auth.uid()`-gated policy. The CI workflow `supabase-ci.yml` lints migrations to enforce this. The service-role key bypasses RLS and is used ONLY by ai-service + edge functions for explicit writes — never for user reads.
2. **Emergency override pre-AI.** Hardcoded keyword detection in `ai-service` runs BEFORE any AI provider call. Any match short-circuits to `EMERGENCY` regardless of model output.
3. **Structured output only.** Every AI provider call uses tool/JSON-schema mode. Free text is rejected. Pydantic models validate before the result is returned to the edge function.
4. **Disclaimers at API level.** Result payloads include `disclaimer_required` plus the disclaimer text — UI is not the source of truth.
5. **Free-tier enforcement is server-side.** The mobile app shows the counter; the edge function gates the call.
6. **EMERGENCY is never paywalled.** Edge function bypasses tier checks when the override fires.
7. **Secrets from env only.** Loaded via `app.core.config.Settings` (Python), `--dart-define` (Dart), `Deno.env.get` (Edge Fn). No `.env` file is read at runtime in any deployed environment — Doppler injects directly.
8. **No `dynamic` in Dart.** Strict casts + inference enforced by the analyzer.
9. **No bare `except` in Python.** Catch `Exception` only in the top-level handler; subclass `PawDocError` for app-level errors.

## Data Flow — Analysis Request (Phase 1+)

See roadmap §4 for the full mermaid sequence diagram. Phase 0 doesn't yet
implement this; the seams exist in code (the edge function and AI-service
directories) but the wiring is the Phase 1 deliverable.

## Deployment Topology

| Service | Hosting | URL pattern |
|---------|---------|-------------|
| mobile | App Store + Play Store (Phase 2) | n/a |
| supabase | Supabase managed Postgres + Edge Functions | `https://<project-ref>.supabase.co` |
| ai-service | Fly.io | `https://pawdoc-ai-{dev,prod}.fly.dev` |
| R2 buckets | Cloudflare | `pawdoc-uploads-{dev,prod}` |

## Observability

| Concern | Tool | Phase |
|---------|------|-------|
| Errors (mobile + AI service) | Sentry | Phase 1 |
| Product analytics + A/B | PostHog (self-hosted) | Phase 1 |
| Uptime | Better Uptime | Phase 0 (configured externally) |
| Subscription analytics | RevenueCat | Phase 1 |
| App-store reviews | AppFollow | Phase 2 |

## Scaling Plan (cf. roadmap §5)

| Trigger | Action |
|---------|--------|
| 10M+ analyses rows | Partition `analyses` by month |
| 1M+ embeddings | Migrate from pgvector to Pinecone |
| 100K+ MAU | Add Supabase read replicas |
| 200+ concurrent users | Enable pgBouncer (Supabase Pro) |
| Stable $5M+ ARR | Consider Supabase self-host |

## Where to Read Next

- Local dev: [`local-development.md`](local-development.md)
- Cloud account setup: [`environment-setup.md`](environment-setup.md)
- Deployment: [`deployment.md`](deployment.md)
- CI/CD: [`ci-cd.md`](ci-cd.md)
- Phase 0 plan: [`reports/phase0-foundation-plan.md`](reports/phase0-foundation-plan.md)
