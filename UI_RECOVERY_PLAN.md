# PawDoc — UI Recovery Plan (Phase 7)
**2026-06-13** · how to actually ship the new UI. The new UI **is** truly not shipping; this is the fix.

## Objective
Land the `ui-translation` UI on `main`, **combined** with the #41–#72 finalization
fixes + the locale fix (PR #74), without losing either the new UI or the
safety/logic fixes. Then rebuild + device-validate the *actual* new UI.

## The core challenge
`ui-translation` branched off `e1aed76` (pre-finalization), so it has **none** of
the #41–#72 fixes, and main has none of the UI. Merging them conflicts on **7
files** that both sides changed — each must be resolved by **combining** the new
UI with the finalization logic:

| File | New UI (ui-translation) | Finalization logic to preserve |
|------|-------------------------|--------------------------------|
| `auth/sign_in_screen.dart` | full restyle (+431) | **E1** forgot-password dialog, **E3** Apple-gating + min-pw 8 |
| `family/family_settings_screen.dart` | restyle (+607) | **E9** manual-invite, **E12** Upgrade→paywall, go_router import |
| `health/history_timeline_screen.dart` | restyle (+470) | **E10** PDF 402 upsell |
| `text_input/symptom_text_screen.dart` | restyle (+395) | **E16** min-12 + emergency-keyword bypass |
| `analysis/result_screen.dart` | restyle (+44) | (verify A5/result wiring) |
| `router/app_router.dart` | `root_shell` bottom-nav routes | **E1** `/recovery` route + passwordRecovery listener |
| `pubspec.yaml` | new `_v1` asset registration | **B2** launcher-icons config, **B3** none here |
| *(also)* `src/app.dart` | (unchanged on branch) | **locale fix** (PR #74) must be applied on top |

The other ~40 ui-translation files (onboarding, referral, reminders, account,
delete, premium, `root_shell.dart`, `paw_ui.dart`, the 9 illustrations) are
**non-overlapping** and should merge cleanly.

## Recommended approach
**Rebase `ui-translation` onto current `main`** (preferred over merge — cleaner
linear history for the protected branch), resolving conflicts per-commit:
1. Branch `recover/ui-on-main` from `origin/ui-translation`.
2. `git rebase origin/main` (or merge `origin/main` in). For each of the 7
   conflicts, **keep the new UI markup AND re-apply the finalization logic**
   (table above) — never drop a safety/logic fix to take the UI.
3. Apply the **locale fix** (PR #74's `localeListResolutionCallback` in `app.dart`)
   on top.
4. Resolve `pubspec.yaml` as a **union** (new `_v1` assets + the B2 launcher-icons
   block).

## Validation (must all pass before merge)
- `flutter analyze` clean; `flutter test` (the full suite — l10n incl. the new EN
  fallback guards, capture/upload, family RLS-aligned, no-motion-safety, widget).
- `flutter build apk` + `appbundle`.
- `node --test`, `ruff`/`pytest`, `./scripts/test-rls.sh` (unchanged by UI but run
  for safety).
- `doppler run -p pawdoc -c dev -- flutter build apk --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY` → install on device.
- **Device re-validation of the NEW UI**: confirm the **bottom nav** appears;
  walk auth (E1 forgot-pw visible), onboarding, the new screens, and **re-verify
  the emergency safety path** (detected, vet CTA not paywalled, disclaimer) **in
  the new emergency_result screen**, and that the **locale fallback** is English.

## Files affected
The 47 files in `git diff e1aed76 origin/ui-translation` + `app.dart` (locale fix).
Conflict resolution concentrated in the 7 overlap files above.

## Branches required
`recover/ui-on-main` (rebase of `ui-translation` onto `main` + #74 locale fix) →
PR → squash-merge (founder, with the standard review/admin gate).

## Estimated effort
**~4–8 h agent** (7 combine-merges + full re-validation) **+ a founder device-pass**
of the new UI. MEDIUM-LARGE — the risk is in the 7 combine-merges (UI markup ×
logic fixes); everything else merges clean.

## Do NOT
- Do **not** take the UI by reverting the finalization fixes (would re-open
  E1/E3/E5/E9/E10/E12/E16/locale).
- Do **not** ship until the **emergency safety path is re-verified in the new
  screens** (the new UI rewrites `emergency_result_screen.dart` — the safety
  guarantees must be re-confirmed there).

## Note
This recovery is a **separate, sizable, authorized execution** — not done in this
audit mission (whose job was to find the truth). Recommend running it as its own
mission with the merge/validation authority.
