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

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end
$$;
