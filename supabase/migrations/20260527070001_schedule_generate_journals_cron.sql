-- Phase 5.3 — Schedule /generate-journals via pg_cron + pg_net (Sunday 00:00 UTC).
--
-- ⚠️ SUPABASE-MANAGED EXTENSIONS: pg_cron, pg_net and Vault exist on a real
-- Supabase project but NOT on a bare Postgres image, so this migration is NOT
-- exercised by the local Docker test harnesses — the founder applies it with
-- `supabase db push` (alongside `20260527040001` from Phase 3.3 P2). The
-- eligibility logic it drives (`pets_pending_journal`) lives in 20260527070000
-- and IS tested headlessly.
--
-- Reuses the SAME Vault secrets as the reminders cron — `project_url` (base URL)
-- and `cron_secret` — so no new secret is committed to git. The Edge Function
-- enforces the same `x-cron-secret` (== CRON_SECRET) header check.

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- Idempotent (re)schedule: weekly, Sunday 00:00 UTC.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'generate-journals-weekly') then
    perform cron.unschedule('generate-journals-weekly');
  end if;
end
$$;

select cron.schedule(
  'generate-journals-weekly',
  '0 0 * * 0',
  $cron$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/generate-journals',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 55000
  );
  $cron$
);
