# PawDoc — Design Asset Extraction Report
**OLD → NEW UI Translation · Pre-implementation asset inventory**

- **Mode:** Read-only discovery. No code modified, no assets created, no mockups cropped, no artwork regenerated, no branches/commits.
- **Date:** 2026-06-12
- **Authoritative source:** `images/new-image/` (treated as approved Figma).
- **Compared against:** `images/old-image/` (current implementation) and `mobile/assets/` (current asset tree).
- **Purpose:** Give the founder a complete, deduplicated list of every asset required to reach 95–99% visual parity, with production-ready GPT Image prompts, so assets can be generated and dropped into `mobile/assets/` *before* the implementation mission begins.

> **How to read this:** Section 4 is the actionable checklist. Each missing item is classed as **GENERATE** (make with GPT Image), **CODE** (build in Flutter — do **not** generate), **REUSE** (existing asset is fine), or **UPDATE** (existing asset exists but should be re-arted). Generating CODE-class items would be wasted effort, so they are listed but not given image prompts.

---

## 1. Executive Summary

- **20 OLD↔NEW screen pairs** map cleanly by number. Numbers **009** and **020** do not exist in either folder (sequence gaps, not untranslated screens).
- The NEW design is a **comprehensive art-led redesign**: a deep **teal-green gradient world** with glow/particles, a recurring **cream-puppy + grey-kitten** character duo, glowing emblems (moon, shield-heartbeat, bell), and decorative motifs (paw prints, hearts, sparkles, botanical leaves, a paw-print food bowl).
- **Good news:** the repo's existing illustrations are the **same illustrator style** as the onboarding/empty-state screens. Roughly **half** the heroes can be **reused or lightly updated** rather than generated from scratch.
- **True generation need:** approximately **14–18 unique illustration/emblem assets** (Tier 1 = must-have, Tier 2 = nice-to-have). Backgrounds, decorative motifs, feature/value icons, nav icons, and social icons are **CODE / icon-font**, not generated art.
- **Two blocking design decisions** must be resolved before generation (see §1.1) — without them, generated art risks being thrown away.
- **Readiness:** **PARTIAL today → YES once the two decisions are made and the Tier-1 assets are generated.** (Full rationale in §9.)

### 1.1 Two decisions required before any art is generated

| # | Decision | Why it blocks generation |
|---|----------|--------------------------|
| **D1 — Theme: light vs. dark** | NEW **001 (Login)** is a **light cream** background; **every other NEW screen (002–022)** is **dark teal-green**. | If the duo hero must appear on *both* a cream and a dark background, it needs two lighting variants (rim-light differs). Decide whether 001 is intentionally light, or should be re-arted dark to match. |
| **D2 — Illustration style: cartoon vs. realistic** | Onboarding/empty/premium use a **soft cartoon-painterly** style (matches existing assets). Family (012), Referral (013), Describe (016), Log-event (017/021) use a **more realistic/painterly** style. | GPT Image cannot mix styles convincingly across a screen flow. Pick **one** house style (recommendation: the cartoon style, since existing assets already match it) so all heroes are consistent. |

---

## 2. Screen Mapping Matrix

Identity column is **inferred from NEW mockup content** and should be confirmed against the app's routes. (The original batch list's example names — e.g. "002 = signup" — do **not** match actual content; real content is shown below.)

| # | OLD file | NEW file | Status | Inferred screen (from NEW content) | Likely route/source |
|---|----------|----------|--------|-------------------------------------|---------------------|
| 001 | `001_login_screen.jpg` | `001_login_screen_reference.png` | **FOUND** | Login / sign-in (**light cream**) | `auth/sign_in_screen.dart` |
| 002 | `002.jpg` | `002.png` | **FOUND** | Home — empty / "Welcome to PawDoc" | `home/` empty state |
| 003 | `003.jpg` | `003.png` | **FOUND** | Onboarding value — "Never wonder…" | `onboarding/` |
| 004 | `004.jpg` | `004.png` | **FOUND** | Add pet — name + species picker | `onboarding/` / `pets/` |
| 005 | `005.jpg` | `005.png` | **FOUND** | Onboarding safety — "Built to keep pets safe" | `onboarding/` |
| 006 | `006.jpg` | `006.png` | **FOUND** | Onboarding notifications opt-in | `onboarding/` / `notifications/` |
| 007 | `007.jpg` | `007.png` | **FOUND** | Onboarding first-check — "3 free checks" | `onboarding/` |
| 008 | `008.jpg` | `008.png` | **FOUND** | Home — with pet (dashboard) | `home/` |
| **009** | — | — | **NOT PROVIDED** | (sequence gap — no OLD, no NEW) | n/a |
| 010 | `10.jpg` | `10.png` | **FOUND** | Account / settings | `account/` |
| 011 | `11.jpg` | `11.png` | **FOUND** | Premium / paywall | `monetization/paywall_screen.dart` |
| 012 | `12.jpg` | `12.png` | **FOUND** | Family sharing | `family/` |
| 013 | `13.jpg` | `13.png` | **FOUND** | Refer a friend | `referral/` |
| 014 | `14.jpg` | `14.png` | **FOUND** | Delete account | `account/` |
| 015 | `15.jpg` | `15.png` | **FOUND** | Capture method picker (photo/video/describe) | `capture/` |
| 016 | `16.jpg` | `16.png` | **FOUND** | Describe symptoms (text input) | `text_input/` |
| 017 | `17.jpg` | `17.png` | **FOUND** | Log event (generic) | `health/` / `reminders/` |
| 018 | `18.jpg` | `18.png` | **FOUND** | History / health timeline | `health/` |
| 019 | `19.jpg` | `19.png` | **FOUND** | Analysis result (MONITOR + media-error) | `analysis/` |
| **020** | — | — | **NOT PROVIDED** | (sequence gap — no OLD, no NEW) | n/a |
| 021 | `21.jpg` | `21.png` | **FOUND** | Log event (vaccination variant) | `health/` |
| 022 | `22.jpg` | `22.png` | **FOUND** | Reminders list | `reminders/` |

**Totals:** OLD screens = 20 · NEW references = 20 · Matched = **20/20** · Missing references = **0** · Sequence gaps = **2** (009, 020).

> **Action for founder:** confirm whether 009 and 020 are intentional gaps or screens whose references were never exported (e.g. EMERGENCY result, video-capture live view). If they exist as app screens, provide NEW references or they cannot be translated.

---

## 3. Existing Asset Audit (`mobile/assets/`) — *verified visually, not assumed*

| Existing asset | What it is (verified) | NEW screen that needs it | Verdict |
|----------------|-----------------------|--------------------------|---------|
| `brand/logo_mark_v1.png` | Teal gradient shield + white paw + coral heart | 001/002 header mark | **REUSE / minor UPDATE** (NEW header uses a smaller flat shield-paw) |
| `illustrations/empty_states/empty_home_welcome_v1.png` | Cream puppy + grey kitten peeking over a glowing ring | 002 welcome hero | **REUSE** (near-exact; 002 just adds a moon glow behind) |
| `illustrations/monetization/paywall_peace_of_mind_v1.png` | Cream puppy sleeping in teal glow dome | (was OLD 011) | **REUSE elsewhere / superseded** (NEW 011 uses a new night duo — see A-007) |
| `illustrations/analysis/shield_care_v1.png` | Teal shield + heartbeat + check | 005 safety emblem | **REUSE / composite** (NEW 005 places the duo under this emblem) |
| `illustrations/analysis/analysis_scan_accent_v1.png` | Scan accent | 019 result accents | **REUSE / UPDATE** |
| `illustrations/onboarding/onboarding_hero_value_v1.png` | Onboarding hero | 003 hero | **UPDATE** (NEW 003 pose differs — see A-002) |
| `illustrations/empty_states/empty_history_story_v1.png` | History empty illustration | 018 hero | **UPDATE** (NEW 018 = sleeping dog on comet — see A-008) |
| `illustrations/growth/family_care_circle_v1.png` | **Cartoon** family hugging puppy+kitten | 012 family hero | **UPDATE** (NEW 012 is **realistic/night** — style mismatch, see D2 + A-010) |
| `illustrations/growth/referral_gift_v1.png` | Teal gift box + coral bow + paw | 013 / 007 / 008 | **REUSE as prop** (NEW 013 hero adds animals — see A-011) |
| `illustrations/growth/referral_gift_open_v1.png` | Open gift box | 013 | **REUSE** |
| `illustrations/system/system_error_calm_v1.png` | Sleeping puppy + glowing heart cord | 019 error | **UPDATE** (NEW 019 dog is awake/worried — see A-014) |
| `icons/species/species_{dog,cat,rabbit,guinea_pig,bird,reptile,other_paw}.png` | Flat teal line species faces | 004 species chips | **REUSE (MVP) / optional UPDATE** (NEW chips are richer — see A-021) |
| `icons/status/status_{emergency,monitor,normal}.png` | Status glyphs (monitor = amber eye) | 019 triage banner | **REUSE** (monitor eye matches NEW 019 banner) |
| `icons/actions/action_*.png` (14) | Action glyphs (camera, video, describe, history…) | 008/015 action rows | **REUSE / UPDATE per icon** |
| `brand/splash_logo.png` (referenced, file absent) | Splash logo | n/a | **MISSING** (already a known gap; not NEW-design specific) |

**Net:** the existing tree already covers a large share of the NEW art at the right style. The genuinely new work is the **duo pose variants**, a handful of **emblems/emotional graphics**, the **premium trust elements**, and **restyle UPDATES** for the screens listed above.

---

## 4. Missing / Required Asset Inventory

Style baseline for all GENERATE items (so they match existing assets): **soft painterly children's-book illustration; rounded forms; an ivory/cream puppy with floppy ears and a grey-and-white kitten as recurring characters; soft teal-green palette (#1FBFA8 / #46C9B0 / #0E211C) with warm coral heart accents (#FF7A7A); gentle rim-light glow; transparent background; no text.**

> Palette values throughout are **approximate** — sample exact hexes from the mockups during implementation.

### Tier 1 — Hero & emblem illustrations (GENERATE) — must-have for ≥95%

#### A-001 — Welcome duo under glowing moon
- **Used on screens:** 002 (Home empty / welcome)
- **Proposed filename:** `welcome_duo_moon_v1.png`
- **Save location:** `mobile/assets/illustrations/empty_states/`
- **Category:** Hero Illustration
- **Description:** Cream puppy + grey kitten peeking up, a soft glowing full moon behind them; tiny sparkles.
- **Extraction notes:** Top third of 002, centered above "Welcome to PawDoc". (Existing `empty_home_welcome_v1.png` is ~90% there — generation optional if you add the moon glow in code.)

#### A-002 — Onboarding "content duo" (sitting, hearts)
- **Used on screens:** 003 (Onboarding value)
- **Proposed filename:** `onboarding_duo_content_v1.png`
- **Save location:** `mobile/assets/illustrations/onboarding/`
- **Category:** Hero Illustration
- **Description:** Puppy sitting upright, kitten leaning against it, both calm/happy, small floating hearts.
- **Extraction notes:** Upper third of 003, above "Never wonder if your pet needs the vet again." Replaces `onboarding_hero_value_v1.png`.

#### A-003 — Pet-creation duo (protective hug)
- **Used on screens:** 004 (Add pet)
- **Proposed filename:** `onboarding_duo_hug_v1.png`
- **Save location:** `mobile/assets/illustrations/onboarding/`
- **Category:** Hero Illustration
- **Description:** Puppy with a paw gently around the kitten, both facing forward, reassuring.
- **Extraction notes:** Top-right of 004, beside the "Tell us about your pet" heading.

#### A-004 — Safety emblem with duo (shield + heartbeat)
- **Used on screens:** 005 (Onboarding safety)
- **Proposed filename:** `onboarding_safety_duo_v1.png`
- **Save location:** `mobile/assets/illustrations/onboarding/`
- **Category:** Hero Illustration
- **Description:** Glowing teal shield with a white heartbeat/ECG line + check, the duo seated below it.
- **Extraction notes:** Top of 005. Can be a **composite** of existing `shield_care_v1.png` + a duo — generate only if you want a single baked illustration.

#### A-005 — Notifications duo under glowing bell
- **Used on screens:** 006 (Onboarding notifications)
- **Proposed filename:** `onboarding_bell_duo_v1.png`
- **Save location:** `mobile/assets/illustrations/onboarding/`
- **Category:** Hero Illustration
- **Description:** A softly glowing bell with a small heart cut-out, the duo seated beneath looking up.
- **Extraction notes:** Top of 006. (Bell glow can alternatively be CODE — see A-015.)

#### A-006 — First-check duo (green collars)
- **Used on screens:** 007 (Onboarding first check)
- **Proposed filename:** `onboarding_firstcheck_duo_v1.png`
- **Save location:** `mobile/assets/illustrations/onboarding/`
- **Category:** Hero Illustration
- **Description:** Puppy + kitten wearing small teal collars, content, a "3 free checks" sparkle badge nearby.
- **Extraction notes:** Top of 007.

#### A-007 — Premium night hero (duo sleeping)
- **Used on screens:** 011 (Premium / paywall)
- **Proposed filename:** `premium_night_duo_v1.png`
- **Save location:** `mobile/assets/illustrations/monetization/`
- **Category:** Premium Illustration
- **Description:** Golden/cream dog + cat sleeping peacefully on a cushion at night, crescent moon and soft curtains behind, warm glow.
- **Extraction notes:** Top-right hero of 011. Supersedes `paywall_peace_of_mind_v1.png` for this screen.

#### A-008 — History "comet sleep" hero
- **Used on screens:** 018 (History timeline)
- **Proposed filename:** `history_comet_sleep_v1.png`
- **Save location:** `mobile/assets/illustrations/empty_states/`
- **Category:** Hero Illustration
- **Description:** Puppy curled asleep riding a glowing teal comet/shooting-star trail.
- **Extraction notes:** Top of 018, above "[pet]'s health story starts here." Replaces `empty_history_story_v1.png`.

#### A-009 — Delete-account "stardust dog"
- **Used on screens:** 014 (Delete account)
- **Proposed filename:** `delete_stardust_dog_v1.png`
- **Save location:** `mobile/assets/illustrations/system/`
- **Category:** Premium Illustration *(emotional/system)*
- **Description:** A gentle puppy partially dissolving into drifting teal stardust particles — wistful, not scary.
- **Extraction notes:** Top of 014, above "This action is permanent." Emotionally load-bearing — keep it soft.

#### A-010 — Family-at-night hero
- **Used on screens:** 012 (Family sharing)
- **Proposed filename:** `family_night_dog_v1.png`
- **Save location:** `mobile/assets/illustrations/growth/`
- **Category:** Hero Illustration
- **Description:** A warm family group holding a dog at night, hearts floating, cozy glow.
- **Extraction notes:** Top-right of 012. **Style decision (D2):** existing `family_care_circle_v1.png` is cartoon; NEW 012 is realistic. Re-art in the **chosen** house style.

#### A-011 — Referral hero (duo + gift)
- **Used on screens:** 013 (Refer a friend)
- **Proposed filename:** `referral_duo_gift_v1.png`
- **Save location:** `mobile/assets/illustrations/growth/`
- **Category:** Referral Illustration
- **Description:** Dog + cat beside a wrapped teal gift box with a coral bow, celebratory sparkles.
- **Extraction notes:** Top-right of 013. Can reuse `referral_gift_v1.png` as the box prop + add animals.

### Tier 2 — Supporting heroes, emblems & trust elements (GENERATE) — for full parity

#### A-012 — Describe-symptoms hero (puppy + phone)
- **Used on screens:** 016 (Describe symptoms)
- **Proposed filename:** `describe_puppy_phone_v1.png`
- **Save location:** `mobile/assets/illustrations/analysis/`
- **Category:** Hero Illustration
- **Description:** Small puppy looking at / holding a phone, curious, screen glow.
- **Extraction notes:** Top-right of 016. Small (decorative, not full-width).

#### A-013 — Log-event hero (dog + calendar-check)
- **Used on screens:** 017, 021 (Log event)
- **Proposed filename:** `logevent_calendar_dog_v1.png`
- **Save location:** `mobile/assets/illustrations/health/` *(new folder — see §6)*
- **Category:** Hero Illustration
- **Description:** Friendly dog beside a calendar showing a check mark.
- **Extraction notes:** Top-right of 017 & 021. One asset serves both.

#### A-014 — Result-state dog set (monitor / media-error)
- **Used on screens:** 019 (Analysis result)
- **Proposed filename:** `result_dog_monitor_v1.png` (+ optional `result_dog_normal_v1.png`, `result_dog_emergency_v1.png`)
- **Save location:** `mobile/assets/illustrations/analysis/`
- **Category:** Hero Illustration *(safety surface — see §4 note)*
- **Description:** A small worried/attentive dog for the amber MONITOR banner; a confused/sorry dog for the "we couldn't process this media" body.
- **Extraction notes:** 019 has two: tiny dog inside the amber banner + a larger dog face in the dark body. **Do not** let art replace or weaken the triage text/disclaimer (see safety note below).

> **⚠ Safety note (CLAUDE.md gate):** Screen 019 carries the triage status (MONITOR) and the API-injected disclaimer. Illustrations here are decorative only — the **status banner, "When to seek a vet" guidance, and disclaimer text must remain exactly as the app injects them.** No asset may overlap or obscure them.

#### A-015 — Glowing bell emblem
- **Used on screens:** 006, 022 (Reminders)
- **Proposed filename:** `emblem_bell_glow_v1.png`
- **Save location:** `mobile/assets/illustrations/system/`
- **Category:** Accent / Emblem
- **Description:** A softly glowing teal notification bell with a tiny heart.
- **Extraction notes:** **Prefer CODE** (Material `Icons.notifications_rounded` + radial glow). Generate only if a painted bell is wanted.

#### A-016 — "Free checks" gift badge
- **Used on screens:** 007, 008 (free-checks chip/card)
- **Proposed filename:** `badge_free_checks_v1.png`
- **Save location:** `mobile/assets/illustrations/growth/`
- **Category:** Badge
- **Description:** Small gift/ticket badge reading the count visually (no baked text), sparkles.
- **Extraction notes:** Reuse `referral_gift_v1.png` if a distinct badge isn't worth a generation.

#### A-017 — Premium "coming soon" envelope+paw
- **Used on screens:** 011 (Premium "Notify me" card)
- **Proposed filename:** `premium_notify_envelope_v1.png`
- **Save location:** `mobile/assets/illustrations/monetization/`
- **Category:** Premium Illustration
- **Description:** A teal envelope with a paw-print seal and a couple of sparkles ("we'll let you know").
- **Extraction notes:** Inside the "Premium is coming soon!" card on 011.

#### A-018 — Trust avatar set (happy pet parents)
- **Used on screens:** 011 ("2.3k+ happy pet parents")
- **Proposed filename:** `avatars/avatar_parent_{1,2,3}_v1.png`
- **Save location:** `mobile/assets/icons/avatars/`
- **Category:** Avatar
- **Description:** 3 small circular friendly pet-parent portraits for an overlapping avatar stack.
- **Extraction notes:** Beside the 5-star "Trusted by pet parents" badge on 011. **Verify the "2.3k+" claim is true** before shipping it (honesty gate — see §9 risk).

### Tier 3 — Sets, decoration, backgrounds (mostly CODE / REUSE — do NOT generate one-by-one)

#### A-019 — Decorative motif kit (paws · hearts · sparkles · leaves · food bowl)
- **Used on screens:** all
- **Class:** **CODE** (positioned Material/custom icons + `CustomPaint`), or one optional sprite sheet.
- **Description:** Scattered paw prints, line+filled hearts, sparkles/fireflies, corner botanical leaves, a paw-print food bowl at the bottom of onboarding/home.
- **Notes:** These are cheap and crisper as code; generating them as raster risks blurry scaling. If you prefer assets, generate **one** transparent "decor kit" sheet and slice in-engine.

#### A-020 — Background system (dark teal-green gradient + glow + particles)
- **Used on screens:** 002–022 (and a cream variant for 001)
- **Class:** **CODE** (`BoxDecoration` linear/radial gradient + a lightweight particle/vignette layer).
- **Description:** Vertical deep teal-green gradient (~#0E211C → #0A1714) with a soft central glow behind heroes and faint drifting particles; 001 is a cream variant (~#F5EFE1).
- **Notes:** Do **not** ship full-screen background PNGs (size + scaling). Build in Flutter. **Blocked on D1** (light vs dark).

#### A-021 — Species chip illustration set (×7)
- **Used on screens:** 004
- **Class:** **REUSE (MVP) / optional UPDATE**
- **Description:** dog, cat, rabbit, guinea pig, bird, reptile, other-paw chip art.
- **Notes:** Existing `species_*.png` are usable now. Only regenerate if you want the richer painted look; if so, generate all 7 in one consistent style pass.

#### A-022 — Feature / value / log-type / common-issue icons
- **Used on screens:** 003, 005, 006, 007, 011, 016, 017, 021
- **Class:** **CODE / icon-font** (Material Symbols or a small custom line-icon set)
- **Description:** clock, 24/7, dollar, vet-shield, error-shield, lock, vet-decides, alert-bell, early-heart, day-night-moon, tag, bolt, the 4 "Premium value" glyphs (vet-informed/private/always-improving/made-with-love), log-type (syringe/cross/pill/scale/pencil), common-issue (vomiting/diarrhea/limping/not-eating/lethargic).
- **Notes:** ~30 small glyphs — all available as Material Symbols / line icons. **Do not generate these as images.**

#### A-023 — Bottom-nav & social-share icons
- **Used on screens:** 008/010 (nav), 013 (social)
- **Class:** **CODE / icon package**
- **Description:** Home/Pets/Help/Settings/Account nav; WhatsApp/Instagram/Messenger/Email/More share icons.
- **Notes:** Nav = Material icons. Social = a brand-icon package (e.g. simple_icons / font_awesome) — **never** custom-draw third-party brand marks.

#### A-024 — Brand wordmark / header mark
- **Used on screens:** 001, 002
- **Class:** **REUSE / minor UPDATE**
- **Description:** "PawDoc" wordmark + small shield-paw mark in the header.
- **Notes:** `logo_mark_v1.png` covers the mark. **Font note:** `Inter-Regular.ttf` and `Uncial_Antiqua/UncialAntiqua-Regular.ttf` were recently added to the workspace — confirm which (if either) is the intended wordmark face before relying on it; the NEW wordmark reads as a rounded bold sans (Inter-like), **not** Uncial Antiqua (a medieval display face). Flag for founder.

---

## 5. GPT Image Prompt Library

Reusable **style preamble** — prepend to every Tier-1/Tier-2 prompt for character consistency:

> *Soft painterly children's-book illustration, rounded gentle shapes, smooth cel-paint shading with a soft inner glow. Recurring characters: an ivory/cream puppy with floppy ears and a small black nose, and a grey-and-white kitten with big friendly eyes. Calming teal-green palette (#1FBFA8, #46C9B0, deep #0E211C) with warm coral heart accents (#FF7A7A). Cozy, safe, reassuring mood. Centered subject, generous empty margins. **Fully transparent background (alpha), no ground shadow slab, no text, no logos, no UI.***

**Universal negative prompt** (append to all):

> *text, words, letters, captions, watermark, signature, UI elements, buttons, frame, border, background scenery, photographic realism, harsh shadows, gradient banding, extra limbs, deformed anatomy, blurry, low-res, jpeg artifacts, clutter.*

> Generate each at **1024×1024 transparent PNG**. For consistent characters, generate **A-002 first**, then use it as an image reference ("same puppy and kitten characters") for A-001/003/004/005/006/007.

---

**A-001 · welcome_duo_moon**
- **Positive:** *[style preamble] The cream puppy and grey kitten peeking up from the bottom edge, a large soft glowing pale-yellow full moon directly behind them, faint floating sparkles and two tiny hearts. Wide top margin.*
- **Negative:** *[universal] + nighttime city, realistic moon craters detail.*
- **Output:** 1024×1024, transparent PNG, square, subject in lower-center.

**A-002 · onboarding_duo_content**
- **Positive:** *[style preamble] The puppy sitting upright facing forward, the kitten sitting close and leaning gently against the puppy's side, both content with soft smiles, three small floating coral hearts above.*
- **Negative:** *[universal].*
- **Output:** 1024×1024, transparent PNG.

**A-003 · onboarding_duo_hug**
- **Positive:** *[style preamble] The puppy with one front paw gently wrapped around the kitten in a protective hug, both looking forward warmly, a couple of tiny sparkles.*
- **Negative:** *[universal].*
- **Output:** 1024×1024, transparent PNG.

**A-004 · onboarding_safety_duo**
- **Positive:** *[style preamble] Above the puppy and kitten floats a glowing teal heraldic shield containing a white heartbeat/ECG line and a small check mark; the duo sits calmly beneath it looking up; soft protective glow.*
- **Negative:** *[universal] + medical equipment, hospital.*
- **Output:** 1024×1024, transparent PNG.

**A-005 · onboarding_bell_duo**
- **Positive:** *[style preamble] A softly glowing rounded teal notification bell with a tiny heart cut-out hovers above; the puppy and kitten sit beneath, ears perked, looking up; gentle radiant rings.*
- **Negative:** *[universal].*
- **Output:** 1024×1024, transparent PNG.

**A-006 · onboarding_firstcheck_duo**
- **Positive:** *[style preamble] The puppy and kitten each wearing a small teal collar, sitting happily side by side, a small glowing sparkle badge floating near the top corner.*
- **Negative:** *[universal] + readable numbers on badge.*
- **Output:** 1024×1024, transparent PNG.

**A-007 · premium_night_duo**
- **Positive:** *[style preamble] A cream dog and a tabby-grey cat sleeping peacefully curled together on a soft round cushion; behind them a calm night scene with a slim crescent moon and softly draped curtains; warm golden-and-teal glow, a few stars.*
- **Negative:** *[universal] + bright daylight.*
- **Output:** 1024×1024 transparent PNG (subject + minimal night ambiance only; keep edges transparent).

**A-008 · history_comet_sleep**
- **Positive:** *[style preamble] The cream puppy curled asleep, riding the head of a long glowing teal comet / shooting-star with a sparkling tail sweeping to one side; serene, dreamy.*
- **Negative:** *[universal] + full starfield background.*
- **Output:** 1024×1024, transparent PNG (comet tail may extend horizontally — keep within frame).

**A-009 · delete_stardust_dog**
- **Positive:** *[style preamble] A gentle cream puppy sitting, the rear half of its body softly dissolving into drifting teal-and-gold stardust particles that float upward; wistful, tender, peaceful — never frightening.*
- **Negative:** *[universal] + horror, scary, dark/morbid tone, skeleton, ghost.*
- **Output:** 1024×1024, transparent PNG.

**A-010 · family_night_dog**  *(house-style per D2)*
- **Positive:** *[style preamble] A warm group of family members (mixed ages) gathered close around a happy cream dog, soft hearts floating, cozy evening glow; tender "everyone in the loop" feeling.*
- **Negative:** *[universal] + identifiable real people, brand logos on clothing.*
- **Output:** 1024×1024, transparent PNG.

**A-011 · referral_duo_gift**
- **Positive:** *[style preamble] The cream puppy and grey kitten sitting beside a wrapped teal gift box with a coral ribbon bow and a small paw-print tag, celebratory sparkles around; joyful.*
- **Negative:** *[universal].*
- **Output:** 1024×1024, transparent PNG.

**A-012 · describe_puppy_phone**
- **Positive:** *[style preamble] A small cream puppy curiously looking at a smartphone held up in its paws, soft screen glow lighting its face; light, friendly.*
- **Negative:** *[universal] + readable phone UI, app icons, brand logos.*
- **Output:** 1024×1024, transparent PNG.

**A-013 · logevent_calendar_dog**
- **Positive:** *[style preamble] A friendly cream dog seated next to a rounded teal wall calendar that shows a single large check mark, a small sparkle; organized, reassuring.*
- **Negative:** *[universal] + readable dates/numbers, month names.*
- **Output:** 1024×1024, transparent PNG.

**A-014 · result_dog_monitor** (+ optional normal/emergency)
- **Positive (monitor):** *[style preamble] A small cream puppy with a gently concerned, attentive expression, ears slightly back, looking up watchfully; calm amber-warm rim light.*
- **Optional normal:** *…relaxed, happy, healthy puppy, soft green glow.*  **Optional emergency:** *…alert, upright puppy looking urgently toward viewer, soft red-warm rim light (calm, not gory).* 
- **Negative:** *[universal] + injury, blood, distress, medical gore.*
- **Output:** 1024×1024, transparent PNG each.

**A-017 · premium_notify_envelope**
- **Positive:** *[style preamble] A rounded teal envelope sealed with a small coral paw-print wax seal, a couple of soft sparkles rising, conveying "we'll let you know."*
- **Negative:** *[universal] + stamps, addresses, text.*
- **Output:** 1024×1024, transparent PNG.

**A-018 · avatar_parent_{1,2,3}**
- **Positive:** *[style preamble] A friendly circular head-and-shoulders portrait of a happy pet parent (vary age/gender/skin tone across the three), warm soft lighting, simple solid soft-teal backdrop inside the circle.*
- **Negative:** *[universal except background] + identifiable real individuals, celebrities.*
- **Output:** 512×512 each, transparent PNG outside the circle (or pre-circled).

*(Tier-3 items A-015/016/019/020/021/022/023/024 are CODE/REUSE — no generation prompts; see §4 notes. If A-021 species are re-arted, reuse the style preamble per animal with the universal negative.)*

---

## 6. Output Specifications

| Asset class | Format | Background | Production size | Min size | Aspect | Notes |
|-------------|--------|-----------|-----------------|----------|--------|-------|
| Hero illustrations (A-001…A-014, A-017) | PNG | **Transparent** | **1024×1024** | 512×512 | 1:1 | Ship 1× @1024; Flutter scales down. Optionally add `@2x`/`@3x` resolution variants if upscaling is ever needed. |
| Emblems/badges (A-015/016/017) | PNG | Transparent | 512×512 | 256×256 | 1:1 | Prefer CODE for bell/glow. |
| Avatars (A-018) | PNG | Transparent | 512×512 | 128×128 | 1:1 | Pre-cropped to circle is fine. |
| Species chips (A-021, if re-arted) | PNG | Transparent | 256×256 | 128×128 | 1:1 | Keep all 7 visually consistent. |
| Decor kit (A-019, if rastered) | PNG | Transparent | 1024×1024 sheet | — | — | Prefer CODE. |
| Backgrounds (A-020) | **n/a — CODE** | — | — | — | device | Gradient + particles in Flutter; **no PNG**. |
| Icons (A-022/023) | **n/a — icon font** | — | — | — | — | Material Symbols / brand-icon package. |

**File conventions (match repo):** snake_case, `_v1` suffix, placed under the existing `mobile/assets/...` tree. Declared folders already exist in `pubspec.yaml`; **only one new folder is implied: `assets/illustrations/health/`** (for A-013) — add it to `pubspec.yaml` `assets:` when implementing (implementation phase, not now).

**Retina:** Flutter renders downscaled crisply, so a single 1024 master is sufficient for phone heroes. Add `2.0x/3.0x` variant subfolders only if a hero is shown near full-bleed.

---

## 7. Asset Reuse Opportunities

- **One character set, many poses.** Generate the puppy+kitten **once** (A-002), then reference it for A-001/003/004/005/006/007 — keeps 6 onboarding heroes consistent and cuts iteration count.
- **Existing assets cover ~6 slots**: `empty_home_welcome_v1` (≈A-001), `shield_care_v1` (A-004 emblem), `referral_gift_v1`/`_open` (A-011 prop + A-016 badge), `status_monitor` (019 banner eye), `species_*` (A-021), `logo_mark_v1` (A-024). Treat these as **done/minor-update**, not new generations.
- **A-013 serves two screens** (017 + 021). **A-014** is one base puppy expression reused for normal/monitor/emergency tints.
- **Decoration & icons are code, not art** — the largest count of "visual elements" (paws, hearts, sparkles, ~30 glyphs, nav, gradients) needs **zero** generation.

---

## 8. Total Assets Required & Estimated Generation Count

| Bucket | Count | Action |
|--------|------:|--------|
| **Tier 1 — must generate** (A-001–A-011, minus existing-covered) | **~8–9** | GENERATE |
| **Tier 2 — should generate** (A-012, A-013, A-014, A-017, A-018×3) | **~6–7** | GENERATE |
| Existing reusable (minor/no update) | ~6 slots | REUSE / UPDATE |
| Decoration / backgrounds / icons / nav / social | ~5 groups (~40 elements) | **CODE / icon-font** |
| Species chips | 7 | REUSE now, optional re-art |

- **Unique illustrations to generate (Tier 1 + Tier 2):** **≈ 14–18.**
- **Estimated GPT Image calls** (with 2–3 iterations each for character consistency): **≈ 35–50.**
- **Assets that must NOT be generated** (code/icon/reuse): the majority of on-screen "elements."

---

## 9. Translation Readiness Assessment

**Verdict: PARTIAL → YES (≥95% achievable) once the conditions below are met.**

**Why PARTIAL today:**
1. **D1 unresolved (light vs. dark):** 001 is cream, the rest dark. Until decided, the duo heroes can't be finalized (lighting differs), and the background system can't be locked.
2. **D2 unresolved (cartoon vs. realistic):** Family/Referral/Describe/Log heroes are drawn in a different style than onboarding + existing assets. Generating before this is decided risks a style-inconsistent flow and rework.
3. **Assets not yet generated:** ~14–18 illustrations don't exist in the repo yet (only baked into mockups).

**Why YES once met:** The hard parts of parity — **layout, spacing, color, typography, component styling, backgrounds, decoration, and icons — are all reproducible in Flutter** without any external art, and the existing asset tree + AppImage fallback system already match the house style. With D1/D2 decided and the Tier-1/Tier-2 assets dropped into `mobile/assets/`, every screen except the two sequence gaps (009, 020) can reach **95–99%**.

**Residual risks to surface (non-asset):**
- **Honesty/compliance:** NEW screens introduce claims — **"2.3k+ happy pet parents," "5-star rating," "$0.33/day," "3 free checks."** These must be **true and substantiated** before shipping (CLAUDE.md honesty gate; ties to the launch-audit GAP-B5 overclaim finding). Flag each for verification during implementation.
- **Safety surface (019):** the triage status + API-injected disclaimer must remain intact; art is decorative only.
- **Brand icons (013):** use a licensed icon package; don't hand-draw WhatsApp/Instagram/etc.
- **Font ambiguity:** confirm whether `Inter` or `Uncial Antiqua` is the intended wordmark face.
- **009 / 020:** confirm whether these are real screens needing references (e.g. EMERGENCY result, video live-capture) — if so, request NEW references.

---

## Appendix — Files reviewed
- **NEW references (20):** `images/new-image/{001_login_screen_reference,002,003,004,005,006,007,008,10,11,12,13,14,15,16,17,18,19,21,22}.png`
- **OLD references (sampled):** `images/old-image/001_login_screen.jpg`, `11.jpg` (+ full file listing).
- **Existing assets (sampled visually):** `logo_mark_v1`, `paywall_peace_of_mind_v1`, `empty_home_welcome_v1`, `shield_care_v1`, `family_care_circle_v1`, `referral_gift_v1`, `system_error_calm_v1`, `species_dog`, `status_monitor` (+ full `mobile/assets/` tree and `pubspec.yaml`).

**— End of report. No code, assets, branches, or commits were created. Awaiting founder review and asset generation before the implementation phase begins.**
