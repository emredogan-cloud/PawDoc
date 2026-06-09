// Phase A — trust boundary between the Edge Functions and the internal AI
// service. Every call from an Edge Function to the Python AI service
// (pawdoc-ai) goes through these headers; the bearer token authenticates the
// caller so the AI service can refuse anything that isn't us.
//
// Kept a PURE function (token passed in, not read from Deno.env here) so it runs
// under `node --test` without a Deno global. Callers pass
// `Deno.env.get("AI_SERVICE_TOKEN") ?? ""`.

/**
 * Build the headers for a request to the internal AI service.
 * @param {string} requestId  end-to-end trace id (CR #23)
 * @param {string} token      AI_SERVICE_TOKEN (empty in local/dev => no auth header)
 * @returns {Record<string,string>}
 */
export function aiServiceHeaders(requestId, token) {
  const headers = {
    "content-type": "application/json",
    "x-request-id": requestId,
  };
  // Only attach the credential when configured. In production the token is set
  // on both sides; in dev it is empty and the AI service allows unauthenticated
  // local calls. Sending no header (vs an empty bearer) keeps dev logs clean.
  if (token) headers["authorization"] = `Bearer ${token}`;
  return headers;
}
