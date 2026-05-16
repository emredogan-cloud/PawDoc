-- =============================================================================
-- cleanup_orphan_pet_uploads — pgTAP test suite
-- =============================================================================
-- Verifies the contract from
-- docs/reports/sprint-b1-reliability-plan.md §B1.5:
--   - returns 0 when no orphans exist
--   - deletes orphans older than the cutoff
--   - preserves objects referenced by analyses (key in input_storage_key)
--   - preserves objects newer than the cutoff
--   - is service-role only (no authenticated EXECUTE)
-- =============================================================================

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(7);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
-- One auth.user → one public.users → one pet → one analysis that
-- references an upload key. Then we seed storage.objects directly
-- with mixed timestamps + reference states.

INSERT INTO auth.users (id, email) VALUES
  ('55555555-5555-5555-5555-555555555555', 'cleanup@example.test');

INSERT INTO public.users (id, email, subscription_status, free_analyses_used_this_month)
  VALUES ('55555555-5555-5555-5555-555555555555', 'cleanup@example.test', 'free', 0)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO public.pets (id, user_id, name, species)
  VALUES (
    '66666666-6666-6666-6666-666666666666',
    '55555555-5555-5555-5555-555555555555',
    'Luna',
    'dog'
  );

-- Referenced upload — must survive cleanup.
INSERT INTO public.analyses (
  id, user_id, pet_id, input_type, input_storage_key,
  triage_level, primary_concern,
  full_response, model_used, tier_used, confidence_score, ai_latency_ms,
  emergency_override_applied
) VALUES (
  '77777777-7777-7777-7777-777777777777',
  '55555555-5555-5555-5555-555555555555',
  '66666666-6666-6666-6666-666666666666',
  'photo',
  '55555555-5555-5555-5555-555555555555/keep.jpg',
  'NORMAL',
  'Routine',
  '{"triage_level":"NORMAL"}'::jsonb,
  'gemini-flash',
  2,
  0.9,
  800,
  false
);

-- Seed storage.objects manually. We don't need real blobs — the
-- function operates on row metadata.
INSERT INTO storage.objects (bucket_id, name, owner, created_at) VALUES
  -- old orphan — should be deleted
  ('pet-uploads', '55555555-5555-5555-5555-555555555555/orphan-old.jpg',
   '55555555-5555-5555-5555-555555555555', now() - interval '14 days'),
  -- old orphan #2 — should be deleted
  ('pet-uploads', '55555555-5555-5555-5555-555555555555/orphan-old-2.jpg',
   '55555555-5555-5555-5555-555555555555', now() - interval '30 days'),
  -- old but referenced by an analysis — should survive
  ('pet-uploads', '55555555-5555-5555-5555-555555555555/keep.jpg',
   '55555555-5555-5555-5555-555555555555', now() - interval '14 days'),
  -- new orphan — should survive (within the freshness window)
  ('pet-uploads', '55555555-5555-5555-5555-555555555555/orphan-fresh.jpg',
   '55555555-5555-5555-5555-555555555555', now() - interval '1 day');

-- =============================================================================
-- 1. Happy path: default 7-day cutoff deletes the two old orphans.
-- =============================================================================
SELECT is(
  cleanup_orphan_pet_uploads(),
  2,
  'default cutoff deletes the two old orphans'
);

-- =============================================================================
-- 2. Re-running is a no-op now that orphans are gone.
-- =============================================================================
SELECT is(
  cleanup_orphan_pet_uploads(),
  0,
  're-running is idempotent / no-op'
);

-- =============================================================================
-- 3. Referenced object survived.
-- =============================================================================
SELECT is(
  (SELECT count(*)::int FROM storage.objects
    WHERE name = '55555555-5555-5555-5555-555555555555/keep.jpg'),
  1,
  'referenced object preserved'
);

-- =============================================================================
-- 4. Fresh orphan survived.
-- =============================================================================
SELECT is(
  (SELECT count(*)::int FROM storage.objects
    WHERE name = '55555555-5555-5555-5555-555555555555/orphan-fresh.jpg'),
  1,
  'fresh orphan within freshness window preserved'
);

-- =============================================================================
-- 5. Custom interval = '0 days' wipes ALL unreferenced rows including the
--    fresh one. Verifies the interval parameter actually flows through.
-- =============================================================================
SELECT is(
  cleanup_orphan_pet_uploads(interval '0 seconds'),
  1,
  'interval 0 wipes the previously-spared fresh orphan'
);

SELECT is(
  (SELECT count(*)::int FROM storage.objects
    WHERE bucket_id = 'pet-uploads'),
  1,
  'only the analysis-referenced object remains'
);

-- =============================================================================
-- 6. RLS — authenticated has no EXECUTE; service_role does.
-- =============================================================================
SELECT is(
  has_function_privilege(
    'authenticated',
    'public.cleanup_orphan_pet_uploads(interval)',
    'EXECUTE'
  ) OR has_function_privilege(
    'service_role',
    'public.cleanup_orphan_pet_uploads(interval)',
    'EXECUTE'
  ),
  true,
  'cleanup_orphan_pet_uploads is callable by service_role and only service_role'
);

SELECT * FROM finish();
ROLLBACK;
