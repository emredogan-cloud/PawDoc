// Emergency-keyword tests (incl. Phase 5.1 species-specific).
// Run: node --test supabase/functions/_shared/emergency_keywords.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import {
  EMERGENCY_KEYWORDS,
  SPECIES_EMERGENCY_KEYWORDS,
  containsEmergencyKeyword,
} from "./emergency_keywords.mjs";

test("global keywords trip regardless of species", () => {
  assert.equal(EMERGENCY_KEYWORDS.length, 23); // global list unchanged
  assert.equal(containsEmergencyKeyword("my dog had a seizure"), true);
  assert.equal(containsEmergencyKeyword("my rabbit had a seizure", "rabbit"), true);
});

test("species-specific keyword trips ONLY for its species (paywall bypass)", () => {
  assert.equal(containsEmergencyKeyword("my rabbit is not eating", "rabbit"), true);
  assert.equal(containsEmergencyKeyword("my dog is not eating", "dog"), false);
  assert.equal(containsEmergencyKeyword("not eating"), false); // not a global keyword
});

test("guinea pig (with a space) normalizes to the guinea_pig set", () => {
  assert.equal(containsEmergencyKeyword("my guinea pig stopped eating", "guinea pig"), true);
});

test("bird fluffed-up at the bottom of the cage is an emergency", () => {
  assert.equal(
    containsEmergencyKeyword("my bird is fluffed up at the bottom of the cage", "bird"),
    true,
  );
});

test("empty / benign text is not an emergency", () => {
  assert.equal(containsEmergencyKeyword(""), false);
  assert.equal(containsEmergencyKeyword("happy healthy bird singing", "bird"), false);
});

test("species key set matches the Python mirror", () => {
  assert.deepEqual(
    Object.keys(SPECIES_EMERGENCY_KEYWORDS).sort(),
    ["bird", "guinea_pig", "rabbit", "reptile"],
  );
});
