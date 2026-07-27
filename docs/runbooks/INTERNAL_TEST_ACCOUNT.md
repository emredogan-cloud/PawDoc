# Internal test account — permanent Premium

PawDoc keeps one internal QA account with permanent Premium access so the paid
surfaces can be exercised on real devices without repeatedly buying (or
sandbox-refunding) the product.

```
email     test.tester@pawdoc.app
uid       d9b28fd7-a6a9-4efa-8aea-dae751f0c1fb
status    subscription_status = 'internal_tester'
```

## How it works

Premium is normally granted by a RevenueCat purchase: the store fires a webhook,
`supabase/functions/revenuecat-webhook` writes `users.subscription_status`, and
every gate reads that column. The internal grant uses **the same column and the
same gates** — it is simply one more accepted value:

```js
// supabase/functions/_shared/premium.mjs — the single definition
export const INTERNAL_TESTER_STATUS = "internal_tester";
export const PREMIUM_STATUSES = new Set(["premium", "trial", INTERNAL_TESTER_STATUS]);
```

Four gates consume it, and they all import from that one module (or mirror it):

| Gate | File |
|---|---|
| Photo-check quota | `supabase/functions/analyze/index.ts` |
| Assistant daily limit | `supabase/functions/_shared/assistant_chat.mjs` |
| PDF Health Report | `supabase/functions/generate-pdf-report/index.ts` |
| Client UI (paywall, meters, Memories cap) | `mobile/lib/src/account/user_profile.dart` |

## Why this is not a global bypass

- **No client can grant it to itself.** `authenticated` holds *no* table-level
  `UPDATE` grant on `public.users`, so a self-`PATCH` of `subscription_status`
  fails with `42501 permission denied` before RLS is even consulted. Verified
  against the live database — both a self-promotion to `premium` and an attempt
  to zero the photo-quota counter are rejected.
- **It is per-row, not a flag.** There is no "if debug then premium" branch, no
  environment switch, and no email-pattern match anywhere in the app. Exactly one
  row in `public.users` carries this status.
- **The purchase flow is untouched.** Every other account still buys through
  RevenueCat, still receives `premium` from the webhook, and still restores
  normally. Removing the grant changes nothing for them.
- **It is distinguishable.** Because the status is `internal_tester` rather than
  a plain `premium` row, support, analytics and revenue reporting can tell an
  internal tester apart from a paying customer at a glance.
- **A store event cannot clobber it.** The RevenueCat webhook's update carries
  `.neq("subscription_status", INTERNAL_TESTER_STATUS)`, so a stray EXPIRATION
  for a stale sandbox purchase cannot silently strip the QA account's access
  mid-test.

## Granting / revoking

Use the script (service role required — it will not run without it):

```bash
doppler run -p pawdoc -c dev -- ./scripts/grant-internal-tester.sh status test.tester@pawdoc.app
doppler run -p pawdoc -c dev -- ./scripts/grant-internal-tester.sh grant  test.tester@pawdoc.app
doppler run -p pawdoc -c dev -- ./scripts/grant-internal-tester.sh revoke test.tester@pawdoc.app   # back to 'free'
```

The account must exist in Auth first; the `public.users` row is created by the
signup trigger on first sign-in.

## Verifying the grant

```
tester  → POST /functions/v1/generate-pdf-report  →  200
free    → POST /functions/v1/generate-pdf-report  →  402 premium_required
```

Both were confirmed against the deployed functions after the grant was applied.

## If you ever retire the account

Run `revoke`, then delete the account normally from the app (which exercises the
same deletion cascade every user gets). Nothing else references the uid.
