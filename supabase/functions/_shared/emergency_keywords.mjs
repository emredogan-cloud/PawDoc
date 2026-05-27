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

export function containsEmergencyKeyword(text) {
  if (!text) return false;
  const t = String(text).toLowerCase();
  return EMERGENCY_KEYWORDS.some((k) => t.includes(k));
}
