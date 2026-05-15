-- =============================================================================
-- Phase 1A — users
-- =============================================================================
-- Public profile + billing state for each authenticated user.
-- Mirrors auth.users 1:1; id is a FK to auth.users(id) with ON DELETE CASCADE
-- so account deletion drops the profile and (via further cascades on child
-- tables) all user-owned data.
--
-- Population: the auth-webhook edge function inserts a row when Supabase
-- emits the `user.created` event. The mobile app NEVER inserts directly.
-- =============================================================================

CREATE TABLE users (
  id                              uuid PRIMARY KEY
                                       REFERENCES auth.users(id) ON DELETE CASCADE,
  email                           text UNIQUE,
  subscription_status             text NOT NULL DEFAULT 'free',
  subscription_tier               text,
  revenuecat_user_id              text,
  one_signal_player_id            text,
  preferred_locale                text NOT NULL DEFAULT 'en',
  free_analyses_used_this_month   int  NOT NULL DEFAULT 0,
  free_analyses_reset_at          timestamptz NOT NULL
                                       DEFAULT (date_trunc('month', now()) + interval '1 month'),
  created_at                      timestamptz NOT NULL DEFAULT now(),
  last_active_at                  timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT users_subscription_status_check
    CHECK (subscription_status IN ('free', 'trial', 'premium', 'family')),
  CONSTRAINT users_free_analyses_used_non_negative
    CHECK (free_analyses_used_this_month >= 0)
);

CREATE INDEX idx_users_subscription ON users(subscription_status);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- A user reads only their own profile.
CREATE POLICY users_select_own ON users
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- INSERTs come only via the auth-webhook (service role). Deny user-facing.
CREATE POLICY users_insert_deny ON users
  FOR INSERT
  TO authenticated
  WITH CHECK (false);

-- A user updates their own row, BUT we also restrict to specific columns at
-- the GRANT level below — RLS gates rows, GRANTs gate columns.
CREATE POLICY users_update_own ON users
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- DELETE is service-role only. Account deletion is a moderated flow.
CREATE POLICY users_delete_deny ON users
  FOR DELETE
  TO authenticated
  USING (false);

-- ---------------------------------------------------------------------------
-- Column-level GRANT — defence in depth
-- ---------------------------------------------------------------------------
-- The RLS UPDATE policy lets the user touch their own row. The GRANT below
-- restricts which columns they can actually change. Billing-relevant columns
-- are writeable only by the service role (which bypasses both RLS and
-- column GRANTs).
REVOKE UPDATE ON users FROM authenticated;
GRANT  UPDATE (preferred_locale, last_active_at, one_signal_player_id) ON users TO authenticated;

COMMENT ON TABLE users IS
  'Public profile + billing state for each authenticated user. 1:1 with auth.users.';
COMMENT ON COLUMN users.id IS
  'Primary key; also FK to auth.users(id). Populated by the auth-webhook on user.created.';
COMMENT ON COLUMN users.subscription_status IS
  'free | trial | premium | family — written ONLY by the revenuecat-webhook (service role).';
COMMENT ON COLUMN users.free_analyses_used_this_month IS
  'Mutated server-side via attempt_consume_free_analysis(). Never written by the client.';
