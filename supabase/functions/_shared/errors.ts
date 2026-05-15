// Typed error class + response builder shared across edge functions.
//
// Discipline:
//   - Every user-visible error is an ApiError with a stable `code` string.
//   - Codes match what the mobile/AI service expect; renaming a code is a
//     breaking change.
//   - The handler shape mirrors what the ai-service returns
//     (`{ error, message }`), so every PawDoc endpoint speaks the same
//     error language.
//   - 5xx responses NEVER echo internal error text — the caller gets a
//     generic message, the operator sees the real cause in logs.

import { corsHeaders, resolveOrigin } from "./cors.ts";

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }

  toResponse(req: Request): Response {
    const origin = resolveOrigin(req.headers.get("Origin")) ?? "*";
    return new Response(
      JSON.stringify({ error: this.code, message: this.message }),
      {
        status: this.status,
        headers: {
          "Content-Type": "application/json",
          ...corsHeaders(origin),
        },
      },
    );
  }
}

export const Errors = {
  unauthorized: (msg = "Authentication required.") => new ApiError(401, "unauthorized", msg),
  forbidden: (msg = "Not allowed.") => new ApiError(403, "forbidden", msg),
  notFound: (msg = "Not found.") => new ApiError(404, "not_found", msg),
  conflict: (msg = "Conflict.") => new ApiError(409, "conflict", msg),
  validation: (msg: string) => new ApiError(422, "validation_error", msg),
  rateLimited: (msg = "Rate limit exceeded.") => new ApiError(429, "rate_limited", msg),
  notImplemented: (phase = "next phase") =>
    new ApiError(501, "not_implemented", `Implemented in ${phase}.`),
  upstream: (msg = "Upstream service failure.") => new ApiError(502, "upstream_error", msg),
} as const;

/**
 * Wrap a handler so any thrown ApiError becomes a structured response.
 * Unknown errors become 500 with a generic body — the real cause goes to
 * stdout only.
 */
export function withErrorHandler(
  handler: (req: Request) => Promise<Response> | Response,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    try {
      return await handler(req);
    } catch (err) {
      if (err instanceof ApiError) {
        return err.toResponse(req);
      }
      console.error("unhandled_error", {
        name: err instanceof Error ? err.name : "unknown",
        message: err instanceof Error ? err.message : String(err),
      });
      const origin = resolveOrigin(req.headers.get("Origin")) ?? "*";
      return new Response(
        JSON.stringify({
          error: "internal_error",
          message: "An unexpected error occurred.",
        }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            ...corsHeaders(origin),
          },
        },
      );
    }
  };
}
