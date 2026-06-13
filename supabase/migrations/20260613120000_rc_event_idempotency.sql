-- GAP-E5: idempotency ledger for RevenueCat webhook events.
--
-- RevenueCat retries a webhook on any non-2xx response and can redeliver the
-- same event. The handler grants one-time add-on credits (e.g. the $4.99 PDF
-- report) with a read-modify-write, so without a dedup guard a retried or
-- duplicated NON_RENEWING_PURCHASE would grant credits more than once.
--
-- The webhook "claims" an event by inserting its id here BEFORE applying any
-- credit. The primary key makes the claim atomic: a duplicate delivery hits a
-- unique-violation and is skipped as already-processed. On a transient failure
-- AFTER the claim, the handler deletes its claim so RevenueCat's retry can
-- re-process (the credit is never silently lost).
create table if not exists public.processed_rc_events (
  -- RevenueCat event.id (a UUID string). Kept as text so a non-UUID id can
  -- never break the insert.
  event_id     text primary key,
  app_user_id  text,
  event_type   text,
  processed_at timestamptz not null default now()
);

-- Server-only ledger: written by the revenuecat-webhook Edge Function using the
-- service_role (which bypasses RLS). RLS is enabled with NO policies, so no
-- client role (anon / authenticated) can read or write it. This is the correct
-- "deny all clients" posture for an internal table — it is not user data.
alter table public.processed_rc_events enable row level security;

comment on table public.processed_rc_events is
  'GAP-E5 idempotency ledger: one row per processed RevenueCat event_id, '
  'written by the revenuecat-webhook (service_role). RLS on, no policies — '
  'clients have no access. Not user data.';
