-- Phase 1.1 — Migration v1: initial schema (Section 5 of the roadmap).
-- Tables + indexes exactly per the roadmap, with two corrections applied per
-- the owner-approved Critical Review items:
--   CR #20: consistent FK ON DELETE semantics (the source omitted them on
--           analyses.*, reminders.user_id, analysis_feedback.analysis_id,
--           referrals.referrer_user_id, which would block deletes / orphan rows).
--           All user-owned rows CASCADE so account/pet deletion works.
--   CR #2 (linkage half): public.users.id references auth.users(id) so that
--           auth.uid() == users.id, which is what makes the RLS policies in the
--           next migration actually function. (The source used a standalone
--           gen_random_uuid() PK, which RLS auth.uid() = user_id can never match.)
-- Extensions (uuid-ossp, vector) were enabled in 20260527000000.
-- NOTE (CR #9, surfaced for Phase 2): "store every analysis permanently" vs GDPR
-- erasure is unresolved. CASCADE here supports erasure-on-account-deletion; if
-- the legal-hold policy chooses anonymise-and-retain, revisit these FKs then.

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text unique,
  subscription_status text default 'free', -- free | trial | premium | family
  subscription_tier text,
  revenuecat_user_id text,
  one_signal_player_id text,
  preferred_locale text default 'en',
  free_analyses_used_this_month int default 0,
  free_analyses_reset_at timestamptz default date_trunc('month', now()) + interval '1 month',
  created_at timestamptz default now(),
  last_active_at timestamptz default now()
);

create table public.pets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  name text not null,
  species text not null, -- dog | cat | rabbit | bird | reptile | other
  breed text,
  birth_date date,
  sex text,
  weight_kg decimal(5, 2),
  photo_url text,
  medical_notes text,
  is_active bool default true,
  created_at timestamptz default now()
);

create table public.analyses (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid references public.pets (id) on delete cascade,   -- CR #20
  user_id uuid not null references public.users (id) on delete cascade, -- CR #20
  input_type text not null, -- photo | video | text
  input_storage_key text,   -- Cloudflare R2 key
  text_description text,
  triage_level text,         -- EMERGENCY | MONITOR | NORMAL
  primary_concern text,
  full_response jsonb,       -- complete structured AI output
  model_used text,
  tier_used int,             -- 2 | 3 | 4
  confidence_score decimal(4, 3),
  ai_latency_ms int,
  emergency_override_applied bool default false,
  embedding extensions.vector(1536), -- semantic cache (populated in Phase 3.2)
  created_at timestamptz default now()
);

create table public.health_events (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  event_type text not null, -- vaccination | vet_visit | medication | weight | custom
  event_date date not null,
  notes text,
  metadata jsonb,
  created_at timestamptz default now()
);

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade, -- CR #20
  reminder_type text not null,
  due_date date not null,
  is_sent bool default false,
  notification_sent_at timestamptz,
  created_at timestamptz default now()
);

create table public.analysis_feedback (
  id uuid primary key default gen_random_uuid(),
  analysis_id uuid not null references public.analyses (id) on delete cascade, -- CR #20
  outcome text, -- resolved_on_own | vet_confirmed | vet_said_nothing | still_monitoring | other
  rating int,   -- 1-5
  comment text,
  created_at timestamptz default now()
);

create table public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_user_id uuid not null references public.users (id) on delete cascade, -- CR #20
  referred_email text,
  referral_code text unique,
  converted bool default false,
  converted_at timestamptz,
  created_at timestamptz default now()
);

-- Key indexes (Section 5).
create index idx_analyses_pet_id on public.analyses (pet_id);
create index idx_analyses_user_id_created on public.analyses (user_id, created_at desc);
create index idx_analyses_triage_level on public.analyses (triage_level);
create index idx_pets_user_id on public.pets (user_id) where is_active = true;
create index idx_reminders_due on public.reminders (due_date) where is_sent = false;
create index idx_users_subscription on public.users (subscription_status);
create index idx_analyses_embedding on public.analyses
  using ivfflat (embedding extensions.vector_cosine_ops) with (lists = 100);
