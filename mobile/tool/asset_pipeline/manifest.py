"""
Phase 0 manifest — plate -> production files.

`mode`:
  auto   projection-profile split (icon plates: real gutters between glyphs)
  grid   explicit uniform grid, rows given as lists of column-counts
         (photo mosaics are edge-to-edge, so there is nothing to project)
  single the whole plate is one asset

`bg`:   how to lift the art off its backdrop
  white  un-composite from white  -> transparent, colour preserved
  dark   un-composite from black  -> keeps neon bloom falloff
  keep   already has usable alpha / is a photo; leave pixels alone

`fmt`:  webp (photography, q90) | png (anything needing alpha)
"""

# --------------------------------------------------------------------------
# icon families — all verified in spec order against the rendered plates
# --------------------------------------------------------------------------
SYMPTOM = ["skin-irritation", "itching", "ear-problem", "eye-discharge", "coughing",
           "sneezing", "vomiting", "diarrhea", "appetite-loss", "lethargy", "limping",
           "bloating", "breathing-difficulty", "excessive-thirst", "weight-loss",
           "hair-loss", "bad-breath", "swelling", "seizure", "disorientation",
           "bleeding", "urination-change", "behaviour-change", "pain-response"]
ANAT = ["hip-dysplasia", "elbow-dysplasia", "bloat-stomach", "heart-anatomical",
        "cancer-ribbon", "skin-coat", "eyes-ears-nose", "brain", "lungs", "kidney",
        "liver", "joint"]
VAX = ["rabies", "dhpp", "leptospirosis", "bordetella", "lyme", "influenza",
       "parvovirus", "distemper"]
FA = ["bleeding", "choking", "poisoning", "heatstroke", "cuts", "vomiting",
      "eye-injury", "other"]
ACT = ["copy", "save-diary", "share", "reminder", "helpful", "not-helpful",
       "regenerate", "report"]
NOTIF = ["health-reminders", "health-alerts", "vet-app-updates", "tips-education",
         "community", "promotions"]
MED = ["chewable", "tablet", "liquid", "topical"]
WX = ["sun", "sun-cloud", "cloud", "cloud-rain", "cloud-heavy-rain", "thunder",
      "snow", "wind"]
VITAL = ["resting-heart-rate", "respiratory-rate", "temperature", "resting-time",
         "activity-level"]
REC = ["vet-visit", "medication", "lab-result", "vaccination", "ai-analysis",
       "weight", "note", "memory"]
CARE = ["exercise", "grooming", "shedding", "trainability", "intelligence", "barking",
        "size", "lifespan", "birthday-cake", "vet-visit-search", "vacation-suitcase",
        "playtime-ball"]
BRING = ["medications", "previous-records", "food-treats", "sample-cup", "photos-videos"]
BENEFIT = ["better-care", "more-insights", "save-time", "peace-of-mind", "free-trial",
           "money-back", "secure-private", "family-sharing"]
ACHV = ["first-10-walks", "distance-50km", "calorie-hunter", "week-streak",
        "marathon-paw", "early-bird"]

# monochrome line icons: black on white -> tintable PNG (currentColor equivalent)
LINE = dict(mode="auto", bg="white", fmt="png", size=128, mono=True)
# multicolour tiles / 3D icons: lift off white but keep hue
TILE = dict(mode="auto", bg="flood", fmt="png", size=192)

PLATES = {
 # ---- monochrome line-icon families -------------------------------------
 "icons/core/ic-symptom-<name>.svg.png":
     dict(LINE, out="icons/symptoms/ic-symptom-{}.png", names=SYMPTOM),
 "icons/core/ic-anat-<name>.svg.png":
     dict(LINE, out="icons/anatomy/ic-anat-{}.png", names=ANAT),
 "icons/core/ic-rec-<name>.svg.png":
     dict(LINE, out="icons/records/ic-rec-{}.png", names=REC),
 "icons/core/ic-care-<name>.svg.png":
     dict(LINE, out="icons/breed-care/ic-care-{}.png", names=CARE),
 "icons/core/ic-bring-<name>.svg.png":
     dict(LINE, out="icons/core/ic-bring-{}.png", names=BRING),
 "icons/core/ic-benefit-<name>.svg.png":
     dict(LINE, out="icons/core/ic-benefit-{}.png", names=BENEFIT),
 # vitals: 5 glyphs then 5 ECG sparklines, so 10 cells in one plate
 "icons/core/ic-vital-<name>.svg.png":
     dict(LINE, out="icons/vitals/ic-vital-{}.png",
          names=VITAL + [f"{n}-ecg" for n in VITAL], square=False),

 # ---- multicolour icon families -----------------------------------------
 "icons/core/ic-act-<name>.svg.png":
     dict(TILE, bg="key", out="icons/actions/ic-act-{}.png", names=ACT),
 "icons/core/ic-vax-<name>@3x.png.png":
     dict(TILE, out="icons/vaccines/ic-vax-{}@3x.png", names=VAX),
 "icons/core/ic-fa-<name>@3x.png.png":
     dict(TILE, out="icons/firstaid/ic-fa-{}@3x.png", names=FA),
 "icons/core/ic-med-<name>@3x.png.png":
     dict(TILE, out="icons/medication/ic-med-{}@3x.png", names=MED),
 "icons/core/ic-wx-<name>@3x.png.png":
     dict(TILE, out="icons/weather-3d/ic-wx-{}@3x.png", names=WX, size=224),
 "icons/core/ic-notif-<name>@3x.png.png":
     dict(mode="auto", bg="flood", fmt="png", size=192,
          out="icons/notifications/ic-notif-{}@3x.png", names=NOTIF),
 "icons/core/ic-species-<name>-badge@3x.png.png":
     dict(mode="auto", bg="flood", fmt="png", size=144,
          out="icons/core/ic-species-{}-badge@3x.png", names=["dog", "cat", "other"]),

 # ---- badges -------------------------------------------------------------
 "badges/achievements/bdg-achv-<name>@3x.png.png":
     dict(mode="auto", bg="key", fmt="png", size=264,
          out="badges/achievements/bdg-achv-{}@3x.png",
          names=ACHV + [f"{n}-locked" for n in ACHV] + ["locked-padlock"]),
 "badges/achievements/bdg-hex-frame-unlocked@3x.png, bdg-hex-frame-locked@3x.png.png":
     dict(mode="grid", rows=[2], bg="keep", fmt="png", size=288,
          out="badges/achievements/bdg-hex-frame-{}@3x.png",
          names=["unlocked", "locked"], square=False),
 "badges/bdg-24-7@3x.png, bdg-highlight-crown@3x.png.png":
     dict(mode="auto", bg="keep", fmt="png", size=192,
          out="badges/bdg-{}@3x.png", names=["24-7", "highlight-crown"]),
 "badges/bdg-verified-{lime,blue}@3x.png.png":
     dict(mode="auto", bg="keep", fmt="png", size=144,
          out="badges/bdg-verified-{}@3x.png", names=["lime", "blue"]),

 # ---- infographics --------------------------------------------------------
 "illustrations/infographics/inf-anatomy-{ear,nose,eye,mouth}@3x.webp.png":
     dict(mode="grid", rows=[2, 2], bg="keep", fmt="webp", size=None,
          out="illustrations/infographics/inf-anatomy-{}@3x.webp",
          names=["ear", "nose", "eye", "mouth"]),
 "illustrations/infographics/inf-photoquality-{good,dark,blurry}@3x.webp.png":
     dict(mode="frac", frac=[(0.0, 0.560, [0.0, 1.0]),
                             (0.560, 1.0, [0.0, 0.499, 1.0])],
          bg="keep", fmt="webp", size=None,
          out="illustrations/infographics/inf-photoquality-{}@3x.webp",
          names=["good", "dark", "blurry"]),

 # ---- doodles -------------------------------------------------------------
 "illustrations/doodles/ill-doodle-dog-scale@3x.png, ill-doodle-clipboard@3x.png.png":
     dict(mode="grid", rows=[2], bg="keep", fmt="png", size=512,
          out="illustrations/doodles/ill-doodle-{}@3x.png",
          names=["dog-scale", "clipboard"], checkerboard=True),

 # ---- avatars (photo mosaics) ---------------------------------------------
 "images/avatars/avt-community-{01..06}@3x.webp.png":
     dict(mode="grid", rows=[3, 3], bg="keep", fmt="webp", size=320,
          out="images/avatars/avt-community-{}@3x.webp",
          names=[f"{i:02d}" for i in range(1, 7)]),
 "images/avatars/avt-social-proof-{01..04}@3x.webp.png":
     dict(mode="grid", rows=[2, 2], bg="keep", fmt="webp", size=320,
          out="images/avatars/avt-social-proof-{}@3x.webp",
          names=[f"{i:02d}" for i in range(1, 5)]),
 "images/avatars/avt-map-{01..05}@3x.webp, avt-group-{01..03}@3x.webp.png":
     dict(mode="grid", rows=[2, 2], bg="keep", fmt="webp", size=320,
          out="images/avatars/avt-map-{}@3x.webp",
          names=["01", "02", "03", "04"]),

 # ---- breeds ---------------------------------------------------------------
 "images/breeds/bre-similar-{labrador,flatcoat,toller,chesapeake}@3x.webp.png":
     dict(mode="grid", rows=[2, 2], bg="keep", fmt="webp", size=480,
          out="images/breeds/bre-similar-{}@3x.webp",
          names=["labrador", "flatcoat", "toller", "chesapeake"]),
 "images/breeds/bre-category-{dog,cat,rabbit,bird,reptile,all}@3x.webp.png":
     dict(mode="grid", rows=[4, 2], bg="keep", fmt="webp", size=320,
          out="images/breeds/bre-category-{}@3x.webp",
          names=["dog", "cat", "rabbit", "bird", "reptile", "all"]),

 # ---- community -------------------------------------------------------------
 "images/community/cmn-post-promenade-{01..03}@3x.webp.png":
     dict(mode="grid", rows=[3], bg="keep", fmt="webp", size=None,
          out="images/community/cmn-post-promenade-{}@3x.webp",
          names=["01", "02", "03"]),

 # ---- emergency --------------------------------------------------------------
 "images/emergency/emg-clinic-exterior-{01,02,03}@3x.webp.png":
     dict(mode="grid", rows=[1, 1, 1], bg="keep", fmt="webp", size=None,
          out="images/emergency/emg-clinic-exterior-{}@3x.webp",
          names=["01", "02", "03"]),

 # ---- maps ---------------------------------------------------------------------
 "images/maps/map-route-thumb-{01..03}@3x.webp, map-memory-location@3x.webp.png":
     dict(mode="auto", bg="dark", fmt="webp", size=None,
          out="images/maps/{}@3x.webp",
          names=["map-route-thumb-01", "map-route-thumb-02", "map-route-thumb-03",
                 "map-memory-location"], square=False, keep_bg=True),

 # ---- memories: 6x4, numeric labels burned into each tile's top-left corner ----
 "images/memories/mem-buddy-{01..24}@3x.webp.png":
     dict(mode="grid", rows=[6, 6, 6, 6], bg="keep", fmt="webp", size=512,
          out="images/memories/mem-buddy-{}@3x.webp",
          names=[f"{i:02d}" for i in range(1, 25)], inset=(0.22, 0.06)),

 # ---- onboarding glyphs (plate holds 3 of the 4 specified) --------------------
 "images/onboarding/devices/onb-glyph-{brain,diary,cross,bell}-neon@3x.png.png":
     dict(mode="auto", bg="keep", fmt="png", size=256,
          out="images/onboarding/devices/onb-glyph-{}-neon@3x.png",
          names=["brain", "diary", "bell"]),

 # ---- pet species strip ---------------------------------------------------------
 "images/pets/cast/pet-species-{dog,cat,rabbit,bird,other}@3x.webp.png":
     dict(mode="grid", rows=[5], bg="keep", fmt="webp", size=320,
          out="images/pets/cast/pet-species-{}@3x.webp",
          names=["dog", "cat", "rabbit", "bird", "other"], content_square=True),
}

# Plates that hold two named assets but whose art overlaps, so they cannot be
# split programmatically without cutting through the artwork.
OVERLAPPING = {
 "images/community/cmn-reaction-{heart,paw,thumb}@3x.png.png":
     "3 reaction chips rendered as one overlapping cluster",

 # ICN-801 / ICN-810 are supplied by Lucide instead (spec §6.9: "author, do
 # not generate"). The plates hold 1 and 3 generic glyphs against the ~140
 # and 11 the spec calls for, so nothing here is salvageable as a set.
 "icons/core/ic-<name>.svg.png":
     "ICN-801 core set (~140 glyphs) -> Lucide; plate holds 1 generic vet glyph",
 "icons/core/ic-nav-<name>[-active].svg.png":
     "ICN-810 nav set (11 glyphs) -> Lucide; plate holds 3 generic glyph pairs",
}


# Plates where the generator baked the alpha checkerboard (and sometimes a solid
# red field) into RGB. Keyed out before anything else touches the pixels.
CHECKERBOARD = {
 "illustrations/doodles/ill-doodle-dogface-heart@3x.png.png",
 "illustrations/doodles/ill-pawtrail-dashed@3x.png.png",
}

# Single-asset plates needing a specific backdrop lift.
#   ("dark", floor) -> alpha from luminance, everything below `floor` dropped
SINGLE_FIX = {
 # neon doodle sitting on an opaque dark-grey checkerboard (~#313131)
 "illustrations/doodles/ill-doodle-puppy-shield@3x.png.png": ("dark", 72),
}

# Not salvageable: the generator rendered the alpha checkerboard as pixels
# *through* the artwork, so the silhouettes themselves are perforated.
UNSALVAGEABLE = {
 "illustrations/infographics/inf-size-reference-human-dog.svg.png":
     "INF-504 — pink checkerboard baked through the human/dog silhouettes; "
     "reconstruction loses limb detail. Needs regeneration.",
}

# Resolution + format policy for single-asset plates. The generator emitted
# everything at 1024-1536 px, which is 3-4x more than any of these are drawn
# at. Cap by intended use, and drop to WEBP wherever alpha is not needed.
#   prefix -> (max longest edge, force_format or None = auto)
SINGLE_POLICY = [
 ("brand/logo/brd-app-icon",              1024, "png"),   # launcher source
 ("brand/logo",                            512, "png"),
 ("images/premium/prm-3d",                 384, "png"),   # ~96-128pt tiles
 ("images/premium/prm-crown",              384, "png"),
 ("images/premium/prm-hero",               900, "webp"),
 ("images/ai/ai-assistant-avatar",         384, "png"),
 ("images/ai",                             512, "png"),
 ("images/emergency/emg-firstaid-banner",  900, "webp"),
 ("images/emergency/emg-dog-lesion",       900, "webp"),
 ("images/emergency",                      448, "png"),
 ("images/onboarding/devices/onb-hero",    900, None),
 ("images/onboarding/devices/onb-device",  700, "png"),
 ("images/onboarding",                     448, "png"),
 ("images/maps/map-pin",                   320, "png"),
 ("images/maps",                           900, "webp"),
 ("images/pets/cast/pet-buddy-hero",       800, None),
 ("images/pets/cast/pet-buddy-shield",     512, "png"),
 ("images/pets",                           512, None),
 ("images/breeds",                         700, "webp"),
 ("images/community",                      900, "webp"),
 ("images/avatars",                        384, "webp"),
 ("illustrations/doodles",                 600, "png"),
 ("illustrations/infographics",            700, None),
 ("badges",                                320, "png"),
 ("icons",                                 256, "png"),
]

def policy_for(rel):
    for pre, edge, fmt in SINGLE_POLICY:
        if rel.startswith(pre):
            return edge, fmt
    return 700, None
