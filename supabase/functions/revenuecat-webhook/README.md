# revenuecat-webhook

POST /functions/v1/revenuecat-webhook — receives subscription lifecycle events from RevenueCat.

## Setup

In RevenueCat Dashboard → Project Settings → Integrations → Webhooks:

- URL: `https://<project-ref>.functions.supabase.co/revenuecat-webhook`
- Authorization header: `Bearer <REVENUECAT_WEBHOOK_AUTH_TOKEN>`

Set the matching env in edge function secrets:

```bash
supabase secrets set REVENUECAT_WEBHOOK_AUTH_TOKEN=<token-from-revenuecat-dashboard>
```

## Phase 1A behaviour

- Validates the bearer token (constant-time)
- Validates the body shape (`event.type`, `event.app_user_id` required)
- Logs the event
- Returns `200 { "ok": true, "applied": false }` to ack

**No subscription state changes are written in Phase 1A.** Phase 1B maps:

| RevenueCat event                                         | users.subscription_status |
| -------------------------------------------------------- | ------------------------- |
| INITIAL_PURCHASE, RENEWAL, PRODUCT_CHANGE → premium tier | `premium`                 |
| INITIAL_PURCHASE, RENEWAL, PRODUCT_CHANGE → family tier  | `family`                  |
| CANCELLATION, EXPIRATION, BILLING_ISSUE                  | `free`                    |
| NON_RENEWING_PURCHASE                                    | (no change)               |

## Idempotency / retries

RevenueCat retries on non-2xx. Phase 1B writes will be idempotent (the mapping is deterministic from
the event payload).

## Privacy

The `app_user_id` is opaquely set by the mobile app (RevenueCat docs: should be a stable user
identifier, NOT email). We map it to `users.revenuecat_user_id`.
