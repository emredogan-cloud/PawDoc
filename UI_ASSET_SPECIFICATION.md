# PawDoc — UI Asset Specification

**Source of truth:** `new-interface/` (57 screen mockups, 852 × 1846 px)
**Document status:** Specification only. No assets generated, no Flutter code written, no UI implemented.
**Date:** 2026-07-29
**Scope:** Complete production asset backlog required to implement the redesigned interface pixel-perfectly.

---

## 1. Executive Summary

### 1.1 What was analysed

All 57 PNG mockups in `new-interface/` were inspected individually at full resolution. They describe a
complete visual redesign of PawDoc spanning **8 onboarding screens, 1 home screen, 8 AI-triage screens,
4 AI-assistant screens, 9 health-record screens, 5 pets screens, 5 memories screens, 3 lifestyle screens
(walks/weather/baseline), 2 encyclopedia screens, 4 community screens, 4 emergency/vet screens,
5 premium screens, and 5 account screens.**

The mockups are **production-fidelity renders**, not wireframes. They contain photoreal animal photography,
3D glossy product illustrations, neon line-art doodles, HUD/hologram artwork, stylised maps, infographics,
hexagonal achievement badges and roughly 200 distinct icon glyphs. **None of this exists in the repository
today** — the current Flutter app ships a token-based, widget-drawn UI with no illustration layer.

### 1.2 Headline numbers

| Metric | Count |
|---|---|
| Screens analysed | 57 |
| Distinct asset IDs specified | **157** |
| Specification entries (§6, some cover an ID range) | 125 |
| Individual files to produce (incl. set members) | **≈ 560** |
| Reusable (multi-screen) assets | 110 (70 %) |
| Screen-unique assets | 14 |
| Assets requiring transparency / alpha | 81 |
| Assets that must **not** be AI-generated (licensed marks) | 3 entries / 7 files |
| Icon glyphs total (≈ 205 authored SVG + ≈ 80 generated-then-vectorised) | ≈ 285 |
| Photoreal photography assets | ≈ 96 |
| 3D / glossy illustrations | 21 |
| Neon line-art doodles | 13 |
| Infographics & educational graphics | 9 |
| Badges / achievements | 21 |
| Human avatars | 21 |
| Map artwork | 9 |

> The high reuse ratio (70 %) is the product of the dedup pass in §1.5 — it is an output of this
> specification, not a property of the mockups.

### 1.3 Two visual sub-systems (critical finding)

The mockups are **not one uniform system**. There are two deliberately different palettes, and assets are
**not interchangeable between them**:

| | **System A — Onboarding / Marketing** | **System B — In-App Product** |
|---|---|---|
| Screens | `000`, `002`–`009` (9 screens) | all other 48 screens |
| Canvas | Deep navy-black `#050B14` → `#070D1A` | Pure black `#000000` → card `#0B0F0B` |
| Primary accent | Emerald green `#22C55E` / `#3DDC4E` | Lime / chartreuse `#A3E635` → `#BEF264` |
| Co-accent | **Cyan `#22D3EE` / `#5EEAD4`** (heavy use) | Cyan, violet, orange, red, amber (domain-coded) |
| Illustration language | Neon outline glyphs w/ heavy bloom, 3D phone mockups, orbital light ribbons | Thin lime line icons w/ soft glow, photoreal cut-outs w/ radial glow |
| Pet casting | Golden retriever **puppy** + tabby **kitten** | Golden retriever **adult** + tabby **adult cat** |

Any asset used in both must be produced **twice** (see `ONB-101/ONB-110` vs `PET-210`, and the
cyan/green glyph pairs `ONB-121`/`ONB-122`). This is flagged per-asset below.

### 1.4 Design-system observations that drive the backlog

1. **Photoreal pets carry the brand.** 96 of 468 files are photographic. A consistent "cast" is required —
   the same Golden Retriever, the same tabby cat, the same fawn rabbit — across ~30 screens. Casting drift
   is the single biggest quality risk. Assets `PET-210`–`PET-218` define the cast; every other pet image
   must be generated **from the same seed/reference**.
2. **Two pet-name collisions exist in the mockups.** `Luna` is a rabbit on `010-home-page` but a Golden
   Retriever on `emergency_hub` / `prepare_for_vet_visit` / `pdf_health_report_preview`; `Milo` is a dark
   tabby on `010-home-page` but a white British Shorthair on `manage_multiple_pets`; `Coco` is a rabbit on
   `manage_multiple_pets` but a toy poodle on `nearby_pet_owners`. Both castings are specified (the
   duplicates are cheap) — **product must pick one before generation**, see §9.4.
3. **Icons are a system, not a pile.** ~205 glyphs resolve into 14 coherent families. Generating them one
   by one with GPT Image is the wrong tool (it cannot hold 1.5 px stroke consistency at 24 pt). §7.0
   specifies the correct pipeline: author families as SVG, use GPT Image only for the ~40 genuinely bespoke
   medical/anatomical pictograms, then vectorise.
4. **The emergency surface is a full red re-skin,** not a red accent. `ai_analysis_result_emergency`
   recolours the entire step-indicator, every icon, every card border and the score ring. This means the
   emergency icon family is a **second colourway of the core family**, not new geometry — cheap if the core
   set ships as SVG with `currentColor`, expensive if it ships as PNG.
5. **The premium surface introduces a third rendering style** — translucent green "glass/jelly" 3D — used
   nowhere else. 13 assets. It is self-contained and can be produced as one batch by one artist/prompt seed.
6. **Community screens shift warm.** `community_feed`, `community_post_detail`, `create_post`,
   `nearby_pet_owners` mix amber/orange chip tints with the lime system. Chip icons there are a distinct
   colourway (`ICN-807` warm variant).

### 1.5 Reuse outcome

Naïve per-screen extraction — treating every visual element on every screen as its own request — yields
**297 asset requests**. After dedup this specification produces **157 distinct asset IDs**, of which 110
serve more than one screen. The largest savings:

| Consolidated asset | Replaces | Screens |
|---|---|---|
| `PET-210` Buddy hero cut-out | 6 separate hero requests | 010-home, ai_health_check_start, ai_assistant_home, ai_analysis ×2, symptom_selection |
| `PRM-709` 3D shield + paw | 5 separate hero requests | premium_home, subscription_plans, upgrade_benefits, profile, account_management |
| `EMG-602` red phone + glow rings | 3 | emergency_hub, first_aid_guide, (ai_analysis_result_emergency variant) |
| `ILL-401` doodle puppy + heart bubble | 3 | ai_analysis_loading, ai_analysis_result_monitor, (create_post variant) |
| `MEM-1201` memory photo library (24) | 41 individual photo slots | memories_gallery, memory_detail, search_memories, add_memory, pet_profile, edit_pet |
| `ICN-801` core line-icon set | ~140 one-off icon requests | all 57 screens |

### 1.6 ⚠️ Safety-contract conflicts found in the mockups (surfaced, not resolved)

Per this project's working agreement (*surface, don't silently apply*), the following conflicts between the
new designs and the frozen safety contract in `CLAUDE.md` / `docs/contracts/ANALYSIS_RESULT.md` **must be
resolved by the owner before the affected assets are generated**, because they determine whether those
assets exist at all. They are asset-blocking, not cosmetic.

> **UPDATE 2026-07-30 —** these conflicts have since been fully investigated. See
> **`UI_SAFETY_CONTRACT_REVIEW.md`**, which catalogues **24 violations across 19 screens** with exact
> current text and layout-preserving replacement copy. The `Status` column below reflects that review.

| # | Mockup | Design shows | Contract says | Assets at risk | Status |
|---|---|---|---|---|---|
| C-1 | `ai_analysis_result_low_risk`, `..._monitor` | `68% confidence` chip; `21% / 7% / 4%` differential bars | **"`confidence` is never shown to users"**; no differential | none (UI-only) | ✅ Copy fix specified — review V-01, V-02, V-04 + §3.1 |
| C-2 | `ai_analysis_result_monitor` | *"Good news! No signs of a serious condition"*, `Low` risk | **"never render 'normal'"**; the action ladder has **no "do nothing" rung** | `ILL-401`, `ILL-403` (decor only) | ✅ Copy fix specified — review V-03; assets unaffected |
| C-3 | `ai_analysis_result_emergency` | *"Potential Concern: **Skin Infection**"* | **"never name a condition"** | `EMG-607` (lesion photo) | ✅ **HOLD RELEASED** — review V-05/V-06; `EMG-607` prompt rewritten |
| C-4 | `emergency_hub` | "AI Triage" quick action **on the emergency surface** | **"NEVER add anything to the emergency surfaces … no AI-driven content. The red path stays offline-capable and model-free"** | emergency quick-action tiles | ⚠️ **OWNER DECISION** — review V-16 proposes replacing the tile with an offline Emergency Checklist |
| C-5 | `first_aid_guide` | "Start AI Triage" hero + "AI Powered" badge on the first-aid surface | same as C-4 | **`AI-306`** (dog + green-cross HUD banner) | ✅ **HOLD RELEASED** — review V-17 reframes the banner as an offline "Browse by symptom"; asset rewritten and reclassified `AI-306` → `EMG-609` |
| C-6 | `emergency_hub` | "Heat Alert" dismissible promo strip; clinic cards with ratings | emergency surface limited to help contacts, first aid, disclaimer, ack gate | `EMG-604` (clinic photos) | ⚠️ **OWNER DECISION** — review V-16 proposes removing the Heat Alert strip; clinic photos are help-contact content and survive either way |
| C-7 | `premium_home`, `usage_limits`, +7 more | Premium nav tab sits where `Emergencies` sits on other screens | GET_HELP_NOW must never be paywalled or displaced | nav icon sets `ICN-810` | ⚠️ **OWNER DECISION** — review V-24; affects 9 screens, structural not copy |

**Recommendation (updated):** C-3 and C-5 are resolved — `EMG-607` and `EMG-609` are cleared to generate
with their rewritten prompts. C-4, C-6 and C-7 remain owner decisions, but **none of them blocks an asset
any longer**: C-4 and C-6 are copy/structure changes, and C-7 is a navigation-slot decision. The entire
P0–P6 backlog is now generatable.

### 1.7 Assets that must NOT be AI-generated

`TPB-1701`–`TPB-1703` (Google "G", Visa / Mastercard / AMEX / Apple Pay / Google Pay, RevenueCat wordmark)
are **registered trademarks**. GPT Image must not be used to approximate them — doing so produces
non-compliant marks and violates each brand's usage terms. Source them from the official brand kits.
Prompts are deliberately omitted for these three entries.

Additionally, the 21 human avatars (`AVT-*`) are specified as **synthetic, non-identifiable** people.
They must not resemble real individuals and should carry no implied endorsement.

---

## 2. Naming Convention

### 2.1 File names

```
<family>-<subject>[-<variant>][-<state>]@<scale>.<ext>
```

* lowercase, hyphen-separated, ASCII only, no spaces
* `<family>` — short domain token: `onb ai emg prm pet mem cmn brd map inf ill bdg avt doc bgd`
* `<variant>` — casting/colour/size discriminator (`puppy`, `adult`, `cyan`, `lime`, `red`, `hex`)
* `<state>` — `locked`, `active`, `empty`, `good`, `bad`
* `<scale>` — `@1x` `@2x` `@3x` for raster; **omitted for SVG**
* extension — `.svg` `.webp` `.png`

Examples

```
onb-hero-puppy-kitten-pair@3x.webp
pet-buddy-hero-cutout@3x.png
prm-3d-robot-ai-insights@3x.png
ic-symptom-vomiting.svg
bdg-walk-streak-week-locked@3x.png
emg-clinic-exterior-01@3x.webp
```

### 2.2 Asset IDs

`<PREFIX>-<NNN>` — stable, never reused, referenced from Flutter constants and from this document.

| Prefix | Family |
|---|---|
| `BRD` | Brand / logo |
| `ONB` | Onboarding & marketing artwork |
| `PET` | Pet cast photography |
| `AI` | AI-system artwork |
| `ILL` | Line-art illustrations & doodles |
| `INF` | Infographics / educational graphics |
| `EMG` | Emergency artwork |
| `PRM` | Premium artwork |
| `ICN` | Icon families |
| `BDG` | Badges & achievements |
| `AVT` | Human avatars |
| `MAP` | Map artwork |
| `MEM` | Memory photo library |
| `BRE` | Breed encyclopedia artwork |
| `CMN` | Community artwork |
| `DOC` | Document / PDF artwork |
| `BGD` | Backgrounds & decorative layers |
| `TPB` | Third-party brand marks (source, don't generate) |

### 2.3 Dart constant mapping

```dart
// mobile/lib/src/core/assets/app_assets.dart  (to be authored later — NOT part of this pass)
abstract final class AppAssets {
  static const petBuddyHero = 'assets/images/pets/pet-buddy-hero-cutout.webp';
  //          ^ camelCase of the asset ID's semantic name
}
```

Rule: **asset ID → Dart identifier** is `lowerCamelCase(subject + variant)`; the numeric ID stays only in
this document and in the filename comment.

---

## 3. Folder Structure

```
mobile/assets/
├── brand/                              # BRD — logo, wordmark, app icon
│   └── logo/
├── images/
│   ├── onboarding/                     # ONB — System A only (navy + emerald + cyan)
│   │   ├── heroes/
│   │   └── devices/
│   ├── pets/                           # PET — the photographic cast
│   │   ├── cast/                       #   Buddy / Milo / Luna / Coco
│   │   └── species/                    #   species selector portraits
│   ├── ai/                             # AI — assistant, scan, hologram
│   ├── emergency/                      # EMG — red system
│   ├── premium/                        # PRM — 3D glass system
│   ├── community/                      # CMN — feed artwork, editorial cards
│   ├── memories/                       # MEM — sample memory library
│   ├── breeds/                         # BRE — encyclopedia photography
│   ├── avatars/                        # AVT — synthetic human avatars
│   ├── maps/                           # MAP — stylised map artwork
│   ├── education/                      # INF — infographics, photo-quality examples
│   └── documents/                      # DOC — PDF page artwork, QR
├── illustrations/
│   ├── doodles/                        # ILL — neon line-art pets
│   └── infographics/                   # INF — vector infographics
├── icons/
│   ├── core/                           # ICN-801   ~140 SVG, currentColor
│   ├── nav/                            # ICN-810
│   ├── symptoms/                       # ICN-802
│   ├── anatomy/                        # ICN-803
│   ├── vaccines/                       # ICN-804
│   ├── firstaid/                       # ICN-805
│   ├── actions/                        # ICN-806
│   ├── notifications/                  # ICN-807
│   ├── medication/                     # ICN-808
│   ├── vitals/                         # ICN-811
│   ├── records/                        # ICN-812
│   ├── breed-care/                     # ICN-813
│   └── weather-3d/                     # ICN-809  (raster, not SVG)
├── badges/
│   └── achievements/                   # BDG
├── decor/                              # BGD — tileable / overlay layers
└── third-party/                        # TPB — sourced, licence-tracked
```

**Flutter registration:** declare directories (not individual files) in `pubspec.yaml`. Ship `@1x/@2x/@3x`
variants for raster via Flutter's resolution-aware asset convention (`assets/…/2.0x/name.png`).

---

## 4. Global Reusable Assets

These 24 assets appear on **4 or more screens**. They are the backbone of the system and must be generated
first, reviewed hardest, and never duplicated.

| ID | Asset | Screens | Why it's global |
|---|---|---|---|
| `BRD-001` | Paw + heart logo mark | 000, 002–009, 010-home, pdf_health_report_preview, ai_assistant_chat, notifications | Brand mark |
| `BRD-002` | Horizontal logo lockup | 000, 010-home, pdf_health_report_preview | Brand mark |
| `ICN-801` | Core line-icon set (~140) | **all 57** | Every screen |
| `ICN-810` | Bottom-nav icon sets (2 variants) | 42 | Persistent chrome |
| `PET-210` | Buddy hero cut-out (adult GR, sitting) | 010-home, ai_health_check_start, ai_assistant_home, ai_analysis_loading, symptom_selection, ai_analysis ×2 | Primary pet hero |
| `PET-211` | Buddy circular avatar | 18 screens | Pet chip everywhere |
| `PET-214` | Milo tabby cat avatar | 010-home, manage_multiple_pets, pet_statistics, add_memory, memories_gallery | Pet chip |
| `PET-216` | Luna rabbit avatar | 010-home, manage_multiple_pets, pet_statistics, add_memory | Pet chip |
| `PET-217` | Luna Golden Retriever portrait | emergency_hub, prepare_for_vet_visit, pdf_health_report_preview | Second GR casting |
| `AI-302` | AI assistant avatar (paw-in-bubble) | ai_assistant_chat, ai_message_actions, conversation_history, ai_assistant_home | Chat identity |
| `PRM-707` | Lime crown | premium_home, subscription_plans, upgrade_benefits, usage_limits, profile, account_management, nav | Premium identity |
| `PRM-709` | 3D shield + paw (glass) | premium_home, subscription_plans, upgrade_benefits, profile, account_management | Trust/premium hero |
| `PRM-711` | Dog + cat premium duo photo | premium_home, subscription_plans, upgrade_benefits, ai_health_check_start | Premium hero |
| `EMG-602` | Red phone + concentric glow rings | emergency_hub, first_aid_guide | Emergency CTA |
| `EMG-601` | Red emergency beacon / siren | 004-onboarding, ai_analysis_result_emergency, ai_assistant_home | Emergency mark |
| `EMG-603` | Red shield with `!` | ai_analysis_result_emergency, emergency_hub | Emergency risk badge |
| `ILL-401` | Doodle puppy + heart speech bubble | ai_analysis_loading, ai_analysis_result_monitor, create_post (variant) | Friendly filler |
| `ILL-412` | Dashed paw-print trail | ai_analysis_loading, smart_walks, 009-onboarding | Decorative motif |
| `BGD-1605` | Green radial glow | 010-home, ai_health_check_start, ai_assistant_home, premium_home, + 12 | Behind every cut-out |
| `BGD-1606` | Concentric orbital rings | 002, 004, 005, 006, ai_assistant_home, ai_analysis_loading, privacy_security | Glow furniture |
| `BGD-1601` | Paw-print confetti layer | 000, 002, 008, 009, photo_analysis_upload | Background texture |
| `BGD-1602` | 4-point sparkle stars | 25 screens | Decorative |
| `AVT-1002` | Female user avatar | 010-home, community_feed, create_post | Account identity |
| `AVT-1003` | Male user avatar (Emre) | profile, account_management | Account identity |

---

## 5. Screen-by-Screen Asset Inventory

Legend — **N** = new/unique to this screen · **R** = reused · **V** = variant of an existing asset.

### System A — Onboarding (9 screens)

| Screen | Assets |
|---|---|
| `000.png` Splash / Welcome | **N** `BRD-001` logo mark · **N** `BRD-002` lockup · **N** `ONB-101` puppy+kitten hero · **N** `ONB-111` teal 3D shield+paw · **N** `ONB-121` neon feature glyphs ×4 (brain, diary, cross, bell) · **N** `AVT-1001` social-proof face cluster · **R** `BGD-1601` paw confetti · **R** `BGD-1602` sparkles · **N** `BGD-1611` medical-cross watermark · **N** `TPB-1701` Google G · `ICN-801` |
| `002-onboarding.png` | **V** `ONB-102` puppy+kitten seated pair · **R** `ONB-111` · **N** `ONB-112` hex shield+paw · **N** `ONB-122` circular glyph badges (paw-in-gear, heart-ECG) · **N** `ONB-123` trust glyphs (shield-check, padlock, headset) · **R** `BGD-1601`, `BGD-1606` |
| `003-onboarding.png` | **N** `ONB-104` 3D iPhone mockup frame · **N** `AI-303` AI-scan HUD overlay on dog head · **N** `ONB-124` neon shield+check (large) · **N** `ONB-125` cyan trust glyphs (crosshair, clock-bolt, heart-ECG) · **N** `BGD-1603` hex mesh · **R** `BGD-1601` |
| `004-onboarding.png` | **N** `EMG-601` red beacon · **N** `ONB-113` green house+paw · **N** `ONB-114` "≠" collision badge · **N** `EMG-608` red/green split light streams · **R** `ONB-111` · **N** `ONB-126` cyan trust glyphs (24/7 clock, open book, hands+heart) |
| `005-onboarding.png` | **N** `ONB-115` cyan notebook+paw hero glyph · **R** `ONB-104` phone frame · **N** `ONB-107` dog+kitten cut-out · **N** `ONB-127` 5-hue rail glyphs (node-graph, syringe, calendar, photo, PDF) · **N** `ONB-128` cyan speech-bubble callout · **R** `BGD-1606` |
| `006-onboarding.png` | **N** `AI-301` neon robot mascot ⭐ · **R** `ONB-104` · **N** `ONB-108` puppy+kitten under blanket · **N** `ONB-129` cyan card glyphs ×4 · **N** `BGD-1612` floating cyan hearts · **R** `BGD-1606` |
| `007-onboarding.png` | **N** `ONB-116` green paw-in-circle + plus · **R** `ONB-104` · **N** `ONB-109` dog+cat in green halo arc · **N** `ONB-130` green card glyphs ×6 · **N** `BGD-1604` green aurora ribbons · **N** `ONB-131` neon speech bubbles w/ heart ×2 |
| `008-onboarding.png` | **V** `ONB-117` cyan paw-in-circle + plus · **N** `PET-201`–`PET-205` species portrait cards ⭐ · **N** `PET-213` Buddy on grass, golden hour · **N** `ILL-410` clipboard + shield doodle · **N** `ONB-132` benefit glyphs (heart+paw, bell, violet diary) · **R** `BGD-1601` |
| `009-onboarding.png` | **N** `ONB-118` green check-in-circle · **N** `ONB-110` dog+kitten in halo + smoke · **N** `BRD-005` script lettering · **N** `ONB-133` capability glyphs ×4 (multi-hue) · **R** `BGD-1601`, `BGD-1602` · **N** `BGD-1609` green smoke plumes |

### System B — Home & AI Triage (9 screens)

| Screen | Assets |
|---|---|
| `010-home-page.png` | **R** `BRD-002` · **N** `PET-210` Buddy hero cut-out ⭐ · **R** `PET-211`, `PET-214`, `PET-216` · **N** `AVT-1002` female user avatar · **N** `ICN-810a` nav set A · **R** `BGD-1605`, `BGD-1608` leaf sprigs · **N** `ICN-812` record-type glyphs · `ICN-801` |
| `ai_health_check_start.png` | **N** `PRM-711` dog+cat duo (also premium) · **N** `ICN-803` check-domain glyphs (heart, skin-coat, eyes-ears-nose, brain) · **N** `INF-502` photo-quality examples ×3 · **R** `PET-211`, `BGD-1605` · **N** `BGD-1613` floating lime crosses |
| `photo_analysis_upload.png` | **N** `ONB-134` camera-in-glow-ring dropzone mark · **N** `INF-503` anatomy macro photos ×4 (ear/nose/eye/mouth) · **R** `BGD-1607` giant paw watermark · `ICN-801` |
| `symptom_selection.png` | **N** `ICN-802` symptom pictogram set (24) ⭐ · **R** `PET-210` (portrait crop) · `ICN-801` |
| `ai_analysis_loading.png` | **N** `AI-304` circular AI-scan loading composite ⭐ · **N** `ILL-401` doodle puppy + heart bubble · **R** `ILL-412` paw trail · `ICN-801` |
| `ai_analysis_result_low_risk.png` | **N** `PET-212` Buddy park portrait (bokeh) · **R** `ICN-801` · ⚠️ see C-1 |
| `ai_analysis_result_monitor.png` | **R** `PET-212`, `ILL-401` · **N** `ILL-403` large leaf outline · ⚠️ see C-2 |
| `ai_analysis_result_emergency.png` | **N** `EMG-607` sick dog w/ facial lesion ⭐ · **R** `EMG-601`, `EMG-603` · **N** `ICN-801-red` full red colourway · ⚠️ see C-3 |
| `ai_assistant_home.png` | **R** `PET-210` (w/ paw collar tag) · **N** `AI-307` orbital ring w/ light nodes · **N** `ONB-135` neon speech bubble w/ paw · **R** `PRM-707` crown · **R** `EMG-601` (topic tile) · **R** `BGD-1605` |

### System B — AI Assistant (3 screens)

| Screen | Assets |
|---|---|
| `ai_assistant_chat.png` | **N** `AI-302` AI avatar (paw-in-bubble) ⭐ · **R** `PET-211` w/ ring+badge · `ICN-801` |
| `ai_message_actions.png` | **N** `ICN-806` multicolour message-action icons (8) · **R** `AI-302`, `PET-211` |
| `conversation_history.png` | **N** `ICN-812b` conversation-topic tinted tiles (6) · **R** `AI-302` · `ICN-801` |

### System B — Health records (7 screens)

| Screen | Assets |
|---|---|
| `health_timeline.png` | **N** `INF-504` clinical paw-redness thumbnail · **R** `ICN-812` · `ICN-801` |
| `add_health_record.png` | **R** `INF-504` · **N** `DOC-1503` lab-report thumbnail · **R** `ICN-812` |
| `weight_tracking.png` | **N** `ILL-409` dog-on-scale + clipboard doodle pair · **N** `ILL-402` outline dog silhouette · `ICN-801` |
| `medication_tracker.png` | **N** `ICN-808` medication-form tiles (4) · **N** `ILL-406` puppy + hearts doodle · `ICN-801` |
| `vaccination_manager.png` | **N** `ICN-804` vaccine pathogen tiles (8) ⭐ · **N** `ILL-405` puppy + shield doodle · `ICN-801` |
| `reminder_detail.png` | **R** `ILL-402`, `ICN-808` · `ICN-801` |
| `pdf_health_report_preview.png` | **N** `DOC-1501` PDF page artwork ⭐ · **N** `DOC-1502` QR verify block · **R** `PET-217` Luna GR · `ICN-801` |

### System B — Pets (5 screens)

| Screen | Assets |
|---|---|
| `pet_profile.png` | **R** `PET-211` w/ glow ring · **N** `MEM-1201` (4 slots) · **N** `AVT-1004` female vet avatar · **N** `ILL-402` dog + heart doodle · `ICN-801` |
| `edit_pet.png` | **R** `PET-211`, `MEM-1201` (4 slots) · `ICN-801` |
| `manage_multiple_pets.png` | **R** `PET-211` · **N** `PET-215` Milo white British Shorthair (casting conflict) · **N** `PET-218` Coco fawn rabbit · `ICN-801` |
| `pet_statistics.png` | **R** `PET-211`, `PET-215`, `PET-218` · `ICN-801` |
| `know_your_baseline.png` | **N** `ICN-811` vital-sign glyphs (5) + ECG sparklines · **N** `BDG-906` award rosette · `ICN-801` |

### System B — Memories (4 screens)

| Screen | Assets |
|---|---|
| `memories_gallery.png` | **N** `MEM-1201` memory photo library (24) ⭐ · **R** `PET-211`, `PET-214`, `PET-216` · **N** `BDG-908` crown highlight badge |
| `memory_detail.png` | **R** `MEM-1201/07` hero · **N** `ILL-411` dog-face + heart doodle · **N** `MAP-1105` map thumbnail |
| `add_memory.png` | **R** `MEM-1201`, `PET-211/214/216` · `ICN-801` |
| `search_memories.png` | **R** `MEM-1201` · **N** `ICN-813b` quick-search glyphs (cake, stethoscope, suitcase, ball) |

### System B — Lifestyle (3 screens)

| Screen | Assets |
|---|---|
| `smart_walks.png` | **N** `MAP-1103` live route map ⭐ · **N** `MAP-1104` route thumbnails ×3 · **N** `BDG-901`–`BDG-903` hex achievement badges (5 + locked) ⭐ · **N** `ILL-404` running-dog doodle · **R** `ILL-412`, `ICN-809` |
| `weather_walk_advisor.png` | **N** `ICN-809` 3D weather icon set (8) ⭐ · **N** `PET-219` Buddy-in-shield composite · **R** `PET-211` |
| `know_your_baseline.png` | *(listed above)* |

### System B — Encyclopedia (2 screens)

| Screen | Assets |
|---|---|
| `breed_encyclopedia.png` | **N** `BRE-1301` species category avatars (6) · **N** `BRE-1302` GR park hero portrait · **N** `BRE-1303` similar-breed thumbs (4) · **N** `ICN-803` health-condition glyphs · **N** `ICN-813` breed-care glyphs · **N** `ILL-403` dog-lying doodle |
| `breed_detail.png` | **R** `BRE-1302`, `ICN-803`, `ICN-813` · **N** `INF-501` size-reference infographic ⭐ |

### System B — Community (4 screens)

| Screen | Assets |
|---|---|
| `community_feed.png` | **N** `AVT-1005` member avatars w/ pets (6) ⭐ · **N** `CMN-1401` "Hot Weather Pet Health" editorial card ⭐ · **N** `CMN-1402` promenade post photos (3) · **N** `CMN-1403` reaction chips (3) · **N** `CMN-1404` agility-dog video thumb · **N** `ICN-807w` warm category glyphs · **N** `BDG-904` verified checks · **N** `BDG-905` top-contributor badge |
| `community_post_detail.png` | **R** `AVT-1005`, `CMN-1402`, `CMN-1403`, `BDG-904` |
| `create_post.png` | **R** `AVT-1005`, `CMN-1402` · **N** `ILL-408` dog + heart-bubble doodle · **N** `AVT-1007` group avatars (3) |
| `nearby_pet_owners.png` | **N** `MAP-1101` stylised neighbourhood map ⭐ · **N** `AVT-1006` map + list avatars (5) · **N** `ICN-814` species sub-badges (3) |

### System B — Emergency & Vet (4 screens)

| Screen | Assets |
|---|---|
| `emergency_hub.png` | **R** `EMG-602`, `EMG-603` · **N** `EMG-604` clinic exterior night photos (3) ⚠️ · **N** `EMG-605` emergency-kit still life ⭐ · **N** `EMG-606` red clinic map pins · **N** `MAP-1102` clinic map · **R** `PET-217` · ⚠️ see C-4/C-6 |
| `first_aid_guide.png` | **N** `EMG-609` first-aid hero banner ♻️ *(was `AI-306`, rewritten — see review V-17)* · **N** `ICN-805` first-aid topic tiles (8) ⭐ · **N** `ILL-407` vet + cat + dog doodle · **R** `EMG-602` |
| `prepare_for_vet_visit.png` | **R** `PET-217`, `ICN-802` · **N** `ICN-815` bring-to-vet glyphs (5) · **N** `ILL-413` lightbulb + sparkle card art |
| `pdf_health_report_preview.png` | *(listed above)* |

### System B — Premium (4 screens)

| Screen | Assets |
|---|---|
| `premium_home.png` | **N** `PRM-701`–`PRM-706` 3D feature illustrations (6) ⭐ · **R** `PRM-707` crown · **N** `PRM-709` 3D shield+paw · **N** `PRM-711` dog+cat duo |
| `subscription_plans.png` | **R** `PRM-707`, `PRM-709`, `PRM-711` · **N** `TPB-1702` payment marks ⛔ · **N** `TPB-1703` RevenueCat ⛔ |
| `upgrade_benefits.png` | **R** `PRM-709` (large-paw variant), `PRM-711`, `PRM-707` · **N** `ICN-816` benefit glyphs (4) |
| `usage_limits.png` | **N** `PRM-710` 3D speedometer + shield ⭐ · **N** `PRM-708` 3D crown + paw · **R** `PRM-707` |

### System B — Account (5 screens)

| Screen | Assets |
|---|---|
| `profile.png` | **N** `AVT-1003` male user avatar · **R** `PRM-709`, `PRM-707` · `ICN-801` |
| `account_management.png` | **R** `AVT-1003`, `PRM-707`, `PRM-709` · `ICN-801` |
| `notifications.png` | **N** `PRM-713` 3D bell + paw + sound waves ⭐ · **N** `ICN-807` notification category tiles (6) · **N** `BRD-006` PawDoc push icon · **R** `PET-217` |
| `privacy_security.png` | **N** `PRM-712` 3D shield + paw + padlock ⭐ · **R** `PRM-709` · `ICN-801` |
| `ai_transparency.png` | **N** `AI-305` holographic wireframe dog + cat ⭐ · **R** `PRM-709` · `ICN-801` |

---

## 6 & 7. Complete Asset List with Production Prompts

Every entry below carries the ten required fields. Prompts are written in English, production-ready, and
assume GPT Image generates the final asset directly.

### 7.0 Global prompt preamble (prepend to every prompt in this section)

> **PawDoc style base — System B (in-app):** Dark UI asset for a premium pet-health mobile app. Pure black
> background `#000000`. Primary accent is a bright lime-chartreuse `#A3E635` with highlights toward
> `#BEF264`. Soft outer glow / bloom on all emissive elements. Clean, modern, calm, medical-grade but warm.
> No text, no lettering, no watermarks, no UI chrome, no borders. Centred subject with generous padding.
>
> **PawDoc style base — System A (onboarding):** Dark UI asset for a premium pet-health mobile app.
> Deep navy-black background `#050B14`. Accents: emerald green `#22C55E` and cyan `#22D3EE`. Strong neon
> bloom and light-ribbon energy. No text, no lettering, no watermarks, no UI chrome.

**Transparency:** where "transparent" is specified, request *"isolated subject on a fully transparent
background, alpha channel, no backdrop, no shadow plane"* and post-process with a matte cleanup pass.
GPT Image does not emit true alpha reliably — plan a background-removal step for every transparent asset.

**Icon caveat:** GPT Image cannot hold consistent 1.5 px stroke weight, optical sizing and pixel-grid
alignment across a 140-glyph family. For `ICN-801`, `ICN-810`, `ICN-811`, `ICN-812`, `ICN-813`, `ICN-815`,
`ICN-816` the specified pipeline is **author as SVG** (Lucide/Phosphor base, custom-drawn for bespoke
glyphs). GPT Image is used only for the bespoke medical/anatomical pictograms (`ICN-802`, `ICN-803`,
`ICN-804`, `ICN-805`, `ICN-806`, `ICN-808`, `ICN-809`) — generated one glyph per 1024×1024 plate, then
vectorised and re-stroked to the system weight. Prompts below reflect this.

---

### 6.1 BRAND — `BRD`

---

#### `BRD-001` — PawDoc paw-and-heart logo mark

| Field | Value |
|---|---|
| **Filename** | `brd-logo-mark@3x.png` + `brd-logo-mark.svg` |
| **Folder** | `assets/brand/logo/` |
| **Category** | Icon / brand mark |
| **Used on** | `000`, `002`–`009`, `010-home-page`, `ai_assistant_chat`, `pdf_health_report_preview`, `notifications` (10 screens) |
| **Reusable** | Yes — global |
| **Transparency** | Required |
| **Format** | **SVG** (primary) + PNG @1x/@2x/@3x fallback |
| **Resolution** | Vector; raster 144 × 144 @3x (48 pt) |

> **Prompt:** A flat vector logo mark of a stylised animal paw print, front-facing, perfectly symmetrical.
> Four rounded oval toe beans arranged in a gentle arc above one large rounded main pad. The main pad
> contains a smooth heart shape cut out of its centre. Two-tone: the four toe beans are pure white, the
> main pad is bright lime green `#A3E635`, the heart negative space reads as the background. Clean geometric
> construction, even optical weight, generous spacing between beans, no outline stroke, no gradient, no
> shadow, no text. Isolated on a fully transparent background, alpha channel. Crisp vector-quality edges,
> app-icon grade.

---

#### `BRD-002` — Horizontal logo lockup

| Field | Value |
|---|---|
| **Filename** | `brd-logo-lockup-horizontal@3x.png` + `.svg` |
| **Folder** | `assets/brand/logo/` |
| **Category** | Brand lockup |
| **Used on** | `000`, `010-home-page`, `pdf_health_report_preview` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | Vector; raster 660 × 168 @3x |

> **Prompt:** A horizontal brand lockup: the PawDoc paw-and-heart mark on the left, wordmark on the right.
> Wordmark reads "PawDoc" in a bold geometric sans-serif with tight tracking; the word "Paw" is pure white
> and "Doc" is bright lime green `#A3E635`, set as one continuous word with no space. Baseline of the
> wordmark optically aligned to the mark. Balanced spacing, no outline, no shadow, no tagline. Isolated on a
> fully transparent background, alpha channel.
>
> *Variant note:* System A screens use the same lockup with a **stacked** arrangement (mark above wordmark)
> and emerald `#3DDC4E` for "Doc" — produce as `brd-logo-lockup-stacked-emerald@3x.png`.

---

#### `BRD-003` — App icon

| Field | Value |
|---|---|
| **Filename** | `brd-app-icon-1024.png` |
| **Folder** | `assets/brand/logo/` |
| **Category** | Brand / launcher |
| **Used on** | OS launcher (not a screen) — implied by `BRD-001` |
| **Reusable** | No |
| **Transparency** | **No** (opaque, per store requirements) |
| **Format** | PNG |
| **Resolution** | 1024 × 1024 (master); export full iOS/Android ladder |

> **Prompt:** A square mobile app icon, 1024×1024. Background is a smooth near-black to very dark charcoal
> radial gradient (`#0B0F0B` centre → `#000000` edges) with a subtle lime glow bloom behind the centre.
> Centred: a stylised paw print with four white rounded toe beans and one large lime-green `#A3E635` main
> pad containing a heart-shaped negative space. The mark occupies about 62 % of the canvas. Soft outer glow
> around the paw. Perfectly centred, no text, no rounded-corner mask baked in, flat modern iconography,
> crisp edges, no noise.

---

#### `BRD-005` — "Let's give them the best life" script lettering

| Field | Value |
|---|---|
| **Filename** | `brd-script-best-life@3x.png` |
| **Folder** | `assets/brand/` |
| **Category** | Decorative / lettering |
| **Used on** | `009-onboarding` |
| **Reusable** | No |
| **Transparency** | Required |
| **Format** | **SVG** preferred (crisp at any size) |
| **Resolution** | Vector; raster 960 × 150 @3x |

> **Prompt:** Handwritten script lettering reading "Let's give them the best life" followed by a small
> outlined heart, rendered as a single continuous thin monoline stroke in bright lime green `#A3E635` with a
> soft neon glow. Casual, warm, slightly slanted handwriting with natural stroke variation, an elegant
> underline swash sweeping beneath the phrase. No serif, no drop shadow, no background. Isolated on a fully
> transparent background, alpha channel.

---

#### `BRD-006` — PawDoc push-notification icon

| Field | Value |
|---|---|
| **Filename** | `brd-push-icon@3x.png` |
| **Folder** | `assets/brand/logo/` |
| **Category** | Icon / brand |
| **Used on** | `notifications` (preview card) |
| **Reusable** | Yes (OS notification tray) |
| **Transparency** | No (rounded-square tile) |
| **Format** | PNG |
| **Resolution** | 144 × 144 @3x |

> **Prompt:** A small square app-badge tile with a 22 % corner radius. Background is a solid deep indigo-blue
> `#1E3A8A`. Centred on it, a simple paw print with four toe beans and one main pad in bright cornflower
> blue `#60A5FA`, filling about 60 % of the tile. Flat, no gradient, no glow, no text. Crisp edges, optimised
> for tiny display sizes.

---

### 6.2 ONBOARDING ARTWORK — `ONB` *(System A palette)*

---

#### `ONB-101` — Splash hero: puppy + kitten pair ⭐

| Field | Value |
|---|---|
| **Filename** | `onb-hero-puppy-kitten-splash@3x.webp` |
| **Folder** | `assets/images/onboarding/heroes/` |
| **Category** | Hero artwork / photoreal |
| **Used on** | `000.png` |
| **Reusable** | Base casting reused by `ONB-102`, `ONB-107`–`ONB-110` |
| **Transparency** | Required (subject cut out; glow composited in Flutter) |
| **Format** | **WEBP** (lossy q90) — large photographic hero |
| **Resolution** | 1600 × 1400 @3x master; generate 1536 × 1536 |

> **Prompt:** Photorealistic studio portrait of a young Golden Retriever puppy sitting beside a small brown
> tabby kitten, both facing the camera. The puppy is on the left, mouth slightly open in a friendly
> expression, soft golden fur with visible individual hairs; the kitten is on the right, upright, alert,
> with large green-gold eyes and crisp tabby striping. Both are the same visual scale so neither dominates.
> Cinematic three-quarter key light from the upper left with a cool cyan-green rim light tracing the tops of
> their heads and backs. Very shallow depth of field on the background only; subjects tack-sharp.
> Warm natural fur colour against cool lighting. Isolated on a fully transparent background, alpha channel,
> no floor, no shadow plane, no props. Photographic realism, 85 mm portrait lens look, ultra-detailed fur,
> commercial pet-photography quality.

---

#### `ONB-102` — Onboarding hero: puppy + kitten seated (full body)

| Field | Value |
|---|---|
| **Filename** | `onb-hero-puppy-kitten-seated@3x.webp` |
| **Folder** | `assets/images/onboarding/heroes/` |
| **Category** | Hero artwork / photoreal |
| **Used on** | `002-onboarding` |
| **Reusable** | No (variant of `ONB-101`) |
| **Transparency** | Required |
| **Format** | WEBP |
| **Resolution** | 1600 × 1750 @3x; generate 1024 × 1536 |

> **Prompt:** Photorealistic full-body studio photograph of a Golden Retriever puppy sitting upright next to
> a brown tabby kitten, both seen from the front, both sitting on a dark navy velvet blanket whose folds are
> just visible beneath their paws. The puppy's front legs are straight and its paws are clearly visible; the
> kitten sits tall beside it with its tail curled forward. Cool cyan rim light along both silhouettes,
> warm soft key light on their faces. Same casting and fur detail as the splash hero — identical puppy,
> identical kitten. Dark navy background falling to near-black, no props, no text. Photographic realism,
> ultra-detailed fur, commercial pet-photography quality.

---

#### `ONB-104` — 3D iPhone device mockup frame

| Field | Value |
|---|---|
| **Filename** | `onb-device-iphone-frame@3x.png` |
| **Folder** | `assets/images/onboarding/devices/` |
| **Category** | Device mockup / decorative |
| **Used on** | `003`, `005`, `006`, `007` (4 screens) |
| **Reusable** | **Yes — generate once, composite screenshots into it** |
| **Transparency** | Required (screen area must be transparent) |
| **Format** | PNG (needs clean alpha on the screen cut-out) |
| **Resolution** | 1180 × 2320 @3x |

> **Prompt:** A photorealistic modern smartphone hardware frame shown perfectly front-on, no perspective
> tilt. Dark titanium-grey brushed metal rails with polished chamfered edges, subtle top-left specular
> highlight, thin dark bezel, rounded corners, a pill-shaped camera cut-out at the top centre of the display
> area. The entire display area is empty and fully transparent so a screenshot can be composited into it.
> No buttons rendered on the front face, no reflections across the glass, no shadow beneath the device.
> Isolated on a fully transparent background, alpha channel. Product-photography realism, clean industrial
> design, no branding or logos anywhere on the device.

---

#### `ONB-107` — Dog + kitten cut-out (diary screen)

| Field | Value |
|---|---|
| **Filename** | `onb-hero-dog-kitten-cutout@3x.webp` |
| **Folder** | `assets/images/onboarding/heroes/` |
| **Category** | Hero artwork / photoreal |
| **Used on** | `005-onboarding` |
| **Reusable** | No |
| **Transparency** | Required |
| **Format** | WEBP |
| **Resolution** | 1100 × 1500 @3x |

> **Prompt:** Photorealistic photograph of an adult Golden Retriever sitting upright, facing the camera with
> a relaxed open-mouth expression, wearing a slim dark collar with a small metal tag. Directly in front of
> and below it, a small brown tabby kitten sits looking straight at the camera. The dog's chest fills the
> upper two-thirds, the kitten occupies the lower foreground. Warm key light from the front-left, cool cyan
> rim light on the outer edges of both animals. Isolated on a fully transparent background, alpha channel,
> no floor, no shadow. Ultra-detailed fur, commercial pet-photography realism.

---

#### `ONB-108` — Puppy + kitten under a blanket

| Field | Value |
|---|---|
| **Filename** | `onb-hero-puppy-kitten-blanket@3x.webp` |
| **Folder** | `assets/images/onboarding/heroes/` |
| **Category** | Hero artwork / photoreal |
| **Used on** | `006-onboarding` |
| **Reusable** | No |
| **Transparency** | No (blanket bleeds into background) |
| **Format** | WEBP |
| **Resolution** | 1600 × 800 @3x; generate 1536 × 1024 |

> **Prompt:** Photorealistic cosy photograph of a Golden Retriever puppy and a brown tabby kitten peeking
> out together from underneath a dark teal-green knitted blanket. Only their heads, front paws and upper
> chests are visible; the blanket drapes over their backs and forms soft folds around them. The puppy is on
> the left with a happy open mouth, the kitten on the right pressed against it. Warm intimate key light on
> their faces, cool green ambient light on the blanket. Background is very dark navy, out of focus,
> vignetted at the edges. Shallow depth of field, tack-sharp eyes, ultra-detailed fur and knit texture.
> No text, no props. Photographic realism, warm and reassuring mood.

---

#### `ONB-109` — Dog + cat in green halo arc

| Field | Value |
|---|---|
| **Filename** | `onb-hero-dog-cat-halo@3x.webp` |
| **Folder** | `assets/images/onboarding/heroes/` |
| **Category** | Hero artwork / photoreal composite |
| **Used on** | `007-onboarding` |
| **Reusable** | No |
| **Transparency** | No (glow is part of the art) |
| **Format** | WEBP |
| **Resolution** | 1600 × 900 @3x; generate 1536 × 1024 |

> **Prompt:** Photorealistic head-and-shoulders portrait of an adult Golden Retriever with its tongue out,
> pressed cheek-to-cheek with a brown tabby cat, both facing the camera. Behind them, a thin luminous
> lime-green circular arc forms a halo that passes behind their heads and glows brightly where it emerges on
> either side. Flowing translucent green light ribbons sweep across the lower background, out of focus.
> Deep black background with a soft green bloom. Cool green rim light on the outer edges of both animals,
> warm key light on their faces. Ultra-detailed fur, cinematic, no text, no UI.

---

#### `ONB-110` — Dog + kitten in circle halo with smoke

| Field | Value |
|---|---|
| **Filename** | `onb-hero-dog-kitten-celebration@3x.webp` |
| **Folder** | `assets/images/onboarding/heroes/` |
| **Category** | Hero artwork / photoreal composite |
| **Used on** | `009-onboarding` |
| **Reusable** | No |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 1600 × 1300 @3x; generate 1024 × 1024 |

> **Prompt:** Photorealistic photograph of an adult Golden Retriever wearing a dark collar with a round metal
> tag, sitting beside an upright brown tabby kitten, both facing the camera in a warm friendly pose. A thin
> luminous lime-green circle traces behind them like a halo. Billowing soft green smoke and glowing green
> mist clouds rise from the base of the frame around their bodies, backlit so the smoke glows from within.
> Fine green light particles float in the air. Deep black background. Warm key light on their faces, strong
> green rim light on their silhouettes. Celebratory and warm. Ultra-detailed fur, cinematic, no text.

---

#### `ONB-111` — Teal 3D shield with paw

| Field | Value |
|---|---|
| **Filename** | `onb-shield-paw-teal-3d@3x.png` |
| **Folder** | `assets/images/onboarding/` |
| **Category** | Icon / 3D badge |
| **Used on** | `000`, `002`, `004` (3 screens) |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 480 × 540 @3x |

> **Prompt:** A glossy translucent 3D shield badge, front-on, with a classic rounded-top / pointed-bottom
> shield silhouette. The shield body is made of frosted teal-cyan glass `#2DD4BF` with a bright luminous
> edge outline and internal light refraction. Centred inside the shield, a simple paw print with four toe
> beans and one main pad, rendered in brighter luminous cyan-white as if lit from within. Subtle inner
> glow, thin specular highlight along the upper-left edge, soft cyan bloom radiating outward. No text.
> Isolated on a fully transparent background, alpha channel, no shadow plane. Clean modern 3D icon
> rendering, glass-morphism, high render quality.

---

#### `ONB-114` — "≠" energy-collision badge

| Field | Value |
|---|---|
| **Filename** | `onb-collision-notequal@3x.png` |
| **Folder** | `assets/images/onboarding/` |
| **Category** | Decorative / composite |
| **Used on** | `004-onboarding` |
| **Reusable** | No |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 900 × 480 @3x (includes the light streams) |

> **Prompt:** An abstract energy-collision graphic. In the centre, a small dark circular badge with a thin
> light border containing a clean white "not equal to" mathematical symbol (an equals sign crossed by a
> diagonal slash). Streams of glowing light converge on the badge from both sides: from the left, red-orange
> `#EF4444` light trails with sparks; from the right, lime-green `#22C55E` light trails. Where they meet at
> the badge the two colours flare and scatter fine particles. Long, thin, sweeping motion trails, strong
> bloom. Deep black background. Isolated with a fully transparent background, alpha channel. No text other
> than the ≠ symbol itself.

---

#### `ONB-115` — Cyan notebook + paw hero glyph

| Field | Value |
|---|---|
| **Filename** | `onb-glyph-diary-paw-cyan@3x.png` |
| **Folder** | `assets/images/onboarding/` |
| **Category** | Icon / neon glyph |
| **Used on** | `005-onboarding` |
| **Reusable** | No |
| **Transparency** | Required |
| **Format** | PNG (glow needs raster) — SVG twin for the flat version |
| **Resolution** | 480 × 480 @3x |

> **Prompt:** A neon outline icon of a spiral-bound notebook seen front-on, with a visible spiral binding
> along the left edge and one folded-up corner at the bottom right. Centred on the cover, a simple paw print
> with four toe beans and one main pad. The entire icon is drawn as a single-weight glowing cyan `#22D3EE`
> outline with no fill, radiating a soft cyan bloom. Two small four-point sparkle stars float near the upper
> corners. Beneath the notebook, two thin concentric elliptical light rings suggest a glowing ground plane.
> Deep navy-black background, or isolated on a fully transparent background with alpha channel. Crisp neon
> line art, even stroke weight, no text.

---

#### `ONB-121` — Onboarding feature glyph set (4)

| Field | Value |
|---|---|
| **Filename** | `onb-glyph-{brain,diary,cross,bell}-neon@3x.png` |
| **Folder** | `assets/images/onboarding/` |
| **Category** | Icon family / neon |
| **Used on** | `000-onboarding` |
| **Reusable** | Geometry shared with `ONB-129`/`ONB-130`/`ONB-133` — **generate geometry once, recolour** |
| **Transparency** | Required |
| **Format** | SVG (geometry) + PNG (with baked glow) |
| **Resolution** | 240 × 240 @3x each |

> **Prompt (one glyph per generation, 4 total):** A single neon outline icon centred on a fully transparent
> background, drawn in one consistent medium stroke weight with rounded caps and a soft outer bloom. No fill,
> no text, no container shape.
> **(a)** a human brain seen from the front, showing the two hemispheres and gentle folds — colour bright
> green `#22C55E`.
> **(b)** an open book / diary standing upright with visible page edges — colour cyan `#22D3EE`.
> **(c)** a rounded medical cross (plus sign with equal thick rounded arms) — colour bright green `#22C55E`.
> **(d)** a classic notification bell with a small clapper below it — colour cyan `#22D3EE`.
> Match stroke weight, corner radius and optical size across all four so they read as one family.

---

#### `ONB-134` — Camera-in-glow-ring upload mark

| Field | Value |
|---|---|
| **Filename** | `onb-upload-camera-ring@3x.png` |
| **Folder** | `assets/images/onboarding/` |
| **Category** | Empty state / dropzone artwork |
| **Used on** | `photo_analysis_upload` |
| **Reusable** | No |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 480 × 480 @3x |

> **Prompt:** A glowing circular ring drawn in bright lime green `#A3E635` with a strong outer bloom, open
> and luminous, about 8 px stroke at this scale. Centred inside the ring, a clean white outline camera icon
> (rounded body, lens circle, small viewfinder bump on top). Attached at the lower-right of the ring, a
> small solid lime-green circular badge containing a white plus sign. Three four-point sparkle stars of
> varying size float just outside the ring at the upper-left and right. Isolated on a fully transparent
> background, alpha channel. Neon glow, crisp line art, no text.

---

### 6.3 PET CAST PHOTOGRAPHY — `PET`

> **⚠ Casting rule:** `PET-210` through `PET-213` are the SAME dog. Generate `PET-210` first, approve it,
> then use it as an image reference for every other Buddy asset. The same applies to Milo (`PET-214`) and
> Luna (`PET-216`). Casting drift across screens is the top visual-QA risk in this backlog.

---

#### `PET-201`–`PET-205` — Species selector portraits (5) ⭐

| Field | Value |
|---|---|
| **Filename** | `pet-species-{dog,cat,rabbit,bird,other}@3x.webp` |
| **Folder** | `assets/images/pets/species/` |
| **Category** | Card artwork / photoreal |
| **Used on** | `008-onboarding`; geometry reused by `BRE-1301` |
| **Reusable** | Yes (species pickers, add-pet flow, filters) |
| **Transparency** | No (dark backdrop is part of the card) |
| **Format** | WEBP |
| **Resolution** | 420 × 560 @3x each (3:4 portrait) |

> **Prompt (generate 5 separately, identical lighting and framing):** Photorealistic vertical portrait of a
> single animal, head and upper chest, facing the camera directly, centred in a 3:4 frame. Studio lighting:
> soft warm key from the front-left, subtle cool rim light on the shoulders. Background is a smooth very
> dark charcoal-to-black gradient with a faint warm glow behind the subject. Tack-sharp eyes, ultra-detailed
> fur or feathers, shallow depth of field. No collar, no props, no text.
> **(a) Dog** — a Golden Retriever with a happy open mouth and tongue showing, warm golden coat.
> **(b) Cat** — a brown mackerel tabby with bold stripes, upright ears, amber-green eyes, neutral expression.
> **(c) Rabbit** — a fawn/tan rabbit with tall upright ears and dark round eyes, front-on.
> **(d) Bird** — a peach-faced lovebird with a bright orange-red head and vivid green body, perched, seen
> from the side with its head turned toward the camera.
> **(e) Other** — a golden Syrian hamster sitting upright on its hind legs with both front paws raised
> toward its chest, front-on.
> Keep exposure, contrast, background gradient and framing identical across all five so they tile as one row.

---

#### `PET-210` — Buddy hero cut-out (adult Golden Retriever, sitting) ⭐

| Field | Value |
|---|---|
| **Filename** | `pet-buddy-hero-cutout@3x.webp` |
| **Folder** | `assets/images/pets/cast/` |
| **Category** | Hero artwork / photoreal |
| **Used on** | `010-home-page`, `ai_health_check_start`, `ai_assistant_home`, `ai_analysis_loading`, `symptom_selection`, `ai_analysis_result_low_risk`, `ai_analysis_result_monitor` (7 screens) |
| **Reusable** | **Yes — highest-traffic photo in the app** |
| **Transparency** | Required (green glow composited behind in Flutter) |
| **Format** | WEBP + PNG master |
| **Resolution** | 1300 × 1500 @3x; generate 1024 × 1536 |

> **Prompt:** Photorealistic studio photograph of an adult Golden Retriever sitting upright and facing the
> camera, head slightly tilted, mouth open in a relaxed happy expression with the tongue visible. It wears a
> slim dark brown leather collar with a small round brushed-metal tag hanging at the centre of its chest.
> Rich golden-red coat with long feathered fur on the chest and ears, individually resolved hairs, warm
> highlights along the top of the head and back. Framing: head, chest and front legs down to the paws.
> Key light warm from the front-left at 45°, subtle cool rim light separating the silhouette. Tack-sharp
> eyes with visible catchlights. Isolated on a fully transparent background, alpha channel, no floor, no
> cast shadow, no background elements. 85 mm portrait lens look, commercial pet-photography quality,
> ultra-detailed fur.

---

#### `PET-211` — Buddy circular avatar

| Field | Value |
|---|---|
| **Filename** | `pet-buddy-avatar@3x.webp` |
| **Folder** | `assets/images/pets/cast/` |
| **Category** | Avatar / photoreal |
| **Used on** | 18 screens (every pet chip, selector, list row, timeline) |
| **Reusable** | **Yes — global** |
| **Transparency** | No (circular mask applied in Flutter) |
| **Format** | WEBP |
| **Resolution** | 480 × 480 @3x (square master, cropped to circle in-app) |

> **Prompt:** Photorealistic square close-up portrait of an adult Golden Retriever's head and upper chest,
> facing the camera, mouth open in a friendly expression with the tongue showing. Identical dog to the
> PawDoc hero casting: rich golden-red coat, long feathered ears, warm brown eyes. Framed so the head is
> centred and fills roughly 75 % of the square with even margins — must crop cleanly to a circle without
> clipping the ears. Softly blurred warm outdoor green background, shallow depth of field. Warm natural
> daylight, tack-sharp eyes. No collar tag in frame, no text, no props.

---

#### `PET-212` — Buddy park portrait (analysis result photo)

| Field | Value |
|---|---|
| **Filename** | `pet-buddy-park-portrait@3x.webp` |
| **Folder** | `assets/images/pets/cast/` |
| **Category** | Content photo / photoreal |
| **Used on** | `ai_analysis_result_low_risk`, `ai_analysis_result_monitor` |
| **Reusable** | Yes (sample content) |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 1040 × 960 @3x |

> **Prompt:** Photorealistic photograph of an adult Golden Retriever sitting outdoors in a park, facing the
> camera with an open happy mouth and tongue out, wearing a dark collar with a small round metal tag.
> Identical dog to the PawDoc hero casting. Background is a heavily blurred green park with warm golden-hour
> light filtering through trees, creamy bokeh. The dog fills the centre of the frame from the chest up.
> Warm late-afternoon side light, tack-sharp eyes, ultra-detailed fur. Natural photography, no filters,
> no text, no UI overlay.

---

#### `PET-213` — Buddy on grass, golden hour

| Field | Value |
|---|---|
| **Filename** | `pet-buddy-grass-golden-hour@3x.webp` |
| **Folder** | `assets/images/pets/cast/` |
| **Category** | Content photo / photoreal |
| **Used on** | `008-onboarding` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 940 × 990 @3x |

> **Prompt:** Photorealistic photograph of an adult Golden Retriever sitting on green grass at golden hour,
> facing the camera, mouth open and tongue out, wearing a dark collar with a small bone-shaped metal tag.
> Identical dog to the PawDoc hero casting. Warm low sun behind and to the left creating a golden rim light
> along the ears and back; softly blurred meadow and warm bokeh highlights in the background. The dog fills
> the frame from mid-chest up. Tack-sharp eyes, ultra-detailed fur, natural warm colour grade. No text.

---

#### `PET-214` — Milo, dark tabby cat avatar

| Field | Value |
|---|---|
| **Filename** | `pet-milo-tabby-avatar@3x.webp` |
| **Folder** | `assets/images/pets/cast/` |
| **Category** | Avatar / photoreal |
| **Used on** | `010-home-page`, `pet_statistics`, `add_memory`, `memories_gallery`, `006-onboarding` (in-phone) |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 480 × 480 @3x |

> **Prompt:** Photorealistic square close-up portrait of an adult brown mackerel tabby cat's head and upper
> chest, facing the camera directly with a calm neutral expression. Bold dark striping over a warm brown
> undercoat, distinct "M" marking on the forehead, upright ears, large amber-green eyes with round pupils,
> long white whiskers. Head centred, filling roughly 75 % of the square with even margins for circular
> cropping. Dark neutral background with a subtle warm glow, shallow depth of field. Soft studio key light,
> tack-sharp eyes, ultra-detailed fur. No collar, no props, no text.

---

#### `PET-215` — Milo, white British Shorthair *(casting conflict — see §9.4)*

| Field | Value |
|---|---|
| **Filename** | `pet-milo-shorthair-avatar@3x.webp` |
| **Folder** | `assets/images/pets/cast/` |
| **Category** | Avatar / photoreal |
| **Used on** | `manage_multiple_pets`, `pet_statistics` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 480 × 480 @3x |

> **Prompt:** Photorealistic square close-up portrait of a white British Shorthair cat, facing the camera,
> with a round face, dense plush white coat, small rounded ears and large copper-orange eyes. Calm, regal
> expression. Head centred, filling roughly 75 % of the square with even margins for circular cropping.
> Dark charcoal background with a soft rim light separating the white fur from the backdrop. Soft studio
> key light, tack-sharp eyes, ultra-detailed plush fur texture. No collar, no props, no text.

---

#### `PET-216` — Luna, fawn rabbit avatar

| Field | Value |
|---|---|
| **Filename** | `pet-luna-rabbit-avatar@3x.webp` |
| **Folder** | `assets/images/pets/cast/` |
| **Category** | Avatar / photoreal |
| **Used on** | `010-home-page`, `manage_multiple_pets`, `pet_statistics`, `add_memory` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 480 × 480 @3x |

> **Prompt:** Photorealistic square close-up portrait of a fawn-coloured rabbit facing the camera, with tall
> upright ears, a soft rounded muzzle, dark round eyes and fine whiskers. Warm sandy-tan fur with a paler
> cream chest and muzzle, ultra-detailed individual hairs. Head and ears centred, sized so both ear tips
> remain inside the frame with even margins for circular cropping. Dark neutral background with a subtle
> warm glow, shallow depth of field, soft studio key light. Gentle, calm expression. No props, no text.

---

#### `PET-217` — Luna, Golden Retriever portrait *(second GR casting — see §9.4)*

| Field | Value |
|---|---|
| **Filename** | `pet-luna-retriever-portrait@3x.webp` |
| **Folder** | `assets/images/pets/cast/` |
| **Category** | Avatar / photoreal |
| **Used on** | `emergency_hub`, `prepare_for_vet_visit`, `pdf_health_report_preview`, `notifications` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 640 × 640 @3x |

> **Prompt:** Photorealistic square portrait of an adult female Golden Retriever with a lighter cream-gold
> coat (visibly paler than the PawDoc hero dog so the two read as different pets), facing the camera outdoors
> with a relaxed open mouth and tongue out. Softly blurred green outdoor background with warm daylight,
> shallow depth of field. Head centred and filling about 70 % of the square with even margins for circular
> cropping. Tack-sharp eyes, ultra-detailed fur, natural colour grade. No collar tag, no text, no props.

---

#### `PET-218` — Coco, fawn Holland Lop rabbit

| Field | Value |
|---|---|
| **Filename** | `pet-coco-lop-avatar@3x.webp` |
| **Folder** | `assets/images/pets/cast/` |
| **Category** | Avatar / photoreal |
| **Used on** | `manage_multiple_pets`, `pet_statistics` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 480 × 480 @3x |

> **Prompt:** Photorealistic square close-up portrait of a fawn Holland Lop rabbit facing the camera, with
> long soft ears hanging down either side of its face, a broad rounded head, dark round eyes and a small
> pink nose. Warm sandy-fawn fur with a cream muzzle, ultra-detailed plush texture. Head centred, filling
> about 75 % of the square with even margins for circular cropping. Dark neutral background with soft warm
> glow, gentle studio key light, shallow depth of field. Calm expression. No props, no text.

---

#### `PET-219` — Buddy-in-shield composite (weather advisor)

| Field | Value |
|---|---|
| **Filename** | `pet-buddy-shield-composite@3x.png` |
| **Folder** | `assets/images/pets/cast/` |
| **Category** | Composite badge / photoreal + vector |
| **Used on** | `weather_walk_advisor` (shield variant), `smart_walks` (radar-ring variant) |
| **Reusable** | Yes (2 variants) |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 360 × 400 @3x |

> **Prompt:** A composite badge: a circular photographic portrait of an adult Golden Retriever's face
> (identical casting to the PawDoc hero dog, happy expression) enclosed inside a thin glowing lime-green
> `#A3E635` shield outline that traces around the circle with a pointed base. A small solid lime heart sits
> at the lower-right where the shield edge meets the circle. Soft lime bloom around the shield stroke.
> Isolated on a fully transparent background, alpha channel, no shadow. Clean, crisp, no text.
> *Variant B:* replace the shield outline with two concentric thin lime radar rings and four short tick
> marks at the cardinal points.

---

### 6.4 AI-SYSTEM ARTWORK — `AI`

---

#### `AI-301` — Neon robot mascot ⭐

| Field | Value |
|---|---|
| **Filename** | `ai-robot-mascot-neon@3x.png` |
| **Folder** | `assets/images/ai/` |
| **Category** | Mascot / AI artwork |
| **Used on** | `006-onboarding` (hero); recommended for AI empty states |
| **Reusable** | **Yes — this is the AI brand character** |
| **Transparency** | Required |
| **Format** | PNG (glow) + SVG twin without glow |
| **Resolution** | 1100 × 620 @3x (includes both speech bubbles) |

> **Prompt:** A neon outline mascot illustration drawn entirely in glowing cyan `#22D3EE` line art with a
> soft bloom, on a fully transparent background. Centre: a friendly robot with a rounded-square head, two
> small round dot eyes and a gentle upward-curving smile, a short antenna with a small ball on top rising
> from the crown, and a rounded rectangular body below with a simple paw print centred on its chest. The
> robot is enclosed inside a thin perfect circle. Beneath the circle, three concentric thin elliptical light
> rings suggest a glowing platform. Flanking the circle: on the left a rounded speech bubble containing
> three dots, on the right a rounded speech bubble containing a heart. Consistent single stroke weight
> throughout with rounded caps, no fill, no text, no shadow. Clean neon line art, even glow.
>
> *In-app variant:* recolour the stroke to lime `#A3E635` for System B surfaces →
> `ai-robot-mascot-lime@3x.png`.

---

#### `AI-302` — AI assistant avatar (paw in speech bubble) ⭐

| Field | Value |
|---|---|
| **Filename** | `ai-assistant-avatar@3x.png` |
| **Folder** | `assets/images/ai/` |
| **Category** | Avatar / brand mark |
| **Used on** | `ai_assistant_chat`, `ai_message_actions`, `conversation_history`, `ai_assistant_home` |
| **Reusable** | **Yes — every AI message bubble** |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | Vector; raster 168 × 168 @3x |

> **Prompt:** A circular avatar badge. The circle is filled with a very dark charcoal `#12180F` and has a
> thin lime-green `#A3E635` border with a soft outer glow. Centred inside, a rounded speech-bubble shape
> with a small tail at the lower left, drawn as a lime-green outline; inside the speech bubble sits a small
> solid lime paw print with four toe beans and one main pad. Balanced optical weight, generous inner
> padding, no text. Isolated on a fully transparent background, alpha channel. Crisp, flat, icon-grade
> rendering with a subtle neon glow.

---

#### `AI-303` — AI scan HUD overlay (dog head)

| Field | Value |
|---|---|
| **Filename** | `ai-scan-hud-dog@3x.webp` |
| **Folder** | `assets/images/ai/` |
| **Category** | AI artwork / HUD composite |
| **Used on** | `003-onboarding` (inside the phone mockup) |
| **Reusable** | Overlay layer reusable over any pet photo |
| **Transparency** | Two files: photo (opaque) + HUD overlay (transparent) |
| **Format** | WEBP (photo) + PNG (overlay) |
| **Resolution** | 1030 × 1000 @3x |

> **Prompt (deliver as TWO layers):**
> **Layer 1 — photo:** Photorealistic three-quarter profile of an adult Golden Retriever's head facing left,
> mouth open with the tongue out, warm golden coat, dark background, cinematic side light. Identical casting
> to the PawDoc hero dog.
> **Layer 2 — photo-review overlay, on a fully transparent background** *(rewritten 2026-07-30, finding
> V-14 — the previous landmark-mesh version depicted biometric measurement precision the product does not
> have):* A soft green photo-review overlay made of thin bright lime-green `#4ADE50` lines: four L-shaped
> corner brackets framing a square area, indicating a photo being viewed rather than a subject being
> measured; a very faint square grid at low opacity across the area; and one gentle horizontal light sweep
> across the middle with a soft glow falloff above and below it. No landmark nodes, no connecting mesh, no
> facial tracking points, no biometric markers and nothing anchored to the animal's anatomy. Fine drifting
> light particles. Soft neon bloom, no text, no numbers, no UI panels.

---

#### `AI-304` — Circular AI-scan loading composite ⭐

| Field | Value |
|---|---|
| **Filename** | `ai-loading-scan-ring@3x.png` |
| **Folder** | `assets/images/ai/` |
| **Category** | Loading artwork / composite |
| **Used on** | `ai_analysis_loading` |
| **Reusable** | Yes (any analysis-in-progress state) |
| **Transparency** | Required |
| **Format** | PNG (deliver the ring as a separate layer so Flutter can animate the arc) |
| **Resolution** | 1080 × 1140 @3x |

> **Prompt (deliver as TWO layers):**
> **Layer 1 — masked portrait:** A photorealistic Golden Retriever head in three-quarter profile facing
> left, mouth open, identical casting to the PawDoc hero dog, masked inside a perfect circle. Over the
> portrait, a faint square wireframe grid and a subtle radar crosshair, both in translucent lime green at
> low opacity. Deep green particle bloom behind the circle.
> **Layer 2 — progress ring, transparent background:** A thick circular arc in bright lime green `#A3E635`
> tracing roughly 72 % of a circle with rounded ends, each end carrying a bright glowing cap. A second,
> thinner, dimmer full circle sits just inside it as the track. Strong neon bloom, no text, no percentage
> numerals — the number is rendered by Flutter.

---

#### `AI-305` — Holographic wireframe dog + cat ⭐

| Field | Value |
|---|---|
| **Filename** | `ai-hologram-dog-cat@3x.png` |
| **Folder** | `assets/images/ai/` |
| **Category** | AI artwork / hero |
| **Used on** | `ai_transparency` |
| **Reusable** | Recommended for AI-explainer surfaces |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 1000 × 1000 @3x |

> **Prompt:** A holographic projection illustration. A dog sitting upright with a cat sitting beside and
> slightly in front of it, both rendered as translucent green wireframe holograms built from thin glowing
> contour lines and fine point-cloud dots — the forms readable but see-through, with brighter edges where
> the surface turns away. Colour ranges from deep emerald in the shadows to bright mint-green `#4ADE80` at
> the highlights. Beneath them, a glowing circular holographic platform made of three concentric rings with
> an intense light source at its centre casting an upward glow onto the animals. Fine green light particles
> drift upward around the figures. Two small floating translucent UI glyph cards hover nearby — one showing
> a simple line chart, one showing a heart with an ECG pulse — both drawn as thin green outlines in rounded
> square frames. Deep black background. Isolated with a fully transparent background, alpha channel.
> Sci-fi hologram aesthetic, strong bloom, no text, no numbers.

---

#### `AI-306` → `EMG-609` — First-aid guide hero banner ♻️ *(rewritten 2026-07-30)*

| Field | Value |
|---|---|
| **Filename** | `emg-firstaid-banner@3x.webp` *(was `ai-triage-banner-cross-hud@3x.webp`)* |
| **Folder** | `assets/images/emergency/` *(was `assets/images/ai/`)* |
| **Category** | Banner artwork / hero |
| **Used on** | `first_aid_guide` |
| **Reusable** | Within the first-aid surface only |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 1600 × 660 @3x; generate 1536 × 1024 and crop |
| **♻️ Status** | **HOLD RELEASED.** Conflict C-5 is resolved by finding **V-17** in `UI_SAFETY_CONTRACT_REVIEW.md`: the banner is no longer an "AI Triager" entry point but an offline "Browse by symptom" entry point. The HUD / radar / scan-line treatment existed only to signal AI analysis and has been removed — a scanning reticle on a first-aid screen also implies the app is examining the animal. Asset reclassified `AI` → `EMG`. |

> **Prompt:** A wide dark banner artwork. On the right third, a photorealistic Golden Retriever head in
> three-quarter view resting calmly and looking toward the camera, warm golden fur, soft cinematic side
> light, emerging from darkness with a reassuring rather than clinical mood. On the left-of-centre, a bright
> glowing green medical cross with equal rounded arms, surrounded by two soft concentric halo rings of light
> with smooth, even edges and no tick marks, no crosshairs, no scan lines and no targeting geometry. A
> gentle green glow falls off evenly into the dark left half. Deep black background fading to dark green
> near the cross. Warm natural light on the dog, calm neon bloom on the cross. Nothing in the image should
> suggest scanning, measuring or analysing the animal. No text, no UI chrome, no lettering.

---

#### `AI-307` — Orbital ring with light nodes

| Field | Value |
|---|---|
| **Filename** | `ai-orbital-ring-nodes@3x.png` |
| **Folder** | `assets/images/ai/` |
| **Category** | Decorative / composite layer |
| **Used on** | `ai_assistant_home`; pairs with `BGD-1606` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 900 × 900 @3x |

> **Prompt:** A single thin luminous circular orbit ring drawn in bright lime green `#A3E635` on a fully
> transparent background, with a soft outer bloom. Studded around the circumference at irregular intervals
> are about eight small bright light nodes of varying size, each with a soft halo, and a few four-point
> sparkle stars just outside the ring. The ring stroke varies subtly in brightness so it appears to catch
> light. No fill, no text, no shadow. Clean neon line art, alpha channel.

---

### 6.5 LINE-ART DOODLES — `ILL`

> One family, one hand. All `ILL-*` assets share: **single-weight monoline stroke (~3 px at @3x), rounded
> caps and joins, lime `#A3E635`, soft glow, sketchy but confident, no fill, no shading, transparent
> background.** Generate them in one batch with a shared seed so the "hand" stays consistent.

---

#### `ILL-401` — Doodle puppy with heart speech bubble ⭐

| Field | Value |
|---|---|
| **Filename** | `ill-doodle-puppy-heart-bubble@3x.png` |
| **Folder** | `assets/illustrations/doodles/` |
| **Category** | Illustration / decorative |
| **Used on** | `ai_analysis_loading`, `ai_analysis_result_monitor`, `create_post` (variant) |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | **SVG** preferred + PNG with glow |
| **Resolution** | Vector; raster 600 × 480 @3x |

> **Prompt:** A charming hand-drawn monoline doodle of a small sitting puppy, drawn in a single continuous
> lime-green `#A3E635` stroke with rounded caps and a soft neon glow, on a fully transparent background.
> The puppy faces the viewer with two long floppy ears, two small round dot eyes, a tiny oval nose and a
> simple curved smile; its front legs are two short vertical strokes and its body is one rounded outline.
> To the upper right, a rounded speech bubble with a small tail contains a simple outlined heart. Two
> four-point sparkle stars of different sizes float nearby. Loose, friendly, slightly imperfect sketch
> quality — like a confident marker drawing. No fill, no shading, no text.

---

#### `ILL-402` — Doodle dog sitting with heart

| Field | Value |
|---|---|
| **Filename** | `ill-doodle-dog-sitting-heart@3x.png` |
| **Folder** | `assets/illustrations/doodles/` |
| **Category** | Illustration / decorative |
| **Used on** | `pet_profile`, `weight_tracking`, `reminder_detail` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | Vector; raster 540 × 480 @3x |

> **Prompt:** A hand-drawn monoline doodle of a dog seen from the side, standing with all four legs visible,
> head turned slightly toward the viewer, one ear flopped forward, a curled tail raised behind it. Drawn in
> a single lime-green `#A3E635` stroke with rounded caps and a soft glow, on a fully transparent background.
> A small outlined heart floats just above its back. Loose confident sketch quality, even stroke weight, no
> fill, no shading, no text, no ground line.

---

#### `ILL-404` — Doodle running dog with paw trail

| Field | Value |
|---|---|
| **Filename** | `ill-doodle-running-dog-trail@3x.png` |
| **Folder** | `assets/illustrations/doodles/` |
| **Category** | Illustration / decorative |
| **Used on** | `smart_walks` |
| **Reusable** | Yes (activity surfaces) |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | Vector; raster 660 × 420 @3x |

> **Prompt:** A hand-drawn monoline doodle of a dog running in profile toward the right, legs extended in
> mid-stride, ears blown back, tail streaming behind. Behind and below it, a curving dashed line carries
> three small paw prints of decreasing size, suggesting a trail. Two short speed lines trail from the dog's
> hindquarters. Drawn entirely in a single lime-green `#A3E635` stroke with rounded caps and a soft glow, on
> a fully transparent background. Energetic, loose sketch quality, no fill, no shading, no text.

---

#### `ILL-405` — Doodle puppy with protection shield

| Field | Value |
|---|---|
| **Filename** | `ill-doodle-puppy-shield@3x.png` |
| **Folder** | `assets/illustrations/doodles/` |
| **Category** | Illustration / educational |
| **Used on** | `vaccination_manager` |
| **Reusable** | Yes (protection / immunity surfaces) |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | Vector; raster 660 × 480 @3x |

> **Prompt:** A hand-drawn monoline doodle of a small puppy sitting on the left, facing right with floppy
> ears and a friendly smile. Beside it on the right stands a shield outline slightly taller than the puppy,
> with a medical cross centred inside it. Two small outlined hearts and two four-point sparkle stars float
> in the space above them. Drawn in a single lime-green `#A3E635` stroke with rounded caps and a soft glow,
> on a fully transparent background. Loose, warm, confident sketch quality, no fill, no shading, no text.

---

#### `ILL-407` — Doodle vet with cat and dog

| Field | Value |
|---|---|
| **Filename** | `ill-doodle-vet-cat-dog@3x.png` |
| **Folder** | `assets/illustrations/doodles/` |
| **Category** | Illustration / educational |
| **Used on** | `first_aid_guide` |
| **Reusable** | Yes (professional-care surfaces) |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | Vector; raster 720 × 480 @3x |

> **Prompt:** A hand-drawn monoline doodle showing a veterinarian standing in the centre, seen from the
> chest up, with short hair, a simple friendly face and a stethoscope hanging around their neck. A cat sits
> to their left and a dog sits to their right, both facing the viewer, each about half the height of the
> person. Three small medical crosses float in the background at different sizes. Drawn entirely in a single
> lime-green `#A3E635` stroke with rounded caps and a soft glow, on a fully transparent background. Warm,
> approachable, loose sketch quality, no fill, no shading, no facial detail beyond dots and simple curves,
> no text.

---

#### `ILL-409` — Doodle pair: dog on scale + clipboard

| Field | Value |
|---|---|
| **Filename** | `ill-doodle-dog-scale@3x.png`, `ill-doodle-clipboard@3x.png` |
| **Folder** | `assets/illustrations/doodles/` |
| **Category** | Illustration / educational |
| **Used on** | `weight_tracking` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | Vector; raster 420 × 400 @3x each |

> **Prompt (two separate drawings, matching hand):** Hand-drawn monoline doodles in a single grey-green
> stroke with rounded caps on a fully transparent background, loose confident sketch quality, no fill, no
> shading, no text.
> **(a)** A dog standing in profile on a flat rectangular bathroom scale, with a small round dial visible on
> the scale's face and the dog's tail raised.
> **(b)** A clipboard seen front-on with a clip at the top and four horizontal ruled lines on the page, the
> top two lines preceded by small check marks.

---

#### `ILL-411` — Doodle dog face with heart and sparkles

| Field | Value |
|---|---|
| **Filename** | `ill-doodle-dogface-heart@3x.png` |
| **Folder** | `assets/illustrations/doodles/` |
| **Category** | Illustration / decorative |
| **Used on** | `memory_detail` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | Vector; raster 480 × 400 @3x |

> **Prompt:** A hand-drawn monoline doodle of a dog's face seen front-on — a rounded head outline, two
> floppy ears hanging at the sides, two round dot eyes, a small oval nose and a simple smiling muzzle. A
> single outlined heart floats just above the head, flanked by three four-point sparkle stars of varying
> size. Drawn in a single lime-green `#A3E635` stroke with rounded caps and a soft glow, on a fully
> transparent background. Warm, loose sketch quality, no fill, no shading, no text.

---

#### `ILL-412` — Dashed paw-print trail

| Field | Value |
|---|---|
| **Filename** | `ill-pawtrail-dashed@3x.png` |
| **Folder** | `assets/illustrations/doodles/` |
| **Category** | Decorative motif |
| **Used on** | `ai_analysis_loading`, `smart_walks`, `009-onboarding` |
| **Reusable** | **Yes — recurring motif** |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | Vector; raster 300 × 660 @3x |

> **Prompt:** A gently curving vertical dashed line drawn in lime green `#A3E635` with a soft glow, on a
> fully transparent background. Positioned along the curve at three points are three small paw prints, each
> rotated to follow the direction of the curve and each slightly smaller than the one below it. Each paw
> print has four toe beans and one main pad, drawn as solid shapes. Clean, light, decorative. No fill on the
> line, no text, no shadow.

---

### 6.6 INFOGRAPHICS & EDUCATIONAL — `INF`

---

#### `INF-501` — Breed size-reference infographic ⭐

| Field | Value |
|---|---|
| **Filename** | `inf-size-reference-human-dog.svg` |
| **Folder** | `assets/illustrations/infographics/` |
| **Category** | Infographic / educational |
| **Used on** | `breed_detail` |
| **Reusable** | **Yes — template for every breed** (silhouette swaps per breed) |
| **Transparency** | Required |
| **Format** | **SVG** (must scale + relabel per breed) |
| **Resolution** | Vector; layout 1080 × 620 @3x |

> **Prompt:** A clean comparison infographic on a fully transparent background. On the left, a flat
> medium-grey `#4B5563` silhouette of a standing adult human seen from the side, arms at their sides. On the
> right, a flat medium-grey silhouette of a Golden Retriever standing in profile facing left, at correct
> relative scale — roughly one-third the human's height at the shoulder. Both silhouettes are solid fills
> with no internal detail, no facial features. A thin vertical dimension line with small end caps runs
> alongside the human, and a matching vertical dimension line runs alongside the dog's shoulder height.
> A thin horizontal ground line connects both figures at their feet. Minimal, technical, editorial-diagram
> style. **No text or numerals — all labels are rendered by the app.**

---

#### `INF-502` — Photo-quality example set (3)

| Field | Value |
|---|---|
| **Filename** | `inf-photoquality-{good,dark,blurry}@3x.webp` |
| **Folder** | `assets/images/education/` |
| **Category** | Educational graphic / photoreal |
| **Used on** | `ai_health_check_start` |
| **Reusable** | Yes (camera guidance anywhere) |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 240 × 240 @3x each |

> **Prompt (3 separate images of the SAME dog and framing):** Photorealistic close-up of an adult Golden
> Retriever's head and shoulder, three-quarter view, filling the square frame. Same dog, same pose, same
> composition in all three; only the capture quality changes.
> **(a) good** — bright even natural daylight, tack-sharp focus, correct exposure, clearly visible fur
> detail and skin.
> **(b) dark** — badly underexposed, heavy shadow across the subject, muddy detail, most of the frame
> falling to near-black.
> **(c) blurry** — severe motion blur and out-of-focus softness, the dog barely distinguishable, very low
> contrast and dim.
> No text, no overlays, no badges — the check/cross markers are drawn by the app.

---

#### `INF-503` — Anatomy macro photo set (4)

| Field | Value |
|---|---|
| **Filename** | `inf-anatomy-{ear,nose,eye,mouth}@3x.webp` |
| **Folder** | `assets/images/education/` |
| **Category** | Educational / medical photography |
| **Used on** | `photo_analysis_upload` |
| **Reusable** | Yes (capture guidance, symptom help) |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 260 × 300 @3x each |

> **Prompt (4 separate macro photographs, same dog, same lighting):** Photorealistic clinical macro
> photograph of a healthy adult Golden Retriever, shot with soft even diffuse lighting, shallow depth of
> field, natural colour, no filters, no text, no medical instruments in frame.
> **(a) ear** — close-up of the inner ear flap lifted to show the clean pink ear canal opening and
> surrounding fur.
> **(b) nose** — tight close-up of the black moist nose and surrounding muzzle fur, showing nostril texture.
> **(c) eye** — extreme close-up of one warm brown eye showing the iris detail, eyelid margin, lashes and a
> clean white sclera edge.
> **(d) mouth** — close-up of the open mouth showing healthy pink gums, white teeth and the tongue.
> Neutral, non-alarming, veterinary-reference quality. All four must look like the same animal.

---

#### `INF-504` — Clinical paw-redness thumbnail

| Field | Value |
|---|---|
| **Filename** | `inf-clinical-paw-redness@3x.webp` |
| **Folder** | `assets/images/education/` |
| **Category** | Medical illustration / photoreal |
| **Used on** | `health_timeline`, `add_health_record` |
| **Reusable** | Yes (sample record content) |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 300 × 300 @3x |

> **Prompt:** Photorealistic clinical close-up of a dog's front paw held gently upright, showing the pad and
> the fur between the toes. The skin between two toe pads shows mild pink-red irritation with slight
> inflammation — visible but minor, not a wound, no blood, no discharge. Soft even diffuse lighting, natural
> colour, shallow depth of field, neutral blurred background. Veterinary-reference photography quality,
> calm and non-alarming, no text, no instruments.

---

### 6.7 EMERGENCY ARTWORK — `EMG`

---

#### `EMG-601` — Red emergency beacon

| Field | Value |
|---|---|
| **Filename** | `emg-beacon-siren@3x.png` |
| **Folder** | `assets/images/emergency/` |
| **Category** | Emergency graphic / icon |
| **Used on** | `004-onboarding`, `ai_analysis_result_emergency`, `ai_assistant_home` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG (glow) + SVG twin |
| **Resolution** | 240 × 260 @3x |

> **Prompt:** A glowing emergency beacon light icon, front-on. A dome-shaped red lamp `#EF4444` sits on a
> short rectangular base, drawn as a bold outline with a translucent red glowing fill inside the dome and a
> bright hot highlight at its centre. Five short straight rays radiate outward from the top and upper sides
> of the dome, indicating flashing. Strong red bloom around the whole object. Isolated on a fully
> transparent background, alpha channel, no shadow, no text. Clean icon rendering, urgent but not gory.

---

#### `EMG-602` — Red phone with medical cross + glow rings ⭐

| Field | Value |
|---|---|
| **Filename** | `emg-call-phone-rings@3x.png` |
| **Folder** | `assets/images/emergency/` |
| **Category** | Emergency graphic |
| **Used on** | `emergency_hub`, `first_aid_guide` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 420 × 420 @3x |

> **Prompt:** A circular emergency-call graphic. At the centre, a solid white telephone handset icon tilted
> slightly, with a small medical cross attached at its upper right. Around the handset, three concentric
> thin circular rings in bright red `#EF4444`, each progressively fainter outward, glowing strongly as if
> pulsing outward. The innermost area behind the handset carries a soft dark-red radial glow. Isolated on a
> fully transparent background, alpha channel, no shadow, no text. Strong red neon bloom, urgent, clean icon
> rendering.

---

#### `EMG-603` — Red shield with exclamation

| Field | Value |
|---|---|
| **Filename** | `emg-shield-alert@3x.png` |
| **Folder** | `assets/images/emergency/` |
| **Category** | Emergency graphic / badge |
| **Used on** | `ai_analysis_result_emergency`, `emergency_hub` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG + SVG |
| **Resolution** | 220 × 250 @3x |

> **Prompt:** A shield badge with a classic rounded-top, pointed-bottom silhouette, drawn as a bold red
> `#EF4444` outline with a translucent dark-red interior and a strong red outer glow. Centred inside the
> shield, a bold exclamation mark — a thick vertical bar above a round dot — in the same bright red. Clean,
> symmetrical, urgent. Isolated on a fully transparent background, alpha channel, no shadow, no text beyond
> the exclamation mark itself.

---

#### `EMG-604` — Emergency clinic exterior photos (3) ⚠️

| Field | Value |
|---|---|
| **Filename** | `emg-clinic-exterior-{01,02,03}@3x.webp` |
| **Folder** | `assets/images/emergency/` |
| **Category** | Photography / content |
| **Used on** | `emergency_hub` |
| **Reusable** | Yes (clinic finder) |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 420 × 300 @3x each |
| **♻️ Status** | **HOLD RELEASED 2026-07-30.** Review finding V-16 keeps the clinic list on the emergency surface — clinic photos are help-contact content, which the contract explicitly permits. Only the Heat Alert strip and the AI Triage tile are proposed for removal, and neither uses this asset. |

> **Prompt (3 separate images, same night mood):** Photorealistic exterior photograph of a modern veterinary
> emergency hospital at night, shot from across the street at a slight angle. Warm interior light glows
> through large plate-glass windows; the building facade is dark stone and glass. An illuminated sign above
> the entrance glows brightly. Wet asphalt in the foreground reflects the light. Blue hour sky, cinematic,
> shallow depth of field, no people, no vehicles, no readable text on any signage or window.
> **(a)** the sign panel glows cool blue.
> **(b)** the sign panel glows red and white.
> **(c)** the sign panel glows in a red-and-blue split.
> *Note:* the mockups show "24/7", "ANIMAL ER" and "VET ER" signage. Generate the signs as **blank glowing
> panels** and render the label text in Flutter — GPT Image cannot be trusted with legible signage, and
> localisation requires it to be text anyway.

---

#### `EMG-605` — Emergency kit still life ⭐

| Field | Value |
|---|---|
| **Filename** | `emg-kit-stilllife@3x.png` |
| **Folder** | `assets/images/emergency/` |
| **Category** | Card artwork / product still life |
| **Used on** | `emergency_hub` |
| **Reusable** | Yes (preparedness content) |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 600 × 440 @3x |

> **Prompt:** A photorealistic product still life arranged as a small group. A grey plastic pet carrier with
> a wire mesh front door stands at the centre-left, seen at a three-quarter angle. In front of and to the
> right of it, a red hard-shell first-aid case with a white cross on its lid sits closed. Beside them, two
> small white medicine bottles with amber labels and a coiled red nylon leash rest on the surface. Even soft
> studio lighting from above-left, subtle contact shadows only, muted realistic colours against a dark
> background. Isolated on a fully transparent background, alpha channel, no floor plane, no text or
> readable labels on any item. Commercial product-photography quality.

---

#### `EMG-606` — Red clinic map pin

| Field | Value |
|---|---|
| **Filename** | `emg-mappin-clinic@3x.png` |
| **Folder** | `assets/images/emergency/` |
| **Category** | Map marker / icon |
| **Used on** | `emergency_hub` |
| **Reusable** | Yes (all clinic maps) |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | Vector; raster 108 × 132 @3x |

> **Prompt:** A map marker pin with a classic teardrop silhouette — a circle at the top narrowing to a point
> at the bottom. The pin body is solid white with a bold red `#EF4444` outline and a soft red glow. Centred
> inside the circular head, a small red first-aid case icon with a white cross on it. Clean, crisp,
> symmetrical, optimised for small display sizes. Isolated on a fully transparent background, alpha channel,
> no shadow, no text.

---

#### `EMG-607` — Dog with facial skin lesion ⚠️

| Field | Value |
|---|---|
| **Filename** | `emg-dog-lesion-clinical@3x.webp` |
| **Folder** | `assets/images/emergency/` |
| **Category** | Medical photography / hero |
| **Used on** | `ai_analysis_result_emergency` |
| **Reusable** | No |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 1150 × 870 @3x |
| **♻️ Status** | **HOLD RELEASED (rewritten 2026-07-30).** Conflict C-3 is resolved by findings **V-05 / V-06** in `UI_SAFETY_CONTRACT_REVIEW.md`: the tile caption changes from "Potential Concern — Skin Infection" to "What to show your vet — An open sore above the right eye". The artwork was written to depict an *infected* lesion; it must now depict an *observable injury* with no diagnostic characterisation. |

> **Prompt:** Photorealistic photograph of an adult Golden Retriever lying down on a soft surface with its
> head resting on its front paws, eyes open but subdued, expression tired and low-energy. Above the right
> eyebrow there is a clearly visible sore patch roughly two centimetres across: reddened, slightly swollen
> skin with thinned fur around the edges and a shallow open graze at the centre. It must read as a visible
> injury an owner would photograph to show a vet — obvious and worth attention, but not clinically
> characterised: no crusting, no discharge, no pus, no weeping, no blood, no gore, nothing that suggests a
> specific diagnosis. Warm desaturated colour grade, soft directional window light from the front-left, very
> shallow depth of field with a blurred neutral background. Sombre but not distressing. Natural photography,
> no text, no medical instruments, no human hands in frame.

---

#### `EMG-608` — Red/green comparison light streams

| Field | Value |
|---|---|
| **Filename** | `emg-compare-streams@3x.png` |
| **Folder** | `assets/images/emergency/` |
| **Category** | Decorative / composite |
| **Used on** | `004-onboarding` |
| **Reusable** | No |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 900 × 560 @3x |

> **Prompt:** Two opposing streams of glowing light meeting in the centre of a wide frame. From the left,
> sweeping curved red-orange `#EF4444` light trails with fine sparks; from the right, sweeping curved
> lime-green `#22C55E` light trails. The two sets of trails arc toward each other and flare where they meet
> in the middle, scattering small particles. Long, thin, elegant motion trails with strong bloom against a
> fully transparent background, alpha channel. Abstract, energetic, no objects, no text.

---

### 6.8 PREMIUM ARTWORK — `PRM`

> One family, one render. All `PRM-70x` share: **translucent green glass / soft jelly material, emissive
> inner glow, bright lime rim light `#A3E635`, three-quarter front view, floating with no ground contact,
> subtle green particle sparkles, deep black background, soft ambient occlusion, no hard shadows.**
> Generate as one batch with a shared seed so material and lighting match across all six.

---

#### `PRM-701` — 3D AI Health Insights robot ⭐

| Field | Value |
|---|---|
| **Filename** | `prm-3d-ai-insights@3x.png` |
| **Folder** | `assets/images/premium/` |
| **Category** | Premium artwork / 3D illustration |
| **Used on** | `premium_home` |
| **Reusable** | Yes (AI upsell surfaces) |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 480 × 400 @3x |

> **Prompt:** A 3D illustration of a friendly robot head-and-torso character, rendered in translucent green
> glass with a soft emissive inner glow and a bright lime `#A3E635` rim light. The robot has a rounded-square
> head with two glowing oval eyes and a gentle smiling mouth line, a short antenna with a glowing ball on
> top, and a small rounded body below. Floating to its lower right, a small rounded chat bubble containing
> three dots, in the same glass material. Three four-point sparkle stars glow around the figure. Three-quarter
> front view, floating with no ground contact. Deep black background, isolated with a fully transparent
> background and alpha channel. Soft glossy jelly-like material, high-quality 3D render, no text.

---

#### `PRM-702` — 3D Vet Chat Priority

| Field | Value |
|---|---|
| **Filename** | `prm-3d-vet-chat@3x.png` |
| **Folder** | `assets/images/premium/` |
| **Category** | Premium artwork / 3D illustration |
| **Used on** | `premium_home` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 480 × 400 @3x |

> **Prompt:** A 3D illustration of an open laptop seen at a three-quarter front angle, rendered in
> translucent green glass with an emissive inner glow and bright lime rim light. On the laptop screen, a
> simplified figure of a veterinarian — head, shoulders, a white coat silhouette and a stethoscope around
> the neck — rendered in brighter glowing green as if displayed on the screen. Floating just above the
> laptop's upper right corner, a rounded chat bubble containing three dots in the same glass material.
> A few small green sparkles around the composition. Floating with no ground contact, deep black background,
> isolated with a fully transparent background and alpha channel. Glossy jelly material, high-quality 3D
> render, no text.

---

#### `PRM-703` — 3D Unlimited Storage

| Field | Value |
|---|---|
| **Filename** | `prm-3d-storage@3x.png` |
| **Folder** | `assets/images/premium/` |
| **Category** | Premium artwork / 3D illustration |
| **Used on** | `premium_home` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 480 × 400 @3x |

> **Prompt:** A 3D illustration of a rounded, puffy cloud shape rendered in translucent green glass with an
> emissive inner glow and bright lime rim light. Embossed at the centre of the cloud, a glowing infinity
> symbol in brighter green. Overlapping the cloud's lower right edge, a small rounded square photo tile
> showing a simplified mountain-and-sun landscape glyph, in the same glass material. Several small green
> sparkle stars float around the cloud. Floating with no ground contact, deep black background, isolated on
> a fully transparent background with alpha channel. Soft glossy jelly material, high-quality 3D render,
> no text.

---

#### `PRM-704` — 3D Health Reports PDF

| Field | Value |
|---|---|
| **Filename** | `prm-3d-pdf-report@3x.png` |
| **Folder** | `assets/images/premium/` |
| **Category** | Premium artwork / 3D illustration |
| **Used on** | `premium_home` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 480 × 400 @3x |

> **Prompt:** A 3D illustration of a document page standing upright at a slight three-quarter angle, with a
> folded corner at the top right, rendered in translucent green glass with an emissive inner glow and bright
> lime rim light. Across the page, four short horizontal content lines and one small leaf-like glyph are
> embossed in brighter glowing green. At the lower left of the page, a small rounded rectangular tab
> protrudes, coloured a deeper solid green as a file-type label — **leave the tab blank, no lettering**.
> Small green sparkles float nearby. Floating with no ground contact, deep black background, isolated on a
> fully transparent background with alpha channel. Glossy jelly material, high-quality 3D render, no text.

---

#### `PRM-705` — 3D Smart Alerts

| Field | Value |
|---|---|
| **Filename** | `prm-3d-smart-alerts@3x.png` |
| **Folder** | `assets/images/premium/` |
| **Category** | Premium artwork / 3D illustration |
| **Used on** | `premium_home` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 480 × 400 @3x |

> **Prompt:** A 3D illustration of a classic notification bell seen front-on, rendered in translucent green
> glass with a strong emissive inner glow and bright lime rim light, with a small clapper below. Overlapping
> the bell's lower right, a small round analogue clock face with two glowing hands, in the same glass
> material with a brighter rim. A soft green halo radiates behind the bell and a few sparkles float around
> it. Floating with no ground contact, deep black background, isolated on a fully transparent background
> with alpha channel. Glossy jelly material, high-quality 3D render, no text, no numerals on the clock face.

---

#### `PRM-706` — 3D Multi-Pet Management

| Field | Value |
|---|---|
| **Filename** | `prm-3d-multipet@3x.png` |
| **Folder** | `assets/images/premium/` |
| **Category** | Premium artwork / 3D illustration |
| **Used on** | `premium_home` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 480 × 400 @3x |

> **Prompt:** A 3D illustration of four circular nodes arranged in a diamond formation and joined by thin
> glowing connector lines, all rendered in translucent green glass with an emissive inner glow and bright
> lime rim light. Each circle contains a simple glowing green glyph: top-left a dog's head, top-right a
> cat's head, bottom-left a rabbit's head with long ears, and the centre-bottom a paw print. The connector
> lines glow brighter where they meet each node. Floating with no ground contact, deep black background,
> isolated on a fully transparent background with alpha channel. Glossy jelly material, high-quality 3D
> render, no text.

---

#### `PRM-707` — Lime crown ⭐

| Field | Value |
|---|---|
| **Filename** | `prm-crown-lime@3x.png` + `.svg` |
| **Folder** | `assets/images/premium/` |
| **Category** | Icon / premium identity |
| **Used on** | `premium_home`, `subscription_plans`, `upgrade_benefits`, `usage_limits`, `profile`, `account_management`, `ai_assistant_home`, nav bar (8 screens) |
| **Reusable** | **Yes — global premium mark** |
| **Transparency** | Required |
| **Format** | SVG (primary) + PNG |
| **Resolution** | Vector; raster 108 × 90 @3x |

> **Prompt:** A simple flat crown icon seen front-on, with three upward points — the centre point taller than
> the two outer ones — each tipped with a small rounded ball, sitting on a solid horizontal base band. Filled
> solid in bright lime green `#A3E635` with a subtle darker lime outline and a soft outer glow. Symmetrical,
> geometric, clean, optimised to read clearly at 24 px. Isolated on a fully transparent background, alpha
> channel, no shadow, no gems, no text.

---

#### `PRM-708` — 3D crown with paw

| Field | Value |
|---|---|
| **Filename** | `prm-3d-crown-paw@3x.png` |
| **Folder** | `assets/images/premium/` |
| **Category** | Premium artwork / 3D badge |
| **Used on** | `usage_limits` |
| **Reusable** | Yes (upsell banners) |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 360 × 340 @3x |

> **Prompt:** A 3D crown badge seen front-on, drawn as a thick glowing lime-green `#A3E635` outline with a
> translucent dark-green interior — three upward points each tipped with a small glowing ball, on a solid
> base band. Centred inside the crown's body, a solid lime paw print with four toe beans and one main pad.
> Bright neon bloom around the entire crown, with six four-point sparkle stars of varying size scattered
> around it. Floating with no ground contact. Isolated on a fully transparent background, alpha channel, no
> shadow, no text.

---

#### `PRM-709` — 3D shield with paw ⭐

| Field | Value |
|---|---|
| **Filename** | `prm-3d-shield-paw@3x.png` |
| **Folder** | `assets/images/premium/` |
| **Category** | Premium artwork / 3D badge |
| **Used on** | `premium_home`, `subscription_plans`, `upgrade_benefits`, `profile`, `account_management`, `ai_transparency` (6 screens) |
| **Reusable** | **Yes — global trust mark** |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 560 × 620 @3x |

> **Prompt:** A 3D shield badge seen front-on, with a classic rounded-top, pointed-bottom silhouette. The
> shield is rendered as a thick glowing lime-green `#A3E635` outline enclosing a translucent dark-green
> glass interior with visible internal light refraction and a bright specular highlight along the upper-left
> edge. Centred inside the shield, a large solid lime paw print with four toe beans and one main pad,
> glowing as if lit from within. Strong neon bloom radiating outward, with several four-point sparkle stars
> floating around the shield at varying sizes. Floating with no ground contact. Isolated on a fully
> transparent background, alpha channel, no shadow plane, no text.
>
> *Variant `PRM-709b` (`upgrade_benefits`):* same shield but the paw is oversized and offset to the right,
> breaking slightly past the shield's edge.

---

#### `PRM-710` — 3D usage speedometer + shield ⭐

| Field | Value |
|---|---|
| **Filename** | `prm-3d-usage-gauge@3x.png` |
| **Folder** | `assets/images/premium/` |
| **Category** | Premium artwork / 3D illustration |
| **Used on** | `usage_limits` |
| **Reusable** | No |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 900 × 560 @3x |

> **Prompt:** A 3D illustration pairing two objects. On the left, a semicircular speedometer gauge seen
> front-on: a thick arc of segmented tick bars sweeping from left to right, graduating in colour from bright
> lime green `#A3E635` through yellow to orange `#FB923C` at the right end, with a bold needle pointing up
> and to the right into the orange zone, and a solid lime paw print sitting at the gauge's hub. On the
> right, a shield badge with a glowing lime outline and a translucent dark-green interior containing a solid
> lime paw print. Both objects float side by side with a strong neon bloom and scattered golden-green
> sparkle stars around them. Deep black background, isolated with a fully transparent background and alpha
> channel. Glossy 3D render, no text, no numerals on the gauge.

---

#### `PRM-711` — Premium dog + cat duo photo

| Field | Value |
|---|---|
| **Filename** | `prm-hero-dog-cat-duo@3x.webp` |
| **Folder** | `assets/images/premium/` |
| **Category** | Hero artwork / photoreal |
| **Used on** | `premium_home`, `subscription_plans`, `upgrade_benefits`, `ai_health_check_start` |
| **Reusable** | **Yes** |
| **Transparency** | Required |
| **Format** | WEBP |
| **Resolution** | 1250 × 1000 @3x |

> **Prompt:** Photorealistic photograph of an adult Golden Retriever sitting upright on the left with a
> happy open mouth and tongue out, and an adult brown tabby cat sitting upright on the right, slightly lower
> and closer to the viewer, looking directly at the camera with a calm expression. Their bodies overlap
> slightly so they read as a pair. Same casting as the PawDoc hero dog and hero cat. Warm key light from the
> front-left, subtle cool rim light along both silhouettes. Framing from mid-body up. Isolated on a fully
> transparent background, alpha channel, no floor, no shadow, no props, no collars. Ultra-detailed fur,
> commercial pet-photography quality.

---

#### `PRM-712` — 3D privacy shield with padlock ⭐

| Field | Value |
|---|---|
| **Filename** | `prm-3d-shield-lock@3x.png` |
| **Folder** | `assets/images/premium/` |
| **Category** | 3D illustration / trust |
| **Used on** | `privacy_security` |
| **Reusable** | Yes (security surfaces) |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 700 × 600 @3x |

> **Prompt:** A 3D illustration of a shield badge seen front-on with a glowing lime-green `#A3E635` outline
> and a translucent dark-green glass interior, containing a large solid lime paw print in its upper half.
> Overlapping the shield's lower-right edge and standing slightly in front of it, a chunky 3D padlock in the
> same glowing lime glass material, with a solid body and a raised shackle, and a small keyhole. A thin
> elliptical light ring orbits behind the shield at an angle. Several four-point sparkle stars of varying
> size float around the composition. Strong neon bloom, floating with no ground contact. Isolated on a fully
> transparent background, alpha channel, no shadow, no text.

---

#### `PRM-713` — 3D notification bell with paw ⭐

| Field | Value |
|---|---|
| **Filename** | `prm-3d-bell-paw@3x.png` |
| **Folder** | `assets/images/premium/` |
| **Category** | 3D illustration / hero |
| **Used on** | `notifications` |
| **Reusable** | Yes (alerts surfaces) |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 620 × 560 @3x |

> **Prompt:** A large notification bell seen front-on, drawn as a thick glowing lime-green `#A3E635` outline
> with a translucent dark interior and a small clapper below. Centred on the bell's face, a solid lime paw
> print with four toe beans and one main pad. On each side of the bell, two curved arc lines radiate outward
> like sound waves, brighter nearest the bell. Strong neon bloom throughout, with fine green light particles
> and a few four-point sparkle stars floating around it. Floating with no ground contact. Isolated on a
> fully transparent background, alpha channel, no shadow, no text.

---

### 6.9 ICON FAMILIES — `ICN`

---

#### `ICN-801` — Core UI line-icon set (~140 glyphs) ⭐

| Field | Value |
|---|---|
| **Filename** | `assets/icons/core/ic-<name>.svg` |
| **Folder** | `assets/icons/core/` |
| **Category** | Icon family |
| **Used on** | **All 57 screens** |
| **Reusable** | **Yes — the backbone of the UI** |
| **Transparency** | Required (SVG, `currentColor`) |
| **Format** | **SVG only** — must recolour to lime / red / cyan / violet / amber at runtime |
| **Resolution** | 24 × 24 viewBox, 1.5 px stroke, rounded caps and joins |

**Pipeline: author, do not generate.** A 140-glyph family needs stroke-weight, terminal and optical-size
consistency that GPT Image cannot hold. Base the set on Lucide (ISC licence, 1.5 px rounded, already
matches the mockups' language), extend with the bespoke glyphs listed under `ICN-802`–`ICN-816`, and export
every glyph with `stroke="currentColor"` so the red emergency colourway (`ai_analysis_result_emergency`) is
a tint, not a second set of files.

**Inventory (grouped):**

* *Navigation & chrome* — chevron-left/right/down, x, plus, minus, more-horizontal, more-vertical, search,
  filter/sliders, sort, expand, collapse, external-link, refresh, share-node, download, upload
* *Status* — check, check-circle, x-circle, alert-triangle, alert-circle, info-circle, question-circle,
  shield, shield-check, shield-alert, lock, unlock, eye, eye-off
* *Time* — clock, clock-history, calendar, calendar-check, calendar-plus, calendar-x, timer, stopwatch,
  moon-zzz, sun
* *Health* — heart, heart-pulse, activity/ecg, stethoscope, syringe, capsule/pill, pill-bottle, flask,
  clipboard, clipboard-check, thermometer, bandage, first-aid-kit, medical-cross, microchip, blood-drop,
  weight-scale, dna
* *Pets* — paw, paw-cluster, dog-face, cat-face, rabbit, bird, dog-side-silhouette, food-bowl, bone,
  leash/walking-dog, collar-tag, grooming-brush
* *Media* — camera, image, images-stack, video, play, mic, gallery, crop, focus-frame, hand
* *Comms* — chat-bubble, chat-bubbles, speech-bubble-dots, bell, bell-off, mail, phone, headset, megaphone,
  send
* *Data* — bar-chart, line-chart, donut-chart, trend-up, trend-down, target, node-graph, gauge, sparkline
* *Places* — map-pin, map, navigate/compass, home, hospital-building, car, globe, tree, cloud
* *People* — user, user-plus, users, users-three, user-check, vet-person, crown
* *Files* — document, document-plus, document-download, folder, folder-plus, pdf, paperclip, printer,
  qr-code, credit-card, wallet, tag
* *Editing* — pencil, note-pencil, trash, drag-handle, copy, bookmark, star, flag, thumbs-up, thumbs-down,
  lightbulb, sparkle, sparkles, gear, key, smartphone, leaf, flame, droplet, wind, graduation-cap, gift,
  suitcase, cake, tennis-ball, brain, lungs, stomach

> **Prompt (only for the ~15 bespoke glyphs Lucide lacks — one glyph per 1024 × 1024 plate, then vectorise):**
> A single minimal line icon centred on a pure white background, drawn in flat black with one uniform
> medium stroke weight, rounded caps and rounded joins, no fill, no shading, no gradient, no colour, no
> text, no frame. Geometric and balanced, designed to read clearly at 24 pixels, generous inner spacing,
> consistent with the Lucide icon family. Subject: `<glyph>` — e.g. *a veterinarian's head and shoulders
> with a stethoscope around the neck* / *a dog's head in side profile* / *a food bowl seen at a
> three-quarter angle* / *a microchip implant card* / *a weight scale with a paw print on its platform* /
> *a grooming brush with bristles*.

---

#### `ICN-802` — Symptom pictogram set (24) ⭐

| Field | Value |
|---|---|
| **Filename** | `assets/icons/symptoms/ic-symptom-<name>.svg` |
| **Folder** | `assets/icons/symptoms/` |
| **Category** | Icon family / medical pictograms |
| **Used on** | `symptom_selection`, `prepare_for_vet_visit`, `ai_assistant_home`, `first_aid_guide` |
| **Reusable** | **Yes — safety-critical, appears wherever symptoms are chosen** |
| **Transparency** | Required |
| **Format** | SVG (`currentColor`) |
| **Resolution** | 24 × 24 viewBox, 1.5 px stroke; generate at 1024 × 1024 then vectorise |

**Inventory (12 shown in `symptom_selection`, 12 behind "Show more"):**
`skin-irritation` · `itching` · `ear-problem` · `eye-discharge` · `coughing` · `sneezing` · `vomiting` ·
`diarrhea` · `appetite-loss` · `lethargy` · `limping` · `bloating` · `breathing-difficulty` ·
`excessive-thirst` · `weight-loss` · `hair-loss` · `bad-breath` · `swelling` · `seizure` · `disorientation` ·
`bleeding` · `urination-change` · `behaviour-change` · `pain-response`

> **Prompt (one glyph per generation):** A single minimal veterinary symptom pictogram centred on a pure
> white background, drawn in flat black with one uniform medium stroke weight, rounded caps and joins, no
> fill, no colour, no text, no frame. Clear, calm and clinical rather than cartoonish; instantly readable at
> 24 pixels. Subject:
> **skin-irritation** — a patch of skin with a few fur strands rising from it and a scattered cluster of
> small dots indicating a rash.
> **itching** — a paw with three short curved motion lines beside it and two small spark marks.
> **ear-problem** — a single dog ear seen from the side, with one small curved wave line beside it.
> **eye-discharge** — an almond-shaped eye with a pupil, lashes above and one small teardrop below.
> **coughing** — a dog's head in side profile with three short puff shapes emerging from the muzzle.
> **sneezing** — a muzzle and nose in side profile with a fan of small droplet marks spraying forward.
> **vomiting** — a simplified stomach organ outline.
> **diarrhea** — a simplified looped intestine outline.
> **appetite-loss** — an empty food bowl seen at a slight three-quarter angle.
> **lethargy** — a dog curled up asleep with three "z" marks of decreasing size rising from it.
> **limping** — a single leg bone with rounded ends, tilted.
> **bloating** — a rounded distended abdomen outline with two short pressure lines at its sides.
> **breathing-difficulty** — a pair of lungs with a short wave line across them.
> **excessive-thirst** — a water bowl with three droplets above it.
> **weight-loss** — a downward trend arrow over a simplified animal silhouette.
> **hair-loss** — a patch of skin with three fur strands detaching and falling away.
> **bad-breath** — a muzzle in profile with two wavy odour lines.
> **swelling** — a limb outline with a raised rounded bulge and two short radiating lines.
> **seizure** — a head silhouette with a jagged lightning line across it.
> **disorientation** — a head silhouette with a spiral inside it.
> **bleeding** — a single droplet with a small cross-hatch wound mark beside it.
> **urination-change** — a droplet inside a simplified bladder outline.
> **behaviour-change** — a brain outline with two small opposing arrows beside it.
> **pain-response** — a paw with three short radiating lines above it.
> Keep stroke weight, corner radius and optical size identical across all 24 so they read as one family.

---

#### `ICN-803` — Anatomy & health-condition glyph set (12)

| Field | Value |
|---|---|
| **Filename** | `assets/icons/anatomy/ic-anat-<name>.svg` |
| **Folder** | `assets/icons/anatomy/` |
| **Category** | Icon family / medical illustration |
| **Used on** | `breed_encyclopedia`, `breed_detail`, `ai_health_check_start` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | 24 × 24 viewBox (list) / 32 × 32 (cards) |

**Inventory:** `hip-dysplasia` · `elbow-dysplasia` · `bloat-stomach` · `heart-anatomical` · `cancer-ribbon` ·
`skin-coat` · `eyes-ears-nose` · `brain` · `lungs` · `kidney` · `liver` · `joint`

> **Prompt (one glyph per generation):** A single minimal anatomical line icon centred on a pure white
> background, flat black, one uniform medium stroke weight, rounded caps and joins, no fill, no colour, no
> text, no frame. Clinically accurate in silhouette but heavily simplified; readable at 24 pixels. Subject:
> **hip-dysplasia** — a simplified hip joint: a rounded femoral head seated in a socket, with the femur
> shaft extending down.
> **elbow-dysplasia** — a simplified elbow joint where two long bones meet at an angle.
> **bloat-stomach** — a rounded distended stomach organ with a short oesophagus at the top.
> **heart-anatomical** — an anatomically shaped heart with two visible major vessels at the top, not a
> symbolic love-heart.
> **cancer-ribbon** — an awareness ribbon with crossed tails.
> **skin-coat** — a horizontal skin surface layer with five fur strands rising from it in a gentle fan.
> **eyes-ears-nose** — a compact cluster of three glyphs: a dog ear at the upper left, an eye at the upper
> right and a nose/muzzle below, arranged in a triangle.
> **brain** — a brain seen from the front showing two hemispheres and gentle folds.
> **lungs** — a pair of lungs with a central trachea.
> **kidney** — a single bean-shaped kidney with a short vessel stem.
> **liver** — a simplified two-lobed liver silhouette.
> **joint** — two bone ends meeting with a small gap and three short arc lines around the junction.

---

#### `ICN-804` — Vaccine pathogen tiles (8) ⭐

| Field | Value |
|---|---|
| **Filename** | `assets/icons/vaccines/ic-vax-<name>@3x.png` |
| **Folder** | `assets/icons/vaccines/` |
| **Category** | Icon family / colour tiles |
| **Used on** | `vaccination_manager`, `pdf_health_report_preview` |
| **Reusable** | Yes |
| **Transparency** | No (the tile background is part of the asset) |
| **Format** | PNG (gradient fills) — or SVG if flattened to two-stop gradients |
| **Resolution** | 132 × 132 @3x (44 pt rounded square, 28 % corner radius) |

**Inventory & colourway:** `rabies` violet-blue `#6366F1` · `dhpp` teal `#14B8A6` · `leptospirosis` violet
`#8B5CF6` · `bordetella` orange `#F97316` · `lyme` amber `#F59E0B` · `influenza` cyan `#06B6D4` ·
`parvovirus` rose `#F43F5E` · `distemper` emerald `#10B981`

> **Prompt (one tile per generation):** A rounded-square app tile with a 28 % corner radius, filled with a
> smooth diagonal two-tone gradient from the specified hue at the top-left to a darker shade of the same hue
> at the bottom-right, with a very subtle inner top highlight. Centred on the tile, a simple white pictogram
> occupying about 55 % of the tile width, drawn with clean flat shapes and no outline. Soft coloured glow
> beneath the tile. No text.
> **rabies** — a rounded shield containing a single bold letter-free viral capsid hexagon.
> **dhpp** — a cluster of four small connected spheres.
> **leptospirosis** — a spiral corkscrew bacterium with a soft spiked outline.
> **bordetella** — a rounded rod-shaped bacterium cell with short surface cilia.
> **lyme** — a simplified tick silhouette seen from above.
> **influenza** — a spherical virus particle with short surface spikes.
> **parvovirus** — a geometric icosahedral virus capsid.
> **distemper** — a spherical virus with a wavy envelope outline.
> Keep the tile geometry, gradient angle, glyph scale and glow identical across all eight.

---

#### `ICN-805` — First-aid topic tiles (8) ⭐

| Field | Value |
|---|---|
| **Filename** | `assets/icons/firstaid/ic-fa-<name>@3x.png` |
| **Folder** | `assets/icons/firstaid/` |
| **Category** | Icon family / colour tiles |
| **Used on** | `first_aid_guide` |
| **Reusable** | Yes (emergency content lists) |
| **Transparency** | No |
| **Format** | PNG |
| **Resolution** | 156 × 156 @3x (52 pt rounded square, 26 % radius) |

**Inventory & colourway:** `bleeding` red `#DC2626` · `choking` lime `#84CC16` · `poisoning` violet `#7C3AED`
· `heatstroke` orange `#EA580C` · `cuts` blue `#2563EB` · `vomiting` teal `#0D9488` · `eye-injury` dark-red
`#9F1239` · `other` slate `#475569`

> **Prompt (one tile per generation):** A rounded-square app tile with a 26 % corner radius, filled with a
> smooth diagonal gradient from the specified hue at the top-left to a darker shade at the bottom-right,
> with a soft glossy highlight across the upper edge. Centred on it, a bold white-and-tinted pictogram
> occupying about 55 % of the tile. Subtle coloured glow beneath the tile. No text.
> **bleeding** — a single large teardrop-shaped blood drop with a bright highlight.
> **choking** — a simplified throat and airway silhouette with a small blocking shape lodged in it.
> **poisoning** — a classic skull-and-crossbones.
> **heatstroke** — a thermometer with a rising red column and a small sun beside its bulb.
> **cuts** — two adhesive bandages crossed in an X.
> **vomiting** — a stomach organ outline.
> **eye-injury** — an eye with a prominent pupil and iris.
> **other** — three horizontal dots.
> Keep tile geometry, gradient angle, glyph scale and gloss identical across all eight.

---

#### `ICN-806` — Message-action icons (8, multicolour)

| Field | Value |
|---|---|
| **Filename** | `assets/icons/actions/ic-act-<name>.svg` |
| **Folder** | `assets/icons/actions/` |
| **Category** | Icon family / multicolour |
| **Used on** | `ai_message_actions` |
| **Reusable** | Yes (any AI message long-press sheet) |
| **Transparency** | Required |
| **Format** | SVG (fixed colours, not `currentColor`) |
| **Resolution** | 28 × 28 viewBox |

**Inventory & colourway:** `copy` blue `#3B82F6` · `save-diary` green `#22C55E` · `share` violet `#A855F7` ·
`reminder` amber `#FBBF24` · `helpful` lime `#A3E635` · `not-helpful` red `#EF4444` · `regenerate` cyan
`#22D3EE` · `report` red-orange `#F97316`

> **Prompt (one glyph per generation):** A single minimal line icon centred on a pure white background,
> drawn in one uniform medium stroke weight with rounded caps and joins, in the specified solid colour, no
> fill, no gradient, no text, no frame. Readable at 28 pixels, consistent with the Lucide icon family.
> Subject: **copy** — two overlapping rounded rectangles offset diagonally. **save-diary** — a calendar
> page with a plus sign in its lower area. **share** — three connected nodes forming a share network.
> **reminder** — a notification bell with a clapper. **helpful** — a thumbs-up hand. **not-helpful** — a
> thumbs-down hand. **regenerate** — a four-point sparkle beside a smaller sparkle. **report** — a flag on
> a pole. Keep stroke weight and optical size identical across all eight.

---

#### `ICN-807` — Notification-category tiles (6, multicolour)

| Field | Value |
|---|---|
| **Filename** | `assets/icons/notifications/ic-notif-<name>@3x.png` |
| **Folder** | `assets/icons/notifications/` |
| **Category** | Icon family / tinted circles |
| **Used on** | `notifications`; warm colourway variant on `community_feed` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG (tinted glow) |
| **Resolution** | 132 × 132 @3x (44 pt circle) |

**Inventory & colourway:** `health-reminders` lime · `health-alerts` green · `vet-app-updates` green ·
`tips-education` violet `#A855F7` · `community` blue `#3B82F6` · `promotions` orange `#F97316`

> **Prompt (one per generation):** A circular tile with a very dark charcoal fill, a thin border in the
> specified accent colour and a soft coloured outer glow. Centred inside, a minimal line icon in the same
> accent colour, one uniform medium stroke weight, rounded caps, no fill, occupying about 45 % of the
> circle. Subject: **health-reminders** — a calendar with a small check. **health-alerts** — a heart with
> an ECG pulse line across it. **vet-app-updates** — a rounded chat bubble with three dots.
> **tips-education** — a gift box with a ribbon. **community** — two overlapping person silhouettes.
> **promotions** — a megaphone tilted upward. No text. Keep circle size, border weight and glyph scale
> identical across all six.

---

#### `ICN-808` — Medication-form tiles (4)

| Field | Value |
|---|---|
| **Filename** | `assets/icons/medication/ic-med-<name>@3x.png` |
| **Folder** | `assets/icons/medication/` |
| **Category** | Icon family / colour tiles |
| **Used on** | `medication_tracker`, `reminder_detail` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | PNG |
| **Resolution** | 132 × 132 @3x |

**Inventory & colourway:** `chewable` violet `#8B5CF6` · `tablet` blue `#3B82F6` · `liquid` orange `#F97316`
· `topical` teal `#14B8A6`

> **Prompt (one per generation):** A rounded-square app tile with a 28 % corner radius filled with a smooth
> diagonal gradient in the specified hue, with a soft coloured glow beneath. Centred on it, a clean white
> pictogram at about 55 % of the tile width: **chewable** — a capsule tilted 45°, split into two tones along
> its midline. **tablet** — a round pill seen face-on with a score line across the middle. **liquid** — a
> dropper bottle with a bulb top and a single droplet below its tip. **topical** — a squeeze tube with a cap
> and a small dab of cream at the nozzle. No text. Identical tile geometry across all four.

---

#### `ICN-809` — 3D weather icon set (8) ⭐

| Field | Value |
|---|---|
| **Filename** | `assets/icons/weather-3d/ic-wx-<name>@3x.png` |
| **Folder** | `assets/icons/weather-3d/` |
| **Category** | Icon family / 3D raster |
| **Used on** | `weather_walk_advisor`, `smart_walks` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | **PNG** (3D shading — not vectorisable) |
| **Resolution** | 240 × 240 @3x (hero variant 480 × 480) |

**Inventory:** `sun` · `sun-cloud` · `cloud` · `cloud-rain` · `cloud-heavy-rain` · `thunder` · `snow` ·
`wind`

> **Prompt (one per generation, one consistent render setup):** A glossy 3D weather icon floating on a fully
> transparent background, rendered in a soft toy-like plastic material with rounded edges, gentle ambient
> occlusion and a single soft key light from the upper left. Three-quarter front view, no ground contact, no
> cast shadow, no text. The sun is a warm saturated yellow-orange sphere with short rounded triangular rays;
> clouds are soft rounded puffy volumes in cool light grey with a bluish underside; raindrops are glossy
> translucent blue teardrops; snowflakes are simple white six-point crystals; lightning is a bold saturated
> yellow bolt; wind is three tapered curved grey streaks. Subject: **sun** — the sun alone. **sun-cloud** —
> the sun peeking from behind a cloud at the upper left. **cloud** — a single cloud. **cloud-rain** — a
> cloud with three falling raindrops. **cloud-heavy-rain** — a darker cloud with six falling raindrops.
> **thunder** — a dark cloud with a lightning bolt below it. **snow** — a cloud with three falling
> snowflakes. **wind** — a cloud with three wind streaks trailing to the right. Keep material, lighting
> angle, gloss level and optical size identical across all eight so the set reads as one system.

---

#### `ICN-810` — Bottom-navigation icon sets (2 variants, 11 glyphs)

| Field | Value |
|---|---|
| **Filename** | `assets/icons/nav/ic-nav-<name>[-active].svg` |
| **Folder** | `assets/icons/nav/` |
| **Category** | Icon family / navigation |
| **Used on** | 42 screens |
| **Reusable** | **Yes — persistent chrome** |
| **Transparency** | Required |
| **Format** | SVG (`currentColor`) |
| **Resolution** | 28 × 28 viewBox |

**Variant A (health app, 6 slots):** `home` · `pets` · `[+ FAB]` · `assistant` · `health` · `settings`
**Variant B (social/premium, 6 slots):** `home` · `pets` · `ai-care` · `community` · `emergencies` |
`premium` · `profile`

⚠️ Variant B places **Premium** in the slot that otherwise holds **Emergencies** (`premium_home`,
`subscription_plans`, `upgrade_benefits`, `usage_limits`, `privacy_security`, `account_management`). See
conflict **C-7** — the emergency entry point must not be displaced by a monetisation tab. Resolve before
implementation; the icon assets themselves are unaffected.

> **Prompt (bespoke glyphs only — `pets`, `ai-care`, `emergencies`):** A single minimal line icon centred on
> a pure white background, flat black, one uniform medium stroke weight, rounded caps and joins, no fill, no
> text, no frame; readable at 24 pixels. **pets** — a cluster of four small toe beans above one larger main
> pad, forming a paw print. **ai-care** — a large four-point sparkle with a smaller four-point sparkle at
> its upper right. **emergencies** — a shield with a paw print centred inside it. Provide each in an
> outline "inactive" weight and a solid-filled "active" weight.

---

#### `ICN-811` — Vital-sign glyphs + ECG sparklines (5)

| Field | Value |
|---|---|
| **Filename** | `assets/icons/vitals/ic-vital-<name>.svg` |
| **Folder** | `assets/icons/vitals/` |
| **Category** | Icon family / medical |
| **Used on** | `know_your_baseline` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | 24 × 24 (glyph) + 120 × 32 (sparkline) |

**Inventory:** `resting-heart-rate` · `respiratory-rate` · `temperature` · `resting-time` · `activity-level`
Each pairs with a small lime ECG-style sparkline path.

> **Prompt:** Minimal line icons, flat black on white, uniform medium stroke, rounded caps, no fill, no
> text. **resting-heart-rate** — a heart outline with a small solid dot at its centre. **respiratory-rate**
> — a pair of lungs with a central trachea. **temperature** — a thermometer with a bulb and a rising column.
> **resting-time** — a crescent moon with a small four-point sparkle beside it. **activity-level** — a dog
> running in profile with two short motion lines behind it.
> **Sparklines:** deliver as five separate SVG paths — an irregular ECG-style waveform 120 × 32, thin
> uniform stroke, rounded caps, no axes, no fill, no text; each with a different but plausible rhythm.

---

#### `ICN-812` — Record-type & timeline tiles (8)

| Field | Value |
|---|---|
| **Filename** | `assets/icons/records/ic-rec-<name>.svg` |
| **Folder** | `assets/icons/records/` |
| **Category** | Icon family / tinted circles |
| **Used on** | `health_timeline`, `add_health_record`, `010-home-page`, `conversation_history`, `pdf_health_report_preview` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | 24 × 24 viewBox in a 44 pt tinted circle |

**Inventory & tint:** `vet-visit` violet · `medication` lime · `lab-result` teal · `vaccination` blue ·
`ai-analysis` lime · `weight` amber · `note` violet · `memory` pink

> **Prompt:** Minimal line icons, flat black on white, uniform medium stroke, rounded caps, no fill, no
> text. **vet-visit** — a calendar page with a small plus. **medication** — a capsule tilted 45°.
> **lab-result** — an Erlenmeyer flask with a liquid line. **vaccination** — a syringe tilted 45°.
> **ai-analysis** — a four-point sparkle with a smaller companion sparkle. **weight** — a rounded weight
> box with a handle and a paw print on its face. **note** — a page with three ruled lines and a small pencil
> at its corner. **memory** — a landscape photo frame with a mountain and sun inside.

---

#### `ICN-813` — Breed-care & quick-search glyphs (12)

| Field | Value |
|---|---|
| **Filename** | `assets/icons/breed-care/ic-care-<name>.svg` |
| **Folder** | `assets/icons/breed-care/` |
| **Category** | Icon family |
| **Used on** | `breed_encyclopedia`, `breed_detail`, `search_memories` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | 24 × 24 viewBox |

**Inventory:** `exercise` · `grooming` · `shedding` · `trainability` · `intelligence` · `barking` ·
`size` · `lifespan` · `birthday-cake` · `vet-visit-search` · `vacation-suitcase` · `playtime-ball`

> **Prompt:** Minimal line icons, flat black on white, uniform medium stroke, rounded caps, no fill, no
> text; readable at 24 pixels. **exercise** — a person running in profile. **grooming** — a brush with
> bristles. **shedding** — three loose fur strands with short motion curves. **trainability** — a graduation
> cap. **intelligence** — a brain. **barking** — a speaker cone with two sound arcs. **size** — a dog side
> silhouette with a vertical dimension arrow beside it. **lifespan** — an hourglass. **birthday-cake** — a
> two-tier cake with a single lit candle. **vet-visit-search** — a stethoscope. **vacation-suitcase** — a
> suitcase with a handle and one strap. **playtime-ball** — a tennis ball with a curved seam line.

---

#### `ICN-814` — Species sub-badges (3)

| Field | Value |
|---|---|
| **Filename** | `assets/icons/core/ic-species-<name>-badge@3x.png` |
| **Folder** | `assets/icons/core/` |
| **Category** | Badge / marker overlay |
| **Used on** | `nearby_pet_owners`, `community_feed` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | 72 × 72 @3x |

> **Prompt:** A small circular badge with a solid coloured fill and a thin darker ring, containing a simple
> white pictogram at about 55 % of the badge width, designed to overlay the corner of a larger avatar.
> **dog** — lime green `#A3E635` fill, white paw print. **cat** — violet `#8B5CF6` fill, white cat head with
> pointed ears and whiskers. **other** — rose `#F43F5E` fill, white heart. Flat, no gradient, crisp at small
> sizes, no text. Isolated on a fully transparent background, alpha channel.

---

#### `ICN-815` — "Bring to your vet" glyphs (5)

| Field | Value |
|---|---|
| **Filename** | `assets/icons/core/ic-bring-<name>.svg` |
| **Folder** | `assets/icons/core/` |
| **Category** | Icon family / educational |
| **Used on** | `prepare_for_vet_visit` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | 32 × 32 viewBox |

> **Prompt:** Minimal line icons, flat black on white, uniform medium stroke, rounded caps, no fill, no
> text. **medications** — a pill bottle with a cap, and a capsule resting beside it. **previous-records** —
> a clipboard with three ruled lines, the top two preceded by check marks. **food-treats** — a food bowl
> seen at a three-quarter angle with a small mound of kibble in it. **sample-cup** — a lidded specimen cup
> with a small shield mark on its side. **photos-videos** — a phone seen front-on with a landscape photo
> glyph and a small play triangle on its screen.

---

#### `ICN-816` — Benefit / trust glyphs (8)

| Field | Value |
|---|---|
| **Filename** | `assets/icons/core/ic-benefit-<name>.svg` |
| **Folder** | `assets/icons/core/` |
| **Category** | Icon family |
| **Used on** | `upgrade_benefits`, `subscription_plans`, `usage_limits`, `002-onboarding`, `004-onboarding` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | 28 × 28 viewBox |

> **Prompt:** Minimal line icons, flat black on white, uniform medium stroke, rounded caps, no fill, no
> text. **better-care** — a shield with a four-point star inside, flanked by two small sparkles.
> **more-insights** — a heart with a medical cross inside, flanked by sparkles. **save-time** — a clock face
> with a small sparkle at its upper right. **peace-of-mind** — a cloud with a heart nestled inside it.
> **free-trial** — a circular arrow forming an open loop. **money-back** — a shield with a check inside.
> **secure-private** — a padlock with a small plus on its body. **loved-by-parents** — a heart with a paw
> print inside it.

---

### 6.10 BADGES & ACHIEVEMENTS — `BDG`

---

#### `BDG-901` / `BDG-902` — Hexagonal achievement frames ⭐

| Field | Value |
|---|---|
| **Filename** | `bdg-hex-frame-unlocked@3x.png`, `bdg-hex-frame-locked@3x.png` |
| **Folder** | `assets/badges/achievements/` |
| **Category** | Badge / achievement system |
| **Used on** | `smart_walks`; extensible to any gamified surface |
| **Reusable** | **Yes — the frame is generated once, inner icons composite on top** |
| **Transparency** | Required |
| **Format** | SVG (frame) + PNG (with glow) |
| **Resolution** | Vector; raster 264 × 288 @3x |

> **Prompt (two variants):** A hexagonal badge frame in a flat-top hexagon orientation, drawn as a thick
> clean outline with a translucent dark interior, centred on a fully transparent background, no text, no
> inner icon — the centre must stay empty for compositing.
> **(a) unlocked** — outline in bright lime green `#A3E635` with a strong neon outer glow and a subtle inner
> gradient from dark green to near-black; a thin secondary hexagon outline sits just inside the first.
> **(b) locked** — identical geometry but in flat medium grey `#4B5563` with no glow, a flatter dark
> interior and slightly reduced opacity.

---

#### `BDG-903` — Achievement inner icons (6)

| Field | Value |
|---|---|
| **Filename** | `bdg-achv-<name>@3x.png` |
| **Folder** | `assets/badges/achievements/` |
| **Category** | Badge / achievement system |
| **Used on** | `smart_walks` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | 120 × 120 @3x |

**Inventory:** `first-10-walks` (paw) · `distance-50km` (mountain route) · `calorie-hunter` (flame) ·
`week-streak` (calendar) · `marathon-paw` (medal, locked state) · `early-bird` (sunrise)

> **Prompt (one per generation):** A single bold pictogram centred on a fully transparent background, drawn
> in bright lime green `#A3E635` with a uniform medium stroke and a soft glow, sized to sit inside a
> hexagonal badge with generous margins. No text, no numerals, no frame. **first-10-walks** — a paw print.
> **distance-50km** — two overlapping mountain peaks with a winding path over them. **calorie-hunter** — a
> stylised flame. **week-streak** — a calendar page with a small check. **marathon-paw** — a circular medal
> hanging from a short ribbon. **early-bird** — a sun rising over a horizon line with three short rays.
> Also deliver a **grey `#4B5563`, no-glow** copy of each for the locked state, plus a
> `bdg-achv-padlock@3x` closed padlock glyph in grey for the locked overlay.

---

#### `BDG-904` — Verified check badges (2)

| Field | Value |
|---|---|
| **Filename** | `bdg-verified-{lime,blue}@3x.png` |
| **Folder** | `assets/badges/` |
| **Category** | Badge |
| **Used on** | `pet_profile`, `profile`, `account_management` (lime); `community_feed`, `community_post_detail` (blue, for verified vets) |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | 66 × 66 @3x |

> **Prompt:** A small verification badge: a scalloped circle (a circle with about twelve rounded lobes
> around its edge, like a seal) filled solid, containing a bold white check mark at its centre. Two
> colourways — one in bright lime green `#A3E635`, one in vivid blue `#3B82F6`. Flat, no gradient, no
> shadow, crisp at 22 pixels. Isolated on a fully transparent background, alpha channel, no text.

---

#### `BDG-905` — Top-contributor badge

| Field | Value |
|---|---|
| **Filename** | `bdg-top-contributor@3x.png` |
| **Folder** | `assets/badges/` |
| **Category** | Badge |
| **Used on** | `community_feed` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | 60 × 60 @3x |

> **Prompt:** A small circular badge with a solid lime-green `#A3E635` fill and a soft glow, containing a
> simple black paw print at its centre occupying about 55 % of the badge. Flat, crisp at small sizes, no
> gradient, no text. Isolated on a fully transparent background, alpha channel.

---

#### `BDG-906` — Award rosette

| Field | Value |
|---|---|
| **Filename** | `bdg-award-rosette@3x.png` |
| **Folder** | `assets/badges/` |
| **Category** | Badge |
| **Used on** | `know_your_baseline`, `upgrade_benefits` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | 108 × 132 @3x |

> **Prompt:** An award rosette icon: a scalloped circular medal at the top with a small star at its centre,
> and two short ribbon tails hanging from its lower edge, angled apart. Drawn as a clean outline in warm
> amber `#FBBF24` with a uniform medium stroke, rounded caps and a soft glow, no fill. Symmetrical, crisp,
> no text. Isolated on a fully transparent background, alpha channel.

---

#### `BDG-907` / `BDG-908` — "24/7" badge and crown highlight badge

| Field | Value |
|---|---|
| **Filename** | `bdg-24-7@3x.png`, `bdg-highlight-crown@3x.png` |
| **Folder** | `assets/badges/` |
| **Category** | Badge |
| **Used on** | `004-onboarding`, `emergency_hub` / `memories_gallery` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | 96 × 96 @3x |

> **Prompt (a) 24/7:** A thin circular clock outline in cyan `#22D3EE` with a soft glow, with a small
> clock hand inside; the circle is broken at the upper area to leave a clean gap for the app to render
> "24/7" text. No baked-in lettering.
> **Prompt (b) crown highlight:** A small circular badge with a solid lime-green fill containing a simple
> black three-point crown glyph at its centre, flat, crisp at 20 pixels, no gradient, no text. Both isolated
> on fully transparent backgrounds with alpha channels.

---

### 6.11 HUMAN AVATARS — `AVT`

> **Ethics constraint:** all human likenesses must be **synthetic and non-identifiable**. They must not
> resemble any real person, must not imply endorsement, and must be diverse in age, skin tone and gender
> presentation. Vet avatars must not imply a licensed relationship with PawDoc.

---

#### `AVT-1001` — Social-proof face cluster (4)

| Field | Value |
|---|---|
| **Filename** | `avt-social-proof-{01..04}@3x.webp` |
| **Folder** | `assets/images/avatars/` |
| **Category** | Avatar / photoreal |
| **Used on** | `000.png` |
| **Reusable** | Yes |
| **Transparency** | No (circular mask in Flutter) |
| **Format** | WEBP |
| **Resolution** | 132 × 132 @3x each |

> **Prompt (4 separate images):** Photorealistic square headshot of a friendly smiling adult looking
> directly at the camera, framed from the shoulders up with the head centred and filling about 70 % of the
> frame for clean circular cropping. Soft natural daylight, gently blurred neutral outdoor background,
> shallow depth of field, warm and approachable expression, casual clothing. Four distinct synthetic people:
> a woman with long dark wavy hair; a man with short dark hair and a light beard; a woman with straight
> shoulder-length brown hair; a man with short light-brown hair. Diverse skin tones. Not resembling any real
> or famous person. No text, no logos, no props.

---

#### `AVT-1002` — Female user avatar

| Field | Value |
|---|---|
| **Filename** | `avt-user-female@3x.webp` |
| **Folder** | `assets/images/avatars/` |
| **Category** | Avatar / photoreal |
| **Used on** | `010-home-page`, `community_feed`, `create_post` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 180 × 180 @3x |

> **Prompt:** Photorealistic square headshot of a smiling woman in her late twenties with long dark wavy
> hair, looking directly at the camera, framed from the shoulders up, head centred and filling about 70 % of
> the frame for circular cropping. Soft natural daylight, gently blurred neutral background, warm friendly
> expression, casual dark top. Synthetic person not resembling anyone real. No text, no logos, no jewellery
> branding.

---

#### `AVT-1003` — Male user avatar

| Field | Value |
|---|---|
| **Filename** | `avt-user-male@3x.webp` |
| **Folder** | `assets/images/avatars/` |
| **Category** | Avatar / photoreal |
| **Used on** | `profile`, `account_management` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 420 × 420 @3x (larger — rendered at 128 pt on profile) |

> **Prompt:** Photorealistic square headshot of a smiling man in his mid-twenties with short dark curly hair
> and a short trimmed beard, looking directly at the camera, framed from the shoulders up, head centred and
> filling about 70 % of the frame for circular cropping. Soft natural daylight, gently blurred outdoor
> background with warm bokeh, relaxed friendly expression, plain dark T-shirt. Synthetic person not
> resembling anyone real. No text, no logos.

---

#### `AVT-1004` — Veterinarian avatar

| Field | Value |
|---|---|
| **Filename** | `avt-vet-female@3x.webp` |
| **Folder** | `assets/images/avatars/` |
| **Category** | Avatar / photoreal |
| **Used on** | `pet_profile`, `community_feed`, `community_post_detail` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 180 × 180 @3x |

> **Prompt:** Photorealistic square headshot of a friendly female veterinarian in her thirties wearing a
> clean white clinical coat with a stethoscope around her neck, looking directly at the camera with a warm
> professional smile, framed from the shoulders up, head centred for circular cropping. Softly blurred light
> clinical interior background, even diffuse lighting. Synthetic person not resembling anyone real. **No name
> badge, no embroidered text, no clinic logo, no lettering anywhere.**

---

#### `AVT-1005` — Community member avatars with pets (6) ⭐

| Field | Value |
|---|---|
| **Filename** | `avt-community-{01..06}@3x.webp` |
| **Folder** | `assets/images/avatars/` |
| **Category** | Avatar / photoreal composite |
| **Used on** | `community_feed`, `community_post_detail`, `create_post` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 180 × 180 @3x |

> **Prompt (6 separate images):** Photorealistic square portrait of a person together with their pet, both
> faces visible and close together, looking toward the camera, framed from the chest up, composed so the
> pair stays inside a circular crop. Soft natural outdoor daylight, gently blurred green background, warm
> affectionate mood. Six distinct pairings: a young woman with a Golden Retriever; a man with a Golden
> Retriever puppy; a woman with a Maine Coon cat; a woman with a small toy Poodle; a man with a Border
> Collie; a man with a spotted short-haired dog. Diverse ages and skin tones. Synthetic people not
> resembling anyone real. No text, no logos, no visible brand marks on clothing.

---

#### `AVT-1006` / `AVT-1007` — Map avatars (5) and group avatars (3)

| Field | Value |
|---|---|
| **Filename** | `avt-map-{01..05}@3x.webp`, `avt-group-{01..03}@3x.webp` |
| **Folder** | `assets/images/avatars/` |
| **Category** | Avatar / photoreal |
| **Used on** | `nearby_pet_owners` / `create_post` |
| **Reusable** | Yes (`AVT-1006` may reuse `AVT-1005` crops) |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 132 × 132 @3x |

> **Prompt:** Reuse `AVT-1005` at a tighter crop for `AVT-1006` — no new generation required unless more
> variety is wanted. For `AVT-1007` (group avatars), generate three photorealistic square images suitable
> for small circular crops: (a) a Golden Retriever's face close-up; (b) a sunrise path through a park with
> no people; (c) a flat lime-green tile containing a simple black graduation-cap glyph (vector, not
> photographic). Soft daylight, blurred backgrounds, no text.

---

### 6.12 MAP ARTWORK — `MAP`

> **Implementation note:** if the app uses a live map SDK, `MAP-1101`–`MAP-1103` become **map style JSON**
> (a dark green theme) rather than raster assets, and only the markers (`EMG-606`, `MAP-1106`) ship as
> images. Generate the rasters only for static previews, empty states and screenshots. This decision must be
> made before generation — it changes 5 of the 8 map assets.

---

#### `MAP-1101` — Stylised neighbourhood map ⭐

| Field | Value |
|---|---|
| **Filename** | `map-community-neighbourhood@3x.webp` |
| **Folder** | `assets/images/maps/` |
| **Category** | Map illustration |
| **Used on** | `nearby_pet_owners` |
| **Reusable** | Yes (static preview) |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 1600 × 1200 @3x |

> **Prompt:** A stylised top-down city map illustration in a dark theme. Background is very dark green-black
> `#0A1410`. Roads are drawn as thin dark-grey lines forming an irregular grid with a few diagonal avenues.
> Park areas are rendered as slightly lighter desaturated dark-green blocks with subtle tree texture.
> Building blocks are barely-lighter dark shapes with no detail. A large soft lime-green translucent circle
> is centred in the frame as a radius overlay, with a thin bright lime outline. No labels, no street names,
> no place names, no icons, no pins — **all text and markers are rendered by the app**. Clean modern
> navigation-app aesthetic, flat, no perspective, no 3D buildings.

---

#### `MAP-1102` — Emergency clinic map

| Field | Value |
|---|---|
| **Filename** | `map-emergency-clinics@3x.webp` |
| **Folder** | `assets/images/maps/` |
| **Category** | Map illustration |
| **Used on** | `emergency_hub` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 1600 × 660 @3x |

> **Prompt:** A stylised top-down city map illustration in a dark theme, wide letterbox format. Background
> very dark green-black, roads as thin dark-grey lines radiating from a central junction, subtle darker
> block shapes for buildings, one lighter dark-green park area. A soft lime-green translucent glow circle
> sits at the centre. No labels, no text, no pins, no icons — markers are composited by the app. Flat, no
> perspective, clean navigation-app aesthetic.

---

#### `MAP-1103` — Live walk route map ⭐

| Field | Value |
|---|---|
| **Filename** | `map-walk-route-live@3x.webp` |
| **Folder** | `assets/images/maps/` |
| **Category** | Map illustration |
| **Used on** | `smart_walks` |
| **Reusable** | Yes |
| **Transparency** | Route polyline delivered as a separate transparent PNG layer |
| **Format** | WEBP (base) + PNG (route layer) |
| **Resolution** | 1600 × 1050 @3x |

> **Prompt (two layers):**
> **Base:** a stylised top-down dark city map — very dark green-black background, thin dark-grey roads in an
> irregular grid, two lighter dark-green park areas, subtle building blocks. No text, no labels, no icons.
> **Route layer (transparent):** a single bright lime-green `#A3E635` polyline tracing a winding walking
> route across the frame, about 6 px wide with rounded joins and a soft outer glow, with a solid filled
> circle marking the start point and a small checkered-flag marker at the end point. Nothing else on the
> layer, alpha channel, no text.

---

#### `MAP-1104` / `MAP-1105` — Route thumbnails (3) and memory location thumbnail

| Field | Value |
|---|---|
| **Filename** | `map-route-thumb-{01..03}@3x.webp`, `map-memory-location@3x.webp` |
| **Folder** | `assets/images/maps/` |
| **Category** | Map illustration / thumbnail |
| **Used on** | `smart_walks` / `memory_detail` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 240 × 240 @3x / 300 × 200 @3x |

> **Prompt:** Small square stylised dark map thumbnails: very dark green-black background, a few thin
> dark-grey road lines, one lighter dark-green park patch, and a single bright lime-green winding route
> polyline with a soft glow crossing the tile — a different route shape in each of the three. No text, no
> labels, no pins. For the memory location thumbnail, use the same base without a route polyline and leave
> the centre clear for a pin composited by the app.

---

#### `MAP-1106` — User location pin

| Field | Value |
|---|---|
| **Filename** | `map-pin-user@3x.png` |
| **Folder** | `assets/images/maps/` |
| **Category** | Map marker |
| **Used on** | `nearby_pet_owners`, `emergency_hub`, `smart_walks` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | 120 × 150 @3x |

> **Prompt:** A map marker pin with a classic teardrop silhouette, filled solid bright lime green `#A3E635`
> with a soft glow, containing a black paw print centred in its circular head. Beneath the pin's point, a
> small solid blue `#3B82F6` circle with a thin white ring represents the precise location dot. Clean,
> crisp, symmetrical, optimised for small sizes. Isolated on a fully transparent background, alpha channel,
> no shadow, no text.

---

### 6.13 MEMORY PHOTO LIBRARY — `MEM`

---

#### `MEM-1201` — Memory photo library (24 photos) ⭐

| Field | Value |
|---|---|
| **Filename** | `mem-buddy-{01..24}@3x.webp` |
| **Folder** | `assets/images/memories/` |
| **Category** | Content photography / sample data |
| **Used on** | `memories_gallery`, `memory_detail`, `search_memories`, `add_memory`, `pet_profile`, `edit_pet` (6 screens, 41 display slots) |
| **Reusable** | **Yes — one library fills every slot** |
| **Transparency** | No |
| **Format** | WEBP (q80 — these are decorative sample content) |
| **Resolution** | 1200 × 1200 @3x master; app crops to square, 4:3 and 16:9 |

> **⚠ Product note:** these are **seed/sample content**, shown before a user has added their own memories.
> They must be visually marked as samples in-app or replaced by an empty state — otherwise the gallery
> implies the user has photos they never took.

> **Prompt (24 separate images, all the same dog):** Photorealistic lifestyle photograph of an adult Golden
> Retriever — the same dog throughout, matching the PawDoc hero casting: rich golden-red coat, warm brown
> eyes, dark collar. Natural available light, shallow depth of field, warm authentic colour grade, candid
> amateur-but-beautiful phone-photography feel. No text, no watermarks, no people's faces in frame.
> Scenes:
> 01 portrait sitting in green grass · 02 running toward the camera with a tennis ball in its mouth in a
> sunlit park · 03 standing in tall golden grass · 04 sleeping curled on a soft cushion indoors ·
> 05 sitting among purple and white wildflowers · 06 wearing a small party hat with colourful balloons
> behind · 07 head out of a car window, ears blown back · 08 sitting in a bathtub covered in white foam ·
> 09 close-up with a single yellow flower resting on its nose · 10 silhouette on a beach at sunset ·
> 11 standing in a green meadow at golden hour · 12 asleep hugging a small teddy bear · 13 swimming in a
> lake with only its head above water · 14 shaking water off beside a lake · 15 sitting beside a birthday
> cake with one lit candle · 16 wearing a green winter jacket in fresh snow · 17 sitting by a mountain lake
> at dawn · 18 lying on a wooden porch in warm evening light · 19 walking on an autumn path covered in
> orange leaves · 20 close-up portrait against a plain dark background · 21 playing tug with a rope toy ·
> 22 sitting beside a Christmas tree with warm lights · 23 rolling on its back in grass · 24 curled asleep
> in a dog bed at night with soft lamp light.

---

### 6.14 BREED ENCYCLOPEDIA — `BRE`

---

#### `BRE-1301` — Species category avatars (6)

| Field | Value |
|---|---|
| **Filename** | `bre-category-{dog,cat,rabbit,bird,reptile,all}@3x.webp` |
| **Folder** | `assets/images/breeds/` |
| **Category** | Category thumbnail / photoreal |
| **Used on** | `breed_encyclopedia` |
| **Reusable** | Yes — **may reuse `PET-201`–`PET-205` at a tighter circular crop** |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 156 × 156 @3x |

> **Prompt:** Reuse `PET-201`–`PET-204` at a tight circular-safe crop. Generate two additions in the same
> lighting and framing: **reptile** — a photorealistic close-up head portrait of a bearded dragon facing the
> camera, warm sandy scales, dark round eye, dark neutral background, soft studio key light; **all** — not a
> photo: a flat lime-green paw print on a dark circular tile.

---

#### `BRE-1302` — Golden Retriever hero portrait (encyclopedia)

| Field | Value |
|---|---|
| **Filename** | `bre-golden-retriever-hero@3x.webp` |
| **Folder** | `assets/images/breeds/` |
| **Category** | Hero photography |
| **Used on** | `breed_encyclopedia`, `breed_detail` |
| **Reusable** | Yes — **template for every breed page** |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 1000 × 1300 @3x (3:4 portrait) |

> **Prompt:** Photorealistic vertical editorial portrait of a Golden Retriever sitting in a sunlit park,
> body angled slightly to the left, head turned toward the camera with an alert, dignified expression and a
> closed mouth. Full body from the paws up, filling the vertical frame. Warm late-afternoon backlight
> creating a golden rim along the coat, softly blurred green trees and grass behind, creamy bokeh. Rich
> golden coat with visible feathering on the chest, legs and tail. No collar, no leash, no people, no text.
> Editorial breed-encyclopedia photography quality, 85 mm lens look, tack-sharp eyes.

---

#### `BRE-1303` — Similar-breed thumbnails (4)

| Field | Value |
|---|---|
| **Filename** | `bre-similar-{labrador,flatcoat,toller,chesapeake}@3x.webp` |
| **Folder** | `assets/images/breeds/` |
| **Category** | Thumbnail photography |
| **Used on** | `breed_encyclopedia` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 210 × 210 @3x |

> **Prompt (4 separate images, identical lighting and framing):** Photorealistic square head-and-shoulder
> portrait of a dog facing the camera, head centred and filling about 70 % of the frame for circular
> cropping, softly blurred natural green outdoor background, warm daylight, shallow depth of field, calm
> expression, no collar, no text. Breeds: **(a)** a yellow Labrador Retriever with a broad head and short
> dense coat; **(b)** a black Flat-Coated Retriever with a long feathered black coat and a lean head;
> **(c)** a Nova Scotia Duck Tolling Retriever with a foxy red-orange coat and white blaze; **(d)** a
> Chesapeake Bay Retriever with a wavy deadgrass-brown coat and amber eyes. Each must be clearly
> distinguishable as its breed.

---

### 6.15 COMMUNITY — `CMN`

---

#### `CMN-1401` — "Hot Weather Pet Health" editorial card ⭐

| Field | Value |
|---|---|
| **Filename** | `cmn-editorial-hot-weather@3x.webp` |
| **Folder** | `assets/images/community/` |
| **Category** | Editorial card artwork / illustration |
| **Used on** | `community_feed` |
| **Reusable** | Template for a seasonal editorial series |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 1600 × 900 @3x |

> **Prompt:** A stylised painterly digital illustration in a wide 16:9 format on a deep teal-green
> background. A Golden Retriever wearing black sunglasses lies relaxed on its belly in the centre-left,
> facing the viewer with a contented expression. Above and behind it, a large striped beach umbrella in
> cream and warm coral tilts over the scene, casting a soft shade. To the right, a round blue paddling pool
> with gently rippling water and a few floating highlights. Soft flat shading with painterly texture, warm
> summer palette against the cool dark background, subtle vignette. Editorial magazine-cover feel.
> **No text, no lettering, no headline** — all copy is rendered by the app over this artwork. Leave the
> upper-left third relatively uncluttered as a text safe area.

---

#### `CMN-1402` — Community post photos (3)

| Field | Value |
|---|---|
| **Filename** | `cmn-post-promenade-{01..03}@3x.webp` |
| **Folder** | `assets/images/community/` |
| **Category** | Content photography |
| **Used on** | `community_feed`, `community_post_detail`, `create_post` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 1200 × 900 @3x |

> **Prompt (3 images, same location and time of day):** Photorealistic photographs taken on a waterside
> promenade at sunrise, with warm golden light, long soft shadows, a row of ornate lamp posts along the
> path, calm water and a hazy skyline in the distance. **(a)** a Golden Retriever sitting on the promenade
> facing the camera, backlit by the low sun; **(b)** the empty promenade receding into the distance with no
> animals or people; **(c)** a Golden Retriever running along the promenade toward the camera, slight motion
> blur in the legs. Natural warm colour grade, shallow depth of field, no text, no identifiable signage,
> no recognisable people.

---

#### `CMN-1403` — Reaction chips (3)

| Field | Value |
|---|---|
| **Filename** | `cmn-reaction-{heart,paw,thumb}@3x.png` |
| **Folder** | `assets/images/community/` |
| **Category** | Icon / badge |
| **Used on** | `community_feed`, `community_post_detail` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG + PNG |
| **Resolution** | 72 × 72 @3x |

> **Prompt:** Three small circular reaction chips, each a solid-filled circle containing a simple white
> pictogram at about 55 % of the diameter, flat with no gradient and a thin darker rim: **heart** — rose-red
> `#F43F5E` circle with a white heart; **paw** — lime-green `#A3E635` circle with a black paw print;
> **thumb** — blue `#3B82F6` circle with a white thumbs-up. Crisp at 22 pixels, designed to overlap in a
> stacked cluster. Isolated on fully transparent backgrounds, alpha channel, no text.

---

#### `CMN-1404` — Agility dog video thumbnail

| Field | Value |
|---|---|
| **Filename** | `cmn-agility-jump@3x.webp` |
| **Folder** | `assets/images/community/` |
| **Category** | Content photography |
| **Used on** | `community_feed` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 1200 × 900 @3x |

> **Prompt:** Photorealistic action photograph of a Border Collie leaping over a blue-and-yellow agility
> jump bar on a grass training field, captured mid-air with all four legs off the ground and ears lifted.
> Bright overcast daylight, shallow depth of field with a blurred green field behind, slight motion energy
> in the frame. Sharp on the dog's face. No people, no text, no visible branding on the equipment.

---

### 6.16 DOCUMENT ARTWORK — `DOC`

---

#### `DOC-1501` — PDF health-report page artwork ⭐

| Field | Value |
|---|---|
| **Filename** | `doc-pdf-report-template.svg` + `doc-pdf-page-thumb-{01..06}@3x.webp` |
| **Folder** | `assets/images/documents/` |
| **Category** | PDF artwork / template |
| **Used on** | `pdf_health_report_preview` |
| **Reusable** | Yes — the template drives every generated report |
| **Transparency** | No |
| **Format** | **SVG** for the live template; WEBP for the page thumbnails |
| **Resolution** | A4 vector; thumbnails 200 × 260 @3x |

> **Implementation note:** the report page shown in the mockup is **not an image** — it is a generated
> document. Only two things are true assets here: the **masthead lockup** (`BRD-002` + a "Pet Health Diary"
> descriptor rule) and the **six page thumbnails** used in the preview strip. The page body must be composed
> from live data.

> **Prompt (page thumbnails only)** *(rewritten 2026-07-30, finding V-22 — the report gains a per-row
> provenance tag and a footer legend band, which changes the page silhouette):* Six small vertical
> document-page thumbnails on a dark background, each showing a blurred, unreadable dark-themed report
> layout: a header band at the top, two or three rounded content cards with faint lime and grey horizontal
> lines standing in for text, and small coloured dots standing in for icons. Each content row ends with a
> very small pill-shaped tag mark at its right edge, and a narrow separated band sits at the foot of every
> page carrying three tiny pill marks in a row, standing in for a source legend. Deliberately illegible —
> this is a shrunken-page impression, not readable content. Slight variation in card arrangement between
> the six. No real text, no lettering, no logos.

---

#### `DOC-1502` — QR verification block

| Field | Value |
|---|---|
| **Filename** | *generated at runtime* |
| **Folder** | n/a |
| **Category** | Functional graphic |
| **Used on** | `pdf_health_report_preview` |
| **Reusable** | n/a |
| **Transparency** | n/a |
| **Format** | Generated |
| **Resolution** | 300 × 300 @3x |

> **Do not generate.** A QR code must encode a real verification URL. Produce it at runtime with a Dart QR
> package (`qr_flutter`) or server-side during PDF generation. An AI-generated QR-looking graphic is
> non-functional and actively harmful in a health-record context — a vet scanning it would get nothing.

---

#### `DOC-1503` — Lab-report document thumbnail

| Field | Value |
|---|---|
| **Filename** | `doc-lab-report-thumb@3x.webp` |
| **Folder** | `assets/images/documents/` |
| **Category** | Thumbnail / sample content |
| **Used on** | `add_health_record` |
| **Reusable** | Yes |
| **Transparency** | No |
| **Format** | WEBP |
| **Resolution** | 300 × 300 @3x |

> **Prompt:** A photorealistic square thumbnail of a printed laboratory report sheet lying flat on a neutral
> surface, photographed from directly above under soft even light. The page shows a header band, a small
> table grid and rows of fine printed lines that are deliberately too small and slightly out of focus to
> read. Clean white paper with a subtle shadow at the edges. **No legible text, no lettering, no logos, no
> patient names.**

---

### 6.17 BACKGROUNDS & DECOR — `BGD`

> These are **composable layers**, not per-screen artwork. Producing them once and tinting/scaling them in
> Flutter removes ~40 one-off background requests from the backlog.

---

#### `BGD-1601` — Paw-print confetti layer

| Field | Value |
|---|---|
| **Filename** | `bgd-paw-confetti@3x.png` |
| **Folder** | `assets/decor/` |
| **Category** | Background / decorative |
| **Used on** | `000`, `002`, `008`, `009`, `photo_analysis_upload` |
| **Reusable** | **Yes** |
| **Transparency** | Required |
| **Format** | PNG (also deliver an SVG variant for crisp scaling) |
| **Resolution** | 1600 × 1900 @3x (full-screen layer) |

> **Prompt:** A scattered decorative layer of paw prints on a fully transparent background. About eighteen
> paw prints, each with four toe beans and one main pad, distributed unevenly across a tall vertical frame
> with clear negative space through the middle third. The prints vary in size from small to medium and each
> is rotated to a different angle. They vary in opacity from faint to moderately bright, all in lime green
> `#A3E635` with a soft glow on the brighter ones. No repetition pattern, no grid, no text, alpha channel.

---

#### `BGD-1602` — Sparkle star set

| Field | Value |
|---|---|
| **Filename** | `bgd-sparkle-{sm,md,lg}@3x.png` |
| **Folder** | `assets/decor/` |
| **Category** | Decorative |
| **Used on** | 25 screens |
| **Reusable** | **Yes** |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | Vector; raster 48/72/108 @3x |

> **Prompt:** A four-point sparkle star with long tapering concave points — the classic "twinkle" shape —
> drawn as a solid filled shape in bright lime green `#A3E635` with a soft outer glow, perfectly
> symmetrical, on a fully transparent background. Deliver three sizes with identical proportions. No
> outline, no text, alpha channel.

---

#### `BGD-1603` — Hexagonal mesh network

| Field | Value |
|---|---|
| **Filename** | `bgd-hex-mesh@3x.png` |
| **Folder** | `assets/decor/` |
| **Category** | Background / technical texture |
| **Used on** | `003-onboarding` |
| **Reusable** | Yes (AI/technical surfaces) |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 1200 × 800 @3x |

> **Prompt:** An abstract technical network texture on a fully transparent background: a loose lattice of
> thin cyan `#22D3EE` lines forming irregular hexagonal and triangular cells, with small glowing nodes at
> the vertices. The mesh is densest at the lower left and fades out completely toward the upper right.
> Low opacity overall with a soft glow on the nodes. No text, no solid fills, alpha channel.

---

#### `BGD-1604` — Green aurora light ribbons

| Field | Value |
|---|---|
| **Filename** | `bgd-aurora-ribbons@3x.png` |
| **Folder** | `assets/decor/` |
| **Category** | Background / decorative |
| **Used on** | `007-onboarding` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 1600 × 700 @3x |

> **Prompt:** Flowing translucent ribbons of green light sweeping horizontally across a wide frame, like an
> aurora. Several overlapping bands of varying width and brightness, ranging from deep emerald to bright
> lime `#A3E635`, with soft edges and additive glow where they cross. Fine light particles drift among them.
> Fully transparent background with alpha channel, no hard edges, no text, no objects.

---

#### `BGD-1605` — Green radial glow

| Field | Value |
|---|---|
| **Filename** | `bgd-radial-glow@3x.png` |
| **Folder** | `assets/decor/` |
| **Category** | Background / lighting layer |
| **Used on** | 16 screens (behind every photographic cut-out) |
| **Reusable** | **Yes — the single most reused decor layer** |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 1200 × 1200 @3x |

> **Prompt:** A soft circular radial glow on a fully transparent background: bright saturated green
> `#22C55E` at the centre fading smoothly and evenly to complete transparency at the edges, with no visible
> banding and no hard boundary. Perfectly circular and symmetrical. Nothing else in the frame — no
> particles, no rings, no text. Alpha channel.
>
> *Note:* this can equally be implemented as a Flutter `RadialGradient` — prefer that if the team wants to
> avoid the asset. Specified here so the design intent is recorded either way.

---

#### `BGD-1606` — Concentric orbital rings

| Field | Value |
|---|---|
| **Filename** | `bgd-orbital-rings@3x.png` |
| **Folder** | `assets/decor/` |
| **Category** | Background / decorative |
| **Used on** | `002`, `004`, `005`, `006`, `ai_assistant_home`, `ai_analysis_loading`, `privacy_security` |
| **Reusable** | **Yes** |
| **Transparency** | Required |
| **Format** | PNG + SVG |
| **Resolution** | 1000 × 400 @3x |

> **Prompt:** Three thin concentric ellipses viewed at a shallow angle, as if looking across a horizontal
> plane, drawn in glowing cyan-green with a soft bloom on a fully transparent background. The rings grow
> progressively wider and fainter outward, brightest at the front edge and fading toward the back. No fill,
> no text, alpha channel. Clean neon line art.

---

#### `BGD-1607` — Giant paw watermark

| Field | Value |
|---|---|
| **Filename** | `bgd-paw-watermark@3x.png` |
| **Folder** | `assets/decor/` |
| **Category** | Background / watermark |
| **Used on** | `photo_analysis_upload`, `prepare_for_vet_visit` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | Vector; raster 900 × 900 @3x |

> **Prompt:** A single large paw print with four toe beans and one main pad, filled solid in a very dark
> desaturated grey at low opacity, softly blurred at the edges, tilted about 15 degrees. On a fully
> transparent background, alpha channel. No outline, no glow, no text — a subtle watermark only.

---

#### `BGD-1608` — Leaf sprigs

| Field | Value |
|---|---|
| **Filename** | `bgd-leaf-sprig-{left,right}@3x.png` |
| **Folder** | `assets/decor/` |
| **Category** | Decorative |
| **Used on** | `010-home-page` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | Vector; raster 120 × 120 @3x |

> **Prompt:** A small decorative sprig of two leaves on a short curved stem, drawn as a clean outline in
> lime green `#A3E635` with a uniform medium stroke, rounded tips and a soft glow, no fill. Deliver a
> left-leaning and a mirrored right-leaning version. On a fully transparent background, alpha channel, no
> text.

---

#### `BGD-1609` — Green smoke plumes

| Field | Value |
|---|---|
| **Filename** | `bgd-smoke-plumes@3x.png` |
| **Folder** | `assets/decor/` |
| **Category** | Background / atmospheric |
| **Used on** | `009-onboarding` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | PNG |
| **Resolution** | 1600 × 700 @3x |

> **Prompt:** Billowing volumetric smoke clouds rising from the bottom edge of a wide frame, lit from within
> so they glow green — deep emerald in the dense areas, bright mint at the illuminated edges. Soft, wispy,
> organic forms with fine detail and gradual falloff to complete transparency at the top. Fully transparent
> background with alpha channel, no hard edges, no objects, no text.

---

#### `BGD-1611` / `BGD-1612` / `BGD-1613` — Floating glyph layers

| Field | Value |
|---|---|
| **Filename** | `bgd-cross-watermark@3x.png`, `bgd-floating-hearts@3x.png`, `bgd-floating-crosses@3x.png` |
| **Folder** | `assets/decor/` |
| **Category** | Decorative |
| **Used on** | `000` / `006` / `ai_health_check_start` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | Vector |

> **Prompt:** Scattered decorative glyph layers on fully transparent backgrounds, each glyph drawn as a
> clean outline with a uniform stroke, varying in size and opacity, distributed unevenly with generous
> negative space and no repeating grid. **(a)** rounded medical crosses in very dark desaturated green at
> low opacity, as a subtle watermark. **(b)** outlined hearts in glowing cyan `#22D3EE`, five of them at
> different sizes with a soft bloom. **(c)** rounded medical crosses in bright lime `#A3E635`, three at
> different sizes with a soft glow. No fill, no text, alpha channel.

---

### 6.18 THIRD-PARTY MARKS — `TPB` ⛔ DO NOT GENERATE

---

#### `TPB-1701` — Google "G" logo

| Field | Value |
|---|---|
| **Filename** | `tpb-google-g.svg` |
| **Folder** | `assets/third-party/` |
| **Category** | Third-party brand mark |
| **Used on** | `000.png` (Continue with Google) |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | Vector |

> **⛔ No prompt.** Registered trademark. Source the official asset from Google Identity's *Sign in with
> Google* branding guidelines and follow the mandated button geometry, clear space and minimum size. An
> AI-approximated "G" is a trademark violation and will fail Play Console brand review.

---

#### `TPB-1702` — Payment network marks (5)

| Field | Value |
|---|---|
| **Filename** | `tpb-{visa,mastercard,amex,applepay,googlepay}.svg` |
| **Folder** | `assets/third-party/` |
| **Category** | Third-party brand marks |
| **Used on** | `subscription_plans` |
| **Reusable** | Yes |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | Vector |

> **⛔ No prompt.** Registered trademarks. Source from each network's official brand centre (Visa Brand
> Portal, Mastercard Brand Hub, Amex Partner Toolkit, Apple Pay Marketing Guidelines, Google Pay Brand
> Guidelines). Apple Pay and Google Pay marks additionally carry **mandatory usage rules** about placement
> and the surrounding claim — review before shipping the pricing screen.

---

#### `TPB-1703` — RevenueCat wordmark

| Field | Value |
|---|---|
| **Filename** | `tpb-revenuecat.svg` |
| **Folder** | `assets/third-party/` |
| **Category** | Third-party brand mark |
| **Used on** | `subscription_plans` ("Secure payment powered by RevenueCat") |
| **Reusable** | No |
| **Transparency** | Required |
| **Format** | SVG |
| **Resolution** | Vector |

> **⛔ No prompt.** Source from RevenueCat's press kit. **Also verify the claim is accurate** — RevenueCat
> is a subscription-management layer, not the payment processor; the payment is processed by Apple/Google.
> "Secure payment powered by RevenueCat" as written is misleading and should be reworded regardless of the
> asset.

---

## 8. Asset Dependency Map

### 8.1 Casting-reference chains (generate the parent, then derive)

These are **hard dependencies**: the child asset must be generated using the approved parent as an image
reference, or the cast will drift visibly between screens.

```
PET-210  Buddy hero cut-out            ← APPROVE FIRST, this is the casting anchor
  ├── PET-211  Buddy circular avatar                 (18 screens)
  ├── PET-212  Buddy park portrait                   (2 screens)
  ├── PET-213  Buddy grass golden hour               (1 screen)
  ├── PET-219  Buddy-in-shield composite             (2 screens)
  ├── AI-303   AI scan HUD — photo layer             (1 screen)
  ├── AI-304   Loading scan composite — photo layer  (1 screen)
  ├── EMG-609  First-aid hero banner ♻️ rewritten     (1 screen)
  ├── INF-502  Photo-quality examples ×3             (1 screen)
  ├── INF-503  Anatomy macro set ×4                  (1 screen)
  ├── EMG-607  Lesion photo ⚠️ blocked                (1 screen)
  ├── MEM-1201 Memory library ×24                    (6 screens)
  ├── CMN-1402 Promenade posts ×3                    (3 screens)
  └── BRE-1302 Encyclopedia hero portrait            (2 screens)

HERO CAT (defined inside PRM-711)
  ├── PET-214  Milo tabby avatar                     (5 screens)
  ├── ONB-101/102/107/108/109/110  onboarding pairs  (6 screens)  ← kitten variant
  └── PET-201–205 species selector (cat card)        (1 screen)

PET-216  Luna rabbit avatar
  └── PET-201–205 species selector (rabbit card)

BDG-901  Hex frame (unlocked)  +  BDG-903  inner icons ×6
  └── 6 composed achievement badges + 6 locked variants   ← composite, do not generate 12 badges

ICN-801  Core SVG icon set  (currentColor)
  ├── ICN-801-lime   runtime tint    (48 screens)
  ├── ICN-801-red    runtime tint    (ai_analysis_result_emergency — full re-skin)
  └── ICN-810        nav variants A/B derived from the same glyphs

BRD-001  Logo mark
  ├── BRD-002  horizontal lockup
  ├── BRD-003  app icon
  └── BRD-006  push icon (recoloured)
```

### 8.2 Layer-composition dependencies (multi-file assets)

Assets that **must ship as separate layers** so Flutter can animate or recolour them:

| Composite | Layers | Why |
|---|---|---|
| `AI-303` AI scan HUD | photo + HUD overlay | HUD must animate (scan beam sweep) |
| `AI-304` Loading ring | masked portrait + progress arc | arc must animate 0→100 % |
| `MAP-1103` Walk route | base map + route polyline | route is drawn from live GPS |
| `ONB-104` Device frame | frame with transparent screen | screenshots composite inside |
| `BDG-901/903` Achievements | frame + inner icon | 6 icons × 2 states from 2 frames |
| `EMG-604` Clinic photos | photo with **blank** sign panel | signage text is localised |
| `DOC-1501` PDF template | masthead only | page body is generated from data |

### 8.3 Cross-system twins (same geometry, two palettes)

Generate the geometry once, recolour for the second system — do **not** commission twice:

| Geometry | System A (cyan/emerald) | System B (lime) |
|---|---|---|
| Robot mascot | `AI-301` cyan | `AI-301b` lime |
| Paw-in-circle + plus | `ONB-117` cyan | `ONB-116` green |
| Shield + paw | `ONB-111` teal 3D | `PRM-709` lime 3D |
| Feature glyph quartet | `ONB-121` cyan/green | `ONB-133` multi-hue |
| Notebook + paw | `ONB-115` cyan | `ONB-132c` violet |
| Logo lockup | stacked, emerald | horizontal, lime |

### 8.4 Blocking chains (asset ← decision)

```
RESOLVED 2026-07-30 — UI_SAFETY_CONTRACT_REVIEW.md closed the asset-blocking chains:
  C-5 ─✅─→  AI-306 rewritten as EMG-609, hold released
  C-3 ─✅─→  EMG-607 prompt rewritten, hold released
  C-6 ─✅─→  EMG-604 ×3 cleared (clinic photos are help-contact content either way)
  C-4 / C-7 remain owner decisions but block NO asset — copy and navigation only

STILL BLOCKING:
§9.4 casting decision     ──blocks──→  PET-215, PET-217, PET-218   (name/species collisions)
Map SDK decision (§6.12)  ──blocks──→  MAP-1101/1102/1103/1104     (raster vs style JSON)
Memory-seed decision      ──blocks──→  MEM-1201 ×24                (sample content vs empty state)
```

### 8.5 Reuse graph — highest-leverage assets

Ordered by screens served per asset generated:

| Rank | Asset | Screens served |
|---|---|---|
| 1 | `ICN-801` core icon set | 57 |
| 2 | `ICN-810` nav sets | 42 |
| 3 | `BGD-1602` sparkles | 25 |
| 4 | `PET-211` Buddy avatar | 18 |
| 5 | `BGD-1605` radial glow | 16 |
| 6 | `PRM-707` crown | 8 |
| 7 | `PET-210` Buddy hero | 7 |
| 8 | `BGD-1606` orbital rings | 7 |
| 9 | `PRM-709` 3D shield + paw | 6 |
| 10 | `MEM-1201` memory library | 6 (41 slots) |
| 11 | `AVT-1005` community avatars | 3 |
| 12 | `ICN-802` symptom set | 4 |

---

## 9. Generation Priority

Six waves. Each wave is gated on the previous one being **visually approved**, because later waves depend
on earlier casting and material decisions.

### P0 — Blocking decisions (no generation; owner only)

> **UPDATE 2026-07-30 —** the first two rows are now **closed**. `UI_SAFETY_CONTRACT_REVIEW.md` supplies
> exact replacement copy for all 24 violations and rewritten prompts for the affected assets. No asset in
> this backlog is blocked any longer; C-4, C-6 and C-7 survive as copy/structure decisions only.

| Item | Decision needed | Blocks |
|---|---|---|
| ~~C-3, C-5~~ | ✅ **CLOSED** — resolved by review findings V-05/V-06 and V-17; `EMG-607` and `EMG-609` prompts rewritten | *nothing* |
| ~~C-1, C-2~~ | ✅ **CLOSED** — resolved by review findings V-01–V-04 and §3.1; UI copy only, no asset impact | *nothing* |
| C-4, C-6, C-7 | Emergency-surface scope (AI triage tile, Heat Alert strip) and the Premium-vs-Emergencies nav slot. Proposals in review V-16 and V-24. | *nothing* — copy and navigation only |
| §9.4 casting | Which pet is Luna / Milo / Coco? | `PET-215`, `PET-217`, `PET-218` |
| Map strategy | Live SDK with a dark style, or static raster previews? | `MAP-1101`–`MAP-1104` |
| Memory seeding | Ship 24 sample photos, or an empty state? | `MEM-1201` (24 files) |
| Icon strategy | Confirm SVG-authored core set (recommended) vs generated | `ICN-801`, `ICN-810` |

**These are cheap to decide and expensive to get wrong.** P0 costs nothing but unblocks 35 files.

---

### P1 — Foundation (must exist before anything else looks right)

*Target: 6 assets / ~150 files. Everything downstream references these.*

| Order | ID | Asset | Files |
|---|---|---|---|
| 1 | `BRD-001` | Logo mark | 4 |
| 2 | `BRD-002` | Logo lockup (2 arrangements) | 6 |
| 3 | `ICN-801` | Core icon set — **author, don't generate** | ~140 |
| 4 | `ICN-810` | Nav sets A + B | 22 |
| 5 | `PET-210` | **Buddy hero cut-out — the casting anchor** | 3 |
| 6 | `PRM-711` | Dog + cat premium duo — **defines the hero cat** | 3 |

> Gate: `PET-210` and `PRM-711` must be signed off before **any** other pet photography is generated.
> Every later pet asset uses them as an image reference.

---

### P2 — Core product surfaces (the screens users hit every session)

*Target: 24 assets / ~90 files.*

| ID | Asset | Rationale |
|---|---|---|
| `PET-211`, `PET-214`, `PET-216` | Pet avatars | 18 / 5 / 4 screens |
| `PET-212`, `PET-213` | Buddy content photos | Result + onboarding |
| `AI-302` | AI assistant avatar | Every AI message |
| `AI-304` | Loading scan composite | Core triage flow |
| `ICN-802` | Symptom pictograms ×24 | Core triage flow, safety-critical |
| `ICN-812` | Record-type tiles ×8 | Timeline, home, records |
| `BGD-1602`, `BGD-1605`, `BGD-1606` | Sparkles, radial glow, orbital rings | 25 / 16 / 7 screens |
| `BGD-1601`, `BGD-1607` | Paw confetti, paw watermark | 5 / 2 screens |
| `PRM-707` | Crown | 8 screens |
| `EMG-601`, `EMG-602`, `EMG-603` | Emergency beacon, call ring, alert shield | Safety path |
| `ICN-806`, `ICN-808`, `ICN-811` | Action / medication / vitals icons | Records + assistant |
| `ILL-401`, `ILL-402`, `ILL-412` | Core doodles | 3 / 3 / 3 screens |
| `INF-502`, `INF-503`, `INF-504` | Capture guidance + clinical thumbs | Triage flow |
| `BDG-904` | Verified badges | Profile + community |

---

### P3 — Onboarding & first-run (System A)

*Target: 22 assets / ~55 files. High impact on conversion, but only seen once.*

`ONB-101` · `ONB-102` · `ONB-104` · `ONB-107` · `ONB-108` · `ONB-109` · `ONB-110` · `ONB-111` · `ONB-112`
· `ONB-113` · `ONB-114` · `ONB-115` · `ONB-116` · `ONB-117` · `ONB-118` · `ONB-121` · `ONB-122`–`ONB-135`
· `AI-301` (robot mascot ⭐) · `AI-303` · `PET-201`–`PET-205` (species cards ⭐) · `AVT-1001` · `BRD-005`
· `BGD-1603`, `BGD-1604`, `BGD-1609`, `BGD-1611`–`BGD-1613` · `EMG-608`

> Generate `AI-301` and `PET-201`–`PET-205` early in this wave — the robot is the AI brand character and
> the species cards are reused by `BRE-1301`.

---

### P4 — Monetisation & settings

*Target: 15 assets / ~30 files. Revenue-bearing, and the 3D style is a single self-contained batch.*

`PRM-701`–`PRM-706` (the six 3D feature illustrations — **generate as one batch, shared seed**) ·
`PRM-708` · `PRM-709` · `PRM-710` · `PRM-712` · `PRM-713` · `ICN-807` · `ICN-816` · `AVT-1003` ·
`TPB-1701`–`TPB-1703` (**source, don't generate**)

---

### P5 — Content & community

*Target: 20 assets / ~75 files. Rich, but the app is functional without them.*

`MEM-1201` ×24 · `AVT-1002`, `AVT-1004`, `AVT-1005` ×6, `AVT-1006`, `AVT-1007` · `CMN-1401` ⭐ ·
`CMN-1402` ×3 · `CMN-1403` · `CMN-1404` · `BRE-1301` ×2 new · `BRE-1302` · `BRE-1303` ×4 · `MAP-1101`–
`MAP-1106` · `ICN-813`, `ICN-814` · `DOC-1503`

---

### P6 — Depth & polish

*Target: 18 assets / ~50 files.*

`ICN-803` (anatomy ×12) · `ICN-804` (vaccine tiles ×8) · `ICN-805` (first-aid tiles ×8) · `ICN-809`
(3D weather ×8) · `ICN-815` · `BDG-901`–`BDG-908` (achievement system) · `ILL-403`–`ILL-411` (remaining
doodles) · `INF-501` (size infographic) · `EMG-605`, `EMG-606` · `PET-215`, `PET-217`, `PET-218`,
`PET-219` · `AI-305` (hologram ⭐) · `DOC-1501` · `BGD-1608`

---

### 9.4 Open product questions that must be answered before P2/P6

1. **Pet cast.** `Luna` is a rabbit on home but a Golden Retriever on four other screens; `Milo` is a dark
   tabby on home but a white British Shorthair on the pets screens; `Coco` is a rabbit on the pets screens
   but a toy poodle in the community. Pick one casting per name. Cost of getting it wrong: 4 regenerated
   photo assets and a credibility hit on a health app.
2. **Language.** `smart_walks` and `weather_walk_advisor` are in Turkish; every other screen is in English.
   No asset carries baked-in text in this specification (deliberately) — confirm that all copy stays in
   Flutter so localisation is not blocked by artwork.
3. **Sample content.** `MEM-1201` (24 photos), `CMN-1402`, `AVT-1005` and `EMG-604` are seed content shown
   before the user has data. Decide whether they ship as samples, demo-mode-only, or are replaced by empty
   states. A health app showing photos the user never took is a trust problem.
4. **Nav variant.** Two different 6-slot bottom bars appear across the mockups (see `ICN-810`). One must
   win — and per conflict C-7, the emergency entry point must survive whichever wins.

---

## 10. Handover Checklist

Before generation begins:

- [ ] Owner has ruled on conflicts **C-1 – C-7** (§1.6)
- [ ] Pet casting locked (§9.4.1)
- [ ] Map strategy decided — SDK style vs raster (§6.12)
- [ ] Memory-seeding decided (§9.4.3)
- [ ] Nav variant chosen (§9.4.4)
- [ ] Icon pipeline confirmed as **authored SVG** for `ICN-801` / `ICN-810` (§7.0)
- [ ] Third-party marks requested from official brand kits — **not generated** (§6.18)
- [ ] Background-removal step budgeted for all 61 transparent raster assets (§7.0)
- [ ] `PET-210` + `PRM-711` approved before any derived pet photography (§8.1)

During generation:

- [ ] Every derived pet asset generated with its parent as an image reference
- [ ] `PRM-701`–`PRM-706` generated as one batch with a shared seed
- [ ] `ICN-802`, `ICN-804`, `ICN-805`, `ICN-809` each generated as one batch for family consistency
- [ ] No asset contains baked-in text, lettering, signage or numerals
- [ ] Human avatars verified as non-identifiable and diverse
- [ ] `EMG-604` sign panels delivered blank

Before hand-off to Flutter:

- [ ] `@1x` / `@2x` / `@3x` ladders exported for every raster asset
- [ ] WEBP quality audited (q90 heroes, q80 content photos)
- [ ] All SVGs exported with `stroke="currentColor"` where tinting is required
- [ ] Total bundle-size impact measured against the current APK/AAB baseline
- [ ] Asset-ID → Dart constant map authored (`app_assets.dart`)

---

## 11. Revision History

### r2 — 2026-07-30 · Safety-contract refinement pass

Driven by **`UI_SAFETY_CONTRACT_REVIEW.md`** (24 violations across 19 screens). Changes to this document:

| § | Change |
|---|---|
| §1.6 | Conflict table gains a `Status` column. C-1, C-2, C-3, C-5 **closed**; C-4, C-6, C-7 downgraded to owner decisions that block no asset. |
| §5 | `first_aid_guide` row: `AI-306` → `EMG-609`, ⚠️ removed. |
| §6.4 `AI-303` | Layer-2 prompt **rewritten** — landmark mesh and biometric tracking points removed (review V-14). |
| §6.4 `AI-306` | **Rewritten and reclassified → `EMG-609`.** HUD/radar/scan-line treatment removed; folder `images/ai/` → `images/emergency/`; filename → `emg-firstaid-banner@3x.webp`; HOLD released (review V-17). |
| §6.7 `EMG-604` | HOLD released — clinic photos are help-contact content (review V-16). |
| §6.7 `EMG-607` | Prompt **rewritten** — lesion depicted as an observable injury, not an infection; HOLD released (review V-05/V-06). |
| §6.16 `DOC-1501` | Thumbnail prompt **rewritten** — page silhouette gains provenance tags and a legend band (review V-22). |
| §8.4 | Blocking chains updated: three of the four asset-blocking chains are closed. |
| §9 P0 | C-1/C-2 and C-3/C-5 rows closed. |

**Net effect on the backlog:** 4 prompts rewritten, 1 asset renamed and reclassified, 3 holds released.
Asset ID count is unchanged at 157 (`AI-306` is retained as an alias of `EMG-609` so existing references
resolve). **No asset in this backlog is blocked by a safety conflict any longer.**

### r1 — 2026-07-29 · Initial specification

57 screens analysed; 157 asset IDs / ≈560 files specified across 125 entries.

---

**End of specification.** No assets have been generated, no Flutter code has been written, and no UI has
been implemented. Awaiting instruction before proceeding to generation or implementation.

**Companion documents**
* `UI_SAFETY_CONTRACT_REVIEW.md` — safety violations, replacement copy, confidence-percentage review
* `UI_ASSET_PROMPT_LIBRARY.html` — searchable, filterable, copy-to-clipboard prompt library (offline, self-contained)

