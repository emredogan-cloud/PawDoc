<!--
Google Play listing — Phase 2.3.
Same convention as the iOS file: user-facing storefront copy is wrapped in a pair of
HTML-comment markers (VISIBLE-COPY start / end), which scripts/verify-phase-2.3.sh
checks for the banned word. Play has NO separate keyword field (it indexes the
descriptions), so the SEO term Apple hides is NEVER used in Play's visible copy.
DO NOT use "diagnose / diagnosis / treat / cure" in visible copy — use
"triage / monitor / guidance / check".
-->

# Google Play — Store Listing Metadata

| Field | Value | Limit | Length |
|---|---|---|---|
| App name (Title) | `PawDoc: AI Pet Health` | 30 | 21 ✓ |
| Short description | (see below) | 80 | 72 ✓ |
| Full description | (see below) | 4000 | ✓ |
| Package name | `app.pawdoc` | — | — |
| Category | Lifestyle *(evolution I5)* | — | — |
| Content rating | 12+ / Teen-equivalent via IARC *(consistent with Terms 13+; evolution I6)* | — | — |

> **No keyword field on Play.** Unlike Apple, Play has no hidden keyword field — it
> ranks on the title + descriptions, which are user-visible. So the SEO term Apple
> hides is **never** used in Play's visible copy; ASO terms (symptom, checker, vet,
> triage, dog, cat, emergency, monitor) are woven naturally into the description.

## Title (visible)

<!-- VISIBLE-COPY:START -->
PawDoc: AI Pet Health
<!-- VISIBLE-COPY:END -->

## Short description (visible, 80 max)

<!-- VISIBLE-COPY:START -->
Your pet's health record, organized — symptom guidance in seconds, an emergency button that works offline, and a vet-visit summary in your hand.
<!-- VISIBLE-COPY:END -->
(72 / 80 characters.)

## Full description (visible, 4000 max)

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

## Graphics checklist (Play requirements)

- **App icon:** 512×512 PNG (32-bit, alpha).
- **Feature graphic:** 1024×500 (required to be featured).
- **Phone screenshots (2–8):** same ordered story as iOS —
  <!-- VISIBLE-COPY:START -->
  (1) "Notice. Decide. Remember." + result · (2) "How it works": camera → AI → result · (3) "It never says fine - it says what to watch for." + WATCH AND RE-CHECK result · (4) "Emergency guidance, always free." (safety promise) · (5) "Everything in one place": multi-pet, history, reminders.
  <!-- VISIBLE-COPY:END -->
- 7-inch & 10-inch tablet screenshots optional but recommended.

## Play Console review / compliance notes (NOT user-facing)

These mirror the iOS App Store Review Notes — Play also scrutinizes health apps.

- PawDoc is an **AI-assisted information and triage tool, not a veterinary service.**
  It does not provide a veterinary diagnosis or treatment.
- **Disclaimers are server-injected and shown on every result** (not optional UI).
- **Emergencies are never gated behind payment.**
- **In-app account deletion** is implemented and also reachable via the web per Play's
  data-deletion policy (Account → Delete Account → full erasure).
- **Data safety form:** declare collected data (account email, pet profile, uploaded
  photos), encryption in transit, and that users can request deletion. EXIF/GPS is
  stripped from images before upload.
- **Health/Medical declaration:** position the app as informational triage and guidance;
  do not claim to diagnose, treat, cure, or prevent disease.

> ⚠️ Public release is **hard-gated** by `docs/runbooks/18-legal-and-launch-gate.md` §1.
> Submission workflow: `docs/runbooks/19-beta-and-launch.md`.
