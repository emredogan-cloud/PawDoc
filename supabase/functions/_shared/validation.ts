// Hand-rolled validation primitives.
//
// We avoid a runtime validator dependency (zod, valibot, etc.) for three
// reasons:
//   1. Each function has 1-2 payload shapes — the overhead isn't worth it.
//   2. Edge functions run in security-sensitive contexts; less third-party
//      code in the bundle is good.
//   3. Hand-rolled type guards are 10-15 lines each and read like
//      pseudocode.
//
// The pattern is: parse the JSON body, then call a per-shape validator
// that throws Errors.validation on the first failure.

import { Errors } from "./errors.ts";

export async function readJson(req: Request): Promise<unknown> {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    throw Errors.validation("Body must be valid JSON.");
  }
  return body;
}

export function asObject(
  v: unknown,
  field = "body",
): Record<string, unknown> {
  if (v === null || typeof v !== "object" || Array.isArray(v)) {
    throw Errors.validation(`${field} must be a JSON object.`);
  }
  return v as Record<string, unknown>;
}

export function asString(v: unknown, field: string): string {
  if (typeof v !== "string" || v.length === 0) {
    throw Errors.validation(`${field} must be a non-empty string.`);
  }
  return v;
}

export function asUuid(v: unknown, field: string): string {
  const s = asString(v, field);
  // RFC 4122 — 8-4-4-4-12 hex digits.
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
  ) {
    throw Errors.validation(`${field} must be a valid UUID.`);
  }
  return s.toLowerCase();
}

export function asOneOf<T extends string>(
  v: unknown,
  allowed: readonly T[],
  field: string,
): T {
  const s = asString(v, field);
  if (!allowed.includes(s as T)) {
    throw Errors.validation(
      `${field} must be one of: ${allowed.join(", ")}.`,
    );
  }
  return s as T;
}

export function asOptional<T>(
  v: unknown,
  parser: (v: unknown, field: string) => T,
  field: string,
): T | undefined {
  if (v === undefined || v === null) return undefined;
  return parser(v, field);
}
