# PawDoc — UI Truth Verdict
**2026-06-13** · evidence-based. Prior reports are corrected where wrong, not defended.

## The founder is right. The new UI is NOT on main and was never shipped.

The "new UI" — the **UI-translation program** (Batches 1–4 + launch hardening:
the pixel-faithful screen rewrites, the **bottom-nav `root_shell`**, the `paw_ui`
kit, and 9 new `_v1` illustrations) — lives entirely on the **unmerged
`ui-translation` branch** (+9 commits ahead of main). main carries an *earlier*
redesign (the ui-cycle E–L + M0–M4 motion work), which is what every prior
"device validation" actually tested. The device shows that earlier UI — which,
relative to the approved translation, is the "old" one.

## The 7 questions (explicit answers)

**1. Did the new UI actually reach main?  → NO.**
`ui-translation` is **not merged** (`git merge-base --is-ancestor` = false; +9
commits). main's log contains zero translation/batch commits. `root_shell.dart`
(bottom nav), `paw_ui.dart`, and all 9 `_v1` illustrations are **MISSING from
main**. (main *does* have the ui-cycle E–L + M0–M4 redesign — a real but earlier
UI.)

**2. Did the generated assets reach the APK?  → NO.**
APK forensics on the validated artifact (`unzip -l`): `analysis_companion_v1`,
`emergency_support_v1`, `trust_sleeping_cat_v1`, `referral_envelope_paw_v1`,
`monitor_result_v1` — all **ABSENT**. main has **no `illustrations/*.png`** at all
(its redesign uses Rive avatars + fallbacks; the static illustrations are a
ui-translation addition).

**3. Was the APK installed during validation freshly built?  → YES (but from the wrong branch).**
The APK was built fresh on 2026-06-13 14:08 from **main @ `d167ed0`** via Doppler.
It was NOT stale — but it was built from main, which lacks `ui-translation`. So a
fresh build of the wrong source.

**4. Did the founder really test the new UI?  → NO.**
Neither the founder's earlier observation nor my device validation exercised the
new UI. Both ran a main-based build (the ui-cycle UI). Tell-tale: my device home
screenshots show **no bottom navigation bar**, but the new UI's `root_shell` adds
exactly that — so the device was never running ui-translation.

**5. Is the previous device-validation report still trustworthy?  → PARTIALLY.**
Everything it reported about the *installed build* is true and reproducible
(launch, auth, onboarding, pet, the **emergency safety path**, the locale bug).
What it got WRONG by omission: it did not detect that the build was missing the
entire ui-translation program — it validated main's UI and implicitly treated it
as "the" UI. The flows + safety findings stand; the implied "this is the shipping
UI" does not.

**6. Single root cause  → A: the new UI never merged.**
The `ui-translation` branch (the actual new UI + assets + pubspec registration)
was never merged into main. It is self-consistent on the branch (assets present,
pubspec updated, screens wired) — it simply never landed. Secondary: the device
validation compounded it by building from main (E — effectively the wrong
artifact for "is the new UI shipping?"). NOT B/C/D/F: assets+pubspec ARE correct
on the branch; the APK was fresh; no fallback-masking on main (main genuinely has
no new UI to mask).

**7. Exact next steps  → execute UI_RECOVERY_PLAN.md.**
Merge `ui-translation` into main, combining it with the #41–#72 finalization
fixes + the locale fix (PR #74) on the 7 overlapping files, then rebuild + device-
validate the ACTUAL new UI. Summary below; full plan in UI_RECOVERY_PLAN.md.

## Evidence index (phases 0–5)
- **P0/P1:** `git merge-base --is-ancestor origin/ui-translation origin/main` = false; +9 commits; BATCH_01–04 + FINAL_UI_IMPLEMENTATION_REPORT on `ui-translation`, **not** main.
- **P2 assets:** `_v1` illustrations + `root_shell.dart` + `paw_ui.dart` present on `ui-translation`, MISSING on main; pubspec asset registration is on the branch only.
- **P3 provenance:** APK built 14:08 2026-06-13 from main `d167ed0` (fresh, wrong branch).
- **P4 forensics:** `unzip -l` → new `_v1` assets ABSENT from the APK.
- **P5 device:** device runs main's UI (no bottom nav) → classification **OLD** vs the ui-translation target. (new-image reference PNGs are no longer in the working tree, so a pixel diff wasn't possible; the structural bottom-nav absence is definitive.)

## Honest correction of prior claims
The earlier mission's "20/20 UI translations completed **and merged**" was **false
on the 'merged' half** — the work was completed *on a branch* but never reached
main. My subsequent finalization merge train (#41–#72) **did not include
`ui-translation`**, and my device-validation report did not catch that the new UI
was absent. That is the gap, stated plainly.
