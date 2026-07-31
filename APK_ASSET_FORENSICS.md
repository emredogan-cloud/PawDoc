# APK Asset Forensics — Phase 4
**2026-06-13** · are the new UI assets physically inside the validated APK?

Method: `unzip -l mobile/build/app/outputs/flutter-apk/app-release.apk`.

## New UI illustrations in the APK
| Asset | In APK? |
|-------|:--:|
| `analysis_companion_v1` | ❌ ABSENT |
| `emergency_support_v1` | ❌ ABSENT |
| `trust_sleeping_cat_v1` | ❌ ABSENT |
| `referral_envelope_paw_v1` | ❌ ABSENT |
| `monitor_result_v1` | ❌ ABSENT |

## Broader finding
The APK contains **no `assets/illustrations/*.png` at all** (59 `flutter_assets`
entries are fonts/motion/icons/brand). main's redesign uses **Rive avatars +
fallbacks**, not the static illustrations — those are exclusively a
`ui-translation` addition.

## Determination
**The new UI assets are NOT physically inside the APK.** Consistent with Phase 2/3:
they exist only on the unmerged `ui-translation` branch, so a main-built APK could
never contain them.
