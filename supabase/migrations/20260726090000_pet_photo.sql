-- Post-beta polish: a pet's own profile photo.
--
-- Stores an R2 *storage key*, never a URL. The legacy `photo_url` column is
-- deliberately left alone: a client-supplied URL was the blind-SSRF vector
-- closed in GAP-A2, and display URLs are minted server-side by /sign-media-url
-- from the key. Keys live in the `pets/` scope (upload_key.mjs), so they are
-- displayable and owner-deletable, unlike analysis `uploads/`.
alter table public.pets
  add column if not exists photo_key text;

comment on column public.pets.photo_key is
  'R2 object key for the pet''s profile photo: pets/<owner uuid>/<uuid>.<ext>. '
  'Null = no photo (the app falls back to the species avatar). Signed for '
  'display by the sign-media-url function; never a URL.';

-- Shape guard: scope, two uuids, allowlisted extension, no traversal. Mirrors
-- parseMediaKey() in supabase/functions/_shared/upload_key.mjs.
alter table public.pets
  drop constraint if exists pets_photo_key_shape_chk;
alter table public.pets
  add constraint pets_photo_key_shape_chk check (
    photo_key is null
    or photo_key ~ '^pets/[0-9a-fA-F-]{36}/[0-9a-fA-F-]{36}\.(jpg|jpeg|png|webp)$'
  );

-- Ownership guard. RLS already limits a row to its owner, but nothing stopped
-- an owner from pointing their own row at ANOTHER user's object key and having
-- the display path sign a GET for it. The key's user segment must be the row's
-- owner, enforced in the database rather than trusted from the client.
create or replace function public.pets_photo_key_owned()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if new.photo_key is not null
     and new.photo_key not like 'pets/' || new.user_id::text || '/%' then
    raise exception 'photo_key must live under pets/<owner>/ (got %)', new.photo_key
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists pets_photo_key_owned_trg on public.pets;
create trigger pets_photo_key_owned_trg
  before insert or update of photo_key, user_id on public.pets
  for each row execute function public.pets_photo_key_owned();
