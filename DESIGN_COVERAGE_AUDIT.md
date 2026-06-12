# PawDoc Design Coverage Audit (OLD → NEW)

**Date:** 2026-06-12 · **Branch:** `ui-translation`

## Totals
- **OLD screens:** 20 — `001,002,003,004,005,006,007,008,10,11,12,13,14,15,16,17,18,19,21,22`
- **NEW references:** 20 — exact 1:1 by number
- **Matched:** 20 / 20
- **Translated:** 20 / 20
- **Untranslated:** 0
- **Sequence gaps (no OLD, no NEW):** 2 → **009**, **020**

## Coverage matrix

| # | NEW screen | Translated | Batch | File | Parity |
|---|-----------|:---------:|:----:|------|------:|
| 001 | Login (cream) | ✅ | 1 | `auth/sign_in_screen.dart` | ~93% *(device)* |
| 002 | Home — empty | ✅ | 1 | `home/home_screen.dart` | ~92% |
| 003 | Onboarding — value | ✅ | 1 | `onboarding/onboarding_flow.dart` | ~90% |
| 004 | Add pet / species | ✅ | 1 | `onboarding/onboarding_flow.dart` | ~90% |
| 005 | Onboarding — safety | ✅ | 1 | `onboarding/onboarding_flow.dart` | ~92% |
| 006 | Onboarding — notifications | ✅ | 1/2 | `onboarding/onboarding_flow.dart` | ~90% |
| 007 | Onboarding — first check | ✅ | 1/2 | `onboarding/onboarding_flow.dart` | ~88% |
| 008 | Home — with pet | ✅ | 2 | `home/home_screen.dart` | ~78% |
| **009** | — *(no reference)* | — | — | — | — |
| 010 | Account | ✅ | 2 | `account/account_screen.dart` | ~90% |
| 011 | Premium | ✅ | 2 | `monetization/paywall_screen.dart` | ~80% |
| 012 | Family sharing | ✅ | 3 | `family/family_settings_screen.dart` | ~91% |
| 013 | Refer a friend | ✅ | 3 | `referral/referral_screen.dart` | ~93% |
| 014 | Delete account | ✅ | 3 | `account/delete_account_screen.dart` | ~90% |
| 015 | Capture picker | ✅ | 3 | `home/home_screen.dart` (`_CaptureSheet`) | ~85% |
| 016 | Describe symptoms | ✅ | 3 | `text_input/symptom_text_screen.dart` | ~95% |
| 017 | Log event | ✅ | 4 | `health/health_event_form_screen.dart` | ~92% |
| 018 | History | ✅ | 4 | `health/history_timeline_screen.dart` | ~96% |
| 019 | Result (MONITOR) | ✅ | 4 | `analysis/result_screen.dart` | ~88% |
| **020** | — *(no reference)* | — | — | — | — |
| 021 | Log event (vaccination) | ✅ | 4 | `health/health_event_form_screen.dart` | ~92% |
| 022 | Reminders | ✅ | 4 | `reminders/reminders_screen.dart` | ~95% |

## Screens missing NEW references (founder action)
- **009** — gap in both folders. No OLD and no NEW. Unknown intended screen. *Need a reference if it's a real screen.*
- **020** — gap in both folders. Most likely the **EMERGENCY result** screen (`analysis/emergency_result_screen.dart` exists in code). It was **not** translated: no NEW reference + it is the most safety-locked surface. *Provide a NEW reference to translate it; until then it keeps its current safety-first styling.*

## Screens with asset gaps (used a documented substitute, per the no-crop/no-regen rule)
- **001 / 012 / 013 / 016 / 017:** the mockups show a **realistic/painterly** animal style; the generated assets are the **cartoon** duo. Used the cartoon assets as provided (D2 style split — see `DESIGN_ASSET_EXTRACTION_REPORT.md`). Caps illustration parity on these screens.
- **008:** no "peeking dog" / "routine clipboard" standalone asset → existing tip card kept.
- **014:** no "stardust dog" asset → used the sleeping-duo for the reassurance footer.

## Screens requiring manual intervention
- **Device validation** of all auth-gated screens (002–022): needs Supabase creds + a seeded test account. Only **001 (login)** was device-validated here.
- **011 honesty decision:** the mockup's "2.3k+ happy pet parents / ★★★★★" was **omitted** (fabricated metric). Provide a substantiated figure + source to add an honest badge.
- **008 navigation:** the mockup's bottom nav / Reports / Go-Premium card were **not** added (brief forbids nav/feature changes).
