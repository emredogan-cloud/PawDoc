-- Phase 5.4 — B2B-Lite ("sitter") tier.
--
-- Adds a per-pet `client_name` so a sitter using PawDoc can label which
-- "client" each pet belongs to. RLS is unchanged (pets are still own-row by
-- user_id — multiple "clients" still belong to the sitter user, so the sitter
-- can manage them under one account; the column is purely cosmetic metadata).
--
-- The `subscription_status` column already accepts free text, so adding the
-- new `b2b_lite` value here only documents the contract; no schema CHECK is
-- introduced (matches how 'premium', 'family', 'trial' are handled today).

alter table public.pets
  add column if not exists client_name text;

comment on column public.pets.client_name is
  'Phase 5.4 B2B-Lite sitter mode: optional human label for the client/owner '
  'of this pet (e.g. "Smith family"). Cosmetic only; RLS still scopes by user_id.';

comment on column public.users.subscription_status is
  'Subscription tier — one of: free | trial | premium | family | b2b_lite. '
  'b2b_lite (Phase 5.4) is the $19.99/mo sitter tier: unlimited pets + premium '
  'features for one human juggling many clients.';
