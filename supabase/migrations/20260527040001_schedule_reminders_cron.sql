-- Phase 3.3 (Part 2) — Schedule /process-reminders via pg_cron + pg_net.
--
-- ⚠️ SUPABASE-MANAGED EXTENSIONS: pg_cron, pg_net and Vault exist on a real
-- Supabase project but NOT on a bare Postgres image, so this migration is NOT
-- exercised by the local Docker test harnesses — it is applied by the founder
-- with `supabase db push` (see docs/runbooks). The query logic it drives lives
-- in 20260527040000 and IS tested headlessly.
--
-- NO SECRETS IN GIT: the project URL and the cron secret are read at run time
-- from Supabase Vault (`vault.decrypted_secrets`). The founder sets them once:
--   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--   select vault.create_secret('<random-long-secret>', 'cron_secret');
-- and sets the SAME value as CRON_SECRET on the Edge Function (Doppler / supabase
-- secrets set), which /process-reminders checks on every call.

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- Idempotent (re)schedule: hourly, on the hour.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'process-reminders-hourly') then
    perform cron.unschedule('process-reminders-hourly');
  end if;
end
$$;

select cron.schedule(
  'process-reminders-hourly',
  '0 * * * *',
  $cron$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/process-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 25000
  );
  $cron$
);
