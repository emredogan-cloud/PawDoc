// Places proxy helper tests. Run: node --test supabase/functions/_shared/places.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { buildPlacesRequest, haversineMeters, parseVets } from "./places.mjs";

test("buildPlacesRequest uses searchNearby for lat/lng", () => {
  const r = buildPlacesRequest({ lat: 40.7, lng: -74.0 });
  assert.match(r.endpoint, /places:searchNearby$/);
  assert.deepEqual(r.body.includedTypes, ["veterinary_care"]);
  assert.equal(r.body.locationRestriction.circle.center.latitude, 40.7);
});

test("buildPlacesRequest uses searchText for a zip/city query", () => {
  const r = buildPlacesRequest({ query: "10001" });
  assert.match(r.endpoint, /places:searchText$/);
  assert.match(r.body.textQuery, /veterinarian 10001/);
});

test("buildPlacesRequest with neither lat/lng nor query is a no-op", () => {
  assert.equal(buildPlacesRequest({}).endpoint, null);
  assert.equal(buildPlacesRequest({ query: "  " }).endpoint, null);
});

test("haversineMeters approximates a known distance (~1.5km)", () => {
  const d = haversineMeters({ lat: 40.748, lng: -73.985 }, { lat: 40.761, lng: -73.977 });
  assert.ok(d > 1300 && d < 1800, `got ${d}`);
});

test("parseVets normalizes, computes distance, sorts nearest-first, caps at 5", () => {
  const api = {
    places: [
      { displayName: { text: "Far Vet" }, location: { latitude: 40.80, longitude: -74.0 }, nationalPhoneNumber: "+1 222", currentOpeningHours: { openNow: false }, formattedAddress: "Far St" },
      { displayName: { text: "Near Vet" }, location: { latitude: 40.701, longitude: -74.0 }, nationalPhoneNumber: "+1 111", currentOpeningHours: { openNow: true }, formattedAddress: "Near St" },
      { displayName: { text: "No Phone Vet" }, location: { latitude: 40.75, longitude: -74.0 } },
      { location: { latitude: 40.9, longitude: -74.0 } },
      { displayName: { text: "E" }, location: { latitude: 41.0, longitude: -74.0 } },
      { displayName: { text: "F (6th, dropped)" }, location: { latitude: 42.0, longitude: -74.0 } },
    ],
  };
  const vets = parseVets(api, { lat: 40.7, lng: -74.0 });
  assert.equal(vets.length, 5); // capped
  assert.equal(vets[0].name, "Near Vet"); // nearest first
  assert.equal(vets[0].openNow, true);
  assert.equal(vets[0].phone, "+1 111");
  assert.equal(vets.find((v) => v.name === "No Phone Vet").phone, null);
  assert.equal(vets[0].distanceMeters !== null, true);
});

test("parseVets tolerates an empty/garbage response", () => {
  assert.deepEqual(parseVets({}, null), []);
  assert.deepEqual(parseVets(null, null), []);
});
