# auth-webhook

POST /functions/v1/auth-webhook — receives Supabase Auth events and mirrors them into the
`public.users` table.

## Setup

In the Supabase Dashboard → Authentication → Hooks → "Send HTTP Hook":

- URL: `https://<project-ref>.functions.supabase.co/auth-webhook`
- Headers: `Authorization: Bearer <SUPABASE_AUTH_WEBHOOK_SECRET>`
- Events: `user.created`, `user.deleted` (insert + delete on auth.users)

Set the matching env in edge function secrets:

```bash
supabase secrets set SUPABASE_AUTH_WEBHOOK_SECRET=<random-32-byte-hex>
```

## Phase 1A behaviour

| Event                     | Action                                                               |
| ------------------------- | -------------------------------------------------------------------- |
| `INSERT` / `user.created` | INSERT into public.users (id, email). Idempotent on unique-violation |
| `UPDATE`                  | Logged, no action (Phase 1B will mirror email changes)               |
| `DELETE` / `user.deleted` | Logged; cascade in DB handles the row delete                         |

## Authentication

Constant-time bearer-token check via `_shared/auth.ts#verifyWebhookSecret`. Missing or wrong token
→ 401.

## Failure semantics

Returns 200 only on successful processing. Any DB error → 502; Supabase will retry. We rely on the
unique constraint on `users.id` for idempotency.
