// Emergency keyword mirror of `ai-service/app/services/safety.py`.
//
// PURPOSE: the edge function checks for emergency keywords BEFORE calling
// the AI service so it can bypass the daily rate-limit and the free-tier
// quota when an obvious emergency is detected (roadmap §7: "Emergency
// analyses are NEVER paywalled").
//
// AUTHORITY: the AI service's check is the *canonical* one — it makes the
// final EMERGENCY classification. This list exists only for the quota-
// bypass decision; safety does not depend on it.
//
// SYNC: the two lists MUST contain the same phrases. A unit test in this
// folder asserts the count + content match the Python list at the
// corresponding line.

export const EMERGENCY_KEYWORDS: readonly string[] = [
  "not breathing",
  "stopped breathing",
  "can't breathe",
  "cant breathe",
  "labored breathing",
  "blue gums",
  "grey gums",
  "gray gums",
  "pale gums",
  "seizure",
  "seizing",
  "convulsing",
  "collapse",
  "collapsed",
  "can't stand",
  "cant stand",
  "grapes",
  "xylitol",
  "rat poison",
  "antifreeze",
  "suspected poisoning",
  "ate something toxic",
  "hit by car",
  "severe bleeding",
  "broken bone",
  "compound fracture",
];

export interface EmergencyMatch {
  matched: boolean;
  keyword: string | null;
}

/** Substring check (case-insensitive). Returns the first matching keyword. */
export function checkEmergencyOverride(text: string | null | undefined): EmergencyMatch {
  if (!text) {
    return { matched: false, keyword: null };
  }
  const lowered = text.toLowerCase();
  for (const kw of EMERGENCY_KEYWORDS) {
    if (lowered.includes(kw)) {
      return { matched: true, keyword: kw };
    }
  }
  return { matched: false, keyword: null };
}
