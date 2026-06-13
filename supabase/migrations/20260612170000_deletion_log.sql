-- GAP-A6: compliance evidence for account deletion (GDPR/KVKK erasure +
-- Apple 5.1.1(v)). The /delete-account Edge Function inserts one row per
-- deletion via the service role. NO PII is stored — only a SHA-256 hash of the
-- uid, the count of R2 objects purged, and the third-party deletion statuses.
create table if not exists public.deletion_log (
  id uuid primary key default gen_random_uuid(),
  uid_hash text not null,
  r2_objects_deleted integer not null default 0,
  third_party jsonb not null default '{}'::jsonb,
  deleted_at timestamptz not null default now()
);

-- RLS on with NO policies => deny-all for anon/authenticated. The service role
-- (used only by the Edge Function) bypasses RLS by design, so it can insert.
alter table public.deletion_log enable row level security;
revoke all on public.deletion_log from anon, authenticated;

comment on table public.deletion_log is
  'GAP-A6 account-deletion audit trail. uid_hash only (no PII). Service-role insert; deny-all for users.';
