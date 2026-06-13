# UI Translation — Batch 3 Report

**Branch:** `ui-translation` · **Commit:** `3f85c92` · **Date:** 2026-06-12

## Implemented screens

| # | Screen | File | Parity | Verified | By |
|---|--------|------|-------:|----------|----|
| 012 | Family sharing | `family/family_settings_screen.dart` | ~91% | ⚠️ static est. | subagent |
| 013 | Refer a friend | `referral/referral_screen.dart` | ~93% | ⚠️ static est. | subagent |
| 014 | Delete account (SAFETY) | `account/delete_account_screen.dart` | ~90% | ⚠️ static est. | me |
| 015 | Capture picker | `home/home_screen.dart` (`_CaptureSheet`) | ~85% | ⚠️ static est. | me |
| 016 | Describe symptoms | `text_input/symptom_text_screen.dart` | ~95% | ⚠️ static est. | subagent |

> Behind auth → static estimates (MANUAL per CLAUDE.md), not faked.

## What changed (presentation-only)
- **012 Family:** dark world; family hero (`familyCircle`); `PawCard` rows; **premium-gating + Upgrade flow**
  preserved; keys `family_invite_paywall_card`, `family_invite_upgrade_button`, `family_invite_button`,
  `family_member_<id>`.
- **013 Referral:** dark world; gift hero; restyled code/share/social/benefit cards; keys `referral_share`,
  `referral_code_input`, `referral_claim_button`; copy/share/claim logic preserved; brand icons not fabricated.
- **014 Delete account (SAFETY):** dark world + "what will be deleted" icon card + reassurance footer. The red
  `FilledButton`, disarm→arm scale, **never-disabled Cancel**, cascade + `popUntil`, and keys
  `delete_confirm_field` / `delete_account_button` / `delete_cancel_button` **all preserved**.
  `delete_account_screen_test` green.
- **015 Capture picker:** mint icon tiles on the existing frosted capture sheet (per-mode camera/video/edit icons kept).
- **016 Describe symptoms:** dark world; restyled chips + text card + "not sure what to include?" helper +
  privacy card. The **char-count gating (minChars 20) + `symptom_text_field` / `symptom_continue_button` keys**
  preserved (feeds triage — logic untouched).

## Method
012/013/016 were translated by focused subagents against the mockups + the shared `paw_ui` spec; 014 (safety) and
015 were done directly. **All claims verified here** by the full suite (not trusted blindly).

## Gates
| Gate | Result |
|------|--------|
| `flutter analyze` | ✅ No issues |
| `flutter test` (full suite) | ✅ **190 passed / 1 skipped / 0 failed** |
| `flutter build apk --debug` | ✅ exit 0 |
| `delete_account_screen_test` | ✅ pass (disarm/arm, Cancel-never-disabled, cascade pop) |
| CI / merge | ⏳ founder-side (`gh` absent; protected `main`) |

## Deviations (intentional)
- **012:** family hero is the existing cartoon `familyCircle` (mockup is realistic — D2 style split).
- **013:** social-share icons are Material symbols (no brand-SVG assets; not fabricated).
- **014:** no "stardust dog" asset → sleeping-duo used in the reassurance footer; gravity of the screen kept.
