# PHASE M0 REPORT — Pre-motion live bug fixes (F-1…F-5)

**Date:** 2026-06-10 · **Branch:** `motion-m0` · **Source of truth:** `PAWDOC_MOTION_ROADMAP.md` §3 (Phase M0) + `PAWDOC_MOTION_FINAL_AUDIT.md` §4 + live registry `runtime/final_ux_audit/INDEX.md`.

## 1 · Scope delivered

| ID | Fix | Commit | Status |
|----|-----|--------|--------|
| — | Founder asset set tracked (M0 substrate; was local-only — clean clones/CI rendered fallbacks; M1+ requires in-repo PNG fallbacks) | `chore(assets)` | COMPLETE |
| F-1 | Delete-account hang: 10s invoke timeout; auth-revoked probe → success; local-scope best-effort sign-out; Cancel **never** disabled; worst case 10s+4s ≤ 15s budget | `fix(account)` | COMPLETE |
| F-2 | Stale "No checks yet": runner invalidates `latestTriageProvider(petId)` the moment an analysis completes; pull-to-refresh also refreshes; hero renders **"Last check: just now"** recency | `fix(home,pets)` | COMPLETE |
| F-3 | EMERGENCY mixed-language: server template + wire urgency display-localized (DE/EN); matched keyword preserved verbatim; unknown values pass through — never hidden | `fix(l10n)` | COMPLETE |
| F-4 | Pets-list last-check chip: root cause was F-2's stale family cache; chip keyed + tested with a MONITOR triage | `fix(home,pets)` | COMPLETE |
| F-5 | Species icons: bird (bold coral beak + catchlight eyes + crest), reptile (friendly gecko head, eyes inside a wide flat profile), other (proper TEAL paw; the old file was a byte-duplicate of reptile) — 1024², 8-bit RGBA, set palette (#007479/#00A1A3/mint/cream/coral) | `fix(assets)` | COMPLETE |

## 2 · Safety guardrails honored
- **Emergency behavior unchanged**: F-3 is pure string presentation; ack gate, back-block, find-vet, paywall bypass untouched (diff is two `Text(...)` expressions + imports).
- **Delete stays dignified**: no motion/delight added; F-1 is engineering only.
- **Contract frozen**: `AnalysisResult` wire format untouched across Dart/Python/TS; localization is display-side.
- **No business/AI logic modified.** No paywall/subscription logic modified.

## 3 · Validation gates

| Gate | Result |
|------|--------|
| `flutter analyze` | **PASS** — No issues found |
| `flutter test` (full) | **PASS** — 140/140 (14 new M0 tests) |
| `flutter test test/paywall_policy_test.dart` | **PASS** — 7/7 incl. "NEVER shows during/after an EMERGENCY" |
| `./scripts/verify-disclaimers.sh` | **PASS** — 6/6 |
| `flutter build apk --debug` | **PASS** — apk produced (see §5) |
| GitHub CI | run on PR (see PR checks) |
| Device validation | **PENDING — BLOCKED: no USB device attached** (see §5) |

New tests:
- `account_service_test.dart` — 8 orchestration tests incl. the exact live F-1 case (hang + revoked auth → success within 15s, `fake_async`-driven) and the honest-failure case (hang + valid auth → TimeoutException surfaces).
- `delete_account_screen_test.dart` — Cancel enabled during "Deleting…" and pops; failure re-enables; disarmed until DELETE typed.
- `latest_triage_refresh_test.dart` — completed analysis refetches `latestTriageProvider` (fails without the runner invalidation).
- `home_hero_last_check_test.dart` — "Last check: just now" / "No checks yet" / level fallback.
- `pets_list_test.dart` (+2) — chip renders with a MONITOR triage; absent with none.
- `emergency_l10n_test.dart` — DE screen has zero mixed-language fragments; EN canonical; unknown values verbatim.
- `last_check_test.dart` — recency ladder + clock-skew.

## 4 · Documented deviations (surfaced, not silent)
1. **One PR for all of M0** (mission git strategy: `motion-m0`) vs the roadmap's aside that F-1 deserves "its own carefully-reviewed PR". Mitigation: F-1 is an isolated, fully-tested commit (`fix(account)`) and can be reviewed/reverted independently.
2. **F-5 production route**: roadmap's GPT-Image prompts were not executable in this environment; icons were authored as hand-built vector SVGs rendered at 1024² matching the sampled set palette. Visual goal met (chip-scale identity verified at 96px next to the dog reference); files are drop-in replaceable if the founder later regenerates via GPT-Image.
3. **`fake_async` added to dev_dependencies** (test-only) to drive the delete timeout deterministically.

## 5 · Device validation — BLOCKED
`adb devices` shows no attached device (USB bus has no phone; no wireless-ADB service discoverable). The Xiaomi 22095RA98C used for the live audit was disconnected after 17:41. **Per the mission, M0 will not be merged until the on-device pass (delete-account live ≤15s, post-check hero refresh, DE emergency screen, pets chip, icon chips) is captured under `runtime/motion_validation/m0/`.**

## 6 · Rollback
Each fix is an isolated commit on `motion-m0`; revert per-fix. F-2/F-4 share one commit by design (same root cause). Asset substrate and F-5 are separate commits.
