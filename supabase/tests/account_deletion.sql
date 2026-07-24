-- CR #9 cascade test: deleting the auth user removes ALL their app data via the
-- ON DELETE CASCADE FKs (Phase 1.1 / CR #20). Runs after rls_isolation.sql in
-- the same psql session (fixtures already seeded; user A has 2 pets by now).
reset role;

delete from auth.users where id = '11111111-1111-1111-1111-111111111111';

do $$
begin
  if exists (select 1 from public.users where id = '11111111-1111-1111-1111-111111111111') then
    raise exception 'CR #9: public.users row for A was not cascaded';
  end if;
  if (select count(*) from public.pets where user_id = '11111111-1111-1111-1111-111111111111') <> 0 then
    raise exception 'CR #9: pets for A were not cascaded';
  end if;
  if (select count(*) from public.analyses where user_id = '11111111-1111-1111-1111-111111111111') <> 0 then
    raise exception 'CR #9: analyses for A were not cascaded';
  end if;
  if (select count(*) from public.health_events) <> 1 then
    raise exception 'CR #9: A''s health_events not cascaded (B''s one should remain)';
  end if;
  if (select count(*) from public.pet_memories
      where user_id = '11111111-1111-1111-1111-111111111111') <> 0 then
    raise exception 'CR #9: pet_memories for A were not cascaded';
  end if;
  if (select count(*) from public.pet_memories
      where user_id = '22222222-2222-2222-2222-222222222222') <> 1 then
    raise exception 'CR #9: B''s pet_memories should be untouched';
  end if;
  if (select count(*) from public.assistant_conversations
      where user_id = '11111111-1111-1111-1111-111111111111') <> 0 then
    raise exception 'CR #9: assistant_conversations for A were not cascaded';
  end if;
  if (select count(*) from public.assistant_messages
      where user_id = '11111111-1111-1111-1111-111111111111') <> 0 then
    raise exception 'CR #9: assistant_messages for A were not cascaded';
  end if;
  if (select count(*) from public.assistant_conversations
      where user_id = '22222222-2222-2222-2222-222222222222') <> 1 then
    raise exception 'CR #9: B''s assistant_conversations should be untouched';
  end if;
  -- Paw Community (Phase 6): deleting A dissolves A's entire social graph.
  if exists (select 1 from public.community_profiles
             where user_id = '11111111-1111-1111-1111-111111111111') then
    raise exception 'CR #9: community_profile for A was not cascaded';
  end if;
  if (select count(*) from public.community_connections) <> 0 then
    raise exception 'CR #9: A''s community_connections were not cascaded';
  end if;
  if (select count(*) from public.community_messages) <> 0 then
    raise exception 'CR #9: A''s community_messages were not cascaded';
  end if;
  if (select count(*) from public.walk_proposals) <> 0 then
    raise exception 'CR #9: A''s walk_proposals were not cascaded';
  end if;
  if (select count(*) from public.community_reports) <> 0 then
    raise exception 'CR #9: A''s community_reports were not cascaded';
  end if;
  if (select count(*) from public.community_profiles) <> 2 then
    raise exception 'CR #9: B/C community_profiles should remain';
  end if;
  -- User B must be untouched.
  if (select count(*) from public.users where id = '22222222-2222-2222-2222-222222222222') <> 1 then
    raise exception 'CR #9: user B should be untouched';
  end if;
end
$$;

select 'ACCOUNT DELETION CASCADE OK' as result;
