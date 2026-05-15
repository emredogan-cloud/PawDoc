-- =============================================================================
-- RLS cross-user isolation — pgTAP test suite
-- =============================================================================
-- Verifies every Phase 1A table prevents cross-user data access through the
-- authenticated role. Service role bypasses RLS (Postgres BYPASSRLS) — that
-- is the intended escape hatch for ai-service + webhooks and is NOT tested
-- here (its safety is enforced by who holds the service_role key).
--
-- Run via:  supabase test db
--
-- Single file rather than one-per-table because the user fixtures are
-- expensive and shared. All work is in one transaction; ROLLBACK at the
-- bottom keeps the database hermetic across runs.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(48);

-- ---------------------------------------------------------------------------
-- Fixtures: two users + their owned rows.
-- ---------------------------------------------------------------------------
-- Use deterministic UUIDs so assertions can reference them by literal.
INSERT INTO auth.users (id) VALUES
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222');

INSERT INTO public.users (id, email) VALUES
  ('11111111-1111-1111-1111-111111111111', 'alice@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.test');

INSERT INTO public.pets (id, user_id, name, species) VALUES
  ('aaaa1111-aaaa-1111-aaaa-111111111111', '11111111-1111-1111-1111-111111111111', 'Alice-Dog',   'dog'),
  ('bbbb2222-bbbb-2222-bbbb-222222222222', '22222222-2222-2222-2222-222222222222', 'Bob-Cat',     'cat');

-- Service role writes analyses (Phase 1A: insert directly under postgres role,
-- which has BYPASSRLS just like service_role).
INSERT INTO public.analyses (id, pet_id, user_id, input_type) VALUES
  ('a1111111-aaaa-1111-aaaa-111111111111', 'aaaa1111-aaaa-1111-aaaa-111111111111', '11111111-1111-1111-1111-111111111111', 'photo'),
  ('a2222222-bbbb-2222-bbbb-222222222222', 'bbbb2222-bbbb-2222-bbbb-222222222222', '22222222-2222-2222-2222-222222222222', 'photo');

INSERT INTO public.health_events (id, pet_id, event_type, event_date) VALUES
  ('e1111111-aaaa-1111-aaaa-111111111111', 'aaaa1111-aaaa-1111-aaaa-111111111111', 'vaccination', current_date),
  ('e2222222-bbbb-2222-bbbb-222222222222', 'bbbb2222-bbbb-2222-bbbb-222222222222', 'vaccination', current_date);

INSERT INTO public.reminders (id, pet_id, user_id, reminder_type, due_date) VALUES
  ('11111111-aaaa-1111-aaaa-111111111111', 'aaaa1111-aaaa-1111-aaaa-111111111111', '11111111-1111-1111-1111-111111111111', 'vaccination', current_date + 30),
  ('22222222-bbbb-2222-bbbb-222222222222', 'bbbb2222-bbbb-2222-bbbb-222222222222', '22222222-2222-2222-2222-222222222222', 'vaccination', current_date + 30);

INSERT INTO public.analysis_feedback (id, analysis_id, outcome) VALUES
  ('f1111111-aaaa-1111-aaaa-111111111111', 'a1111111-aaaa-1111-aaaa-111111111111', 'resolved_on_own'),
  ('f2222222-bbbb-2222-bbbb-222222222222', 'a2222222-bbbb-2222-bbbb-222222222222', 'vet_confirmed');

INSERT INTO public.referrals (id, referrer_user_id, referral_code) VALUES
  ('11111111-cccc-1111-cccc-111111111111', '11111111-1111-1111-1111-111111111111', 'ALICE-CODE'),
  ('22222222-cccc-2222-cccc-222222222222', '22222222-2222-2222-2222-222222222222', 'BOB-CODE');

-- ---------------------------------------------------------------------------
-- Helper: pretend to be a user by setting the JWT claims that Supabase Auth
-- normally injects. RLS policies reference `auth.uid()` which reads
-- `request.jwt.claims->>'sub'`.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION test_become(p_user_id uuid) RETURNS void AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id::text, 'role', 'authenticated')::text,
    true
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_become_anonymous() RETURNS void AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', '', true);
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- users
-- =============================================================================
SELECT test_become('11111111-1111-1111-1111-111111111111');

SELECT is(
  (SELECT count(*)::int FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'),
  1, 'users: alice sees her own row'
);
SELECT is(
  (SELECT count(*)::int FROM public.users WHERE id = '22222222-2222-2222-2222-222222222222'),
  0, 'users: alice cannot see bob''s row'
);

-- Update — allowed on her own row, but column GRANT restricts to safe columns.
SELECT lives_ok(
  $$ UPDATE public.users SET preferred_locale = 'de' WHERE id = '11111111-1111-1111-1111-111111111111' $$,
  'users: alice can update her preferred_locale'
);
SELECT throws_ok(
  $$ UPDATE public.users SET subscription_status = 'premium' WHERE id = '11111111-1111-1111-1111-111111111111' $$,
  NULL,
  NULL,
  'users: alice cannot UPDATE subscription_status (column GRANT denied)'
);

-- Insert + delete — fully denied for authenticated.
SELECT throws_ok(
  $$ INSERT INTO public.users (id, email) VALUES ('33333333-3333-3333-3333-333333333333', 'eve@x.test') $$,
  NULL, NULL,
  'users: insert is denied for authenticated'
);
-- Under `USING (false)`, DELETE silently affects 0 rows — Postgres does not
-- throw, the policy just makes no row visible to delete. Assert the row
-- survives the attempt.
SELECT lives_ok(
  $$ DELETE FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111' $$,
  'users: DELETE under USING(false) is a silent no-op'
);
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'),
  1, 'users: alice''s row survived the delete attempt'
);
SELECT test_become('11111111-1111-1111-1111-111111111111');

-- =============================================================================
-- pets
-- =============================================================================
SELECT is(
  (SELECT count(*)::int FROM public.pets),
  1, 'pets: alice sees only her own pet'
);
SELECT is(
  (SELECT count(*)::int FROM public.pets WHERE user_id = '22222222-2222-2222-2222-222222222222'),
  0, 'pets: alice cannot see bob''s pets'
);

SELECT lives_ok(
  $$ INSERT INTO public.pets (user_id, name, species) VALUES ('11111111-1111-1111-1111-111111111111', 'Alice-Cat2', 'cat') $$,
  'pets: alice can insert her own pet'
);
SELECT throws_ok(
  $$ INSERT INTO public.pets (user_id, name, species) VALUES ('22222222-2222-2222-2222-222222222222', 'Stolen', 'cat') $$,
  NULL, NULL,
  'pets: alice cannot insert pets belonging to bob'
);
-- RLS filters bob's pet out of alice's view; UPDATE matches 0 rows silently.
SELECT lives_ok(
  $$ UPDATE public.pets SET name = 'Hijacked' WHERE id = 'bbbb2222-bbbb-2222-bbbb-222222222222' $$,
  'pets: UPDATE on another user''s pet is a silent no-op'
);
RESET ROLE;
SELECT is(
  (SELECT name FROM public.pets WHERE id = 'bbbb2222-bbbb-2222-bbbb-222222222222'),
  'Bob-Cat', 'pets: bob''s pet name unchanged'
);
SELECT test_become('11111111-1111-1111-1111-111111111111');
SELECT is(
  (SELECT count(*)::int FROM public.pets WHERE id = 'bbbb2222-bbbb-2222-bbbb-222222222222'),
  0, 'pets: alice cannot SELECT bob''s pet'
);

-- =============================================================================
-- analyses (append-only from user perspective)
-- =============================================================================
SELECT is(
  (SELECT count(*)::int FROM public.analyses),
  1, 'analyses: alice sees only her own analyses'
);
SELECT is(
  (SELECT count(*)::int FROM public.analyses WHERE id = 'a2222222-bbbb-2222-bbbb-222222222222'),
  0, 'analyses: alice cannot SELECT bob''s analysis'
);
SELECT throws_ok(
  $$ INSERT INTO public.analyses (pet_id, user_id, input_type) VALUES ('aaaa1111-aaaa-1111-aaaa-111111111111', '11111111-1111-1111-1111-111111111111', 'text') $$,
  NULL, NULL,
  'analyses: even own-data INSERT is denied for authenticated (service role only)'
);
SELECT lives_ok(
  $$ UPDATE public.analyses SET triage_level = 'EMERGENCY' WHERE id = 'a1111111-aaaa-1111-aaaa-111111111111' $$,
  'analyses: UPDATE under USING(false) is a silent no-op'
);
SELECT lives_ok(
  $$ DELETE FROM public.analyses WHERE id = 'a1111111-aaaa-1111-aaaa-111111111111' $$,
  'analyses: DELETE under USING(false) is a silent no-op'
);
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM public.analyses WHERE id = 'a1111111-aaaa-1111-aaaa-111111111111' AND triage_level IS NULL),
  1, 'analyses: alice''s analysis survives + is unmodified (append-only enforced)'
);
SELECT test_become('11111111-1111-1111-1111-111111111111');

-- =============================================================================
-- health_events
-- =============================================================================
SELECT is(
  (SELECT count(*)::int FROM public.health_events),
  1, 'health_events: alice sees only events on her own pet'
);
SELECT is(
  (SELECT count(*)::int FROM public.health_events WHERE pet_id = 'bbbb2222-bbbb-2222-bbbb-222222222222'),
  0, 'health_events: alice cannot reach bob''s pet events'
);
SELECT lives_ok(
  $$ INSERT INTO public.health_events (pet_id, event_type, event_date) VALUES ('aaaa1111-aaaa-1111-aaaa-111111111111', 'vet_visit', current_date) $$,
  'health_events: alice can insert events on her own pet'
);
SELECT throws_ok(
  $$ INSERT INTO public.health_events (pet_id, event_type, event_date) VALUES ('bbbb2222-bbbb-2222-bbbb-222222222222', 'vet_visit', current_date) $$,
  NULL, NULL,
  'health_events: alice cannot insert events on bob''s pet'
);

-- =============================================================================
-- reminders
-- =============================================================================
SELECT is(
  (SELECT count(*)::int FROM public.reminders),
  1, 'reminders: alice sees only her own reminders'
);
SELECT lives_ok(
  $$ INSERT INTO public.reminders (pet_id, user_id, reminder_type, due_date) VALUES ('aaaa1111-aaaa-1111-aaaa-111111111111', '11111111-1111-1111-1111-111111111111', 'medication', current_date + 7) $$,
  'reminders: alice can insert her own'
);
SELECT throws_ok(
  $$ INSERT INTO public.reminders (pet_id, user_id, reminder_type, due_date) VALUES ('bbbb2222-bbbb-2222-bbbb-222222222222', '22222222-2222-2222-2222-222222222222', 'medication', current_date + 7) $$,
  NULL, NULL,
  'reminders: alice cannot insert for bob'
);

-- =============================================================================
-- analysis_feedback
-- =============================================================================
SELECT is(
  (SELECT count(*)::int FROM public.analysis_feedback),
  1, 'analysis_feedback: alice sees only feedback on her own analyses'
);
SELECT lives_ok(
  $$ INSERT INTO public.analysis_feedback (analysis_id, rating) VALUES ('a1111111-aaaa-1111-aaaa-111111111111', 5) $$,
  'analysis_feedback: alice can insert feedback on her own analysis'
);
SELECT throws_ok(
  $$ INSERT INTO public.analysis_feedback (analysis_id, rating) VALUES ('a2222222-bbbb-2222-bbbb-222222222222', 5) $$,
  NULL, NULL,
  'analysis_feedback: alice cannot insert feedback on bob''s analysis'
);
SELECT lives_ok(
  $$ UPDATE public.analysis_feedback SET rating = 1 WHERE id = 'f1111111-aaaa-1111-aaaa-111111111111' $$,
  'analysis_feedback: UPDATE under USING(false) is a silent no-op'
);
SELECT lives_ok(
  $$ DELETE FROM public.analysis_feedback WHERE id = 'f1111111-aaaa-1111-aaaa-111111111111' $$,
  'analysis_feedback: DELETE under USING(false) is a silent no-op'
);
RESET ROLE;
SELECT is(
  (SELECT outcome FROM public.analysis_feedback WHERE id = 'f1111111-aaaa-1111-aaaa-111111111111'),
  'resolved_on_own',
  'analysis_feedback: alice''s feedback unchanged + still exists'
);
SELECT test_become('11111111-1111-1111-1111-111111111111');

-- =============================================================================
-- referrals
-- =============================================================================
SELECT is(
  (SELECT count(*)::int FROM public.referrals),
  1, 'referrals: alice sees only her own referrals'
);
SELECT lives_ok(
  $$ INSERT INTO public.referrals (referrer_user_id, referral_code) VALUES ('11111111-1111-1111-1111-111111111111', 'ALICE-CODE-2') $$,
  'referrals: alice can insert her own referral'
);
SELECT throws_ok(
  $$ INSERT INTO public.referrals (referrer_user_id, referral_code) VALUES ('22222222-2222-2222-2222-222222222222', 'BOB-FAKE') $$,
  NULL, NULL,
  'referrals: alice cannot insert a referral on behalf of bob'
);
SELECT throws_ok(
  $$ INSERT INTO public.referrals (referrer_user_id, referral_code, converted, converted_at) VALUES ('11111111-1111-1111-1111-111111111111', 'PRE-CONVERTED', true, now()) $$,
  NULL, NULL,
  'referrals: alice cannot pre-set converted=true on her own row (RLS WITH CHECK)'
);
SELECT lives_ok(
  $$ UPDATE public.referrals SET converted = true, converted_at = now() WHERE id = '11111111-cccc-1111-cccc-111111111111' $$,
  'referrals: UPDATE under USING(false) is a silent no-op'
);
RESET ROLE;
SELECT is(
  (SELECT converted FROM public.referrals WHERE id = '11111111-cccc-1111-cccc-111111111111'),
  false,
  'referrals: alice''s referral converted flag unchanged (service role only)'
);
SELECT test_become('11111111-1111-1111-1111-111111111111');

-- =============================================================================
-- Anonymous (no JWT) should see nothing.
-- =============================================================================
SELECT test_become_anonymous();

SELECT is(
  (SELECT count(*)::int FROM public.users),
  0, 'anonymous: cannot SELECT from users'
);
SELECT is(
  (SELECT count(*)::int FROM public.pets),
  0, 'anonymous: cannot SELECT from pets'
);
SELECT is(
  (SELECT count(*)::int FROM public.analyses),
  0, 'anonymous: cannot SELECT from analyses'
);
SELECT is(
  (SELECT count(*)::int FROM public.health_events),
  0, 'anonymous: cannot SELECT from health_events'
);
SELECT is(
  (SELECT count(*)::int FROM public.reminders),
  0, 'anonymous: cannot SELECT from reminders'
);
SELECT is(
  (SELECT count(*)::int FROM public.analysis_feedback),
  0, 'anonymous: cannot SELECT from analysis_feedback'
);
SELECT is(
  (SELECT count(*)::int FROM public.referrals),
  0, 'anonymous: cannot SELECT from referrals'
);

-- =============================================================================
-- Bob's view — sanity check from the other side.
-- =============================================================================
SELECT test_become('22222222-2222-2222-2222-222222222222');

SELECT is(
  (SELECT count(*)::int FROM public.pets WHERE id = 'aaaa1111-aaaa-1111-aaaa-111111111111'),
  0, 'pets: bob cannot SELECT alice''s pet'
);
SELECT is(
  (SELECT count(*)::int FROM public.analyses WHERE id = 'a1111111-aaaa-1111-aaaa-111111111111'),
  0, 'analyses: bob cannot SELECT alice''s analysis'
);

SELECT * FROM finish();
ROLLBACK;
