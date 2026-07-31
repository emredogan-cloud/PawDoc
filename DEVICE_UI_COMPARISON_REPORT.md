# Device UI Comparison Report — Phase 5
**2026-06-13** · what the device renders vs the new-UI target. Screenshots in `runtime/final_device_validation/screenshots/` (device-validation mission) + `runtime/ui_truth_audit/`.

## Method + caveat
The device ran the main-built APK (this session). The `images/new-image/`
reference designs are **untracked and not in the working tree**, so a pixel-level
diff was not possible. Instead, the comparison uses a **structural discriminator**
that is unambiguous: the new UI's `root_shell.dart` introduces a **bottom
navigation bar** (Home/Pets/Health/Settings). main has no `root_shell`.

## Per-screen classification (device = main build)
| Screen | On device | vs new-UI target | Class |
|--------|-----------|------------------|-------|
| Login | ui-cycle sign-in (no `paw_ui`) | new = restyled (+431) | **OLD** |
| Onboarding 1–5 | ui-cycle/M-series | new = rewritten (+335) | **OLD** |
| Home | **no bottom nav**; History/Log-event/Manage-pets buttons | new = bottom-nav shell | **OLD** |
| Premium | ui-cycle paywall | new = trust pillars (+121) | **OLD** |
| Referral | ui-cycle | new = +743 rewrite | **OLD** |
| Family | ui-cycle | new = +607 rewrite | **OLD** |

## Determination
Every screen on the device is the **OLD** (pre-translation) UI. The decisive,
binary evidence: **the device shows no bottom navigation bar**, which the new UI
(`root_shell`) adds — so the device is conclusively **not** running
`ui-translation`. This matches the founder's observation exactly.
