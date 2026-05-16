// Tests for emergency.ts — keyword detection + parity with Python.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { checkEmergencyOverride, EMERGENCY_KEYWORDS } from "./emergency.ts";

Deno.test("checkEmergencyOverride matches a known keyword", () => {
  const result = checkEmergencyOverride("My dog just had a seizure");
  assertEquals(result.matched, true);
  assertEquals(result.keyword, "seizure");
});

Deno.test("checkEmergencyOverride is case-insensitive", () => {
  assertEquals(checkEmergencyOverride("XYLITOL in gum").matched, true);
  assertEquals(checkEmergencyOverride("Hit By Car!").matched, true);
});

Deno.test("checkEmergencyOverride returns no match for benign text", () => {
  assertEquals(
    checkEmergencyOverride("She seems sleepy today, that's all").matched,
    false,
  );
});

Deno.test("checkEmergencyOverride handles null/empty", () => {
  assertEquals(checkEmergencyOverride(null).matched, false);
  assertEquals(checkEmergencyOverride("").matched, false);
  assertEquals(checkEmergencyOverride(undefined).matched, false);
});

Deno.test("EMERGENCY_KEYWORDS list has the canonical roadmap entries", () => {
  // Spot-checks ensure the list hasn't been silently truncated. The full
  // parity check against the Python list is run by a separate CI step
  // (scripts/check-emergency-parity); this test catches local drift.
  for (
    const kw of [
      "not breathing",
      "seizure",
      "xylitol",
      "hit by car",
      "compound fracture",
    ]
  ) {
    assertEquals(
      EMERGENCY_KEYWORDS.includes(kw),
      true,
      `missing canonical keyword: ${kw}`,
    );
  }
});

Deno.test("EMERGENCY_KEYWORDS has at least 24 entries", () => {
  // Defensive: anyone deleting the list wholesale should fail this test.
  if (EMERGENCY_KEYWORDS.length < 24) {
    throw new Error(
      `EMERGENCY_KEYWORDS shrank to ${EMERGENCY_KEYWORDS.length} entries`,
    );
  }
});
