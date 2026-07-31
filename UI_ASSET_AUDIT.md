# UI Asset Audit — Phase 2
**2026-06-13** · new UI illustrations + code modules across branch / main / pubspec / APK.

| Asset / module | Expected (new UI) | Exists on ui-translation | Registered (pubspec) | In main | Packaged in validated APK | Used by main's code |
|----------------|:--:|:--:|:--:|:--:|:--:|:--:|
| `illustrations/results/analysis_companion_v1.png` | ✅ | ✅ | ✅ (branch) | ❌ | ❌ | ❌ |
| `illustrations/results/emergency_support_v1.png` | ✅ | ✅ | ✅ (branch) | ❌ | ❌ | ❌ |
| `illustrations/results/first_check_complete_v1.png` | ✅ | ✅ | ✅ (branch) | ❌ | ❌ | ❌ |
| `illustrations/results/history_empty_v1.png` | ✅ | ✅ | ✅ (branch) | ❌ | ❌ | ❌ |
| `illustrations/results/monitor_result_v1.png` | ✅ | ✅ | ✅ (branch) | ❌ | ❌ | ❌ |
| `illustrations/premium/premium_value_icons_v1.png` | ✅ | ✅ | ✅ (branch) | ❌ | ❌ | ❌ |
| `illustrations/premium/referral_envelope_paw_v1.png` | ✅ | ✅ | ✅ (branch) | ❌ | ❌ | ❌ |
| `illustrations/premium/trust_sleeping_cat_v1.png` | ✅ | ✅ | ✅ (branch) | ❌ | ❌ | ❌ |
| `illustrations/system/offline_companion_v1.png` | ✅ | ✅ | ✅ (branch) | ❌ | ❌ | ❌ |
| `lib/src/core/root_shell.dart` (bottom nav) | ✅ | ✅ | n/a | ❌ | ❌ | ❌ |
| `lib/src/theme/paw_ui.dart` (UI kit) | ✅ | ✅ | n/a | ❌ | ❌ | ❌ |

## Determination
Every new UI asset + module exists **only on `ui-translation`**, with pubspec
registration **on the branch**. main has **none** of them; the validated APK
contains **no `illustrations/*.png`** at all. The branch's asset+pubspec wiring is
correct — it just never merged. (`images/new-image/` reference designs are
untracked and not currently in the working tree.)
