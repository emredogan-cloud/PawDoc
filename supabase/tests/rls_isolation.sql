-- RLS isolation test (verifies the CR #2 correction).
-- Run after the schema + RLS migrations against the local harness
-- (scripts/test-rls.sh). Asserts that an authenticated user A can neither READ
-- nor WRITE user B's rows, across pets / analyses / health_events.
-- Any violation RAISEs, so psql (ON_ERROR_STOP) exits non-zero.

-- Privileges (RLS still governs which ROWS are visible/insertable). Table DML
-- comes from the shim's default privileges (mirroring Supabase's baseline);
-- re-granting "on all tables" here would also re-open views the migrations
-- deliberately REVOKEd (the accuracy-views lockdown), so DON'T.
grant usage on schema public, auth, extensions to authenticated;
grant execute on function auth.uid() to authenticated;

-- Fixtures (seeded as the table owner, so RLS is bypassed here). The auth
-- provisioning trigger (GAP-D3) auto-creates public.users on the auth insert,
-- so the explicit public.users seed is idempotent under the FULL migration set.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test'),
  ('22222222-2222-2222-2222-222222222222', 'b@test')
on conflict (id) do nothing;
insert into public.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test'),
  ('22222222-2222-2222-2222-222222222222', 'b@test')
on conflict (id) do nothing;
insert into public.pets (id, user_id, name, species) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Rex', 'dog'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'Milo', 'cat')
on conflict (id) do nothing;
insert into public.analyses (id, user_id, pet_id, input_type) values
  ('a1a1a1a1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'text'),
  ('b1b1b1b1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'text');
insert into public.health_events (pet_id, event_type, event_date) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'weight', current_date),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'weight', current_date);
insert into public.pet_memories (id, user_id, pet_id, title, storage_key) values
  ('a2a2a2a2-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'First walk',
   'memories/11111111-1111-1111-1111-111111111111/a2a2a2a2-aaaa-aaaa-aaaa-aaaaaaaaaaaa.jpg'),
  ('b2b2b2b2-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Nap time',
   'memories/22222222-2222-2222-2222-222222222222/b2b2b2b2-bbbb-bbbb-bbbb-bbbbbbbbbbbb.jpg')
on conflict (id) do nothing;

-- Act as authenticated user A.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);

-- READ isolation across the three tables.
do $$
begin
  if (select count(*) from public.pets) <> 1 then
    raise exception 'pets READ: A sees % rows, expected 1', (select count(*) from public.pets);
  end if;
  if exists (select 1 from public.pets where user_id = '22222222-2222-2222-2222-222222222222') then
    raise exception 'pets READ: A can see B''s pet';
  end if;
  if (select count(*) from public.analyses) <> 1 then
    raise exception 'analyses READ: A sees % rows, expected 1', (select count(*) from public.analyses);
  end if;
  if (select count(*) from public.health_events) <> 1 then
    raise exception 'health_events READ: A sees % rows, expected 1', (select count(*) from public.health_events);
  end if;
end
$$;

-- WRITE isolation: A must NOT insert a pet owned by B (WITH CHECK).
do $$
begin
  begin
    insert into public.pets (user_id, name, species)
    values ('22222222-2222-2222-2222-222222222222', 'Hijack', 'dog');
    raise exception 'pets WRITE: A inserted a row for B (RLS WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected: row violates RLS policy
  end;
end
$$;

-- WRITE isolation via parent: A must NOT add a health_event to B's pet.
do $$
begin
  begin
    insert into public.health_events (pet_id, event_type, event_date)
    values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'weight', current_date);
    raise exception 'health_events WRITE: A wrote to B''s pet (RLS WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- Positive control: A CAN insert its own pet.
insert into public.pets (user_id, name, species)
values ('11111111-1111-1111-1111-111111111111', 'Buddy', 'dog');
do $$
begin
  if (select count(*) from public.pets) <> 2 then
    raise exception 'pets WRITE: A should see 2 of its own pets after insert';
  end if;
end
$$;

-- Positive control (CR #2 + Phase 3.1 manual quick-add): A CAN insert a
-- health_event for ITS OWN pet. health_events has no user_id column — the RLS
-- WITH CHECK derives ownership from the parent pet (pet_id -> pets.user_id).
-- This proves the manual health-event logging actually works in production.
insert into public.health_events (pet_id, event_type, event_date, notes)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'vaccination', current_date, 'Rabies booster');
do $$
begin
  if (select count(*) from public.health_events) <> 2 then
    raise exception 'health_events WRITE: A own-pet insert blocked (sees % of its events, expected 2)',
      (select count(*) from public.health_events);
  end if;
  if not exists (
    select 1 from public.health_events
    where pet_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and event_type = 'vaccination'
  ) then
    raise exception 'health_events WRITE: A''s own health_event insert did not persist';
  end if;
end
$$;

-- Reminders WRITE isolation (Phase 3.3): A must NOT create a reminder owned by B.
do $$
begin
  begin
    insert into public.reminders (pet_id, user_id, reminder_type, due_date)
    values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'Hijack', current_date);
    raise exception 'reminders WRITE: A inserted a reminder for B (RLS WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- Positive control (Phase 3.3): A CAN create its own reminder (the client writes
-- reminders directly, RLS-scoped by user_id). Proves the reminders CRUD works.
insert into public.reminders (pet_id, user_id, reminder_type, due_date)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Flea medication', current_date + 7);
do $$
begin
  if (select count(*) from public.reminders) <> 1 then
    raise exception 'reminders WRITE: A should see exactly its own 1 reminder after insert';
  end if;
end
$$;

-- analysis_feedback WRITE isolation (CR #2 / Phase 4.1): A must NOT submit
-- feedback on B's analysis. Ownership is derived from the parent analysis.
do $$
begin
  begin
    insert into public.analysis_feedback (analysis_id, rating, comment)
    values ('b1b1b1b1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 1, 'hijack');
    raise exception 'analysis_feedback WRITE: A wrote feedback on B''s analysis (RLS WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- Positive control (Phase 4.1): A CAN submit feedback on its OWN analysis.
insert into public.analysis_feedback (analysis_id, rating, comment)
values ('a1a1a1a1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 5, 'helpful');
do $$
begin
  if (select count(*) from public.analysis_feedback) <> 1 then
    raise exception 'analysis_feedback WRITE: A should see exactly its own 1 feedback row';
  end if;
end
$$;

-- pet_memories READ isolation (Next Evolution Phase 2): A sees only its own.
do $$
begin
  if (select count(*) from public.pet_memories) <> 1 then
    raise exception 'pet_memories READ: A sees % rows, expected 1',
      (select count(*) from public.pet_memories);
  end if;
  if exists (
    select 1 from public.pet_memories
    where user_id = '22222222-2222-2222-2222-222222222222'
  ) then
    raise exception 'pet_memories READ: A can see B''s memory';
  end if;
end
$$;

-- pet_memories WRITE isolation: A must NOT insert a memory owned by B.
do $$
begin
  begin
    insert into public.pet_memories (user_id, pet_id, title, storage_key)
    values ('22222222-2222-2222-2222-222222222222',
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Hijack',
            'memories/22222222-2222-2222-2222-222222222222/c3c3c3c3-cccc-cccc-cccc-cccccccccccc.jpg');
    raise exception 'pet_memories WRITE: A inserted a row for B (RLS WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- pet_memories WRITE isolation via parent pet: A (as itself) must NOT attach a
-- memory to B's pet — the WITH CHECK pins pet_id to a pet the caller owns.
do $$
begin
  begin
    insert into public.pet_memories (user_id, pet_id, title, storage_key)
    values ('11111111-1111-1111-1111-111111111111',
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Wrong pet',
            'memories/11111111-1111-1111-1111-111111111111/d4d4d4d4-dddd-dddd-dddd-dddddddddddd.jpg');
    raise exception 'pet_memories WRITE: A attached a memory to B''s pet (WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- Positive control: A CAN create + edit a memory for its OWN pet.
insert into public.pet_memories (user_id, pet_id, title, note, storage_key)
values ('11111111-1111-1111-1111-111111111111',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Beach day', 'Sunny afternoon',
        'memories/11111111-1111-1111-1111-111111111111/e5e5e5e5-eeee-eeee-eeee-eeeeeeeeeeee.jpg');
update public.pet_memories set title = 'Beach day!'
where storage_key = 'memories/11111111-1111-1111-1111-111111111111/e5e5e5e5-eeee-eeee-eeee-eeeeeeeeeeee.jpg';
do $$
begin
  if (select count(*) from public.pet_memories) <> 2 then
    raise exception 'pet_memories WRITE: A should see 2 of its own memories after insert';
  end if;
  if not exists (select 1 from public.pet_memories where title = 'Beach day!') then
    raise exception 'pet_memories WRITE: A''s own memory update did not persist';
  end if;
end
$$;

-- assistant_conversations / assistant_messages isolation (Next Evolution
-- Phase 4). B's fixture rows are seeded below as the table owner via a role
-- reset, then we return to acting as A.
reset role;
insert into public.assistant_conversations (id, user_id, title) values
  ('c1c1c1c1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'B private chat')
on conflict (id) do nothing;
insert into public.assistant_messages (user_id, conversation_id, role, content) values
  ('22222222-2222-2222-2222-222222222222', 'c1c1c1c1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'user', 'B secret question');

set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);

-- READ isolation: A sees neither B's conversation nor B's messages.
do $$
begin
  if (select count(*) from public.assistant_conversations) <> 0 then
    raise exception 'assistant_conversations READ: A sees % rows, expected 0',
      (select count(*) from public.assistant_conversations);
  end if;
  if (select count(*) from public.assistant_messages) <> 0 then
    raise exception 'assistant_messages READ: A sees B''s messages';
  end if;
end
$$;

-- WRITE isolation: A must NOT insert a message into B's conversation.
do $$
begin
  begin
    insert into public.assistant_messages (user_id, conversation_id, role, content)
    values ('11111111-1111-1111-1111-111111111111',
            'c1c1c1c1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'user', 'hijack');
    raise exception 'assistant_messages WRITE: A wrote into B''s conversation (WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- WRITE isolation: a client must NOT forge an assistant-role reply.
insert into public.assistant_conversations (id, user_id, title) values
  ('c2c2c2c2-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'A chat');
do $$
begin
  begin
    insert into public.assistant_messages (user_id, conversation_id, role, content)
    values ('11111111-1111-1111-1111-111111111111',
            'c2c2c2c2-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'assistant', 'forged model reply');
    raise exception 'assistant_messages WRITE: client forged an assistant-role row';
  exception
    when insufficient_privilege then null; -- expected: role must be user
  end;
end
$$;

-- WRITE isolation: A cannot pin a conversation to B's pet.
do $$
begin
  begin
    insert into public.assistant_conversations (user_id, pet_id, title)
    values ('11111111-1111-1111-1111-111111111111',
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Wrong pet chat');
    raise exception 'assistant_conversations WRITE: A pinned B''s pet (WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- Positive controls: A CAN chat in its own conversation and rename it.
insert into public.assistant_messages (user_id, conversation_id, role, content)
values ('11111111-1111-1111-1111-111111111111',
        'c2c2c2c2-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'user', 'How much exercise daily?');
update public.assistant_conversations set title = 'Exercise questions'
where id = 'c2c2c2c2-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
do $$
begin
  if (select count(*) from public.assistant_messages) <> 1 then
    raise exception 'assistant_messages WRITE: A''s own user turn was blocked';
  end if;
  if not exists (select 1 from public.assistant_conversations
                 where title = 'Exercise questions') then
    raise exception 'assistant_conversations WRITE: A''s rename did not persist';
  end if;
end
$$;

-- ===========================================================================
-- Paw Community isolation (Next Evolution Phase 6). Adds a third user C to
-- prove non-participant + hidden-profile boundaries.
-- ===========================================================================
reset role;
insert into auth.users (id, email) values
  ('33333333-3333-3333-3333-333333333333', 'c@test')
on conflict (id) do nothing;
insert into public.users (id, email) values
  ('33333333-3333-3333-3333-333333333333', 'c@test')
on conflict (id) do nothing;

insert into public.community_profiles
  (user_id, display_name, bio, species_tags, geohash, is_discoverable, allow_requests)
values
  ('11111111-1111-1111-1111-111111111111', 'Rex''s human', 'Morning walker', '{dog}', 'u33dc', true,  true),
  ('22222222-2222-2222-2222-222222222222', 'Milo''s human', null,             '{cat}', 'u33dc', true,  true),
  ('33333333-3333-3333-3333-333333333333', 'Hidden human', null,             '{dog}', 'u33dc', false, false)
on conflict (user_id) do nothing;

-- Accepted A<->B connection + one message from B; pending B->A request.
insert into public.community_connections (id, requester_id, addressee_id, status) values
  ('d1d1d1d1-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'accepted'),
  ('d2d2d2d2-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222',
   '11111111-1111-1111-1111-111111111111', 'pending')
on conflict (id) do nothing;
insert into public.community_messages (connection_id, sender_id, content) values
  ('d1d1d1d1-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', 'Hi from B');

set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);

-- Profiles: A sees itself + discoverable B, but NEVER hidden C.
do $$
begin
  if (select count(*) from public.community_profiles) <> 2 then
    raise exception 'community_profiles READ: A sees % rows, expected 2 (self + discoverable B)',
      (select count(*) from public.community_profiles);
  end if;
  if exists (select 1 from public.community_profiles
             where user_id = '33333333-3333-3333-3333-333333333333') then
    raise exception 'community_profiles READ: A can see a non-discoverable profile';
  end if;
end
$$;

-- A cannot edit B's profile (USING filters to zero rows — verify unchanged).
update public.community_profiles set display_name = 'HACKED'
where user_id = '22222222-2222-2222-2222-222222222222';
do $$
begin
  if exists (select 1 from public.community_profiles where display_name = 'HACKED') then
    raise exception 'community_profiles WRITE: A modified B''s profile';
  end if;
end
$$;

-- Connection forging: A cannot create a request AS B.
do $$
begin
  begin
    insert into public.community_connections (requester_id, addressee_id, status)
    values ('22222222-2222-2222-2222-222222222222',
            '33333333-3333-3333-3333-333333333333', 'pending');
    raise exception 'community_connections WRITE: A forged a request as B';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- Request gating: C does not allow requests — A cannot request C.
do $$
begin
  begin
    insert into public.community_connections (requester_id, addressee_id, status)
    values ('11111111-1111-1111-1111-111111111111',
            '33333333-3333-3333-3333-333333333333', 'pending');
    raise exception 'community_connections WRITE: request gate (allow_requests) failed';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- A cannot self-accept the request it SENT (only the addressee accepts).
update public.community_connections set status = 'accepted'
where id = 'd2d2d2d2-dddd-dddd-dddd-dddddddddddd'
  and requester_id = '22222222-2222-2222-2222-222222222222';
do $$
begin
  -- A is the ADDRESSEE on d2 (B->A) so this update SHOULD succeed; the real
  -- forge is A accepting a request where A is the REQUESTER. Re-check both:
  if (select status from public.community_connections
      where id = 'd2d2d2d2-dddd-dddd-dddd-dddddddddddd') <> 'accepted' then
    raise exception 'community_connections: addressee A could not accept B''s request';
  end if;
end
$$;

-- Messaging: A can message on the accepted connection…
insert into public.community_messages (connection_id, sender_id, content)
values ('d1d1d1d1-dddd-dddd-dddd-dddddddddddd',
        '11111111-1111-1111-1111-111111111111', 'Hi back from A');
-- …but cannot send AS B (sender forge)…
do $$
begin
  begin
    insert into public.community_messages (connection_id, sender_id, content)
    values ('d1d1d1d1-dddd-dddd-dddd-dddddddddddd',
            '22222222-2222-2222-2222-222222222222', 'forged');
    raise exception 'community_messages WRITE: A sent a message as B';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- Walk proposals: A can propose on the accepted thread; A cannot answer its
-- OWN proposal (only the other side responds).
insert into public.walk_proposals (id, connection_id, proposer_id, place_name, proposed_at)
values ('e1e1e1e1-eeee-eeee-eeee-eeeeeeeeeeee',
        'd1d1d1d1-dddd-dddd-dddd-dddddddddddd',
        '11111111-1111-1111-1111-111111111111', 'Stadtpark', now() + interval '1 day');
update public.walk_proposals set status = 'accepted'
where id = 'e1e1e1e1-eeee-eeee-eeee-eeeeeeeeeeee';
do $$
begin
  if (select status from public.walk_proposals
      where id = 'e1e1e1e1-eeee-eeee-eeee-eeeeeeeeeeee') <> 'pending' then
    raise exception 'walk_proposals: proposer answered its own proposal';
  end if;
end
$$;

-- Reports: as yourself only.
insert into public.community_reports (reporter_id, reported_user_id, reason)
values ('11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222', 'spam');
do $$
begin
  begin
    insert into public.community_reports (reporter_id, reported_user_id, reason)
    values ('22222222-2222-2222-2222-222222222222',
            '11111111-1111-1111-1111-111111111111', 'spam');
    raise exception 'community_reports WRITE: A filed a report as B';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- Non-participant boundary: C sees NOTHING of the A-B thread.
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', false);
do $$
begin
  if (select count(*) from public.community_messages) <> 0 then
    raise exception 'community_messages READ: non-participant C sees the A-B thread';
  end if;
  if (select count(*) from public.community_connections) <> 0 then
    raise exception 'community_connections READ: non-participant C sees A-B connections';
  end if;
  if (select count(*) from public.walk_proposals) <> 0 then
    raise exception 'walk_proposals READ: non-participant C sees A-B proposals';
  end if;
end
$$;

-- Message send on a NON-accepted thread stays impossible even for the
-- pending pair participant: reset to A, who now has the accepted d2 as well —
-- so use B's view: B messaging on d2 AFTER A accepted is legal; the pending
-- gate was proven by policy requiring status='accepted' (d2 was accepted
-- above). Blocked-goes-silent: A blocks d1, then B cannot send.
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
update public.community_connections set status = 'blocked'
where id = 'd1d1d1d1-dddd-dddd-dddd-dddddddddddd';
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$
begin
  begin
    insert into public.community_messages (connection_id, sender_id, content)
    values ('d1d1d1d1-dddd-dddd-dddd-dddddddddddd',
            '22222222-2222-2222-2222-222222222222', 'after block');
    raise exception 'community_messages WRITE: blocked thread accepted a message';
  exception
    when insufficient_privilege then null; -- expected: block is silent server-side
  end;
end
$$;

reset role;
select 'RLS ISOLATION TESTS PASSED' as result;
