# UI Translation — Batch 2 Report

**Branch:** `ui-translation` · **Commit:** `77ed191` · **Date:** 2026-06-12

## Implemented screens

| # | Screen | File | Parity | Verified |
|---|--------|------|-------:|----------|
| 006 | Onboarding — notifications | `onboarding/onboarding_flow.dart` | ~90% | ⚠️ static est. *(landed in Batch 1)* |
| 007 | Onboarding — first check | `onboarding/onboarding_flow.dart` | ~88% | ⚠️ static est. *(landed in Batch 1)* |
| 008 | Home — with pet | `home/home_screen.dart` | ~78% | ⚠️ static est. |
| 010 | Account / settings | `account/account_screen.dart` | ~90% | ⚠️ static est. |
| 011 | Premium / paywall | `monetization/paywall_screen.dart` | ~80% | ⚠️ static est. |

> All five are behind auth → not device-reachable without Supabase creds + a session.
> Scores are static estimates (code vs. mockup), marked MANUAL per CLAUDE.md.

## What changed (presentation-only)
- **008 Home (with pet):** pet hero card → `PawCard` + mint→teal gradient **Check** CTA. The
  whole home already sits in the teal-green world (Batch 1). Last-check logic + `check_<id>` key preserved.
- **010 Account:** dark world; profile header + every menu row → `PawCard` rows with icon tiles +
  chevrons; danger-zone delete stays red. `account_sign_out` / `account_delete` keys, sign-out
  confirm, and all navigation preserved.
- **011 Premium:** dark world; **new night-hero asset** (`premium_sleeping_dog_v1`); envelope+paw
  **"coming soon"** card (the current production state). RevenueCat variants/plans + keys
  (`paywall_annual/monthly/not_now/coming_soon`) and the celebration-on-purchase preserved.

## ⚠️ Rules-driven deviations (intentional — surfaced, not silent)
1. **HONESTY GATE (011):** the 011 mockup shows **"Trusted by pet parents everywhere ⭐⭐⭐⭐⭐
   2.3k+ happy pet parents."** This is the *fabricated social proof removed in the Phase-B honesty
   work* (and flagged as launch-audit **GAP-B5**). Re-adding it would violate CLAUDE.md
   ("NEVER fabricated metrics") and the mission's "preserve disclaimers/safety." → **Not implemented.**
   If you have a *substantiated* number + real review source, provide it and I'll add an honest badge.
2. **No fake CTA (011):** the mockup's **"Notify me when it's available"** button has no backing
   notify mechanism in the app. Adding a dead button is worse than omitting it. → kept informational.
3. **Navigation preserved (008):** the 008 mockup adds a **bottom nav (Home/Pets/Help/Settings)**, a
   **"Reports"** action, and a home **"Go Premium"** card. The brief forbids changing navigation /
   inventing features, so these are **not** added. This caps 008 parity (~78%) — it's the right call.
4. **Peeking-dog / routine-card art (008):** no matching standalone asset → existing tip card kept.

## Gates
| Gate | Result |
|------|--------|
| `flutter analyze` | ✅ No issues |
| `flutter test` (full suite) | ✅ **190 passed / 1 skipped / 0 failed** |
| `flutter build apk --debug` | ✅ exit 0 (compile gate) |
| `paywall_policy_test` | ✅ pass (incl. "never for premium users") |
| CI / merge | ⏳ founder-side (`gh` absent; protected `main`) |

## Logic preserved
RevenueCat purchase/variant/restore, auth sign-out, account deletion entry, all widget keys,
analytics, routing — unchanged. Full suite green.

## Next
Batch 3 — Family (012), Referral (013), Delete account (014), Capture picker (015), Describe (016).
