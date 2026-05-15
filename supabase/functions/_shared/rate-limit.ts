// Rate-limit primitives — interface only.
//
// Phase 1A defines the shape; Phase 1B wires it to Upstash Redis (roadmap
// §3 — semantic cache stack) and to the DB-backed free-tier counter.
//
// The two limiters we'll have:
//   - PerUserDailyLimiter: max-N-per-day-per-user (roadmap §9 — 10/day cap)
//     Backed by a sliding window in Redis.
//   - FreeTierLimiter: monthly counter on `users.free_analyses_used_this_month`.
//     Backed by the `attempt_consume_free_analysis` SQL function.
//
// In 1A both are stubs. Calling them throws `not_implemented` so the
// callsites are visible in code review but cannot accidentally pass.

import { Errors } from "./errors.ts";

export interface LimiterResult {
  readonly allowed: boolean;
  readonly remaining?: number;
  readonly resetAt?: string;
}

export interface PerUserDailyLimiter {
  check(userId: string): Promise<LimiterResult>;
}

export interface FreeTierLimiter {
  /** Returns `true` if the user has free-tier quota and consumes one slot. */
  attempt(userId: string): Promise<boolean>;
}

// ---- Stubs (Phase 1B replaces) ---------------------------------------------

export const noopDailyLimiter: PerUserDailyLimiter = {
  check(_userId: string): Promise<LimiterResult> {
    throw Errors.notImplemented("Phase 1B (Upstash Redis sliding window)");
  },
};

export const noopFreeTierLimiter: FreeTierLimiter = {
  attempt(_userId: string): Promise<boolean> {
    throw Errors.notImplemented(
      "Phase 1B (attempt_consume_free_analysis RPC)",
    );
  },
};
