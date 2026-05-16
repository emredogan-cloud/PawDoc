# Sprint B1 — Real-World Reliability + Chaos Hardening — Implementation Report

**Status:** Complete. Ready to commit + push.
**Companion plan:** [`sprint-b1-reliability-plan.md`](sprint-b1-reliability-plan.md)
**Implemented on:** 2026-05-16

---

## Summary

Sprint B1 closes the reliability gaps the Phase 1 audit flagged
without expanding scope. Every change is a hardening change: no new
features, no new SDKs (the new `connectivity_plus` was already in
`pubspec.yaml`, unused), no architectural redesign.

The user-facing improvements:

- Submitting while offline now fails fast with friendly copy instead
  of consuming a quota slot to discover the obvious.
- Timeouts on upload + analyze surface a specific "took too long"
  message rather than the generic "no internet."
- Retrying a failed analysis on the **same** image **no longer
  re-uploads** — the cached storage key is reused, so a user mashing
  the retry button never creates more than one orphan object per
  picked photo.
- App suspended for >5 min mid-upload? On resume the controller
  switches to a recoverable "Connection was lost while uploading"
  state with an Analyze-again button, instead of a stuck spinner.
- Storage bucket no longer grows monotonically — an idempotent
  service-role-only RPC purges orphans older than 7 days and the
  operational runbook documents the daily `pg_cron` schedule.

| Plan item | Status |
|-----------|--------|
| B1.1 ConnectivityService + offline detection | ✅ Shipped |
| B1.2 Analyze + storage timeouts + richer failure kinds | ✅ Shipped |
| B1.3 AnalysisController hardening (attempt IDs, key caching, dispose-safe, offline pre-flight, debug re-throw) | ✅ Shipped |
| B1.4 Chaos tests | ✅ Shipped (12 new tests) |
| B1.5 Orphan-cleanup RPC + pgTAP + runbook | ✅ Shipped (7 new pgTAP tests) |

---

## 1. Discovered failure modes → fixes

Cross-references the F-codes in §1 of the plan.

### F-N1 / F-N2 — No client-side timeout

`AnalyzeServiceImpl.submit` wraps the `functions.invoke` call in a
30 s `.timeout(...)`. `StorageServiceImpl.uploadPetImage` wraps the
storage upload in a 45 s timeout. Both constructors accept a
`Duration? timeout` override for tests.

### F-N3 — Coarse error mapping → distinct failure kinds

`AnalyzeFailureKind` grew four members:

- `timeout` — request exceeded the per-call cap
- `offline` — pre-flight saw the device offline OR a network call
  failed with no response and `ConnectivityService` reports offline
- `uploadInterrupted` — storage upload timed out or threw
  `StorageUploadInterrupted` (lifecycle observer also uses this)
- (unchanged) `network` — server reachable but no useful response

Each has a unique user-facing string. The lifecycle observer maps a
resume-after-long-idle wedged loading state to `uploadInterrupted`
so the user always sees a specific, actionable message.

### F-N4 / F-O1 — Unused connectivity dependency

New: `mobile/lib/shared/services/connectivity_service.dart`.

- Singleton `ConnectivityServiceImpl` wraps `connectivity_plus`.
- Translates the `List<ConnectivityResult>` API to a boolean
  `online` stream — any non-`none` interface counts as online.
- Fails open: plugin throws → assume online. Captive portals and
  DNS failures still get caught downstream by the request timeout.
- `AlwaysOnlineConnectivityService` (test stub) +
  `RecordingConnectivityService` (chaos test seam).
- `connectivityProvider` is a `StreamProvider<bool>` for widgets.

### F-U1 / F-O3 — Orphaned storage objects (P1.7)

New: `supabase/migrations/20260516030000_orphan_cleanup.sql`

`cleanup_orphan_pet_uploads(p_older_than interval default '7 days')`:

- `SECURITY DEFINER` with `search_path = public, storage`
- Opts into Supabase's `protect_delete` trigger via
  `set_config('storage.allow_delete_query', 'true', true)` —
  scoped to the calling transaction
- `DELETE FROM storage.objects WHERE bucket_id = 'pet-uploads' AND
  created_at < now() - p_older_than AND NOT EXISTS (SELECT 1 FROM
  analyses WHERE input_storage_key = name)`
- Returns `int` deletion count for cron logging / operator review
- `REVOKE … FROM PUBLIC/anon/authenticated; GRANT EXECUTE TO
  service_role`

Production deployment uses `pg_cron`:
```sql
SELECT cron.schedule(
  'pawdoc-orphan-cleanup', '0 4 * * *',
  $$SELECT cleanup_orphan_pet_uploads();$$);
```
Local dev intentionally skips `pg_cron` — the function is still
callable directly. Operational runbook §6 documents both paths plus
the manual SQL editor variant for ad-hoc cleanups.

### F-U2 / F-R2 / F-R3 / F-D3 — Storage-key caching

`AnalysisController` now caches the storage key from a successful
upload, keyed by `identical(image, _cachedUploadFor)`. Retrying a
failed analyze (or re-tapping after a transient AI failure) on the
**same** image short-circuits the upload step entirely — the same
key is sent through to the edge function.

The cache is invalidated when:

- The user picks a new image (`pickImage`)
- The user clears the image (`clearImage`)
- An analysis completes successfully (the key is now committed to
  an `analyses` row, retrying would create a parallel record)
- The controller is reset / disposed

A chaos test (`upload reliability: successful upload then analyze
timeout caches storage key`) verifies the storage service's
`uploadCount` is 1 across two `submit()` calls on the same image.

### F-L2 / F-A3 — Dispose-safe state mutation

`AnalysisController.dispose()` sets `_disposed = true` (kept
alongside Riverpod's `mounted` for explicit semantics in tests).
Every state assignment after an `await` routes through
`_writeState(next, attemptId: …)`, which drops the write when:

- The controller is disposed, OR
- The supplied `attemptId` doesn't match `_currentAttemptId`
  (superseded by a later submit or by the lifecycle recovery)

A chaos test (`dispose mid-flight: dispose during await does not
raise + state stays Idle`) drives a `Completer`-stalled upload,
disposes the controller, then completes the upload — the
`submit()` future resolves cleanly without raising
"StateNotifier was modified after dispose".

### F-A1 / F-D3 — Double-tap race

`AnalysisController._submitting` flips to `true` **synchronously**
at the top of `submit()` — before any `await`. The previous
sequence ran the offline pre-flight first, which microtask-yielded
and left a 1-frame window where a second `submit()` could squeeze
through. The new ordering claims the slot immediately, then runs
the connectivity check inside the try block.

The capture screen consumes a new `isBusy` getter on the
controller, so the Analyze button disables on the same frame as
the tap (belt + braces with the state-based `_canSubmit` check).

### F-A2 — Programmer bugs masked as `.unknown`

The generic `Object` catch in `submit()` still tags the failure as
`.unknown` (so production users see friendly copy) but `rethrows`
in `kDebugMode`. The bug now hot-reloads onto the developer's
console / test failure instead of being silently swallowed.

### F-L4 — Lifecycle wedged-loading recovery

`_AppLifecycleObserver._maybeRefreshOnResume` already woke up after
5+ min idle to refresh pets + re-bind RC/OneSignal. Sprint B1 adds
one line: if the analysis controller provider exists in the
container, call `notifyResumedAfterLongIdle()`. The controller's
hook checks whether the state is `AnalysisUploading` /
`AnalysisAnalysing` and, if so, transitions to a
`uploadInterrupted` failure (and invalidates `_currentAttemptId`
so the original HTTP callbacks discard their late writes).

### F-O2 — Offline pre-flight + dedicated banner

The capture screen reads `connectivityProvider` and renders an
`_OfflineBanner` above the image area when offline. The Analyze
button is disabled in that state. The controller's `submit()`
double-checks via `ConnectivityService.isOnline()` and bails to
`.offline` if the device went offline between paint and tap.

### F-O4 — Eager byte-buffer release

On successful analysis, `_cachedUploadFor`/`_cachedStorageKey` are
nulled out alongside the existing logic. (The `_pendingImage` byte
buffer was already cleared in `reset()`.)

---

## 2. Lifecycle guarantees

After Sprint B1, the analysis flow exposes these invariants:

| Scenario | Guarantee |
|----------|-----------|
| User taps Analyze twice in the same frame | At most one submit runs. |
| User taps Analyze while offline | No quota consume, no upload, friendly copy. |
| Upload times out at 45 s | No analyze call; controller in `uploadInterrupted`; storage cache empty; retry is safe. |
| Analyze times out at 30 s | Quota refund (Sprint A2) + storage key cached; retry reuses the same upload. |
| User backgrounds the app mid-upload for ≥5 min | On resume the loading state flips to `uploadInterrupted`; tap "Analyze" again to retry. |
| User navigates away mid-submit (`autoDispose` fires) | `submit()` future resolves cleanly; no state-after-dispose exception. |
| User retries a failed analysis | One upload per picked photo, even across N retries. |
| Picking a new image after a failed retry | Cache busts; next submit re-uploads. |
| Pet image left in bucket by a failed analysis | Cleared by `cleanup_orphan_pet_uploads()` ≥7 days later (cron). |

---

## 3. Retry guarantees

Carried over from `phase1-full-audit.md §A-2`, no behaviour changes:

- Mobile → Edge: **0 retries**. Non-idempotent by design.
- Edge → AI service: **1 retry** on transport errors only.
- AI service → providers: **1 retry** on 5xx + transport; 0 on
  timeout.

Sprint B1's storage-key cache + Sprint A2's refund RPC together
mean that user-initiated retries (the only retry surface the mobile
has) are now **safe**: at most one upload + at most one quota
consume per attempt, regardless of how many times the user re-taps
Analyze.

---

## 4. Test coverage

| Suite | Before B1 | After B1 |
|-------|-----------|----------|
| Mobile (`flutter test`) | 106 | 124 |
| pgTAP (`supabase test db --local`) | 69 | 76 |

New mobile test files:
- `connectivity_service_test.dart` — 6 tests (Always-online stub,
  Recording stub initial state + transitions, stream replay)
- `analysis_controller_chaos_test.dart` — 12 tests covering every
  failure mode in §1 above

New SQL test file:
- `orphan_cleanup.test.sql` — 7 assertions (default cutoff,
  idempotency, reference preservation, freshness window, interval
  parameter flow-through, RLS/EXECUTE grants)

---

## 5. Remaining reliability risks

These were considered for B1 and **deferred with named landing
zones**:

| Item | Deferred to | Reason |
|------|-------------|--------|
| iOS BGProcessing for resumable uploads | Phase 2 | Needs entitlement, watchdog logic; B1 ships *safe failure* not background tasks |
| Edge function transport retry policy hardening (A-2) | Phase 2 | Edge function side stable; B1 scope is mobile |
| Token-cost telemetry in `analyze_completed` | Phase 2 | `phase1-technical-debt.md` O-3 |
| `webhook_events` idempotency table (M-4) | Phase 2 | RevenueCat webhook safety; `P2.9` |
| OOM-safe compression isolate (R-16) | Phase 2 | `P1.15`; needs `compute()` rewiring |
| `AuthVerifying` stuck-state timeout (M-3) | Phase 2 | `P2.10`; auth-flow specific |
| Magic-byte MIME sniffing on storage objects | Phase 3 | M-8/R-5 |
| S3/R2 blob reconciliation (vs `storage.objects` rows) | Phase 2 | Supabase storage worker handles eventually; cost impact is low |
| Sentry alert routing wiring (R-28) | Operational | Covered in `operational-runbook.md` |

---

## 6. Known platform limitations

- **`connectivity_plus`** reports network *route* state, not
  reachability. Captive portals and DNS poisoning report online;
  the 30 s analyze timeout is the catch-net.
- **Supabase `storage.objects` direct DELETE** is blocked by the
  `storage.protect_delete` trigger. Our cleanup function opts in
  via `set_config('storage.allow_delete_query', 'true', true)`,
  scoped to the calling transaction.
- **Supabase storage blob reconciliation** is eventual — deleting
  a `storage.objects` row doesn't immediately delete the S3/R2
  blob. The cost impact is small; if bucket size doesn't shrink
  within 24 h of a large cleanup, file a Supabase support ticket
  (documented in `operational-runbook.md §6.3`).
- **Flutter `autoDispose`** can fire `dispose()` while async work
  is in flight. We handle this with the `_disposed` + attempt-id
  guards on `_writeState`; the HTTP request itself still runs to
  completion (Dart `Future`s aren't cancellable).
- **`pg_cron`** is not installed in Supabase local dev. Production
  deployment requires the operator to enable + schedule once
  (`operational-runbook.md §6.2`).

---

## 7. Validation results

| Surface | Tool | Result |
|---------|------|--------|
| Mobile static analysis | `flutter analyze` | ✅ no issues |
| Mobile tests | `flutter test` | ✅ 124/124 pass |
| pgTAP database tests | `supabase test db --local` | ✅ 76/76 pass |
| Edge function TypeScript | `deno check analyze/index.ts` | ✅ pass (no behavioural change) |

---

## 8. What's next

Sprint B1 closes the reliability backlog the audit flagged. The
remaining audit items (Phase 2 `P2.*` codes, plus the deferred
list in §5) are now the priority queue. None are launch blockers
for the closed TestFlight beta.
