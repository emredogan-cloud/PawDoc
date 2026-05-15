-- =============================================================================
-- Phase 1A — reminders
-- =============================================================================
-- Vaccination / medication / vet-visit reminders. A daily cron edge function
-- (Phase 3) scans due reminders and pushes via OneSignal.
-- =============================================================================

CREATE TABLE reminders (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id                   uuid NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  user_id                  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reminder_type            text NOT NULL,
  due_date                 date NOT NULL,
  is_sent                  bool NOT NULL DEFAULT false,
  notification_sent_at     timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT reminders_type_check
    CHECK (reminder_type IN ('vaccination', 'medication', 'vet_visit', 'follow_up', 'custom'))
);

-- The cron job scans pending reminders due in N days. Partial index keeps
-- the working set tiny even as the historical table grows.
CREATE INDEX idx_reminders_due ON reminders(due_date) WHERE is_sent = false;
CREATE INDEX idx_reminders_user_id ON reminders(user_id);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY reminders_select_own ON reminders
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY reminders_insert_own ON reminders
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY reminders_update_own ON reminders
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY reminders_delete_own ON reminders
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- The cron job uses the service role, which bypasses RLS and may set
-- is_sent / notification_sent_at on any row.

COMMENT ON TABLE reminders IS
  'Pet-care reminders (vaccinations, meds, etc.). is_sent flipped by the cron edge fn.';
