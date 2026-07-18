-- LEG-03 (evolution Phase 7): affirmative Terms/Privacy acceptance.
--
-- The signup UI gates account creation behind an explicit assent checkbox
-- (email and Apple paths both). The DB stamps WHEN the account came into
-- being post-assent: rows can only be created through the gated flow, so
-- the provisioning timestamp is the acceptance record. A later re-acceptance
-- flow (new Terms version) would update this column explicitly.
alter table public.users
  add column if not exists accepted_terms_at timestamptz not null default now();

comment on column public.users.accepted_terms_at is
  'When the user affirmatively accepted Terms + Privacy (signup assent gate; LEG-03).';
