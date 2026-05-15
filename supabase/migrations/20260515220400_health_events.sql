-- =============================================================================
-- Phase 1A — health_events
-- =============================================================================
-- Manual health entries (vaccinations, vet visits, etc.) per pet.
-- Ownership chain: health_events.pet_id → pets.user_id → auth.uid()
-- =============================================================================

CREATE TABLE health_events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id       uuid NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  event_type   text NOT NULL,
  event_date   date NOT NULL,
  notes        text,
  metadata     jsonb,
  created_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT health_events_type_check
    CHECK (event_type IN ('vaccination', 'vet_visit', 'medication', 'weight', 'custom'))
);

CREATE INDEX idx_health_events_pet_id_date ON health_events(pet_id, event_date DESC);

-- ---------------------------------------------------------------------------
-- RLS — ownership via parent pet
-- ---------------------------------------------------------------------------
ALTER TABLE health_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY health_events_select_own ON health_events
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM pets p
    WHERE p.id = health_events.pet_id AND p.user_id = auth.uid()
  ));

CREATE POLICY health_events_insert_own ON health_events
  FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM pets p
    WHERE p.id = health_events.pet_id AND p.user_id = auth.uid()
  ));

CREATE POLICY health_events_update_own ON health_events
  FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM pets p
    WHERE p.id = health_events.pet_id AND p.user_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM pets p
    WHERE p.id = health_events.pet_id AND p.user_id = auth.uid()
  ));

CREATE POLICY health_events_delete_own ON health_events
  FOR DELETE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM pets p
    WHERE p.id = health_events.pet_id AND p.user_id = auth.uid()
  ));

COMMENT ON TABLE health_events IS
  'Manual health log entries per pet. Ownership joined through pets.user_id.';
