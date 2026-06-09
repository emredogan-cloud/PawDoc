-- Phase B (RF-4 / H1): a shared-group OWNER can delete their account without a
-- pets.family_group_id RESTRICT 500 and WITHOUT losing or orphaning a CO-MEMBER's
-- pet. Self-contained (seeds its own users C + D, fresh UUIDs); runs as superuser.
-- Proves the on_user_delete_reassign_family BEFORE-DELETE trigger reassigns the
-- co-member's shared pet back to their own solo group before the owner's groups
-- cascade away. WITHOUT the Phase B trigger, the delete below 500s on RESTRICT.
reset role;

insert into auth.users (id, email) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'owner-c@test.dev'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'member-d@test.dev');

-- public.users INSERT fires users_create_solo_family -> each gets a solo group.
insert into public.users (id, email) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'owner-c@test.dev'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'member-d@test.dev');

do $$
declare
  c_group uuid;
  d_solo  uuid;
  d_pet   uuid;
begin
  select id into c_group from public.family_groups
    where owner_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  select id into d_solo from public.family_groups
    where owner_user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

  -- D joins C's household and shares a pet INTO C's group.
  insert into public.family_members (group_id, user_id, role)
    values (c_group, 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'member');
  insert into public.pets (user_id, name, species, family_group_id)
    values ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Shared-Rex', 'dog', c_group)
    returning id into d_pet;
  -- C also has their own pet (defaults to C's group via the BEFORE-INSERT trigger).
  insert into public.pets (user_id, name, species)
    values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Owner-Pet', 'cat');

  if (select family_group_id from public.pets where id = d_pet) <> c_group then
    raise exception 'setup: D''s shared pet is not in C''s group';
  end if;

  -- *** Compliance action: the shared-group OWNER deletes their account. ***
  delete from auth.users where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

  -- Owner fully removed (cascade).
  if exists (select 1 from public.users where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc') then
    raise exception 'Phase B: owner C public.users not removed';
  end if;
  if exists (select 1 from public.family_groups where id = c_group) then
    raise exception 'Phase B: C''s shared group was not cascaded away';
  end if;
  if exists (select 1 from public.pets where user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc') then
    raise exception 'Phase B: C''s own pets were not cascaded';
  end if;

  -- Co-member D untouched; the shared pet PRESERVED + reassigned to D's solo group.
  if not exists (select 1 from public.users where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd') then
    raise exception 'Phase B: co-member D must be untouched';
  end if;
  if not exists (select 1 from public.pets where id = d_pet) then
    raise exception 'Phase B: co-member D''s pet was LOST (must never delete another user''s pet)';
  end if;
  if (select family_group_id from public.pets where id = d_pet) <> d_solo then
    raise exception 'Phase B: D''s pet was not reassigned to D''s solo group';
  end if;
  if exists (select 1 from public.family_members where group_id = c_group) then
    raise exception 'Phase B: orphaned family_members remain for the deleted group';
  end if;
end
$$;

select 'PHASE B FAMILY-DELETION CASCADE OK' as result;
