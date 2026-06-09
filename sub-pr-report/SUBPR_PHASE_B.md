# SUB-PR Report — Phase B: Family-Deletion Cascade Compliance Fix (RF-4 / H1)

**Branch:** `phase-b-family-deletion-cascade`
**PR:** https://github.com/emredogan-cloud/PawDoc/pull/32 → `main`
**Date:** 2026-06-09
**Status:** Implemented + validated (test-rls.sh PASS + negative control). **NOT merged, NOT applied to prod** — STOPPED for founder approval per the one-sub-PR-at-a-time discipline. Phase C not started.

---

## Problem (confirmed from the schema)
- `family_groups.owner_user_id → public.users(id)` **ON DELETE CASCADE**
- `pets.family_group_id → family_groups(id)` **ON DELETE RESTRICT**, column **NOT NULL**

Deleting a **shared-group owner** cascades away their owned `family_groups`, but any **co-member's** pet still pointing at that group trips the RESTRICT → the whole `deleteUser` **500s** (GDPR / Apple 5.1.1(v) — a user can't delete their account), and co-members are silently orphaned. Solo-owner deletion already worked (the owner's own pet cascades via `pets.user_id` in the same statement) — verified on-device last session.

## Fix (approach: **dissolve + reassign to solo**, founder-approved)
A `BEFORE DELETE` trigger on `public.users` (`handle_owner_deletion_family_reassign`) reassigns every **co-member** pet out of the departing owner's groups back to that co-member's **own solo group** *before* the cascade runs. Then the owner's groups contain only the owner's own pets (which cascade via `pets.user_id`), so the RESTRICT can't fire and **another user's pet is never lost**. Co-members' membership rows are removed by the existing `family_members.group_id ON DELETE CASCADE`.

**Why a DB trigger (not Edge-only):** enforced at the data layer, so it's correct regardless of the deletion path (the `delete-account` Edge Function, the admin API, or a raw cascade) and is directly testable by `test-rls.sh`. `delete-account` stays a thin `deleteUser` call — no Edge change needed. `SECURITY DEFINER` (reassigns other users' pets → must bypass RLS); only ever fires on a `public.users` DELETE, which is service-role/superuser-only.

**Invariant relied on:** every user has a solo `family_group` (created by `users_create_solo_family` on `public.users` INSERT) — the reassignment target. Phase C hardens that provisioning further.

## Files
- `supabase/migrations/20260609160000_family_deletion_cascade.sql` — the trigger + function.
- `supabase/tests/family_deletion_cascade.sql` — self-contained shared-group-owner deletion case (seeds fresh users C owner + D co-member; D shares a pet into C's group; deletes C; asserts: C + group + C's pets gone, **D untouched, D's pet preserved + reassigned to D's solo group, no orphaned `family_members`**).
- `scripts/test-rls.sh` — wires the migration + new test into the Docker run.

## Validation
| Check | Result |
|---|---|
| `./scripts/test-rls.sh` (with fix) | **PASS** — `PHASE B FAMILY-DELETION CASCADE OK` + all existing tests (rls_isolation, account_deletion, family_sharing, family_invites) still green |
| **Negative control** (migration removed) | **FAIL** as expected: `ERROR: update or delete on table "family_groups" violates foreign key constraint "pets_family_group_id_fkey"` (rc=3) — proves the test catches the real bug and the trigger is what fixes it |
| Solo-owner deletion | unchanged (trigger is a no-op when the owner's groups hold no co-member pets) |
| Rollback-criteria safety | no deletion path loses another user's pet — co-members' pets are reassigned, asserted in the test |

*(shellcheck not installed on this host; the `test-rls.sh` edit only adds a `-f` continuation line identical in form to the existing ones — no new shell logic.)*

## Success criteria (playbook) — met
- ✅ `test-rls.sh` passes including the new shared-group deletion test.
- ✅ Deleting a shared-group owner leaves no orphaned `family_groups`/`family_members`/pets and does not error.
- ✅ Solo-group case unchanged.

## Remaining / next
- **Not applied to prod yet.** The migration ships to prod via the coordinated deploy (`supabase db push`, or the same direct-apply path used for the Phase A profile trigger) — fold into the R2 + failover deploy once you've populated the real R2 creds.
- **Pending (founder, parallel):** populate the 5 real R2 creds in Doppler `prd` (still `SET_IN_PHASE_0.2`); enable Gemini billing (or rely on the now-merged Claude failover, which also needs the AI-service redeploy to go live).
- **Phase C** (auth.users provisioning trigger) is the next sub-PR — **not started**, pending approval here.

**STOP — awaiting founder approval to squash-merge PR #32 and proceed to Phase C.**
