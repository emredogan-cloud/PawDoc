-- =============================================================================
-- Phase 1C — user provisioning trigger
-- =============================================================================
-- Phase 1A relied on the auth-webhook edge function to insert the public.users
-- row on user.created. That works in production where the webhook is wired,
-- but local dev requires manual configuration and the webhook can lag.
--
-- This trigger fires inside Postgres on every INSERT INTO auth.users and
-- creates the matching public.users row. Both paths produce the same row;
-- the webhook now serves as a redundancy + auditing surface (the INSERT
-- raises a unique_violation which the webhook handler swallows).
--
-- The trigger is the canonical provisioning path going forward. The webhook
-- remains because:
--   (a) it lets us hook other side effects (e.g. analytics) in Phase 2,
--   (b) it serves as forensic evidence of the auth event independent of DB
--       state.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Idempotent — duplicate INSERT (e.g. from the webhook firing after the
  -- trigger) is a no-op rather than a UNIQUE violation.
  INSERT INTO public.users (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_auth_user() IS
  'Mirrors auth.users INSERT into public.users. Phase 1C provisioning path.';

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user();

-- The function is SECURITY DEFINER and runs as the table owner, so the
-- usual public/anon/authenticated grants don't apply. We still restrict
-- EXECUTE explicitly to keep the surface auditable.
REVOKE ALL ON FUNCTION public.handle_new_auth_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_auth_user() FROM anon;
REVOKE ALL ON FUNCTION public.handle_new_auth_user() FROM authenticated;
