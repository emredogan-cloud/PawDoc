-- =============================================================================
-- Phase 1A — pets
-- =============================================================================
-- A user can have many pets. Soft delete via is_active (preserves analyses).
-- =============================================================================

CREATE TABLE pets (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            text NOT NULL,
  species         text NOT NULL,
  breed           text,
  birth_date      date,
  sex             text,
  weight_kg       numeric(5,2),
  photo_url       text,
  medical_notes   text,
  is_active       bool NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT pets_species_check
    CHECK (species IN ('dog', 'cat', 'rabbit', 'bird', 'reptile', 'other')),
  CONSTRAINT pets_sex_check
    CHECK (sex IS NULL OR sex IN ('male', 'female', 'unknown')),
  CONSTRAINT pets_weight_positive
    CHECK (weight_kg IS NULL OR weight_kg > 0),
  CONSTRAINT pets_name_not_blank
    CHECK (length(trim(name)) > 0)
);

-- Partial index — only active pets are queried for the home screen / picker.
CREATE INDEX idx_pets_user_id ON pets(user_id) WHERE is_active = true;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE pets ENABLE ROW LEVEL SECURITY;

CREATE POLICY pets_select_own ON pets
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY pets_insert_own ON pets
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY pets_update_own ON pets
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY pets_delete_own ON pets
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

COMMENT ON TABLE pets IS
  'User-owned pet records. Soft-delete via is_active=false to preserve analysis history.';
