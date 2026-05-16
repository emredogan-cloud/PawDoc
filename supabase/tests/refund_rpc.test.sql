-- =============================================================================
-- refund_free_analysis — pgTAP test suite
-- =============================================================================
-- Verifies the contract documented in
-- docs/reports/sprint-a2-hardening-plan.md §1.3:
--   - happy path (decrements counter, audit row inserted)
--   - idempotent (same request_id refunds at most once)
--   - subscriber short-circuit (returns true, no decrement)
--   - counter clamped at 0 (no negative balance)
--   - missing user → exception
--   - invalid reason → exception
--   - RLS: authenticated callers cannot read or write the refunds table
-- =============================================================================

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(21);

-- ---------------------------------------------------------------------------
-- Fixtures: two users (free + premium), each pre-consumed some quota.
-- ---------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
  ('33333333-3333-3333-3333-333333333333', 'free@example.test'),
  ('44444444-4444-4444-4444-444444444444', 'premium@example.test');

INSERT INTO public.users (id, email, subscription_status, free_analyses_used_this_month) VALUES
  ('33333333-3333-3333-3333-333333333333', 'free@example.test', 'free', 2),
  ('44444444-4444-4444-4444-444444444444', 'premium@example.test', 'premium', 0)
ON CONFLICT (id) DO UPDATE
  SET subscription_status = EXCLUDED.subscription_status,
      free_analyses_used_this_month = EXCLUDED.free_analyses_used_this_month;

-- =============================================================================
-- 1. Happy path — free user, 2 used → refund decrements to 1.
-- =============================================================================
SELECT is(
  refund_free_analysis('33333333-3333-3333-3333-333333333333'::uuid, 'req-1', 'ai_failure'),
  true,
  'refund returns true on first call'
);

SELECT is(
  (SELECT free_analyses_used_this_month FROM users WHERE id = '33333333-3333-3333-3333-333333333333'),
  1,
  'refund decremented counter from 2 to 1'
);

SELECT is(
  (SELECT count(*)::int FROM analysis_refunds WHERE request_id = 'req-1'),
  1,
  'audit row inserted'
);

SELECT is(
  (SELECT reason FROM analysis_refunds WHERE request_id = 'req-1'),
  'ai_failure',
  'audit row carries reason'
);

-- =============================================================================
-- 2. Idempotency — second call with same request_id is a no-op.
-- =============================================================================
SELECT is(
  refund_free_analysis('33333333-3333-3333-3333-333333333333'::uuid, 'req-1', 'ai_failure'),
  false,
  'duplicate refund returns false'
);

SELECT is(
  (SELECT free_analyses_used_this_month FROM users WHERE id = '33333333-3333-3333-3333-333333333333'),
  1,
  'counter NOT decremented twice'
);

SELECT is(
  (SELECT count(*)::int FROM analysis_refunds WHERE request_id = 'req-1'),
  1,
  'audit table still has exactly one row for req-1'
);

-- =============================================================================
-- 3. Different request_ids each decrement independently.
-- =============================================================================
SELECT is(
  refund_free_analysis('33333333-3333-3333-3333-333333333333'::uuid, 'req-2', 'persist_failure'),
  true,
  'second distinct request_id refunds'
);

SELECT is(
  (SELECT free_analyses_used_this_month FROM users WHERE id = '33333333-3333-3333-3333-333333333333'),
  0,
  'counter now at zero'
);

-- =============================================================================
-- 4. Counter clamp — refund at zero does NOT go negative.
-- =============================================================================
SELECT is(
  refund_free_analysis('33333333-3333-3333-3333-333333333333'::uuid, 'req-3', 'timeout'),
  true,
  'refund at zero returns true (audit row recorded)'
);

SELECT is(
  (SELECT free_analyses_used_this_month FROM users WHERE id = '33333333-3333-3333-3333-333333333333'),
  0,
  'counter clamped at 0 — no negative balance'
);

-- =============================================================================
-- 5. Subscriber — refund returns true but counter unchanged.
-- =============================================================================
SELECT is(
  refund_free_analysis('44444444-4444-4444-4444-444444444444'::uuid, 'req-prem-1', 'ai_failure'),
  true,
  'subscriber refund returns true'
);

SELECT is(
  (SELECT free_analyses_used_this_month FROM users WHERE id = '44444444-4444-4444-4444-444444444444'),
  0,
  'subscriber counter unchanged'
);

SELECT is(
  (SELECT count(*)::int FROM analysis_refunds WHERE request_id = 'req-prem-1'),
  1,
  'subscriber refund still creates an audit row'
);

-- =============================================================================
-- 6. Validation — invalid reason raises.
-- =============================================================================
SELECT throws_ok(
  $$ SELECT refund_free_analysis('33333333-3333-3333-3333-333333333333'::uuid, 'req-bad-reason', 'malicious_drop_table') $$,
  NULL, NULL,
  'invalid reason raises an exception'
);

-- The failed call should NOT have left an audit row.
SELECT is(
  (SELECT count(*)::int FROM analysis_refunds WHERE request_id = 'req-bad-reason'),
  0,
  'invalid reason did not create an audit row'
);

-- =============================================================================
-- 7. Validation — missing user raises.
-- =============================================================================
SELECT throws_ok(
  $$ SELECT refund_free_analysis('99999999-9999-9999-9999-999999999999'::uuid, 'req-no-user', 'ai_failure') $$,
  NULL, NULL,
  'missing user raises an exception'
);

-- =============================================================================
-- 8. RLS — authenticated user cannot read or write.
-- =============================================================================
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

SELECT is(
  (SELECT count(*)::int FROM public.analysis_refunds),
  0,
  'RLS: authenticated SELECT sees nothing'
);

SELECT throws_ok(
  $$ INSERT INTO public.analysis_refunds (user_id, request_id, reason)
     VALUES ('33333333-3333-3333-3333-333333333333', 'sneaky', 'ai_failure') $$,
  NULL, NULL,
  'RLS: authenticated INSERT denied'
);

RESET ROLE;

-- Service-role-only EXECUTE — verified via the catalog rather than by
-- attempting the call (a permission-denied during a SECURITY DEFINER
-- function invocation breaks pgTAP's savepoint recovery in some
-- environments). Catalog check is equivalent.
SELECT is(
  has_function_privilege(
    'authenticated',
    'public.refund_free_analysis(uuid, text, text)',
    'EXECUTE'
  ),
  false,
  'RLS: authenticated has no EXECUTE on refund_free_analysis'
);

SELECT is(
  has_function_privilege(
    'service_role',
    'public.refund_free_analysis(uuid, text, text)',
    'EXECUTE'
  ),
  true,
  'service_role has EXECUTE on refund_free_analysis'
);

SELECT * FROM finish();
ROLLBACK;
