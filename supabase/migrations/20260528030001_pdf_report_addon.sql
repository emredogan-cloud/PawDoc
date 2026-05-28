-- Phase 6.3 — PDF Health Report ($4.99 consumable add-on).
--
-- Adds a per-user credit counter incremented by the RevenueCat webhook when a
-- one-time `pdf_report_addon` purchase fires. Premium / Family / Trial /
-- B2B-Lite tiers ignore this counter (they get unlimited PDFs server-side),
-- so the counter only matters for the free tier.
--
-- Default 0 (free users start with no credits). The /generate-pdf-report Edge
-- Function decrements after a successful PDF render.

alter table public.users
  add column if not exists pdf_reports_remaining int not null default 0
    check (pdf_reports_remaining >= 0);

comment on column public.users.pdf_reports_remaining is
  'Phase 6.3 — PDF Health Report credit pool. Free users buy via the '
  'pdf_report_addon RevenueCat consumable; premium tiers ignore this.';
