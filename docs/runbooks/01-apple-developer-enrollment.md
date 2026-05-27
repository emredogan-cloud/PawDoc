# 01 — Apple Developer Program enrollment

**Why now:** review takes 24–48h (sometimes longer for identity checks) and it gates TestFlight + the App Store. This is the critical-path item — **start it on Day 1.**

**Cost:** $99 / year. **Time:** ~30 min to apply, then Apple's review.

## Steps

1. Go to <https://developer.apple.com/programs/enroll/>.
2. Sign in with the **Apple ID you want to own the app** (use a dedicated business Apple ID, not a personal throwaway). Enable two-factor auth on it.
3. Choose the entity type:
   - **Individual / Sole Proprietor** — fastest; the app lists *your name* as seller. No D-U-N-S needed.
   - **Organization / Company** — lists your company as seller; **requires a D-U-N-S number** (free from Dun & Bradstreet, can take a few days). Pick this only if you have an LLC/company and want it as the public seller.
   > For a solo founder shipping fast, **Individual** is the common choice. You can migrate to Organization later.
4. Complete the personal/organization details and accept the agreements.
5. Pay the $99 fee.
6. Wait for the **"Welcome to the Apple Developer Program"** email.

## What to record (you'll need these in Phase 0.4)

- **Team ID** — App Store Connect → top-right account menu, or developer.apple.com → Membership details.
- The owning Apple ID email.
- Entity type chosen.

> The **App Store Connect API key** (`.p8`) used by Fastlane to upload TestFlight builds is created in **Phase 0.4**, not now. Don't generate it yet.

## For the SUB-PR report

Record one of:
- ✅ "Welcome" email received — enrollment **complete**, or
- ⏳ Enrollment **initiated on <date>**, status *in review*, case/reference number **<id>**.

The roadmap's DoD accepts "in review" as long as it was initiated Day 1.

## If it stalls (> 48h)

Identity/D-U-N-S verification is the usual cause. Don't wait passively — contact **Apple Developer Support** (<https://developer.apple.com/contact/>) with your enrollment reference.
