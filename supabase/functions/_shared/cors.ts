// Shared CORS helpers used by every Edge Function.
//
// Edge Functions are stateless — each request is a fresh Deno isolate. So
// every function imports these helpers and applies them; there is no global
// middleware layer in the Supabase Edge runtime.

const ALLOWED_ORIGIN_PATTERNS: RegExp[] = [
  /^https?:\/\/localhost(:\d+)?$/,
  /^https?:\/\/127\.0\.0\.1(:\d+)?$/,
  /^app\.pawdoc\.app$/,
  /^https:\/\/pawdoc\.app$/,
  /^https:\/\/.*\.pawdoc\.app$/,
];

/**
 * Pick a single Allow-Origin value for the request based on the Origin header.
 * Returns null if the origin is disallowed — callers should reject the request.
 */
export function resolveOrigin(origin: string | null): string | null {
  if (!origin) return null;
  return ALLOWED_ORIGIN_PATTERNS.some((re) => re.test(origin)) ? origin : null;
}

/**
 * Standard CORS headers for a JSON response.
 * Callers MUST pass the validated origin from `resolveOrigin`.
 */
export function corsHeaders(origin: string): HeadersInit {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type, x-client-info, apikey",
    "Access-Control-Max-Age": "600",
    "Vary": "Origin",
  };
}

/**
 * Build the standard 204 preflight response.
 */
export function preflight(origin: string | null): Response {
  if (!origin) {
    return new Response(null, { status: 403 });
  }
  return new Response(null, { status: 204, headers: corsHeaders(origin) });
}
