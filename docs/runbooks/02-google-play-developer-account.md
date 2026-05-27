# 02 — Google Play Developer account

**Cost:** $25 **one-time** (not annual). **Time:** ~30 min to apply; identity verification can take 1–3 days.

## Steps

1. Go to <https://play.google.com/console/signup>.
2. Sign in with the **Google account that will own the app** (prefer a dedicated business account; enable 2FA).
3. Choose account type:
   - **Personal** — fastest for a solo founder.
   - **Organization** — requires a D-U-N-S number and shows the company as developer.
   > Google now requires **identity verification** (and, for personal accounts created recently, sometimes app-testing prerequisites before public production release). Start early.
4. Enter your developer name (this is shown publicly on the store listing) and contact details.
5. Pay the $25 registration fee.
6. Complete **identity verification** (government ID + address) when prompted.

## What to record

- The owning Google account email.
- Developer (public) name.
- Account type (Personal / Organization).
- Verification status.

> The **Play service-account JSON** that Fastlane uses to upload builds is created in **Phase 0.4**. Not now.

## For the SUB-PR report

- ✅ Account created on `<date>`, identity verification: *complete / pending*.

## Notes

- Google Play review is generally faster than Apple's, but **health apps get extra scrutiny** — that matters in Phase 2.3, not here.
- Keep the developer name consistent with the Apple seller name for brand trust.
