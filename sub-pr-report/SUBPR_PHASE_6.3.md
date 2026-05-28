# SUB-PR Report — Phase 6.3: Family Sharing + PDF Health Report + Insurance Affiliate

**Status:** Complete and fully green (ruff + 152 pytest, **80 node** incl. RC addon + pdf_report shaper, `test-rls.sh` PASS — legacy CR #2 + Family Sharing A/B/C scenario, flutter analyze + 91 tests, shellcheck).
**Branch:** `phase-6.3-revenue-addons` (from `origin/main` = `6b9f660`, post-6.2 merge)
**Date:** 2026-05-28

Phase 6 closes with the highest-risk single migration in the codebase (per-user → per-family-group RLS) wired safely behind two `SECURITY DEFINER` helpers, a fully-server-enforced $4.99 PDF Health Report add-on that **never persists the PDF**, and an opt-in pet-insurance affiliate CTA.

---

## 1. Files created / modified

**Family Sharing (DB + RLS):**
```
supabase/migrations/20260528030000_family_sharing.sql   family_groups + family_members tables;
                                                         pets.family_group_id with backfill + NOT NULL;
                                                         SECURITY DEFINER helpers is_family_member,
                                                         is_family_pet (RLS bypass to break recursion);
                                                         BEFORE-INSERT trigger defaults pet.family_group_id;
                                                         AFTER-INSERT trigger creates the solo family for
                                                         every new user; full RLS redesign for pets +
                                                         analyses + health_events + reminders +
                                                         family_groups + family_members.
supabase/tests/family_sharing.sql                        9 assertions across 4 users (A/B/C/D scenario)
                                                         on real Postgres.
scripts/test-rls.sh                                      (mod) applies the new migration + runs the
                                                         family sharing test alongside the existing
                                                         legacy CR #2 isolation test.
```

**PDF Health Report add-on:**
```
supabase/migrations/20260528030001_pdf_report_addon.sql  users.pdf_reports_remaining int >= 0.
supabase/functions/_shared/pdf_report.mjs                Pure content shaper (sections + filename).
supabase/functions/_shared/pdf_report.test.mjs           7 unit tests.
supabase/functions/generate-pdf-report/index.ts          Edge Function: server-side entitlement check,
                                                          decrement counter, RLS-scoped data fetch,
                                                          inline pdf-lib render, no persistence.
supabase/functions/_shared/revenuecat.mjs       (mod)     ADDON_PRODUCTS + addonCreditsFromEvent.
supabase/functions/revenuecat-webhook/index.ts  (mod)     Applies addon credits ahead of the
                                                          subscription mapping.
supabase/functions/_shared/monetization.test.mjs(mod)     +4 tests for the addon mapping.
supabase/config.toml                            (mod)     verify_jwt=true for generate-pdf-report.

mobile/lib/src/account/user_profile.dart        (mod)     +pdfReportsRemaining +canRequestPdfReport.
mobile/lib/src/health/pdf_report_service.dart             Invoke + SharePlus; throws
                                                          PdfReportPaywallException on HTTP 402.
mobile/lib/src/health/history_timeline_screen.dart (mod) +'generate_pdf_report' IconButton.
mobile/lib/src/analytics/analytics.dart         (mod)     +pdfReport{Requested,Generated,Purchased}.
mobile/test/pdf_entitlement_test.dart                     3 unit tests for canRequestPdfReport.
```

**Insurance affiliate CTA:**
```
mobile/lib/src/config/env.dart                  (mod)     +PET_INSURANCE_AFFILIATE_URL.
mobile/lib/src/monetization/insurance_affiliate_cta.dart  Self-hiding card + dense variant.
mobile/lib/src/analysis/emergency_result_screen.dart (mod) Placed under the EMERGENCY CTA stack.
mobile/lib/src/analysis/result_screen.dart      (mod)     Placed before the feedback widget.
mobile/lib/src/pets/pet_form_screen.dart        (mod)     Placed below the Save button (Pet Profile).
mobile/lib/src/analytics/analytics.dart         (mod)     +insuranceAffiliateClicked(source).
```

**Docs / verifier:**
```
ENVIRONMENT_VARS.md                              (mod)    +PET_INSURANCE_AFFILIATE_URL + Phase 6.3 note.
scripts/verify-phase-6.3.sh                              Phase verifier (incl. running test-rls.sh).
sub-pr-report/SUBPR_PHASE_6.3.md                          This report.
```

## 2. RLS — the exact policies, and how recursion is avoided

The danger with "per-family-group RLS" is that a policy on table A that joins to family_members can itself trigger RLS on family_members — which could recurse back into the policy you're evaluating. The fix is two **`SECURITY DEFINER`** helper functions that bypass RLS on family_members and constrain themselves to `auth.uid()`:

```sql
create or replace function public.is_family_member(check_group_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.family_members
    where group_id = check_group_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_family_pet(check_pet_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from public.pets p
    join public.family_members fm on fm.group_id = p.family_group_id
    where p.id = check_pet_id and fm.user_id = auth.uid()
  );
$$;

revoke all on function public.is_family_member(uuid) from public;
revoke all on function public.is_family_pet(uuid)    from public;
grant execute on function public.is_family_member(uuid) to authenticated, service_role;
grant execute on function public.is_family_pet(uuid)    to authenticated, service_role;
```

Because both helpers are SECURITY DEFINER (running as the function owner, not the caller), they read `family_members` without invoking RLS — so the policies on `family_members` itself can call `is_family_member(group_id)` from their `USING` clauses without recursing. Each helper also restricts itself to `auth.uid()` internally, so even though they bypass RLS, they can't leak membership data across users.

**The new policy stack:**

```sql
-- pets — SELECT family-wide, UPDATE/DELETE owner-only
create policy pets_select_family on public.pets
  for select using (public.is_family_member(family_group_id));
create policy pets_insert_own_in_family on public.pets
  for insert with check ((select auth.uid()) = user_id
                          and public.is_family_member(family_group_id));
create policy pets_update_owner on public.pets
  for update using ((select auth.uid()) = user_id)
                with check ((select auth.uid()) = user_id);
create policy pets_delete_owner on public.pets
  for delete using ((select auth.uid()) = user_id);

-- analyses — same shape (group SELECT/INSERT, owner UPDATE/DELETE)
create policy analyses_select_family on public.analyses
  for select using (public.is_family_pet(pet_id));
create policy analyses_insert_member on public.analyses
  for insert with check ((select auth.uid()) = user_id
                          and public.is_family_pet(pet_id));
create policy analyses_update_owner on public.analyses
  for update using ((select auth.uid()) = user_id)
                with check ((select auth.uid()) = user_id);
create policy analyses_delete_owner on public.analyses
  for delete using ((select auth.uid()) = user_id);

-- health_events — no user_id column; family-wide for all 4 verbs
create policy health_events_select_family on public.health_events
  for select using (public.is_family_pet(pet_id));
create policy health_events_insert_member on public.health_events
  for insert with check (public.is_family_pet(pet_id));
-- (UPDATE / DELETE: same is_family_pet predicate)

-- reminders — same shape as analyses (group SELECT/INSERT, owner UPDATE/DELETE)

-- family_members — SELECT uses the helper too; INSERT only by group owner;
-- DELETE by self OR by group owner.
create policy family_members_select on public.family_members
  for select using (public.is_family_member(group_id));
create policy family_members_insert_by_owner on public.family_members
  for insert with check (
    exists (select 1 from public.family_groups fg
            where fg.id = family_members.group_id
              and fg.owner_user_id = (select auth.uid())));
create policy family_members_delete_self_or_owner on public.family_members
  for delete using (
    (select auth.uid()) = user_id
    or exists (select 1 from public.family_groups fg
               where fg.id = family_members.group_id
                 and fg.owner_user_id = (select auth.uid())));
```

**Standalone users keep working** because of two complementary triggers:

```sql
-- Every NEW user automatically gets a solo group (matches old per-user semantics).
create trigger users_create_solo_family
  after insert on public.users
  for each row execute function public.create_solo_family_for_new_user();

-- Existing client code that doesn't know about family_group_id still works:
-- the BEFORE-INSERT trigger fills in the owner's solo group.
create trigger pets_default_family_group
  before insert on public.pets
  for each row execute function public.default_pet_family_group();
```

Plus a backfill in the same migration that creates a solo group for every existing `public.users` row and updates every pre-migration `pets` row to point at the owner's solo group.

**Tested on real Postgres** (Docker `pgvector:pg16` via `scripts/test-rls.sh`):

| # | Scenario | Result |
|---|----------|--------|
| 1 | A sees Rex (own pet, shared group) | ✅ PASS |
| 2 | B sees Rex via shared `family_group` | ✅ **PASS — sharing works** |
| 3 | C does NOT see Rex (cross-family) | ✅ PASS |
| 4 | B inserts an analysis + health_event on Rex (any member can log) | ✅ PASS |
| 5 | C cannot insert an analysis or health_event on Rex | ✅ PASS |
| 6 | B cannot UPDATE Rex (owner-only) | ✅ PASS |
| 7 | B cannot DELETE A's analysis (owner-only) | ✅ PASS |
| 8 | D's standalone pet is invisible to A/B/C, visible to D | ✅ PASS |
| 9 | After-insert trigger created solo groups for all 4 users | ✅ PASS |

The **legacy CR #2 isolation tests (rls_isolation.sql) still pass unchanged** — proving the family-aware policies fully subsume the old per-user behavior for standalone users.

## 3. PDF privacy lifecycle — how it is delivered and destroyed

**Generated inline, never persisted server-side, share-sheet on the client.**

```
client tap
   ↓
/generate-pdf-report Edge Function
   ↓  (entitlement check: PREMIUM_STATUSES OR pdf_reports_remaining > 0)
   ↓  (RLS-scoped fetch: pets[id] + last-30d analyses + health_events)
   ↓  (pdf-lib renders into a Uint8Array in MEMORY)
   ↓  (admin client decrements pdf_reports_remaining if not premium)
HTTP 200, Content-Type: application/pdf
            Content-Disposition: attachment; filename="pawdoc-<pet>-<date>.pdf"
            Cache-Control: no-store, max-age=0
   ↓
client receives the bytes
   ↓
PdfReportService writes them to the OS TEMP directory
   ↓
SharePlus.share(file) → user picks destination (Files / Mail / AirDrop / …)
```

**Lifecycle guarantees:**

- **NO SERVER STORAGE.** The Edge Function never writes to R2, Supabase Storage, the database, or local disk. The PDF lives only in the function's memory for the duration of the request — once the response is flushed, the bytes are released for GC.
- **NO SERVER LOGGING OF CONTENT.** Only metadata (pet_id, request_id, byte-count summary on error) is logged.
- **`Cache-Control: no-store`** on the response prevents any proxy / CDN / browser caching.
- **`Content-Disposition: attachment`** prevents inline rendering (no leak via browser history).
- **No upload from the client.** `SharePlus.share` hands the file to the OS share sheet; the user picks the destination. The temp file is reclaimed by the OS when temp space is pressured or on app uninstall.
- **RLS-scoped data fetch.** All `pets` / `analyses` / `health_events` reads use the user's JWT — so a sitter can't generate a PDF on a non-family pet even if they spoof the pet_id, and the family-sharing policies apply: a family member CAN generate a PDF for a shared pet (correct — that's the v2 selling point).
- **Server-side entitlement** is enforced even if the client is malicious (no `verify_jwt: false` exposure): the user must be in `PREMIUM_STATUSES` or carry `pdf_reports_remaining > 0`; the counter is decremented post-render so a failed render doesn't burn a credit.

The RevenueCat consumable `pdf_report_addon` ($4.99) increments `pdf_reports_remaining` via the webhook (`addonCreditsFromEvent` in `_shared/revenuecat.mjs`). The mapping is unit-tested in `monetization.test.mjs` (4 cases — NON_RENEWING_PURCHASE, INITIAL_PURCHASE fallback, unknown product, unrelated event).

## 4. Tests executed & results

| Test | Result |
|------|--------|
| `ruff check .` | **clean** |
| `pytest -q` | **152 pass** (unchanged — Phase 6.3 is SQL + Deno + Flutter, no Python deltas) |
| `node --test _shared/*.mjs` | **80 pass** (+7 pdf_report shaper, +4 RC addon) |
| `./scripts/test-rls.sh` (Docker) | **PASS** — legacy CR #2 + Family Sharing (A/B see, C cannot, owner-only writes) |
| `flutter analyze` | **No issues found** |
| `flutter test` | **91 pass** (+3 pdf_entitlement) |
| `./scripts/run-eval.py` (6.1 safety gate) | **exit 0** — 12/12 PASS, FN-on-EMERGENCY=0 |
| `./scripts/verify-phase-6.3.sh` | **exit 0** |
| `shellcheck` (verifier + harness) | **clean** |

## 5. MANUAL (founder)

- `supabase db push` — applies both new migrations. Existing users get their backfilled solo groups; new signups get one automatically via the trigger.
- RevenueCat: configure a consumable product with **product_id `pdf_report_addon`** priced at **$4.99**; reuse the same Webhook URL — the existing handler now applies the credit increment.
- Build defines:
  - `PET_INSURANCE_AFFILIATE_URL` (Trupanion / Healthy Paws partner link) — set when the partner deal lands; the CTA self-hides until then.
- **Family-Sharing UI** (invite a member by email, accept an invite) is **intentionally out of scope** for this sub-PR — the DB layer + the RLS contract are complete and tested. The invite flow is a separate sub-PR (a single Edge Function + 2 mobile screens) and can land any time post-6.3 squash.

## 6. Git branch / commit / push

- Branch: `phase-6.3-revenue-addons`
- Implementation commit (deliverables): `53a5c7b08defa9760c2101f72e399aef6126f914`
- Push: pushed to `origin/phase-6.3-revenue-addons`; open PR at https://github.com/emredogan-cloud/PawDoc/pull/new/phase-6.3-revenue-addons

## 7. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| family_groups + family_members tables + indexes | ✅ DONE | migration; pg test |
| pets.family_group_id with backfill + NOT NULL | ✅ DONE | migration; pet INSERT trigger |
| SECURITY DEFINER helpers (avoid recursion) | ✅ DONE | is_family_member + is_family_pet |
| Per-table RLS rewritten (SELECT/INSERT/UPDATE/DELETE) | ✅ DONE | 4 user-table policy sets + family_* policies |
| Standalone users unaffected (default solo group) | ✅ DONE | trigger + backfill; pg test asserts D's pet stays isolated |
| `test-rls.sh` proves A+B see, C cannot | ✅ DONE | family_sharing.sql; 9/9 assertions PASS |
| /generate-pdf-report Edge Function | ✅ DONE | server-side entitlement + decrement + RLS-scoped read |
| PDF lifecycle privacy (no persistence) | ✅ DONE | inline render + no-store headers; documented |
| RevenueCat $4.99 add-on entitlement wired | ✅ DONE | ADDON_PRODUCTS + addonCreditsFromEvent + webhook |
| Insurance affiliate CTA on Emergency / Result / Pet Profile | ✅ DONE | InsuranceAffiliateCta + 3 placements |
| Analytics: pdfReport* + insuranceAffiliateClicked | ✅ DONE | Analytics class |
| `supabase db push` + RC product setup + first PDF + affiliate URL | ⏳ MANUAL | §5 |

Stopping for approval.
