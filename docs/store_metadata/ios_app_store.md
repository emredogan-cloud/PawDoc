<!--
iOS App Store listing — Phase 2.3.
CONVENTION: every user-facing storefront string is wrapped in a pair of
HTML-comment markers (VISIBLE-COPY start / end) — see the blocks below.
scripts/verify-phase-2.3.sh extracts the text between those markers and asserts the
banned word never appears there. The KEYWORDS line and the App Store Review Notes
sit deliberately OUTSIDE the markers: the hidden SEO keyword term (and the note to
Apple) may use the word there, never in copy a user reads.
DO NOT use "diagnose / diagnosis / treat / cure" in visible copy — use
"triage / monitor / guidance / check / decide".
-->

# iOS App Store — Listing Metadata

| Field | Value | Limit | Length |
|---|---|---|---|
| Name (Title) | `PawDoc: AI Pet Health` | 30 | 21 ✓ |
| Subtitle | `Know When to Call the Vet` | 30 | 25 ✓ |
| Keywords | (see KEYWORDS below) | 100 | 80 ✓ |
| Bundle ID | `app.pawdoc` | — | — |
| Primary category | Lifestyle *(evolution I5 — verify against current Apple category guidance before submission; Medical invites 1.4.1-level scrutiny a records app does not need)* | — | — |
| Secondary category | Lifestyle | — | — |
| Age rating | 12+ *(consistent with Terms 13+; a subscription app that can show a pet emergency is not 4+)* | — | — |

## Title & Subtitle (visible)

<!-- VISIBLE-COPY:START -->
**Title:** PawDoc: AI Pet Health
**Subtitle:** Know When to Call the Vet
<!-- VISIBLE-COPY:END -->

## Keywords (SEO field — NOT shown to users)

The keyword field is comma-separated and counts commas toward the 100-char
limit. **`diagnosis` was deliberately REMOVED (evolution I4):** bidding on the
one word the entire product posture disclaims was a store risk and a
litigation exhibit — the keyword set now matches what the app actually is.

```
pet,health,record,symptom,checker,dog,cat,vet,visit,tracker,rabbit,puppy
```
(72 / 100 characters.)

## Promotional Text (visible, 170 max — updatable without review)

<!-- VISIBLE-COPY:START -->
Your pet's health record, organized — symptom guidance in seconds, an emergency button that works offline, and a vet-visit summary in your hand.
<!-- VISIBLE-COPY:END -->

## Description (visible, 4000 max)

<!-- VISIBLE-COPY:START -->
The health record your vet actually wants to see.

When your dog won't eat or your cat is suddenly acting strange, PawDoc helps you notice what matters, decide how soon to involve your vet, and remember everything when you get there. Describe the symptom or add a photo, and you'll get calm, plain-language guidance: what vets look for with this kind of sign, what to watch for at home, and how soon to call — never a verdict, never a diagnosis.

EMERGENCY HELP, ALWAYS FREE
A red button on the home screen works entirely offline: nearby emergency vets, tap-to-dial poison control, and step-by-step first-aid cards for choking, bleeding, seizures, bloat, and overheating. If what you type sounds urgent, PawDoc takes you straight there — before anything else.

HOW IT WORKS
• Describe what you're seeing (free, unlimited) or add a photo
• Get clear next steps: get help now · call today · book a visit · watch and re-check
• Everything is saved to your pet's timeline automatically

THE RECORD DOES THE REMEMBERING
• Weight trends, vaccinations, medications, and health events in one timeline
• One-tap re-check reminders, delivered by your phone — no account with a push service
• The Vet Visit Prep Pack: your pet's story, organized for the exam room

HONEST BY DESIGN
• PawDoc never tells you your pet is "fine" — it tells you what to watch for and when to act
• When there isn't enough information, it says so instead of guessing
• Emergency help is free forever and never behind a paywall
• Private by design — delete your account and data anytime, right in the app

IMPORTANT
PawDoc provides general information and record-keeping to help you decide whether, and how urgently, to seek veterinary care. It does not diagnose, does not provide veterinary medical advice, and is not a substitute for an in-person examination by a licensed veterinarian. In an emergency, contact your veterinarian or a local emergency animal hospital immediately.

Subscription: symptom checks by text are free with no limit. An optional subscription keeps the full record — unlimited photo logs, full history, reminders, and the Vet Visit Prep Pack; price and terms are shown before you purchase.
<!-- VISIBLE-COPY:END -->

## Screenshots — exact order (slots 1–5)

App Store allows up to 10 slots per device size; PawDoc's canonical ordered set is
these five (caption text is visible on the storefront — no banned words appear in it).

<!-- VISIBLE-COPY:START -->
1. "Notice. Decide. Remember." — hero shot over a completed triage result. (Action-framed, no certainty claim — matches the Play caption.)
2. "How it works." — the three-step flow: camera → AI → result.
3. "It never says fine - it says what to watch for." - a calm WATCH AND RE-CHECK result.
4. "Emergency guidance, always free." — the safety promise: possible emergencies are flagged first and never paywalled.
5. "Everything in one place." — feature breadth: multi-pet, history, reminders.
<!-- VISIBLE-COPY:END -->

Optional: a 15–30s app preview video of the camera → result flow, if available.

---

## App Store Review Notes (to Apple reviewers — NOT user-facing)

> These notes are written for App Review and intentionally reference what PawDoc is
> NOT. This text is never shown to end users.

PawDoc is an **AI-assisted information and triage tool for pet owners — not a
veterinary service.** It helps owners decide whether, and how urgently, to seek
veterinary care. It does **not** provide a veterinary diagnosis or treatment and is
not a substitute for a licensed veterinarian.

Key points for review:
- **Every analysis result shows a clear, non-dismissable disclaimer.** Disclaimers are
  injected server-side (not optional UI) — they cannot be turned off.
- **Emergency guidance is never gated behind payment.** If the app detects a possible
  emergency, it always tells the user to contact a vet immediately, even on the free
  tier and even with no subscription.
- **Conservative by design.** When confidence is low, the app says "insufficient
  information" rather than guessing — it never fabricates a result.
- **In-app account deletion is implemented** (Apple Guideline 5.1.1(v)): Account →
  Delete Account performs a full erasure of the user's data.
- **No medical diagnosis or treatment claims** appear anywhere in the app, copy, or
  screenshots. The product is positioned as information, triage, and guidance only.

How to test:
- Demo account: `[REVIEWER_DEMO_EMAIL]` / `[REVIEWER_DEMO_PASSWORD]` (founder to fill).
- The first analyses are free — no purchase needed to exercise the core flow.
- To see the emergency path, submit the text "my dog is choking and can't breathe":
  the app returns EMERGENCY with a directive to seek care, with no paywall.

Support: support@pawdoc.app · Privacy: https://pawdoc.app/privacy · Terms: https://pawdoc.app/terms

> ⚠️ Public release of this listing is **hard-gated** by the legal/insurance items in
> `docs/runbooks/18-legal-and-launch-gate.md` §1. See `docs/runbooks/19-beta-and-launch.md`.
