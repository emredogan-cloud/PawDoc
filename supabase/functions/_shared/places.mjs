// Pure helpers for the /find-vets Places proxy (Phase 3.4). Plain ESM so it runs
// in Deno (the Edge Function) and Node (the unit test). Uses the Places API
// (New), which returns name + phone + open-now in ONE request via a field mask.

const NEARBY = "https://places.googleapis.com/v1/places:searchNearby";
const TEXT = "https://places.googleapis.com/v1/places:searchText";

// Only the fields we need (keeps the response small + billing tier predictable).
export const PLACES_FIELD_MASK = [
  "places.displayName",
  "places.location",
  "places.nationalPhoneNumber",
  "places.internationalPhoneNumber",
  "places.currentOpeningHours.openNow",
  "places.formattedAddress",
  "places.id",
].join(",");

/** Distance in metres between two {lat,lng} points (haversine). */
export function haversineMeters(a, b) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return Math.round(2 * R * Math.asin(Math.min(1, Math.sqrt(h))));
}

/**
 * Decide which Places (New) endpoint + request body to use:
 *   - lat/lng present  -> searchNearby (veterinary_care, ranked by distance);
 *   - else a text query -> searchText (zip/city fallback);
 *   - else nothing      -> { endpoint: null }.
 */
export function buildPlacesRequest({ lat, lng, query, radius = 8000, maxResults = 5 } = {}) {
  if (typeof lat === "number" && typeof lng === "number") {
    return {
      endpoint: NEARBY,
      fieldMask: PLACES_FIELD_MASK,
      body: {
        includedTypes: ["veterinary_care"],
        maxResultCount: maxResults,
        rankPreference: "DISTANCE",
        locationRestriction: { circle: { center: { latitude: lat, longitude: lng }, radius } },
      },
    };
  }
  if (typeof query === "string" && query.trim().length > 0) {
    return {
      endpoint: TEXT,
      fieldMask: PLACES_FIELD_MASK,
      body: { textQuery: `veterinarian ${query.trim()}`, maxResultCount: maxResults },
    };
  }
  return { endpoint: null, fieldMask: null, body: null };
}

/** Normalize a Places (New) response into a clean, client-safe vet array
 *  (nearest 5). If `origin` is given, compute + sort by distance. */
export function parseVets(apiJson, origin = null) {
  const places = Array.isArray(apiJson?.places) ? apiJson.places : [];
  const vets = places.map((p) => {
    const lat = p?.location?.latitude ?? null;
    const lng = p?.location?.longitude ?? null;
    const hasLatLng = typeof lat === "number" && typeof lng === "number";
    return {
      name: p?.displayName?.text ?? "Veterinary clinic",
      phone: p?.nationalPhoneNumber ?? p?.internationalPhoneNumber ?? null,
      openNow: p?.currentOpeningHours?.openNow ?? null,
      address: p?.formattedAddress ?? null,
      lat,
      lng,
      distanceMeters: origin && hasLatLng ? haversineMeters(origin, { lat, lng }) : null,
    };
  });
  if (origin) {
    vets.sort((a, b) => (a.distanceMeters ?? Number.MAX_SAFE_INTEGER) - (b.distanceMeters ?? Number.MAX_SAFE_INTEGER));
  }
  return vets.slice(0, 5);
}
