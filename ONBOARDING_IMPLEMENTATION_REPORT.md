# PawDoc — Onboarding Implementation Report

**Date:** 2026-08-03 · **Branch:** `ui-impl-phase-p-onboarding` · **Device:**
Redmi Note 8 (M1908C3JGG), 1080×2340 @ 440dpi = **393×851 logical**, the same
size the mockups are drawn at.

**Scope of this pass:** mockups `004`–`009`. `002` and `003` were already
rebuilt; this pass finished the remaining six and, in doing so, restructured the
flow to one page per mockup.

**Verdict:** all eight onboarding pages match the reference composition and were
walked end to end on the device. `flutter analyze` clean, **449 tests green**,
`verify-disclaimers` PASS, no overflow on any page at any scroll position.

---

## 1 · What shipped

| Mockup | Page | Key | Commit |
|---|---|---|---|
| 002 | Every pet deserves calm, informed care | `onb_get_started` | `e26b441` |
| 003 | AI insights, real-time clarity | `onb_next_emergency` | `dc67e5e` |
| 004 | When it's urgent, PawDoc guides you | `onb_next_diary` | `699f503` |
| 005 | All your pet's health, organized beautifully | `onb_next_assistant` | `699f503` |
| 006 | Meet your AI Pet Assistant | `onb_next_chat` | `e61aab5` |
| 007 | One assistant. All paws covered. | `onb_next_pet` | `e61aab5` |
| 008 | Let's add your first furry friend | `onb_pet_continue` | `76b9988` |
| 009 | You're all set, welcome to PawDoc! | `onb_finish` | `76b9988` |

### 004 — the glass cards, built rather than approximated

Two neon slabs: a 1.4dp hairline in the card's hue over a near-black vertical
gradient, an outer bloom, and a glyph straddling the top edge — a red beacon
with five drawn rays on the left, a green house with a paw inside on the right.
Inside: title, tinted subtitle, a hairline, three rows each led by a tinted
circular chip, a second hairline pushed to the card's foot by a `Spacer` so both
chips line up across cards of different content, and a pill.

Between them the supplied `onb-collision-notequal` plate, composited with
`BlendMode.screen` so its black ground drops out and the red and cyan streaks
spill across both cards exactly as drawn. A matte would have left a visible box
across the middle of the composition.

Below it: the transparency panel with the 3D shield, then the trust strip — a
drawn `24/7` dial, an open book, hands cupping a heart, each in a soft halo
rather than a hard ring, as the reference draws them.

### 005 — the whole composition

Left: a five-stop capability rail, each stop a ringed neon badge in its own hue,
threaded by a dotted spine. Centre: the device with a live diary screen — status
bar, pet switcher, filter chips, five timeline rows on a threaded spine with
coloured nodes and thumbnails, tab bar. Right: the callout bubble with its tail
pointing back at the device and the 3D shield straddling its top edge, and
beneath it the dog-and-kitten pair bleeding off the right edge. All of it pooled
in one elliptical floor glow. Then the three-column trust panel and the CTA.

### 006 / 007 — the assistant, twice

Both are the same shape: crest, device with a live chat, capability cards down
each side tethered to the screen with dashed leaders and lit nodes, a
reassurance strip, and a hero the CTA sits over. `006` takes the supplied robot
mascot as its crest and the blanket pair as its hero; `007` composes its
paw-and-plus crest (no plate carries it) and takes the halo pair. Heroes
composite with `BlendMode.screen` and dissolve on three edges; both carry the
flanking heart bubbles.

### 008 — the form, wired to what already exists

The species photo gallery (selection lit emerald with a check badge), the
two-column record card with a glyph in each gutter — name with a validity check,
breed, birth date with a live `2y 2m` age, gender — and beside it the framed
photo well with its camera button over the dashed "Add a clear photo" box. Then
the "more details, the better" card with its clipboard art, three benefits, and
the privacy strip.

Nothing here is a new product feature: `Pet` already carries name, breed, birth
date, sex and a photo key, and `PetFormScreen` already edits all five. The page
reaches for the same repository, the same photo service and the same crop
screen.

### 009 — the send-off

Success crest with its sparks, the celebration hero floating in a hand-placed
field of paw prints, the trust card riding up over the hero's foot, the sparked
"Here's what you can do now" rule, four capability tiles, the privacy row with
its PRIVATE BY DESIGN badge, and the sign-off line.

---

## 2 · Three defects found by walking the flow

None were caught by the 449 tests. All three were found on the device.

### 2.1 The add-pet step could not be passed — BLOCKER

The first-run journey now runs **before** authentication
(`0001 → 002…009 → gateway`), and `PetsRepository.create` reads
`auth.currentUser!.id`. The null check threw, the page caught it as
*"Could not save your pet. Try again."*, and the flow dead-ended at step 7 on
every cold install.

**Fixed** with `PendingPet`: the draft — and the photo bytes plus crop, since
uploading also needs a JWT — is held in memory and created on the first
authenticated frame in `RootShell`, the one surface Google, email, guest and a
returning user all land on. It fails soft: an upload error still saves the pet,
a create error keeps the draft for the next attempt.

### 2.2 Finishing looped back to the beginning — BLOCKER

`_finish()` went to `/`. The router redirects an unauthenticated `/` to
`/welcome` until `FirstRun` is marked done — and only the gateway marks it. So
"Start My Journey" returned the user to the app-open screen.

**Fixed:** onboarding hands off to `/auth-gateway` when signed out, home when
signed in. Verified on device — the journey now ends on the gateway.

### 2.3 A System A leak on the species picker

The shipping `SpeciesChip` resolves its accent through the app palette, which
now points at lime, so the selected species card rendered **lime on navy** on a
System A page. `system_isolation_test` does not reach it — it checks the header.
`SpeciesGallery` takes its colour from the page instead.

---

## 3 · The measurement finding that shaped everything

**The mockups are AI-rendered pictures of an app, not exported design frames.**

At 853px wide for a 393dp screen (2.17 px/dp, confirmed by the home-indicator
position), the reference type measures:

| Element | Reference | Shipped |
|---|---|---|
| Display headline | ~27dp on a 30dp line | 28 / 30 |
| Deck | ~12dp | 13 |
| Card title | ~14.5dp | 16 |
| Row label | ~9.5dp | 10.5 |
| Rail label | ~8dp | 11 |
| CTA | ~17.5dp | 17.5 |

The last two rows are the point: 8–9.5dp copy is not readable on a handset. So
**layout, spacing, proportion and composition are matched exactly** — page
gutter 18dp (measured; it had been 20), card gap 34, card radius 28, crest 76 —
and type sits ~15% above the naive scale, with the device giving back the width
that costs on `005`–`007`. Nothing was dropped to make room, and nothing was
cropped: pages scroll where the reference does not fit.

---

## 4 · Deliberate departures, and why

| Where | Reference | Shipped | Reason |
|---|---|---|---|
| `004` right card | "Not Urgent" | "Keep Watching" / "Monitor Safely" | a triage verdict, and the closest thing in the flow to an all-clear; the action ladder has no "do nothing" rung |
| `004` deck | "Instant emergency detection" | "Step-by-step emergency guidance" | promises a reliability the pipeline does not claim — a false-negative risk in marketing copy |
| `005` diary row | "Mild coughing detected" · `Low` badge · "Monitor at home" | "Cough noted — keep watching. Recheck within 24–48 hours.", no badge | a finding, a severity grade and a terminating instruction: three contract breaks (V-14) |
| `006` answer | "Sneezing can be caused by mild irritants, allergies, or infections" | checks observations, closes on a timeframe | names conditions as causes (V-13) |
| `007` answer | as drawn | as drawn | the safety review names this the compliant reference |
| `005` rail | amber for Memories | rose | amber is `monitorLight`, a safety-locked status colour design_tokens forbids as decoration |
| `009` sign-off | handwriting face | italic accent | the bundle ships Bricolage + Inter; a fifth webfont for one line is not worth the payload |

`onboarding_system_a_test` was **strengthened**, not relaxed: it now walks both
assistant samples for the banned causes instead of one, and a new case pins the
`005` diary row against the mockup's "detected" / severity badge / "Monitor at
home".

---

## 5 · Structural change: one page per mockup

The flow carried eight pages for eight mockups but collapsed `006`+`007` into
one and invented an **activation page** to fill the gap — so neither assistant
mockup was ever on screen. It is now 1:1, which is also the `Step N of 8` the
later mockups print in their own footers.

The activation page is gone. What it said — free text checks, opt-in reminders,
emergency never paywalled — is carried by `004` and `009`. Its `LivingPetAvatar`
"Paw Pal arrives" beat went with it; no mockup has that moment, and reinstating
it would need a page the reference does not define. **Raised as an owner
decision (§9) rather than assumed.**

---

## 6 · Assets

- **`onb-hero-dog-kitten-cutout` was never a cutout.** It was a rendered
  checkerboard baked into RGB — which means the auth gateway (`000`) had been
  drawing a checkerboard behind its hero. Keyed by flood-filling the light
  neutral **from the border only** so interiors survive (a global white key
  would have destroyed them), eroded 2px to swallow the matte fringe, feathered.
  This is the only asset changed.
- Everything else on these six pages is a supplied plate used as-is:
  `onb-collision-notequal`, `onb-shield-paw-teal-3d`, `onb-glyph-diary-paw-cyan`,
  `ai-robot-mascot-neon`, `onb-hero-puppy-kitten-blanket`,
  `onb-hero-dog-cat-halo`, `onb-hero-dog-kitten-celebration`, the seven
  `pet-species-*` portraits and `pet-buddy-*`.
- Glyphs with no plate (siren rays, house-with-paw, the paw-plus crest, the
  `24/7` dial, the clipboard art) are composed from Lucide + drawing, per D-6.

---

## 7 · Verification

| Gate | Result |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | **449 passed** |
| `verify-disclaimers.sh` | PASS |
| `verify-no-placeholders.sh` | OK on overclaims (founder-fill items remain, launch-gated) |
| Overflow sweep — 8 pages × 3 scroll positions | none |
| End-to-end device walk | app-open → `002`…`009` → pet saved → auth gateway |
| 320dp at 200% text scale | no exception (pinned by test) |

**Not run** (headless / founder-side): iOS, the release-build matrix, the RLS
Docker suite. The pet write was exercised through the pre-auth draft path; the
**authenticated** flush (`PendingPet.flush` → real insert + R2 upload) is
covered by code but has not been walked with a live session on the device —
worth one pass before release.

---

## 8 · Known limitations

1. The `008` photo preview shows the picked image under `BoxFit.cover` — exactly
   right for an untouched (centred) crop, approximate for a moved one. The
   upload always uses the real crop.
2. The auth gateway `000` has not been re-walked against its own mockup: its
   hero shield overlaps the dog and the social-proof line ellipsizes. Outside
   the `004`–`009` scope; the obvious next screen.
3. `002`'s hero still shows faint plate edges at its sides.
4. `004`/`005` close on the reference's dot rail while `006`–`009` close on
   `Step N of 8`, because that is what each mockup draws.

---

## 9 · Needs an owner decision

- **The activation page is gone** (§5). Confirm, or ask for the Paw Pal arrival
  moment to be reinstated somewhere.
- **`004`'s right-hand card** is titled "Keep Watching", not the reference's
  "Not Urgent" (§4). A safety call, not a design one.
- **Dot rail vs. step label** (§8.4) — unify, or keep per-mockup?
- **`new-interface/` (57 mockups, 93 MB) is still untracked.**
- Test accounts from earlier device passes (`onbqa.aug03@example.com`,
  `onbqa2.aug03@example.com`) still hold test pets in the Supabase project.
