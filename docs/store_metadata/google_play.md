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
| Category | Medical | — | — |
| Content rating | Everyone (via IARC questionnaire) | — | — |

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
Know when to call the vet. AI triage for your pet's symptoms in seconds.
<!-- VISIBLE-COPY:END -->
(72 / 80 characters.)

## Full description (visible, 4000 max)

<!-- VISIBLE-COPY:START -->
Know when to call the vet — in seconds.

When your dog won't eat or your cat is suddenly acting strange, the hardest question is always the same: is this an emergency, or can it wait? PawDoc helps you decide. Add a photo and a few details about your pet, and our AI gives you fast, clear triage guidance — so you can stop the late-night worry and act with confidence.

PawDoc is an information and triage tool, not a replacement for your veterinarian. Every result is checked against built-in safety rules and always shows a clear disclaimer. If something looks urgent, PawDoc tells you to contact a vet right away — and that emergency guidance is never hidden behind a paywall.

HOW IT WORKS
• Add a photo or describe the symptom you're seeing
• Tell us about your pet — species, age, and history
• Get a clear result in seconds — EMERGENCY, MONITOR, or LIKELY NORMAL — with simple guidance on what to do next

WHY PET PARENTS TRUST PAWDOC
• Safety first: possible emergencies are flagged before anything else
• Honest guidance — when we're not confident, we say so instead of guessing
• Emergency guidance is always free — never hidden behind a paywall
• Private by design — delete your account and data anytime, right in the app

WHAT YOU CAN DO
• Triage symptoms for dogs, cats, rabbits, birds, and more
• Keep all your pets in one place
• Look back over your past checks
• Set reminders to monitor an ongoing concern

IMPORTANT
PawDoc provides general information and triage guidance to help you decide whether, and how urgently, to seek veterinary care. It does not provide veterinary medical advice and is not a substitute for an in-person examination by a licensed veterinarian. In an emergency, contact your veterinarian or a local emergency animal hospital immediately.

Subscription: your first few checks are free. An optional subscription unlocks unlimited triage; the price and terms are always shown before you buy.
<!-- VISIBLE-COPY:END -->

## Graphics checklist (Play requirements)

- **App icon:** 512×512 PNG (32-bit, alpha).
- **Feature graphic:** 1024×500 (required to be featured).
- **Phone screenshots (2–8):** same ordered story as iOS —
  <!-- VISIBLE-COPY:START -->
  (1) "Know exactly what your pet needs." + result · (2) "How it works": camera → AI → result · (3) "No more 2am anxiety spirals." + LIKELY NORMAL result · (4) "Emergency guidance, always free." (safety promise) · (5) "Everything in one place": multi-pet, history, reminders.
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
