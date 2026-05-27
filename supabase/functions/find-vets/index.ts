// Phase 3.4 — /find-vets
// Key-hiding proxy to the Google Places API (New). The client sends only a
// lat/lng (or a zip/city query); the PLACES_API_KEY lives ONLY in this
// function's env (Doppler / supabase secrets) and NEVER reaches the client.
//
// verify_jwt stays default (true): only signed-in users may call it, so the
// Places quota/billing can't be drained anonymously.
//
// Fail-safe: any error (no key, upstream failure) returns 200 with an empty
// list, so the client degrades gracefully to its native-maps fallback instead
// of erroring.
import {
  buildPlacesRequest,
  parseVets,
  // deno-lint-ignore no-import-assertions
} from "../_shared/places.mjs";

Deno.serve(async (req: Request) => {
  const requestId = req.headers.get("x-request-id") ?? crypto.randomUUID();
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "x-request-id": requestId },
    });

  const apiKey = Deno.env.get("PLACES_API_KEY") ?? "";
  if (!apiKey) {
    // Not configured yet -> empty list; client falls back to native maps.
    return json({ vets: [], error: "vet_finder_unavailable" });
  }

  // deno-lint-ignore no-explicit-any
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return json({ vets: [], error: "invalid request" }, 400);
  }

  const lat = typeof body?.lat === "number" ? body.lat : undefined;
  const lng = typeof body?.lng === "number" ? body.lng : undefined;
  const query = typeof body?.query === "string" ? body.query : undefined;

  const { endpoint, fieldMask, body: placesBody } = buildPlacesRequest({ lat, lng, query });
  if (!endpoint) return json({ vets: [], error: "lat/lng or query required" }, 400);

  try {
    const resp = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": fieldMask,
      },
      body: JSON.stringify(placesBody),
    });
    if (!resp.ok) throw new Error(`places ${resp.status}`);
    const data = await resp.json();
    const origin = lat !== undefined && lng !== undefined ? { lat, lng } : null;
    return json({ vets: parseVets(data, origin) });
  } catch (err) {
    console.error("find-vets: upstream failure", requestId, String(err));
    return json({ vets: [], error: "vet_finder_unavailable" });
  }
});
