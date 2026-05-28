// Mirror of ai-service/app/safety.py EMERGENCY_KEYWORDS_BY_LOCALE /
// SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE — KEEP IN SYNC.
//
// Used by the /analyze Edge Function to enforce "EMERGENCY is never paywalled":
// if the text trips a keyword (in the user's preferred_locale), the free-tier
// gate is bypassed (defense in depth; the AI service still runs the
// authoritative hardcoded override). CR #11 (Phase 5.4): locale-aware.
export const EMERGENCY_KEYWORDS_BY_LOCALE = {
  en: [
    "not breathing", "stopped breathing", "can't breathe", "labored breathing",
    "blue gums", "grey gums", "pale gums",
    "seizure", "seizing", "convulsing",
    "collapse", "collapsed", "can't stand",
    "grapes", "xylitol", "rat poison", "antifreeze",
    "suspected poisoning", "ate something toxic",
    "hit by car", "severe bleeding",
    "broken bone", "compound fracture",
  ],
  de: [
    "atmet nicht", "hat aufgehört zu atmen", "kann nicht atmen", "atemnot",
    "schwere atmung", "atmet schwer",
    "blaues zahnfleisch", "graues zahnfleisch", "blasses zahnfleisch",
    "krampfanfall", "krampft", "anfall", "konvulsionen", "zuckungen",
    "kollaps", "zusammengebrochen", "kann nicht stehen",
    "weintrauben", "trauben", "xylit", "xylitol",
    "rattengift", "frostschutzmittel", "frostschutz",
    "verdacht auf vergiftung", "vergiftet",
    "etwas giftiges gefressen", "etwas giftiges gegessen",
    "vom auto angefahren", "angefahren", "starke blutung", "blutet stark",
    "knochenbruch", "gebrochener knochen", "offener bruch", "offene fraktur",
  ],
};

// Species-specific triggers (Phase 5.1, localized in Phase 5.4) — fire ONLY
// for the matching species (e.g. "not eating" = emergency for a rabbit/bird,
// not a dog), in the requested locale.
export const SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE = {
  en: {
    rabbit: [
      "not eating", "won't eat", "stopped eating", "not pooping", "no poop",
      "no droppings", "not drinking", "won't drink", "bloated", "hard belly",
      "head tilt", "tilting head", "gi stasis", "stasis", "not moving",
    ],
    guinea_pig: [
      "not eating", "won't eat", "stopped eating", "not pooping", "no poop",
      "not drinking", "won't drink", "bloated", "gi stasis", "stasis",
      "labored breathing", "not moving",
    ],
    bird: [
      "fluffed", "fluffed up", "puffed", "puffed up", "bottom of the cage",
      "on the cage floor", "sitting on the bottom", "tail bobbing",
      "open mouth breathing", "open-mouth breathing", "not eating", "won't eat",
      "fell off perch", "not perching",
    ],
    reptile: [
      "open mouth breathing", "open-mouth breathing", "mouth rot", "prolapse",
      "unresponsive", "not moving", "gasping",
    ],
  },
  de: {
    rabbit: [
      "frisst nicht", "isst nicht", "frisst kein heu", "frisst kein futter",
      "kein kot", "keine köttel", "kein köttel", "keinen kot abgesetzt",
      "verstopfung", "trinkt nicht", "aufgebläht", "aufgeblähter bauch",
      "harter bauch", "kopfschiefhaltung", "schiefer kopf", "kippt den kopf",
      "magen-darm-stase", "darmstase", "bewegt sich nicht",
    ],
    guinea_pig: [
      "frisst nicht", "isst nicht", "kein kot", "keine köttel",
      "trinkt nicht", "aufgebläht", "aufgeblähter bauch",
      "schwere atmung", "atmet schwer", "darmstase", "bewegt sich nicht",
    ],
    bird: [
      "aufgeplustert", "plustert sich auf", "sitzt am käfigboden",
      "auf dem käfigboden", "auf dem boden des käfigs", "schwanzwippen",
      "wippt mit dem schwanz", "atmet mit offenem schnabel",
      "öffnet den schnabel zum atmen", "frisst nicht",
      "vom ast gefallen", "vom sitzast gefallen", "sitzt nicht auf",
    ],
    reptile: [
      "atmet mit offenem maul", "atmet mit offenem mund", "schnappt nach luft",
      "maulfäule", "prolaps", "reagiert nicht", "bewegt sich nicht",
    ],
  },
};

// Back-compat aliases for older imports / tests.
export const EMERGENCY_KEYWORDS = EMERGENCY_KEYWORDS_BY_LOCALE.en;
export const SPECIES_EMERGENCY_KEYWORDS = SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE.en;

export const SUPPORTED_LOCALES = Object.keys(EMERGENCY_KEYWORDS_BY_LOCALE);

function normSpecies(species) {
  return String(species ?? "").trim().toLowerCase().replace(/ /g, "_");
}

function normLocale(locale) {
  if (!locale) return "en";
  const code = String(locale).trim().toLowerCase().split("-")[0];
  return Object.prototype.hasOwnProperty.call(EMERGENCY_KEYWORDS_BY_LOCALE, code) ? code : "en";
}

// `species` and `locale` are optional; an unknown locale falls back to 'en' so
// we never silently lose paywall-bypass coverage during the German launch.
export function containsEmergencyKeyword(text, species, locale) {
  if (!text) return false;
  const t = String(text).toLowerCase();
  const lkey = normLocale(locale);
  if (EMERGENCY_KEYWORDS_BY_LOCALE[lkey].some((k) => t.includes(k))) return true;
  const speciesKeywords = (SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE[lkey] ?? {})[normSpecies(species)] ?? [];
  return speciesKeywords.some((k) => t.includes(k));
}
