# SUB-PR Report — Phase 3.1: Health History & Multi-Pet Foundation

**Status:** Complete and fully green (analyzer, unit tests, live RLS harness). The retention substrate — timeline, manual events, multi-pet switcher, breed cards — is built and tier-gated.
**Branch:** `phase-3.1-health-history` (from `origin/main` = `eb53de7`, which contains 0.1→2.3)
**Date:** 2026-05-27

---

## 1. Git `main` branch state

Verified by **content**, not just PR status (after `git fetch --prune` — an initial stale fetch briefly showed the pre-2.3 tip):

- `origin/main` HEAD = `eb53de7 Phase 2.3 store launch (#11)`, on top of `f25893d` (#10 workspace), `3882edf` (#9 legal), `e93c935` (#8 polish). Linear.
- Confirmed `docs/store_metadata/ios_app_store.md` is present on `main` → the 2.3 PR did squash-merge as #11.
- This branch is based on that tip — 1 sub-PR ahead, 0 behind.

## 2. Files created / modified

**Created (Flutter):**
```
mobile/lib/src/health/health_event.dart             HealthEvent model + type labels (no user_id col)
mobile/lib/src/health/health_events_repository.dart create()/listForPet() — RLS via parent pet
mobile/lib/src/health/timeline.dart                 TimelineItem + pure merge() + healthTimelineProvider(petId)
mobile/lib/src/health/history_timeline_screen.dart  timeline UI (watches active pet) + Log-event FAB
mobile/lib/src/health/health_event_form_screen.dart manual quick-add (type/date/notes/+weight)
mobile/lib/src/health/breed_insights.dart           static top-breed data + rotatingInsight() (pure)
mobile/lib/src/health/breed_insight_card.dart        rotating, tappable card (per-pet keyed)
mobile/lib/src/core/dates.dart                       tiny date formatter (no intl dep)
mobile/lib/src/pets/active_pet.dart                  activePetIdProvider + activePetProvider (reactive)
mobile/lib/src/pets/pet_limits.dart                  pure tier-limit logic (unit-tested)
mobile/lib/src/pets/add_pet_flow.dart                shared, tier-gated add-pet flow + multi_pet_added
mobile/test/health_test.dart                         14 unit tests (limits, breed, timeline, model)
scripts/verify-phase-3.1.sh                          phase verifier (struct + RLS + analyze + test)
sub-pr-report/SUBPR_PHASE_3.1.md                     this report
```
**Modified:**
```
mobile/lib/src/home/home_screen.dart      active-pet-centric: app-bar pet switcher, breed card,
                                          History + Log-event actions, Check target = active pet
mobile/lib/src/analytics/analytics.dart   + health_event_logged, multi_pet_added
mobile/lib/src/router/app_router.dart     + /history route
mobile/lib/src/pets/pets_list_screen.dart "Add pet" FAB → tier-gated startAddPetFlow
supabase/tests/rls_isolation.sql          + positive control: A inserts a health_event on its own pet
```
**No new env vars / secrets** (analytics events are not config). `ENVIRONMENT_VARS.md` unchanged.

## 3. How the multi-pet tier limits are enforced (Free/Premium = 2, Family = unlimited)

- **Pure logic** (`pets/pet_limits.dart`, unit-tested): `petLimitFor(status)` → `null` (unlimited) for `family`, else `2` (free / trial / premium). `canAddPet(status, count)` → `limit == null || count < limit`.
- **Single enforcement point** (`pets/add_pet_flow.dart`, `startAddPetFlow`) used by **both** add-pet entry points — the home app-bar switcher ("Add pet") and the "My pets" FAB. It reads the current pet count + the user's `subscription_status`, and **before** opening the form:
  - if the tier is at its cap → shows an **upgrade prompt → `PaywallScreen`** (this is a feature gate, not an emergency, so an upsell is allowed by the monetization invariant);
  - otherwise opens the pet form, and on success fires **`multi_pet_added`** when the user now has > 1 pet.
- **Fail-safe:** an unknown/loading subscription status is treated as **free** (most restrictive), so the gate never over-grants.
- **Scope note (surfaced):** this is the **client-side** gate the deliverable asked for. RLS still scopes every `pets` row to the owner; a *hard server-side* count cap (a DB trigger) is **not** added — flagged below as optional future hardening, not silently assumed.

## 4. ✅ RLS on `health_events` allows successful inserts (CR #2) — proven, not asserted

- `health_events` has **no `user_id` column** (owner-approved CR #2 design); ownership is derived from the parent pet. The existing `FOR ALL` policy's `WITH CHECK` is `EXISTS(pets WHERE pets.id = health_events.pet_id AND pets.user_id = auth.uid())`, which **covers INSERT**.
- I added a **positive control** to `supabase/tests/rls_isolation.sql`: acting as user A, insert a `health_event` for A's **own** pet. `./scripts/test-rls.sh` (ephemeral pgvector Docker) is **green**:
  - `INSERT 0 1` — A's own-pet health-event insert **succeeds**;
  - the pre-existing negative control still blocks A from writing to B's pet;
  - `RLS ISOLATION TESTS PASSED` + `ACCOUNT DELETION CASCADE OK`.
- **Net:** the manual quick-add will work in production under RLS, and cross-user writes remain blocked.

### Surfaced decision (did NOT silently apply the literal instruction)
The task asked for `WITH CHECK (auth.uid() = user_id)` on `health_events`. That column **does not exist** by the CR #2-approved schema (ownership is pet-derived). I **preserved the approved design** and *proved* the INSERT path works, rather than adding a redundant `user_id` column (which would revert an approved decision and denormalize ownership, risking drift between `health_events.user_id` and the pet's true owner). If you'd prefer an explicit `user_id` column anyway, say so and I'll add it as its own migration — flagging per the "surface, don't silently apply / preserve approved decisions" rule.

## 5. State management (Riverpod) — reactive pet switching

- `activePetIdProvider` (`NotifierProvider<String?>`) holds the selected pet id, persisted across launches via `shared_preferences` (`ActivePetPrefs`) and hydrated on build.
- `activePetProvider` (`Provider<Pet?>`) derives the active `Pet` from `petsListProvider` + the selection, falling back to the first pet. Selecting a pet updates the notifier → this provider recomputes → **everything watching it rebuilds at once**: the home breed card (keyed per pet so it resets cleanly), the "Check" target, and the history screen.
- `healthTimelineProvider` is `autoDispose.family<…, petId>`, so switching pets fetches a fresh, correctly-scoped timeline. The history screen watches `activePetProvider`, so it re-points even if the active pet changes while it is open.

## 6. Surfaced: breed data kept client-side (static), not a Supabase table (yet)

The roadmap phrased this deliverable as "breed data table … cached in Supabase"; your task said "a **static table or JSON configuration**." I implemented it as a **client-side static config** (`breed_insights.dart`) for the top breeds + species fallbacks. Rationale: it is static reference data (no per-user rows, no RLS, no network/latency, works offline). A Supabase-backed breed table (for remote content updates without an app release) is a clean **future enhancement** — flagged, not silently dropped.

## 7. Tests executed & results

| Test | Result |
|------|--------|
| `flutter analyze` | **No issues found** |
| `flutter test` (full suite) | **All 44 tests pass** (incl. 14 new in `health_test.dart`) |
| `./scripts/test-rls.sh` (Docker pgvector) | **PASS** — health_events own-pet INSERT succeeds; cross-user blocked; cascade OK |
| `./scripts/verify-phase-3.1.sh` | **exit 0** — all structural + RLS + analyze + test checks green; 3 MANUAL (device) |
| `shellcheck scripts/verify-phase-3.1.sh` (Docker) | **clean** |

Safety check included: a unit test asserts **no "diagnosis/diagnose" language** appears in any breed insight (consistent with the app's safety posture).

## 8. Known issues / scope notes

- Breed coverage is the **top breeds first** (per the roadmap execution-risk note) + species fallbacks; expand the table over time.
- The pet-limit gate is **client-side** (deliverable scope). Optional future hardening: a server-side per-user pet-count cap (DB trigger) for defense-in-depth.
- Weight events store the value in `metadata.weight_kg`; a dedicated weight-trend chart is a later (3.x) enhancement.
- Device-only UX (reactive switching, immediate timeline refresh, upgrade prompt at the cap) is **MANUAL** — listed in the verifier; can't be exercised headlessly.

## 9. Risks

- `health_events` INSERT relied on a working RLS policy (the CR #2 risk the roadmap flagged) — **retired** by the positive-control test now in CI's RLS harness.
- Active-pet persistence is best-effort (`shared_preferences`); worst case it falls back to the first pet — never a wrong-pet write, since every query is `petId`-scoped and RLS-guarded.

## 10. Git branch / commit / push

- Branch: `phase-3.1-health-history`
- Implementation commit (deliverables): `cefc59538e36f7bf9a7ecc0f096870c08f62eeaa`
- Push: pushed to `origin/phase-3.1-health-history`; open PR at https://github.com/emredogan-cloud/PawDoc/pull/new/phase-3.1-health-history

## 11. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Timeline interleaves analyses + manual events, RLS-scoped | ✅ DONE | `timeline.dart` `merge()` + unit test; RLS harness |
| Manual event add round-trips & appears immediately | ✅ DONE | form invalidates `healthTimelineProvider`; RLS insert proven |
| Multi-pet switcher enforces tier limits + switches all context | ✅ DONE | `active_pet.dart`, `add_pet_flow.dart`, home switcher; unit tests |
| Breed cards render for the pet's breed and rotate | ✅ DONE | `breed_insights.dart` + `breed_insight_card.dart`; unit tests |
| Both analytics events fire | ✅ DONE | `health_event_logged`, `multi_pet_added` wired |
| RLS INSERT on health_events works (CR #2) | ✅ DONE | `test-rls.sh` green (positive control added) |
| On-device reactive switching / immediate refresh / upgrade prompt | ⏳ MANUAL | verifier MANUAL items |

**Verified now:** analyzer clean, 44 tests green, and the `health_events` RLS INSERT is proven at the DB level. Two items were **surfaced for your decision** (no `user_id` column on `health_events`; breed data kept client-side) rather than silently applied. Stopping for approval before Phase 3.2 (Video Analysis Pipeline + semantic cache).
