// Mirror of ai-service/app/safety.py EMERGENCY_KEYWORDS — KEEP IN SYNC.
// Used by the /analyze Edge Function to enforce "EMERGENCY is never paywalled":
// if the text trips a keyword, the free-tier gate is bypassed (defense in depth;
// the AI service still runs the authoritative hardcoded override).
export const EMERGENCY_KEYWORDS = [
  "not breathing", "stopped breathing", "can't breathe", "labored breathing",
  "blue gums", "grey gums", "pale gums",
  "seizure", "seizing", "convulsing",
  "collapse", "collapsed", "can't stand",
  "grapes", "xylitol", "rat poison", "antifreeze",
  "suspected poisoning", "ate something toxic",
  "hit by car", "severe bleeding",
  "broken bone", "compound fracture",
];

// Species-specific triggers (Phase 5.1) — KEEP IN SYNC with
// ai-service/app/safety.py SPECIES_EMERGENCY_KEYWORDS. These fire only for the
// matching species (e.g. "not eating" = emergency for a rabbit/bird, not a dog),
// so an exotic emergency ALSO bypasses the free-tier paywall gate.
export const SPECIES_EMERGENCY_KEYWORDS = {
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
};

function normSpecies(species) {
  return String(species ?? "").trim().toLowerCase().replace(/ /g, "_");
}

// `species` is optional; when given, the matching species-specific keywords are
// also checked (in addition to the global list).
export function containsEmergencyKeyword(text, species) {
  if (!text) return false;
  const t = String(text).toLowerCase();
  if (EMERGENCY_KEYWORDS.some((k) => t.includes(k))) return true;
  const speciesKeywords = SPECIES_EMERGENCY_KEYWORDS[normSpecies(species)] ?? [];
  return speciesKeywords.some((k) => t.includes(k));
}
