# Sprint B1 — Real-World Reliability + Chaos Hardening — Plan

**Status:** Plan. Implementation tracked in
[`sprint-b1-reliability-implementation.md`](sprint-b1-reliability-implementation.md)
once shipped.
**Owner:** Founder.
**Companion audits:**
- [`phase1-full-audit.md`](phase1-full-audit.md) §M / R / O findings
- [`phase1-production-risks.md`](phase1-production-risks.md) R-13/14/15/16/30/31/33
- [`phase1-stabilization-plan.md`](phase1-stabilization-plan.md) P1.7 / P1.8 / P1.15 / P2.10
- [`sprint-a2-hardening-implementation.md`](sprint-a2-hardening-implementation.md) — closed P0 list

---

## 0. Charter

This is **not** a feature sprint. The job is to ratchet down the
"real-world failure" risk surface that the audit and Sprint A2's
debrief already flagged.

The explicit *non-goals* are:

- New screens, new flows, new analytics events
- Architectural redesign (no replacing Supabase Functions, no
  switching state mgmt, no replacing the storage backend)
- New SDKs beyond `connectivity_plus` which is **already** in
  `pubspec.yaml` and unused
- "Just-in-case" abstractions for things the audit didn't flag
- Refactoring code paths the audit was happy with

The aim: when production users go through tunnels, suspend the app,
double-tap buttons, or have a flaky barista wifi, **the app fails
safely** — never loses quota, never strands orphan uploads, never
gets stuck on a loading screen, never silently double-submits.

---

## 1. Discovered Failure Modes (audit consolidation)

Pulled from the four source docs; numbered for traceability.

### 1.1 Network / Retries / Timeouts
| ID | Source | Failure |
|----|--------|---------|
| F-N1 | R-33 | No client-side timeout cap on the `analyze` call; users on flaky networks see indefinite spinners. |
| F-N2 | R-33 | No client-side timeout on storage upload either. |
| F-N3 | A-2 | The retry contract diverges across mobile / edge / AI; *no client retries at all* on mobile. Acceptable, but the resulting **error mapping is too coarse**: `network` is used for both real "no internet" and "function returned a 5xx without a body". |
| F-N4 | (new) | `connectivity_plus` is a dependency but unused — we have no offline pre-flight, no offline banner, and "submit while offline" yields a generic `network` failure. |

### 1.2 Upload reliability
| ID | Source | Failure |
|----|--------|---------|
| F-U1 | H-8 / P1.7 | Orphaned storage objects: when `_analyze.submit` throws after a successful upload, the image stays in `pet-uploads/<user>/…` forever. Bucket has no TTL. |
| F-U2 | P1.8 / R-31 | `_pendingImage` survives the failure but the **storage key from a successful upload is not cached** — retrying the same analysis re-uploads, doubling the orphan footprint. |
| F-U3 | R-31 | Background-during-upload silently cancels the in-flight upload; the user lands back on the capture screen with no recovery affordance. Phase 2 (iOS BGProcessing) is the proper fix; B1 ships *safe failure*, not background tasks. |
| F-U4 | (new) | Storage bucket admits up to 5 MiB; client target is 2 MB; nothing guards against a malformed-MIME object slipping past `allowed_mime_types` if the SDK reports its own content-type wrong (M-8/R-5 — magic-byte sniffing is out-of-scope here). |

### 1.3 Mobile lifecycle
| ID | Source | Failure |
|----|--------|---------|
| F-L1 | M-3 / P2.10 | `AuthController` can be stuck in `AuthVerifying` if the user backgrounds between `verifyOTP` returning and the auth stream firing `Authenticated`. Out of scope for B1 (auth-flow-specific). |
| F-L2 | (new, found while reading code) | `AnalysisController` is `autoDispose`; long-running awaits (`uploadPetImage`, `analyze.submit`) can resolve **after** dispose. `state = …` writes on a disposed `StateNotifier` are silent in release but raise in tests. |
| F-L3 | M-2 | `analysis_loading_screen` runs a `Timer.periodic` with `!mounted` setState guard; ticks still fire after the widget is gone until `dispose()` cancels. Cosmetic but flagged. |
| F-L4 | (new) | `_AppLifecycleObserver._maybeRefreshOnResume` refreshes pets + re-binds RC/OneSignal after 5 min idle, but never **resets a stuck `AnalysisUploading` / `AnalysisAnalysing` state**. After a long background, the user may resume into a frozen "Uploading…" screen. |

### 1.4 Async safety
| ID | Source | Failure |
|----|--------|---------|
| F-A1 | (new) | Double-tap on the "Analyze" button: the controller's `_submitting` flag is correct (race-window is microseconds) but the `_canSubmit` UI check is **state-based and racy**; the button disables on state transition, not on submit-flag flip. |
| F-A2 | M-5 | `Object` catch in `analysis_controller.dart` masks programming bugs as `unknown`. Re-throw in debug; capture to Sentry in release. |
| F-A3 | (new) | `Future` returned by `submit()` is non-cancellable; if controller is disposed mid-flight, the upload + analyze still execute against the network. We cannot cancel the HTTP call, but we **can** discard the result safely (`_disposed` guard). |

### 1.5 Offline UX
| ID | Source | Failure |
|----|--------|---------|
| F-O1 | (new) | No offline detection anywhere. The user gets the generic "No internet connection" copy only **after** the request fails. Pre-flight offline check would save the round-trip. |
| F-O2 | (new) | `AnalyzeFailureKind` lumps timeout / offline / partial-upload / upstream into the same two buckets (`network`, `upstreamUnavailable`). Users see "No internet connection" when they're online but the AI service is slow. |

### 1.6 Retry safety
| ID | Source | Failure |
|----|--------|---------|
| F-R1 | A-2 | Mobile does not retry. The audit explicitly endorses this for non-idempotent operations. We keep it. |
| F-R2 | (new) | When the user manually retries (taps Analyze again after a failure), the controller may re-upload + re-consume quota. The refund RPC closes the quota loop; F-U2 closes the upload-duplicate loop. |
| F-R3 | (new) | If the user's storage upload **succeeded but the controller didn't observe it** (e.g. timeout firing right at success), manual retry creates a second object — first one is orphaned. F-U1 cleanup catches it; F-U2 prevents it. |

### 1.7 Orphan / temp-file cleanup
| ID | Source | Failure |
|----|--------|---------|
| F-O3 | P1.7 | No TTL on `pet-uploads`. Bucket grows monotonically. |
| F-O4 | (new) | `image_picker` writes a temp file the OS cleans on its own cadence; on iOS this can take days. We don't control that, but we *should* drop the byte buffer from `_pendingImage` aggressively when the analysis completes. |

### 1.8 Duplicate prevention
| ID | Source | Failure |
|----|--------|---------|
| F-D1 | M-4 / P2.9 | RevenueCat webhook idempotency — flagged out-of-scope (Phase 2). |
| F-D2 | A2 closed | Refund RPC is idempotent via `request_id`. |
| F-D3 | (new) | Storage uploads are de-duped by filename randomness, but **not** by content. A user pressing Analyze 3× rapidly with the same image creates 3 uploads. The `_submitting` flag + `_canSubmit` should prevent this, but the UI race in F-A1 leaves a 1-frame window. |

---

## 2. Scope (what we ship in B1)

Each item maps to one or more F-codes above. Out-of-scope items are
explicitly enumerated in §3.

### B1.1 — ConnectivityService (closes F-N4, F-O1)

- New: `mobile/lib/shared/services/connectivity_service.dart`
- Wraps `connectivity_plus` (already a dep). Pure offline detection.
- Public surface:
  - `Stream<bool> get onlineChanges` (initial value emitted)
  - `Future<bool> isOnline()` for one-shot pre-flight
- Riverpod provider exposes the stream; a derived
  `connectivityProvider` resolves to `bool` for widgets.
- `NoopConnectivityService` (test seam) + `RecordingConnectivityService` (test seam).
- Tests: provider fallback, initial state emission, stream
  transitions, no side effects in `RecordingConnectivityService`.

### B1.2 — Analyze + storage timeouts + richer failure taxonomy (closes F-N1, F-N2, F-N3, F-O2)

- `AnalyzeServiceImpl.submit`: wrap the `functions.invoke` call in
  `.timeout(Duration(seconds: 30))`. Catch `TimeoutException` →
  throw `AnalyzeFailure(AnalyzeFailureKind.timeout)`.
- `StorageServiceImpl.uploadPetImage`: wrap the `uploadBinary` call in
  `.timeout(Duration(seconds: 45))`. Catch `TimeoutException` → throw
  `StorageUploadFailure('timeout')`. Separately distinguish from
  generic upload failure.
- Extend `AnalyzeFailureKind` with:
  - `timeout` — request exceeded the per-call cap
  - `offline` — pre-flight saw offline, OR request failed with no
    response and `ConnectivityService` reports offline
  - `uploadInterrupted` — storage upload timed out or threw a typed
    interruption error (network change, app paused, …)
- Map each to user-friendly copy that doesn't lie about *which*
  layer broke.

### B1.3 — AnalysisController hardening (closes F-U2, F-L2, F-A1, F-A2, F-A3, F-R2, F-R3, F-D3)

The controller already does most of the right things; we ratchet
down four specific risks:

1. **Operation IDs** — every `submit()` invocation assigns a fresh
   `_currentAttemptId`. Late callbacks check the id matches the
   active attempt before mutating state. Closes F-L2 / F-A3.
2. **Storage-key caching** — successful uploads cache the storage
   key keyed by the `PickedImage` identity. Retries with the same
   image reuse the key. Closes F-U2 / F-R3.
3. **Double-tap guard** — `_submitting` flag is sticky from the
   first instruction of `submit()` until the `finally`. Already
   exists; we add an `enabled` getter the UI can render on so the
   button is greyed out the *frame* the submit fires. Closes F-A1.
4. **Dispose safety** — override `dispose()`, set `_disposed = true`,
   and gate every state assignment after an `await` on it.
   Closes F-L2.
5. **Debug re-throw** — in `kDebugMode`, `Object` catch re-throws
   after recording the failure. Closes F-A2.

### B1.4 — Capture screen: offline banner + safer submit (closes F-O1, F-D3, F-L4)

- Use `connectivityProvider` to render a small "Offline" banner.
- Disable the Analyze button when offline (with explanatory copy
  underneath) — pre-flight to avoid the round-trip + spurious quota
  consume attempt.
- Wire the lifecycle observer: after a `_idleResumeThreshold`-long
  background, if the analysis state is `AnalysisUploading` or
  `AnalysisAnalysing`, transition the controller to a
  `AnalysisFailedState(uploadInterrupted, "Connection was lost while
  uploading.")`. The user can retry; the storage-key cache will
  reuse the upload if it actually completed.

### B1.5 — Orphan cleanup migration (closes F-U1 / F-O3 / P1.7)

A SQL function + scheduled trigger that purges storage objects in
`pet-uploads` older than 7 days that no `analyses` row references.

- **Function**: `cleanup_orphan_pet_uploads(p_older_than interval
  default '7 days')` `SECURITY DEFINER`, service-role EXECUTE,
  returns `int` (rows deleted). Uses `storage.delete_object()` so it
  respects bucket policies; ignores rows still in flight (anything
  newer than the interval).
- **Schedule**: `pg_cron.schedule('pawdoc-orphan-cleanup', '0 4 * * *',
  ...)` if `pg_cron` is available, else documented manual cron in
  `operational-runbook.md`. Production-only; the migration uses a
  `DO $$ ... IF available $$` block so local dev (no `pg_cron`)
  doesn't fail.
- **pgTAP**: tests for the *function*, not the schedule:
  - Returns 0 when no objects exist
  - Deletes orphans older than the cutoff
  - Preserves objects referenced by an analysis row
  - Preserves objects newer than the cutoff
  - Service-role only (no `authenticated` EXECUTE)

### B1.6 — Tests

Mobile, in addition to whatever lives in B1.1/B1.4:

- `analysis_controller_chaos_test.dart`:
  - Upload timeout → `uploadInterrupted` state, no analyze call,
    storage-key cache empty
  - Analyze timeout after successful upload → `timeout` state,
    storage-key cache **populated**, retry reuses key (one upload
    total)
  - Repeated `submit()` while busy is a no-op
  - `dispose()` mid-await: no state mutation, no exception
  - Offline → submit refused with `offline` failure, no upload
- `connectivity_service_test.dart`: stream wiring, provider fallback.
- Existing controller tests need a `ConnectivityService` injected;
  they get a `RecordingConnectivityService.alwaysOnline()`.

SQL:
- `orphan_cleanup.test.sql` — the four cases above.

---

## 3. Deliberately out of scope

| Item | Why deferred |
|------|--------------|
| iOS BGProcessing for resumable uploads | Phase 2 — needs entitlement + watchdog logic |
| Edge function retry policy hardening (A-2) | Stable per the audit; B1 is mobile-side |
| Token-cost telemetry in `analyze_completed` | Phase 2 (`phase1-technical-debt.md`) |
| `webhook_events` idempotency table (M-4) | Phase 2 (`P2.9`) |
| OOM-safe compression isolate (R-16) | Phase 2 (`P1.15`) — `compute()` rewiring |
| AuthVerifying timeout (M-3) | Phase 2 (`P2.10`) |
| Magic-byte MIME sniffing on storage objects | Phase 3 |
| Onboarding draft TTL / corruption detection | Not in audit; no evidence of failures |
| Sentry alert routing wiring (R-28) | Operational, not engineering — covered in `operational-runbook.md` |

---

## 4. Files added / modified

### Added
```
mobile/lib/shared/services/connectivity_service.dart
mobile/test/connectivity_service_test.dart
mobile/test/analysis_controller_chaos_test.dart
supabase/migrations/20260516030000_orphan_cleanup.sql
supabase/tests/orphan_cleanup.test.sql
docs/reports/sprint-b1-reliability-plan.md          (this file)
docs/reports/sprint-b1-reliability-implementation.md (post-impl)
```

### Modified
```
mobile/lib/shared/services/analyze_service.dart         + timeout, kinds
mobile/lib/shared/services/storage_service.dart         + timeout
mobile/lib/features/analysis/analysis_controller.dart   + attempt-id, key-cache, dispose-safe, debug re-throw, offline pre-flight
mobile/lib/features/analysis/analysis_capture_screen.dart + offline banner + disable
mobile/lib/shared/services/app_lifecycle_observer.dart  + clear stuck-upload state on resume
docs/operational-runbook.md                             + cron job + manual-run section
docs/environment-setup.md                               + pg_cron note
```

---

## 5. Validation checklist

Before commit:

- [ ] `flutter analyze` clean
- [ ] `flutter test` 100% pass (existing 106 + new tests)
- [ ] `supabase test db --local` 100% pass (existing 69 + 5 new)
- [ ] `deno check` on edge functions (no behavioural change but
      sanity)
- [ ] Manual smoke: airplane-mode toggle on capture screen surfaces
      the offline banner and disables submit
- [ ] Manual smoke: kill app mid-upload, relaunch, controller is in
      `AnalysisIdle` (lifecycle observer caught the long background)

---

## 6. Definition of done

- All F-codes labelled in §1 either have a B1 fix below or an
  explicit out-of-scope entry in §3 with the deferral target.
- The implementation report enumerates every fix + its F-code +
  test coverage.
- No new lint, analyser, or test regressions.
- Operational runbook reflects the cron job + how to run it
  manually if `pg_cron` is unavailable.
