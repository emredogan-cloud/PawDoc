# SUB-PR Report — Phase 3.4: Local Vet Finder & Health Export

**Status:** Complete and fully green (node, ruff/pytest, flutter analyze/test, shellcheck). Key-hiding Places proxy + location-aware vet finder with graceful fallback, and a shareable health report for vets.
**Branch:** `phase-3.4-vet-finder-export` (from `origin/main` = `0ada022`, contains 0.1→3.3 P2)
**Date:** 2026-05-27
**Scope note:** Roadmap Phase 3.4 also includes home-screen widgets, a full Android-parity sweep, Airvet deep links, and SEO articles — those are **out of scope** for this sub-PR (you scoped it to the vet finder + health export). Flagged for a later sub-PR.

---

## 1. Files created / modified

**Created**
```
supabase/functions/find-vets/index.ts            key-hiding Google Places (New) proxy
supabase/functions/_shared/places.mjs (+test)    buildPlacesRequest / parseVets / haversine (nearest 5)
mobile/lib/src/vet_finder/vet.dart               clean Vet model (mirrors the proxy JSON)
mobile/lib/src/vet_finder/vet_finder_service.dart invokes /find-vets (findNearby / findByQuery)
mobile/lib/src/vet_finder/maps_links.dart        pure native-maps + tel deep links (fallback)
mobile/lib/src/vet_finder/vet_finder_screen.dart location → list (call+directions) / manual / maps
mobile/lib/src/export/health_report.dart         pure buildHealthReport → Markdown
mobile/lib/src/export/health_report_service.dart fetch latest analysis + events → build → share
mobile/test/vet_finder_test.dart, export_test.dart  unit tests
scripts/verify-phase-3.4.sh                      phase verifier (+ the no-key-in-client assertion)
sub-pr-report/SUBPR_PHASE_3.4.md                 this report
```
**Modified**
```
supabase/config.toml                          [functions.find-vets] verify_jwt = true
mobile/lib/src/analysis/emergency_result_screen.dart  "Find an emergency vet" → VetFinderScreen(emergency)
mobile/lib/src/analysis/result_screen.dart    MONITOR result → "Find a nearby vet"
mobile/lib/src/health/history_timeline_screen.dart    "Export health report" app-bar action
mobile/lib/src/analytics/analytics.dart       vet_finder_opened / vet_called / health_report_exported
mobile/pubspec.yaml (+ .lock)                  + geolocator ^13.0.0 (resolved 13.0.4)
ENVIRONMENT_VARS.md                            PLACES_API_KEY (server-only) + billing-alert note (CR #12)
```

## 2. How the Places call is securely routed through the Edge Function

- **The key is server-only.** `PLACES_API_KEY` lives **only** in the `find-vets` Edge Function's env (`supabase secrets set` / Doppler). The Flutter client calls `supabase.functions.invoke('find-vets', body: {lat,lng})` (or `{query}`) and receives a **clean JSON array** — it never sees a key or a keyed endpoint.
- **The proxy** (`_shared/places.mjs` + `find-vets/index.ts`) builds a **Places API (New)** request — `places:searchNearby` (`includedTypes: ["veterinary_care"]`, `rankPreference: DISTANCE`) for lat/lng, or `places:searchText` for a zip/city — with a tight **`X-Goog-FieldMask`** (name, phone, open-now, address, location) so phone + open status come back in **one** request. It sends the key as the **`X-Goog-Api-Key`** header server-side, then `parseVets()` normalizes + sorts by distance and returns the **nearest 5**.
- **Abuse protection:** `find-vets` is **`verify_jwt = true`** — only signed-in users can call it, so the Places quota can't be drained anonymously. ENV docs call for a **billing budget alert** (CR #12) and a key restricted to the Places API.
- **Fail-safe:** no key / upstream error → the function returns `200 {vets: []}` (not a 5xx), so the client degrades to its maps fallback instead of erroring.
- **Verified:** `verify-phase-3.4.sh` greps all of `mobile/lib` and asserts **no** `X-Goog-Api-Key`, `PLACES_API_KEY`, `AIza…` key, or keyed `maps.googleapis.com/maps/api` endpoint appears in the client. ✅

## 3. How the location-permission-denial fallback is handled

`VetFinderScreen` never crashes or blocks (the strict rule). Its flow:
1. **Locating:** check `Geolocator.isLocationServiceEnabled()` → `checkPermission()` → `requestPermission()` if denied → `getCurrentPosition()` with a **12s timeout**. On success → `/find-vets {lat,lng}` → the nearest-5 list (each row: name, distance, Open/Closed, **Call** `tel:`, **Directions** native maps).
2. **Any failure path → Manual mode** — service disabled, `denied` / `deniedForever`, timeout, or *any* exception all route to a fallback view with:
   - a **"ZIP code or city"** text field that searches via `/find-vets {query}` (Places text search), and
   - an **always-present "Open in Maps"** button — the native-maps deep link (`google.com/maps/search/?q=veterinarian near me`), the same **Phase 1.4 key-less strategy**.
3. The **Open-in-Maps** affordance is also shown in the list view (and when results are empty), so there is always a working path to a vet — critical on the EMERGENCY screen.

`vet_called` fires on a successful dial; `vet_finder_opened` fires when the screen opens (covering both the EMERGENCY and MONITOR entry points).

## 4. Health report export

`buildHealthReport` (pure, unit-tested) produces clean **Markdown**: pet basics (name/species/breed/age/sex/weight) + the **most recent AI triage** (result, concern, urgency, next steps) + **recent health events**, ending with the "AI-assisted information, not a veterinary diagnosis" note. `HealthReportService` fetches the latest analysis + last 10 events (RLS-scoped) and hands the text to the OS **share sheet** (`share_plus`); `health_report_exported` fires. Reached from the **Health History** screen's export action.

**Decision surfaced:** exported as **text/Markdown** (shared via the native sheet), not a PDF — your brief allowed either, and this avoids a heavy `pdf`/`printing` dependency while remaining copy/paste/print-friendly for a vet. A PDF renderer is a clean future enhancement.

## 5. Tests executed & results

| Test | Result |
|------|--------|
| `node --test _shared/*.mjs` | **36 pass** (+6 Places: request routing, haversine, parse/sort/cap-5, empty) |
| `flutter analyze` | **No issues found** (geolocator 13.0.4 resolved) |
| `flutter test` | **64 pass** (+8: maps links, Vet model, report builder) |
| `ruff` + `pytest` (ai-service) | **clean / 56 pass** (unaffected) |
| `./scripts/verify-phase-3.4.sh` | **exit 0** — incl. the no-key-in-client assertion; 5 MANUAL |
| `shellcheck` (verifier) | **clean** |

## 6. MANUAL (founder / device)

- Set `PLACES_API_KEY` on `find-vets`; restrict the key to the Places API + add a **billing budget alert** (CR #12).
- On device: grant location → nearest-5 with working Call + Directions; deny location → manual search + Open Maps (no crash); export a report → share sheet shows the pet summary.
- Deno typecheck of `find-vets` runs in Supabase CI (deno not installed here); its `_shared` logic is node-tested.

## 7. Git branch / commit / push

- Branch: `phase-3.4-vet-finder-export`
- Implementation commit (deliverables): `<filled post-commit>`
- Push: `<filled post-push>`

## 8. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Location permission via geolocator | ✅ DONE | `vet_finder_screen.dart` |
| Nearby Vets UI from EMERGENCY/MONITOR | ✅ DONE | both result screens → `VetFinderScreen` |
| List: name, distance, open/closed, phone, directions | ✅ DONE | list tile + call/directions |
| `/find-vets` proxy holds the key; clean JSON | ✅ DONE | `find-vets` + `places.mjs`; node test |
| Key never in the client | ✅ DONE | verifier greps `mobile/lib` (no key) |
| Health report export (pet + triage + events) | ✅ DONE | `buildHealthReport` + service; export test |
| Graceful denial fallback (manual + maps) | ✅ DONE | manual mode + always Open-Maps |
| Analytics (3 events) | ✅ DONE | `analytics.dart` + wiring |
| Live Places + device location | ⏳ MANUAL | §6 |

**Verified now:** the Places proxy hides the key (asserted by the no-key-in-client check), the finder degrades gracefully on denial, and the report builder is unit-tested — analyzer + 64 tests + node + ruff/pytest all green. Stopping for approval.
