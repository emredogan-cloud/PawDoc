-- LOCAL TEST SHIM ONLY. Provides the Supabase-managed objects (the extensions
-- and auth schemas, auth.uid(), and the `authenticated` role) that exist on a
-- real Supabase project but not in a bare Postgres image. This is NOT a
-- migration and is never applied to dev/prod — it only backs scripts/test-rls.sh.
create schema if not exists extensions;
create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text
);

-- Mirrors Supabase's auth.uid(): reads the 'sub' claim from the request JWT.
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid;
$$;

-- Supabase's built-in roles. Real projects ship anon/authenticated/service_role;
-- the harness creates them so GRANT/REVOKE in the migrations apply identically.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
end
$$;

-- Mirror Supabase's baseline: anon/authenticated receive table DML by default
-- (RLS then gates rows; per-migration GRANT/REVOKE then tightens columns/ops).
-- Set as a default privilege so tables created by the migrations below inherit
-- it, exactly as on a real project — letting tests assert the Phase 3.3 lockdowns.
alter default privileges in schema public grant select, insert, update, delete on tables to anon, authenticated;
