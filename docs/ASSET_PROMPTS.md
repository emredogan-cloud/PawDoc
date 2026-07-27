# Missing asset audit + generation prompts

Every illustration in PawDoc renders through `AppImage`, which swaps in a themed
fallback when the file is absent. Nothing is broken today — but the assets below
are *referenced by code and not present*, so users currently see the fallback
instead of designed art.

**Drop-in works.** Save a generated file at the exact path and the app uses it on
the next build; no code change. `assets/icons/species/` is registered in
`pubspec.yaml` for exactly this reason (it was missing from the bundle list, so
files placed there would previously have been ignored — fixed in this program).

> **Do not generate these yourself from this file alone** — read the shared
> style block first; consistency across the set matters more than any single image.

## Shared style (prepend to every prompt)

```
Children's-book style digital illustration for a calm, trustworthy pet-health app.
Soft rounded shapes, gentle hand-painted texture, warm friendly character, no harsh
edges. Palette: deep teal-green (#0A1A22, #123B33), mint (#7FE3C4), soft cream
(#F5EFE2), warm coral accents (#FF8A7A) used sparingly. Even, diffuse lighting; no
dramatic shadows. Absolutely NO text, NO letters, NO numbers, NO logos, NO
watermarks, NO UI chrome, NO medical readouts or vital-sign panels. Not photorealistic.
Centred subject with generous margin so it reads at small sizes.
```

The "no numbers / no medical readouts" clause is not stylistic. PawDoc never
shows a measured vital, never names a condition and never says a pet is "normal";
art that implies otherwise contradicts the product's safety copy.

---

## 1. Species icons — 7 files (HIGHEST VALUE)

**Screens:** the species picker chips in onboarding and the Add/Edit-pet form
(`species_chip.dart`), and the pet avatar for every reduce-motion user
(`living_pet_avatar.dart` → `_staticPng`).

**Why it matters:** these are the only missing assets on a path a *new user* hits
in their first minute. Today each chip renders an emoji (🐶 🐱 🐰 🐹 🦜 🦎 🐾),
which is legible but off-brand and inconsistent across Android OEM emoji fonts —
the same chip looks different on Samsung, Xiaomi and Pixel.

| File | Folder | Subject |
|---|---|---|
| `species_dog.png` | `mobile/assets/icons/species/` | dog |
| `species_cat.png` | `mobile/assets/icons/species/` | cat |
| `species_rabbit.png` | `mobile/assets/icons/species/` | rabbit |
| `species_guinea_pig.png` | `mobile/assets/icons/species/` | guinea pig |
| `species_bird.png` | `mobile/assets/icons/species/` | parrot / small bird |
| `species_reptile.png` | `mobile/assets/icons/species/` | friendly gecko / lizard |
| `species_other_paw.png` | `mobile/assets/icons/species/` | generic paw mark |

- **Dimensions:** 512 × 512 px
- **Background:** **transparent** (PNG-32). They sit on both the dark chip and
  the light avatar disc.
- **Style:** head-and-shoulders portrait, front-facing, friendly neutral
  expression, filling ~80% of the canvas.

**Prompt** (repeat per species, swapping the subject line):

```
<shared style block>

A friendly <SPECIES> head-and-shoulders portrait icon, front-facing, warm neutral
expression with soft eyes, filling about 80% of a square canvas with even margin
on all sides. Simple flat-shaded rendering with gentle soft-brush shading, thick
soft outlines, no background whatsoever — fully transparent. The character should
read clearly at 44 pixels wide. Consistent proportions and line weight with a
matching set of seven animal icons (dog, cat, rabbit, guinea pig, bird, reptile,
paw mark).
```

For `species_other_paw.png` substitute:

```
A simple, friendly paw print mark — one large pad and four toe pads, soft rounded
shapes, mint-to-teal gradient fill, thick soft outline, fully transparent
background, centred with even margin, readable at 44 pixels wide.
```

**Acceptance:** drop the seven files in, rebuild, and confirm the picker chips
and the reduce-motion avatar show art instead of emoji. `flutter test` must stay
green (`species_chip` tests assert the fallback path only when the asset is
absent).

---

## 2. Dead declarations — removed, no art needed

These constants were declared but referenced by **zero** screens, and their files
never existed. Generating art for them would add weight nothing renders, so the
declarations were deleted rather than filled:

| Removed constant | Path it claimed |
|---|---|
| `AppAssets.splashLogo` | `assets/brand/splash_logo.png` — the native splash is configured separately via `flutter_native_splash` (`assets/icon/app_icon.png`) |
| `AppAssets.sysOffline` | `assets/illustrations/system/system_offline_v1.png` — superseded by `offlineCompanion`, which exists and *is* used |
| `AppAssets.statusEmergency` / `statusMonitor` / `statusNormal` | `assets/icons/status/*` — the action ladder renders icon + colour + text from code; a `status_normal` glyph would also contradict "never render normal" |
| `AppAssets.avatar(key)` | `assets/icons/avatars/avatar_*.png` — no caller |

If a future screen wants any of them, re-declare and generate then.

---

## 3. Verified present — no action

All other declared art exists on disk: 29 illustrations (onboarding, analysis,
empty states, monetization, premium, results, system) and all 9 motion assets
(8 Lottie + the Paw Pals `.riv` rig). The AI Assistant portrait
(`assets/ai-assistans/ai_assistant_avatar.png`) was produced during this program
from the founder-supplied character art.

---

## How to add a new asset later

1. Put the file at the path `AppAssets` declares.
2. If it lives in a folder not already listed under `flutter: assets:` in
   `mobile/pubspec.yaml`, add the folder — otherwise the file is on disk but not
   in the bundle, and the app silently keeps using the fallback.
3. `flutter test` — `motion_assets_test.dart` enforces the per-file size budget.
