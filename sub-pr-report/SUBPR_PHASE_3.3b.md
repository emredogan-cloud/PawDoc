# SUB-PR Report — Phase 3.3 (Part 2): Engagement, Reminders & Push Notifications

**Status:** Complete and fully green (node, engagement pg test + RLS test, ruff/pytest, flutter analyze/test, shellcheck). Reminders CRUD + a secret-secured, cron-driven push pipeline (due reminders + inactivity re-engagement with a no-spam guard).
**Branch:** `phase-3.3-engagement-notifications` (from `origin/main` = `c911e3e`, contains 0.1→3.3 P1)
**Date:** 2026-05-27

---

## 1. Files created / modified

**Created**
```
supabase/migrations/20260527040000_reminders_engagement.sql   users.last_reengagement_sent_at + due_reminders()
                                                              + users_to_reengage(inactivity,cooldown) + lockdowns
supabase/migrations/20260527040001_schedule_reminders_cron.sql pg_cron + pg_net hourly schedule (Vault-sourced; founder-applied)
supabase/tests/reminders.sql + scripts/test-reminders.sh      engagement query-func pg test (due/lapsed/cooldown/lockdown)
supabase/functions/process-reminders/index.ts                 cron Edge Function: secret-guarded; push + mark sent / stamp
supabase/functions/_shared/reminders.mjs (+ .test.mjs)        cronSecretValid (fail-closed) + OneSignal payload builders
mobile/lib/src/reminders/reminder.dart                        Reminder model + presets
mobile/lib/src/reminders/reminders_repository.dart            CRUD + remindersForPetProvider (RLS-scoped)
mobile/lib/src/reminders/reminder_form_screen.dart            set a reminder (label/preset + due date)
mobile/lib/src/reminders/reminders_screen.dart                manage reminders for the active pet
mobile/test/reminders_test.dart                               Reminder model unit tests
scripts/verify-phase-3.3b.sh                                  phase verifier (structural + all batteries)
sub-pr-report/SUBPR_PHASE_3.3b.md                             this report
```
**Modified**
```
supabase/config.toml                          [functions.process-reminders] verify_jwt = false
supabase/tests/rls_isolation.sql              reminders INSERT controls (A can create own; cannot create B's)
mobile/lib/src/analytics/analytics.dart       reminder_set
mobile/lib/src/health/history_timeline_screen.dart  app-bar "Reminders" entry (Icons.alarm)
ENVIRONMENT_VARS.md                           CRON_SECRET, ONESIGNAL_APP_ID, ONESIGNAL_REST_API_KEY, Vault note
```
RLS verified: `reminders_owner` (user_id) supports the client CRUD — proven by the new positive/negative controls in `rls_isolation.sql` (`test-rls.sh` green).

## 2. How the cron is scheduled, and how the Edge Function is secured

**Scheduling (PostgreSQL).** Migration `20260527040001` (applied on Supabase, where the managed extensions live):
- `create extension pg_cron; create extension pg_net;`
- `cron.schedule('process-reminders-hourly', '0 * * * *', <sql>)` — runs hourly on the hour. The job body is `net.http_post(url, headers, body)` calling `…/functions/v1/process-reminders`.
- **No secret in git:** the project URL and the cron secret are read at run time from **Supabase Vault** (`vault.decrypted_secrets` for `project_url` and `cron_secret`). The founder sets them once (`vault.create_secret(...)`); the migration is idempotent (unschedule-if-exists → schedule).
- This migration uses managed extensions (pg_cron/pg_net/Vault) absent from the bare test image, so it is **founder-applied via `supabase db push`** and intentionally excluded from the Docker tests. The *logic* it drives (`due_reminders`, `users_to_reengage`) is fully tested headlessly.

**Securing the Edge Function against unauthorized triggers.**
- `/process-reminders` requires an **`x-cron-secret` header that must equal `CRON_SECRET`** (Doppler / `supabase secrets set`). The check is constant-time and **fails CLOSED** — if `CRON_SECRET` is empty/unset, *every* call is rejected (401), so a misconfigured deploy can never be triggered into a public notification blast.
- `verify_jwt = false` for it (it's server-to-server from `pg_net`, with no user JWT — the secret header is the authentication). The `pg_cron` job supplies the header from the Vault `cron_secret`, which must equal `CRON_SECRET`.
- The row-selection functions (`due_reminders`, `users_to_reengage`) are `SECURITY DEFINER` and **`REVOKE`d from anon/authenticated, `GRANT`ed to `service_role` only** — a user can't enumerate other users' push ids or reminders through PostgREST.

## 3. How timezone issues are handled / mitigated for due dates

- `reminders.due_date` is a **`DATE`** — a timezone-agnostic calendar date. The client sends it **date-only** (`YYYY-MM-DD`, no time/offset), so there's no client-tz ambiguity at write time.
- `due_reminders()` evaluates **`due_date <= (now() at time zone 'utc')::date`** — i.e. the current date computed in **UTC**, independent of the server's/session's timezone. Evaluation is therefore deterministic and not subject to session-tz drift.
- Because reminders are **day-granular** (not time-of-day) and the cron runs **hourly**, a reminder fires within ~1 hour of **UTC midnight** on its due day. Worst case, a user far from UTC may receive a day-level reminder up to ~a day early/late relative to their *local* midnight — acceptable for "vaccine / flea med / vet appointment" nudges.
- **Refinement path (documented, deferred):** store a per-user timezone (or persist the user's local-midnight as a UTC timestamp at creation) and fire at their local morning. Flagged, not silently added — the current UTC-date approach is the safe MVP.

## 4. Tests executed & results

| Test | Result |
|------|--------|
| `node --test _shared/*.mjs` | **30 pass** (+5 reminder helpers) |
| `./scripts/test-reminders.sh` (Docker) | **PASS** — `due_reminders` (due+unsent+has-player), `users_to_reengage` (lapsed only; excludes active/new/cooled/no-player), lockdowns |
| `./scripts/test-rls.sh` (Docker) | **PASS** — incl. new reminders INSERT positive/negative controls |
| `ruff` + `pytest` (ai-service) | **clean / 56 pass** (unaffected) |
| `flutter analyze` | **No issues found** |
| `flutter test` | **56 pass** (+3 reminders) |
| `./scripts/verify-phase-3.3b.sh` | **exit 0** — all structural + batteries green; 4 MANUAL |
| `shellcheck` (new scripts) | **clean** |

## 5. No-spam guard (strict rule)

The inactivity "we miss you" push is bounded **two ways**: `users_to_reengage(30, 30)` only returns users whose `last_reengagement_sent_at` is null or older than the 30-day cooldown (and who have no analysis in 30 days, and whose account is older than 30 days so brand-new signups aren't pestered), **and** the Edge Function stamps `last_reengagement_sent_at = now()` after sending. So a user receives at most one nudge per 30-day window. The pg test asserts a cooled-down user is excluded.

## 6. MANUAL (founder / live infra)

- Apply `20260527040001` on Supabase (`supabase db push`) — needs pg_cron/pg_net/Vault.
- Set `CRON_SECRET` (Edge) **=** Vault `cron_secret`, and Vault `project_url`; set `ONESIGNAL_APP_ID` + `ONESIGNAL_REST_API_KEY` for live sends; verify a test push.
- Deno typecheck of `process-reminders` runs in Supabase CI (deno not installed here); its `_shared` logic is node-tested.

## 7. Git branch / commit / push

- Branch: `phase-3.3-engagement-notifications`
- Implementation commit (deliverables): `3f1b6a874357565c0b77aa256f190231e07506ff`
- Push: pushed to `origin/phase-3.3-engagement-notifications`; open PR at https://github.com/emredogan-cloud/PawDoc/pull/new/phase-3.3-engagement-notifications

## 8. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Reminders CRUD UI writing to `reminders` (RLS verified) | ✅ DONE | reminders module; rls_isolation controls |
| `/process-reminders` Edge Function + OneSignal | ✅ DONE | `process-reminders/index.ts` + helpers |
| Query due → fetch player id → push → mark sent | ✅ DONE | `due_reminders()` + Edge update; pg test |
| `pg_cron` + `pg_net` hourly schedule | ✅ DONE | `20260527040001` (founder-applied) |
| Inactivity re-engagement (30d) | ✅ DONE | `users_to_reengage`; pg test |
| Secret-header auth (no public blasts) | ✅ DONE | `cronSecretValid` fail-closed; verify_jwt=false |
| No-spam guard (once / 30d) | ✅ DONE | cooldown in query + `last_reengagement_sent_at` stamp; pg test |
| Analytics `reminder_set` | ✅ DONE | `analytics.dart` + form |
| Live cron apply + push send on Supabase | ⏳ MANUAL | §6 |

**Verified now:** the reminder/re-engagement selection logic, the security guard, and the reminders RLS are all proven against real Postgres + node; UI + analytics are wired and analyze/test green. Stopping for approval.
