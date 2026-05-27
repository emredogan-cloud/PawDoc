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
| Primary category | Medical | — | — |
| Secondary category | Lifestyle | — | — |
| Age rating | 4+ | — | — |

## Title & Subtitle (visible)

<!-- VISIBLE-COPY:START -->
**Title:** PawDoc: AI Pet Health
**Subtitle:** Know When to Call the Vet
<!-- VISIBLE-COPY:END -->

## Keywords (SEO field — NOT shown to users)

The keyword field is comma-separated, counts commas toward the 100-char limit, and
is invisible to users. "diagnosis" is included **here only**, for search — it must
never appear in the visible description, subtitle, or screenshots.

```
symptom,checker,dog,cat,sick,emergency,vet,triage,diagnosis,rabbit,puppy,monitor
```
(80 / 100 characters.)

## Promotional Text (visible, 170 max — updatable without review)

<!-- VISIBLE-COPY:START -->
Worried about your pet at 2am? Get fast, clear AI triage guidance — and know whether to relax, monitor at home, or call the vet now.
<!-- VISIBLE-COPY:END -->

## Description (visible, 4000 max)

<!-- VISIBLE-COPY:START -->
Know when to call the vet — in seconds.

When your dog won't eat or your cat is suddenly acting strange, the hardest question is the same every time: is this an emergency, or can it wait until morning? PawDoc helps you decide. Add a photo and a few details, and our AI gives you fast, clear triage guidance — so you can stop the late-night anxiety spiral and act with confidence.

PawDoc is an information and triage tool, not a replacement for your veterinarian. Every result is checked against built-in safety rules and shows a clear disclaimer. If something looks urgent, PawDoc tells you to contact a vet right away — and that emergency guidance is never hidden behind a paywall.

HOW IT WORKS
• Add a photo or describe what you're seeing
• Tell us about your pet — species, age, and history
• Get a clear result in seconds — EMERGENCY, MONITOR, or LIKELY NORMAL — with plain-English guidance on what to do next

WHY PET PARENTS TRUST PAWDOC
• Safety first: possible emergencies are flagged before anything else
• Honest guidance — when we're not confident, we say so instead of guessing
• Built with veterinary input and reviewed for quality
• Private by design — delete your account and data anytime, right in the app

WHAT YOU CAN DO
• Triage symptoms for dogs, cats, rabbits, birds, and more
• Keep all your pets in one place
• Look back over your past checks
• Set reminders to monitor an ongoing concern

IMPORTANT
PawDoc provides general information and triage guidance to help you decide whether, and how urgently, to seek veterinary care. It does not provide veterinary medical advice and is not a substitute for an in-person examination by a licensed veterinarian. In an emergency, contact your veterinarian or a local emergency animal hospital immediately.

Subscription: your first few checks are free. An optional subscription unlocks unlimited triage; price and terms are shown before you purchase and confirmed at submission.
<!-- VISIBLE-COPY:END -->

## Screenshots — exact order (slots 1–5)

App Store allows up to 10 slots per device size; PawDoc's canonical ordered set is
these five (caption text is visible on the storefront — no banned words appear in it).

<!-- VISIBLE-COPY:START -->
1. "Know exactly what your pet needs." — hero shot over a completed triage result.
2. "How it works." — the three-step flow: camera → AI → result.
3. "No more 2am anxiety spirals." — a calm LIKELY NORMAL result.
4. "Reviewed by veterinary experts." — the trust / credibility screen.
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
