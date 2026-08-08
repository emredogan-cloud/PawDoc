# PawDoc — ASO asset production workflow

**Written:** 8 August 2026 · **Listing:** Google Play, `app.pawdoc`, en-US only.

Eight phases, A → H. Phases A–C produce artwork; **D–E are a scripted pass that must run
before any human looks at the result**; F–H are the Console and the final audit.

The prompts live in [`PAWDOC_PLAY_STORE_ASO_PROMPT_LIBRARY.html`](./PAWDOC_PLAY_STORE_ASO_PROMPT_LIBRARY.html).
This file is the process around them.

> **The one sentence to keep.** Every pixel in a store asset is a claim about the product,
> and every claim must be traceable to the source code. Beauty is not evidence. Verify
> against `mobile/lib/`, not against taste.

---

## Phase A — Research *(done; recorded here)*

### A.1 The existing PawDoc assets — audit result

`ASO-image/PlayStore-ASO/` holds eight files. **Every one of them is blocked.**
They were inspected at full resolution and every claim was checked against the codebase.

| File | Dimensions | Format | Verdict |
|---|---|---|---|
| `001.png` | 941×1672 | RGBA | 🔴 Blocked — 5 claim defects + device + format |
| `002.png` | 941×1672 | RGBA | 🔴 Blocked — 6 claim defects + device + format |
| `003.png` | 941×1672 | RGBA | 🔴 Blocked — 5 claim defects incl. a named diagnosis |
| `004.png` | 941×1672 | RGBA | 🔴 Blocked — 4 claim defects + a 2025 calendar |
| `005-feature-graphic.png` | 1672×941 | RGBA | 🔴 Wrong size for a feature graphic (needs 1024×500) |
| `007-app-logo.png` | 1254×1254 | RGBA | 🔴 Wrong size for an icon (needs 512×512) |
| `play-store-feature-graphic.png` | 1024×500 | RGB | 🔴 Correct size — **highest-risk asset in the project** |
| `play-sore-logo.png` | 512×512 | RGB | 🔴 Correct size — structural icon defects |

#### The findings

**F-1 · A "Health Score" the product deliberately refuses to compute** — 🔴 HIGH
`001.png` draws **"Health Score · 92 /100 · Excellent"**; the feature graphic draws **98**.
This exact element was *rejected by name* as decision **D-2**
(`mobile/lib/src/pets/pet_profile_screen.dart:54`): *"A number that reads as a verdict on an
animal's health, with nothing behind it, is exactly the reliance the product must not
invite."* What the app draws instead is a **Care Score** — record completeness, banded in
words. A number the app refuses to show, shown in the listing, is both a fabricated metric
and a direct contradiction of the product's own safety reasoning.

**F-2 · Normality verdicts** — 🔴 HIGH
"Today's Overview · **All Good!**" with green ticks on Activity / Nutrition / Hydration /
Mood (`001`, feature graphic); "**Great job!** Buddy is in great shape" (`004`);
"**All medications up to date!**" (`004`); "this condition appears to be **mild**" (`002`).
PawDoc's action ladder has **no "do nothing" rung** and the app may never render
"normal" (contract v2, `CLAUDE.md`). For a triage product whose stated #1 business risk is
a false negative, a listing that tells owners their pet is fine is the most damaging thing
in the set.

**F-3 · A named diagnosis and a cause** — 🔴 HIGH
`003.png`: "Auto-detect: **Skin Issue**", "**Mild skin irritation detected.** Likely caused
by **allergens or moisture**." That is a diagnosis and an aetiology. The contract forbids
naming a condition; Play's Health Content &amp; Services policy expects a non-medical-device
app to disclaim exactly this.

**F-4 · A confidence figure, twice, with an accuracy claim** — 🔴 HIGH
`003.png`: "**AI Confidence 96%**", "**High accuracy** AI analysis **you can trust**".
`CLAUDE.md`: *"`confidence` is never shown to users."* The app computes it and deliberately
withholds it. "High accuracy … you can trust" is additionally an unsubstantiated
performance claim about a model.

**F-5 · Fabricated social proof** — 🔴 HIGH
Feature graphic: "**Trusted by pet parents**" over **four photorealistic human faces**,
**★★★★★**, "**10K+ Happy Pets**". PawDoc is pre-launch with zero users. Three separate
fabrications — a rating, a user count, and four invented user identities — in the asset at
the top of the listing.

**F-6 · Risk levels that do not exist** — 🟠 MEDIUM
`002.png` shows "**LOW RISK · Keep Monitoring**" and "**HIGH RISK · Visit Vet Immediately**"
*simultaneously, on one screen*. PawDoc has four action labels — `GET HELP NOW`,
`CALL YOUR VET TODAY`, `BOOK A ROUTINE VISIT`, `WATCH AND RE-CHECK` — and no risk scale at
all. Two contradictory results on one screen also reveals the asset as mocked up.

**F-7 · Support and availability claims** — 🟠 MEDIUM
"**24/7 Support** — get guidance anytime, anywhere" (`002`). There is no support team.
"**24/7 AI Triage** — always here" — the AI path needs a network; only the *emergency*
path is offline.

**F-8 · Wrong platform hardware, in all six device assets** — 🟠 MEDIUM
Every mockup is an **iPhone with a Dynamic Island** and an iOS status bar reading **9:41**,
in an Android listing.

**F-9 · A navigation bar the app does not have** — 🟠 MEDIUM
The assets draw *Home / History / Reminders / Profile* (and in `004`, five tabs with
*Diary*). The real bar is **Home / Pets / Health / Emergency** plus a centre action ring
(`core/paw_nav_bar.dart`). **Emergency — the app's strongest honest differentiator — is
absent from every screenshot.**

**F-10 · A stale year** — 🟠 MEDIUM
`004.png` shows a **May 2025** calendar and a "May 28, 2025" appointment, on a listing being
prepared in August 2026.

**F-11 · Medical imagery and a protected emblem** — 🟡 LOW→MEDIUM
A green wireframe dog skeleton hologram (`003`), a photorealistic bloody wound (`002`), and
a **red cross** used as the emergency glyph across several assets. The red cross is a
protected emblem in many jurisdictions and additionally implies a clinic PawDoc does not
operate.

**F-12 · Format defects** — 🔴 blocks upload
All four screenshots are **941×1672 RGBA**. Play requires **no transparency**; 941 px is
below the 1080 px short side that gates promotional eligibility; and 941×1672 is not 9:16.
*(This is the identical defect the FormAI set shipped — same source resolution, same alpha
channel.)*

**F-13 · Icon structure** — 🔴 blocks quality
`play-sore-logo.png` has **pre-rounded corners with a visible border**, and dark square
corners behind them. Play applies **its own** rounded mask: the border is clipped into four
disconnected arcs and the square corners show through. It is also a photograph of a puppy
and a kitten wrapped in a **stethoscope** — unreadable at 48 px, and implying a veterinary
service.

**F-14 · Brand drift** — 🟡 LOW
Three taglines across four assets: "Healthier pets, happier lives.", "Smarter care. Happier
pets.", "Healthier pets. Happier lives." Pick one.

#### Conclusion

**Regenerate all ten assets.** Not correct — regenerate. Twelve of the fourteen findings are
compositional, a device frame, or a claim baked into the concept, which is the class that a
correction pass reintroduces.

### A.2 What the FormAI reference set teaches

`/home/emre/Downloads/FormAI-FitnessKoçu/playstore-new-ASO/FINAL/en-US/` — eight
`1080×1920` **RGB** screenshots, a `1024×500` feature graphic, a `512×512` icon.

**Worth copying:**

- **The format discipline.** 1080×1920, RGB, no alpha, consistent across the set, produced
  by a script rather than by hand. PawDoc's current set fails all four.
- **The trust bar.** FormAI's slot 1 closes on three honest capability statements
  (*on-device form analysis · no frame uploaded · report any reply*). PawDoc's equivalents
  are stronger and truer: *emergency works offline · never metered · never paywalled*.
- **The AI treatment.** An abstract violet orb labelled "AI assistant", with a permanent
  disclosure strip — never a human portrait. Slot 7's prompt copies this exactly.
- **One number per concept, held constant across the whole set.**
- **Real UI inside the phone**, matching the shipped layout and the real nav labels.

**Deliberately not copied:**

- **The density.** FormAI's slot 1 carries a headline, three ticks, five glass cards, a
  phone, a chart, four metrics and a three-part trust bar. At carousel size almost none of
  it is legible. PawDoc's prompts cap text elements at nine.
- **The hero figure.** A photorealistic muscular man dominates the frame. PawDoc's subject
  is the record, not a body; and a photorealistic *pet* invites the same "is this a real
  user's animal?" question a face does.
- **The neon-glass aesthetic.** For a product whose credibility rests on refusing to
  overclaim, restraint is the differentiator. PawDoc's plates are dark and typographic.
- **The green "87% FORM SCORE" gauge.** A score is exactly what PawDoc's D-2 decision
  forbids.

### A.3 The claim-traceability rule

Before accepting any asset, every element that carries meaning must trace to one of four
sources:

1. **Real shipped UI** — this screen exists, at this layout, in this build.
2. **Real computed data** — this number comes from code that computes it.
3. **Real product behaviour** — this sentence describes what the code does, *with the same
   scope*.
4. **Valid marketing framing** — a benefit statement with no factual or outcome claim.

Anything traceable to none of the four is a fabrication and is removed, however good it
looks. **Check the quantifier, not just the noun**: most failures are true-but-widened.

---

## Phase B — Generate

1. Open the prompt library. Work one slot at a time, in order.
2. For each: paste the slot prompt, then paste the **canonical state block** where the
   prompt says `<paste the canonical state block>`, then paste the **PROHIBITED CONTENT**
   block where it says `<same block as slot 1>`. The blocks are repeated per asset on
   purpose — a rules section at the top of a document does not constrain a generator.
3. Generate **at native resolution**, whatever the model gives you (941×1672 is fine —
   Phase D handles the canvas). Do **not** ask the model for 1080×1920 and accept a
   letterboxed or stretched result.
4. Save to `ASO-image/generated/` as `NN-slug.png` (`01-result.png` … `08-free.png`,
   `feature.png`, `icon.png`). **Never overwrite the generated originals** — Phase D reads
   them and never writes to them.
5. Regenerate immediately, before moving on, if the output contains any of: an Apple
   device, a number not in the canonical state, a nav label that is not one of the four, a
   face, a star, or a price.

---

## Phase C — Human review

Read each asset at 100% zoom, and answer the 20-row checklist in §19 of the prompt library.
Two passes that catch different things:

- **Per-asset pass** — does every element belong to *this* screen? (Content migrates
  between frames when a set is generated in one session. Neither a policy check nor a
  design check catches it; only a coherence check does.)
- **Cross-set pass** — is the tagline identical everywhere? Is the nav bar identical? Is
  Biscuit 3 years old in all four assets that mention him?

**An audit finding is a hypothesis until the code confirms it — including your own.** Before
recommending a change, grep for the truth. A previous project nearly "fixed" a correct
navigation label into a wrong one because two assets disagreed and the wrong one was
assumed right.

---

## Phase D — CLI processing *(required; do not run before Phase C)*

> **This phase is mandatory and has not been run.** It must run *after* the images exist and
> *before* any upload. The prompt to run it is at the end of this document.

### D.1 The pipeline principle

```
GENERATE → VALIDATE → REPAIR → NORMALIZE → VERIFY → EXPORT
```

Two committed scripts, and the second must be **independent of the first**:

| Script | Job |
|---|---|
| `tool/playstore_asset_pipeline.py` | Reads `ASO-image/generated/` (read-only), applies pixel repairs at native resolution, re-canvases to the Play target, flattens alpha, strips metadata, writes `ASO-image/FINAL/en-US/` from scratch on every run |
| `tool/validate_play_assets.py` | Re-opens every **output** and asserts Play's published rules from scratch. Catches both a pipeline bug and a file hand-edited afterwards |

A tool that validates its own output only proves it is self-consistent.

### D.2 Order of operations — and why it is not negotiable

**Repair before resampling.** A patch applied after upscaling is pixel-sharp against
surroundings the resample has softened, and reads as an obvious paste. Generated sources
here will be ~941 px wide against a 1080 px target — a 1.15× upscale — so a repair and its
surroundings must go through the same Lanczos pass.

**Measure coordinates; never guess them.** Every constant comes from a luminance-threshold
bounding-box pass over the source. Eyeballed boxes produce visible bands and streaks.
Device mockups are also usually *tilted* — measure the angle off a text baseline before
rendering any replacement glyph run.

### D.3 Toolchain on this machine (VERIFIED 8 Aug 2026)

| Tool | Present | Role |
|---|---|---|
| `python3` + **Pillow 10.2.0** | ✅ | Load, inspect, resample, composite — the backbone |
| `numpy` | ❌ **missing** | Per-pixel repair maths. Install into a venv |
| ImageMagick (`convert`, `identify`) | ✅ | Inspection crops and zooms during review only — not for output |
| `oxipng` / `optipng` | ❌ missing | Lossless recompression |
| `exiftool` | ❌ missing | Strip EXIF/XMP that Pillow leaves behind |
| `pngquant` | ❌ missing | **Deliberately unwanted.** Lossy palette quantisation bands the dark gradients these plates are made of, and there is 4× headroom against Play's 8 MB limit. Installing a tool is not a reason to use it |

`pip` is PEP 668-blocked on this distro; a venv is the supported path:

```bash
python3 -m venv ~/.cache/pawdoc-tools/venv
~/.cache/pawdoc-tools/venv/bin/pip install pillow numpy pyoxipng
```

If a package needs a system binary and there is no passwordless sudo:

```bash
apt-get download exiftool
dpkg-deb -x exiftool_*.deb ~/.cache/pawdoc-tools/prefix
```

### D.4 What the pipeline must do

1. **Read-only sources.** Never write to `ASO-image/generated/`.
2. **Repair** at native resolution: mis-rendered glyphs, off-by-one counted primitives,
   leaked rows, edge bands. Three helpers cover almost everything —
   `inpaint(box)` (bilinear blend from four clean margins; use a vertical-only variant when
   a left/right margin lands on neighbouring glyphs, or it drags them across as streaks),
   `extrapolate_up(box)` (least-squares fit on the clean band below — the only option when a
   region is boxed in on three sides), and `render_fit(text, font, measured_box, colour,
   angle)`.
3. **Normalize:** cover-fit and centre-crop to **1080×1920** (feature graphic **1024×500**,
   icon **512×512**), flatten alpha onto `#0E1413` — the artwork's own canvas colour, never
   white, which fringes — convert to sRGB, strip every ancillary PNG chunk.
4. **Self-check:** re-measure and fail loudly if a repair silently missed.
5. **Determinism:** run twice, diff the hashes. Non-determinism means the artefact you
   validated is not the artefact you upload.

---

## Phase E — Validation

`tool/validate_play_assets.py` asserts, independently:

**Hard — Play rejects the upload otherwise**

| Asset | Rule |
|---|---|
| Screenshots | PNG or JPEG · **no alpha channel** · each side 320–3840 px · longest side ≤ 2 × shortest · ≤ 8 MB · 2–8 per device type |
| Icon | exactly 512×512 · PNG or JPEG · ≤ 1 MB · **one icon globally — not localizable** |
| Feature graphic | exactly 1024×500 · PNG or JPEG · ≤ 15 MB · required |

**Recommendation — quality and featuring, not policy. Do not present these to a founder as
policy.**

| Item | Guidance |
|---|---|
| 1080×1920 screenshots | The canonical size |
| ≥ 4 screenshots at ≥ 1080 px, 16:9 or 9:16 | Gates promotional/featuring eligibility |
| Consistent dimensions within the set | Mixed sizes letterbox inconsistently in the carousel |
| Feature-graphic safe areas | Centre ~250×250 px quiet; ~64 px clear at every edge |
| Icon legible at 48 px | The size it renders at in search and the drawer |
| Slots 1–3 | What appears in search results |
| No duplicate screenshots | Hash the set — a byte-identical duplicate shipped into a reviewed set once, and nobody noticed |

**The invisible checks are the cheapest gate in the process — run them before any human
review:** `Image.mode` for alpha, size, aspect ratio, file size, `md5sum` across the set for
duplicates, PNG chunk enumeration for leftover metadata, and — for the icon — a scan of the
outer rows and columns for a uniform white or black band. A previous project shipped an icon
with a **12-row band of pure white across its bottom edge**; Play's mask would have rendered
it as a white arc, and it survived review because everyone was reviewing the *design*, and
the design was right.

---

## Phase F — Play Console upload *(founder)*

1. **Grow users → Store presence → Main store listing** → language **English (United States)**
2. **App name** → paste from the prompt library §4
3. **Short description** → paste. **The Console counts characters; confirm it accepts it**
   — the value currently in `docs/store_metadata/google_play.md` is 144 characters and will
   be refused.
4. **Full description** → paste
5. **App icon** → upload `icon.png` (512×512). Once — it is global, not per-locale.
6. **Feature graphic** → upload `feature.png` (1024×500)
7. **Phone screenshots** → upload all eight **in slot order**. Verify the carousel order
   after upload; drag to correct it.
8. **AI-generated content declaration** → tick the box for **every** asset produced by an
   image model. Play uses a self-declaration model and asks per asset during the upload
   flow. All ten of these are AI-generated.
9. **Save**
10. **Verify:** preview the listing. Read it as a stranger. Check the icon at thumbnail size.

*Tablet screenshots: ship none.* Play requires none, and PawDoc has no consumer tablet
layout to depict. An absent tablet asset costs a quality signal; a fictional one is a
Misrepresentation risk.

---

## Phase G — Store listing validation

- [ ] Character counts computed, not estimated, and accepted by the Console
- [ ] No banned term in visible copy — `diagnose · diagnosis · treat · cure · prevent`
      (`scripts/verify-phase-2.3.sh` greps for these)
- [ ] Every feature named in the description exists, with the described *behaviour*
- [ ] Every allowance figure matches `entitlements.dart` (5 / 20 / 20)
- [ ] Privacy wording matches the **Data safety** form exactly — see
      `PAWDOC_GOOGLE_PLAY_PRODUCTION_QUESTIONNAIRE.md`
- [ ] The "what PawDoc is not" paragraph is present and includes "not a medical device"
- [ ] No price, trial or discount anywhere in copy or assets
- [ ] Screenshots and description agree with each other, and both agree with the app

---

## Phase H — Final reviewer audit

Run by someone who did not make the assets, with the release build installed on a device.

| # | Step | Owner | Pass means |
|---|---|---|---|
| 1 | Source-code verification | engineering | Every claim maps to a file; every metric to a computation |
| 2 | Real-device walkthrough | founder | Every advertised flow completes on the release build |
| 3 | Screenshot-to-code trace | engineering | Zero unfillable traceability rows |
| 4 | Asset-format validation | script | All assertions green on a freshly regenerated set |
| 5 | Privacy/Data-safety diff | both | No claim broader than the declared data flow |
| 6 | AI-disclosure check | engineering | AI disclosed in-app and in the listing; AI visibly synthetic |
| 7 | Health-claim sweep | engineering | No diagnosis, no score, no "fine", no outcome promise |
| 8 | Subscription check | founder | No price claim anywhere until products are live; then they match the SKUs |
| 9 | "Does the listing describe this app?" | anyone uninvolved | Yes, with nothing surprising |

> **Do not submit merely because the app builds. Do not submit merely because CI is green.
> Do not submit merely because the screenshots look premium.** Green CI is a statement about
> the code, not about the listing.

---

## The Phase D–E hand-off prompt

**Do not run this yet.** Generate the images first (Phase B), review them (Phase C), then
start a session with this:

```text
PawDoc ASO — post-generation CLI phase.

The ASO images have now been generated from
docs/PAWDOC_PLAY_STORE_ASO_PROMPT_LIBRARY.html and are in
ASO-image/generated/ (01-result.png … 08-free.png, feature.png, icon.png).

Read docs/PAWDOC_ASO_PRODUCTION_WORKFLOW.md phases D and E first, then:

1. INSPECT every generated file at full resolution. For each, write the
   two-column traceability table: every text string, number, icon and UI
   element on the left; its trace into mobile/lib/ on the right. Any row you
   cannot fill is a finding.

2. COMPARE each asset against the prompt that produced it. Report every
   deviation, including ones that look like improvements.

3. RUN the invisible checks before anything else, and report the table:
   Image.mode (alpha), size, aspect ratio, file size, md5 across the set for
   duplicates, PNG chunk list, and for the icon a scan of the outer rows and
   columns for a uniform band.

4. BUILD tool/playstore_asset_pipeline.py per phase D.4:
   read-only sources, repair at native resolution BEFORE resampling, measured
   coordinates only (never eyeballed), cover-fit + centre-crop to 1080x1920
   (feature 1024x500, icon 512x512), flatten alpha onto #0E1413, sRGB, strip
   ancillary chunks, selfcheck() assertions at the end. Write to
   ASO-image/FINAL/en-US/. Regenerate from scratch on every run.

5. BUILD tool/validate_play_assets.py as an INDEPENDENT validator that
   re-opens the outputs and asserts phase E's hard rules plus the
   recommendations, with --json for CI. It must not import the pipeline.

6. DETECT and report, per asset: text errors and typos, clipped or truncated
   strings, counted primitives that disagree with their labels, arithmetic
   that does not reconcile, dates that are not 2026, any Apple device, any
   nav label that is not Home/Pets/Health/Emergency, any face, star, rating,
   user count, price, score, confidence figure, named condition, or the words
   fine/healthy/normal/all good/excellent.

7. VERIFY naming and ordering: contiguous slot numbers, the intended
   carousel order, one global icon, no duplicates.

8. PRODUCE the final upload-ready set in ASO-image/FINAL/en-US/ and a short
   report listing what was repaired, what was regenerated, and what was
   deliberately left alone.

Rules: never write to ASO-image/generated/. Do not use pngquant — these are
dark gradient plates and it bands them. Run the pipeline twice and diff the
hashes; non-determinism means the artefact validated is not the artefact
uploaded. Report anything you could not verify rather than assuming it.
```

---

## Sources

- Findings A.1 were produced by inspecting the eight files in
  `ASO-image/PlayStore-ASO/` at full resolution on 8 August 2026 and checking each claim
  against `mobile/lib/`, `supabase/functions/` and `docs/`.
- Process, failure classes and the toolchain rationale are adapted from
  `/home/emre/Downloads/FormAI-FitnessKoçu/docs/PLAY_STORE_ASO_LESSONS_LEARNED.md`
  (FormAI Google Play preparation, July–August 2026), read in full.
- Play asset specifications: Play Console Help, *Add preview assets to showcase your app*.
- AI-generated content declaration: Play Console Help,
  *Declaring AI-generated content in Play Console*.
