// Emergency-keyword tests (Phase 5.1 species-specific + Phase 5.4 localized).
// Run: node --test supabase/functions/_shared/emergency_keywords.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import {
  EMERGENCY_KEYWORDS,
  EMERGENCY_KEYWORDS_BY_LOCALE,
  SPECIES_EMERGENCY_KEYWORDS,
  SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE,
  SUPPORTED_LOCALES,
  containsEmergencyKeyword,
} from "./emergency_keywords.mjs";

test("global keywords trip regardless of species (EN default)", () => {
  assert.equal(EMERGENCY_KEYWORDS.length, 23); // EN list unchanged
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

// --- Phase 5.4 / CR #11: localized emergency keywords ----------------------
test("supported locales include en + de", () => {
  assert.deepEqual([...SUPPORTED_LOCALES].sort(), ["de", "en"]);
});

test("DE global keyword fires under locale=de", () => {
  assert.equal(
    containsEmergencyKeyword("der Hund hatte einen Krampfanfall", "dog", "de"),
    true,
  );
  assert.equal(
    containsEmergencyKeyword("Verdacht auf Vergiftung mit Schokolade", "dog", "de"),
    true,
  );
});

test("DE species keyword fires only for its species under locale=de", () => {
  // 'frisst nicht' = emergency for rabbit, but not for dog (rabbit-only set).
  assert.equal(containsEmergencyKeyword("Mein Kaninchen frisst nicht.", "rabbit", "de"), true);
  assert.equal(containsEmergencyKeyword("Mein Hund frisst nicht.", "dog", "de"), false);
});

test("DE keywords do NOT fire under locale=en (and vice versa)", () => {
  // The German phrase should not trip under English keywords:
  assert.equal(
    containsEmergencyKeyword("der Hund hatte einen Krampfanfall", "dog", "en"),
    false,
  );
  // The English phrase should not trip under German keywords:
  assert.equal(
    containsEmergencyKeyword("my dog had a seizure", "dog", "de"),
    false,
  );
});

test("unknown locale falls back to en (safe default)", () => {
  assert.equal(containsEmergencyKeyword("my dog had a seizure", "dog", "fr"), true);
  assert.equal(containsEmergencyKeyword("my dog had a seizure", "dog", null), true);
});

test("DE species set keys match EN species set keys", () => {
  assert.deepEqual(
    Object.keys(SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE.de).sort(),
    Object.keys(SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE.en).sort(),
  );
});

test("BCP-47 like 'de-DE' normalizes to 'de'", () => {
  assert.equal(
    containsEmergencyKeyword("der Hund hatte einen Krampfanfall", "dog", "de-DE"),
    true,
  );
});

test("EMERGENCY_KEYWORDS_BY_LOCALE en mirrors the EMERGENCY_KEYWORDS alias", () => {
  assert.deepEqual(EMERGENCY_KEYWORDS_BY_LOCALE.en, EMERGENCY_KEYWORDS);
});
