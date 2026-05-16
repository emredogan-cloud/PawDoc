// Per-user daily rate limiter.
//
// Enforces the roadmap §9 cap of "max 10 analyses/day/user". The check
// runs in the edge function BEFORE any expensive AI call. Emergency
// keyword matches bypass this layer entirely; that decisioning lives in
// the analyze handler, not here.
//
// Implementation choices:
//   - Upstash REST API (HTTPS-based; no native Redis client needed).
//   - Fixed-window counter keyed by user_id + UTC date string. INCR +
//     EXPIRE in a single pipeline round-trip.
//   - Fail-open on Upstash errors with a structured warn log. The
//     free-tier counter (DB-backed, atomic) is the harder limit; this is
//     the soft limit. See plan §7.
//   - In-memory fallback for local dev when no Upstash env is set.

import { log } from "./logger.ts";
import { optionalEnv } from "./env.ts";

/**
 * Operational mode of a single rate-limit check. Sprint B3 (F-OPS1)
 * surfaces this in the structured log so an alert rule can count
 * fail-open occurrences. The mode strings are stable identifiers —
 * dashboards and alerts depend on them.
 */
export type LimiterMode =
  | "upstash" // Upstash REST round-trip succeeded
  | "inmemory" // local dev / no Upstash configured
  | "upstash_failopen"; // Upstash failed (5xx / transport); call allowed

export interface LimiterResult {
  readonly allowed: boolean;
  readonly remaining: number;
  readonly resetAtIso: string;
  readonly mode: LimiterMode;
}

export interface PerUserDailyLimiter {
  check(userId: string): Promise<LimiterResult>;
}

/** Roadmap §9 default — exposed as an env knob for staged rollback.
 *
 * Read lazily so test overrides via `Deno.env.set("DAILY_LIMIT", ...)`
 * take effect before the limiter is constructed. */
function readDailyLimit(): number {
  return Number.parseInt(optionalEnv("DAILY_LIMIT", "10"), 10);
}

function utcDayKey(now: Date = new Date()): string {
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, "0");
  const d = String(now.getUTCDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}

function endOfUtcDay(now: Date = new Date()): Date {
  const end = new Date(now);
  end.setUTCHours(24, 0, 0, 0);
  return end;
}

function secondsUntilEndOfUtcDay(now: Date = new Date()): number {
  return Math.ceil((endOfUtcDay(now).getTime() - now.getTime()) / 1000);
}

// ---------------------------------------------------------------------------
// Upstash-backed limiter
// ---------------------------------------------------------------------------

class UpstashLimiter implements PerUserDailyLimiter {
  constructor(
    private readonly url: string,
    private readonly token: string,
    private readonly limit: number = readDailyLimit(),
  ) {}

  async check(userId: string): Promise<LimiterResult> {
    const day = utcDayKey();
    const key = `pawdoc:rate:daily:${userId}:${day}`;
    // Grace TTL: end of day + 1 hour, in case of clock skew between
    // edge function workers.
    const ttl = secondsUntilEndOfUtcDay() + 3600;

    try {
      // Upstash REST: pipeline form lets us INCR + EXPIRE in one request.
      const resp = await fetch(`${this.url}/pipeline`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify([
          ["INCR", key],
          ["EXPIRE", key, String(ttl)],
        ]),
      });

      if (!resp.ok) {
        log.warn("rate_limit_upstash_5xx", {
          status: resp.status,
          user_id: userId,
        });
        // Dedicated counter event for alert rules. One signature for
        // both 5xx and transport-error fail-open paths.
        log.warn("rate_limit_failopen", {
          user_id: userId,
          cause: "upstash_5xx",
          status: resp.status,
        });
        return _failOpen(this.limit);
      }
      const body = (await resp.json()) as Array<{ result: number | string }>;
      const count = Number(body[0]?.result ?? 0);
      const allowed = count <= this.limit;
      const remaining = Math.max(0, this.limit - count);
      return {
        allowed,
        remaining,
        resetAtIso: endOfUtcDay().toISOString(),
        mode: "upstash",
      };
    } catch (err) {
      log.warn("rate_limit_upstash_error", {
        error: (err as Error).message,
        user_id: userId,
      });
      log.warn("rate_limit_failopen", {
        user_id: userId,
        cause: "upstash_transport",
      });
      return _failOpen(this.limit);
    }
  }
}

/**
 * Result returned when Upstash is unreachable. We allow the call (fail
 * open) but mark `remaining` as -1 so callers can spot the degraded mode
 * in logs. The free-tier counter (DB-backed) is the harder limit and
 * remains intact.
 */
function _failOpen(_limit: number): LimiterResult {
  return {
    allowed: true,
    remaining: -1,
    resetAtIso: endOfUtcDay().toISOString(),
    mode: "upstash_failopen",
  };
}

// ---------------------------------------------------------------------------
// In-memory limiter (local dev / no Upstash configured)
// ---------------------------------------------------------------------------

class InMemoryLimiter implements PerUserDailyLimiter {
  private readonly counts = new Map<string, { count: number; expiresAt: number }>();

  constructor(private readonly limit: number = readDailyLimit()) {}

  check(userId: string): Promise<LimiterResult> {
    const day = utcDayKey();
    const key = `${userId}:${day}`;
    const now = Date.now();
    const eod = endOfUtcDay().getTime();
    let entry = this.counts.get(key);
    if (!entry || entry.expiresAt < now) {
      entry = { count: 0, expiresAt: eod };
      this.counts.set(key, entry);
    }
    entry.count += 1;
    return Promise.resolve({
      allowed: entry.count <= this.limit,
      remaining: Math.max(0, this.limit - entry.count),
      resetAtIso: endOfUtcDay().toISOString(),
      mode: "inmemory",
    });
  }
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

let _cached: PerUserDailyLimiter | null = null;

/**
 * Construct (or return cached) the active limiter for this Deno isolate.
 *
 * - If `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN` are both set,
 *   use Upstash.
 * - Otherwise use the in-memory limiter (local dev only — survives only
 *   the isolate lifetime).
 */
export function getDailyLimiter(): PerUserDailyLimiter {
  if (_cached) return _cached;
  const url = optionalEnv("UPSTASH_REDIS_REST_URL");
  const token = optionalEnv("UPSTASH_REDIS_REST_TOKEN");
  if (url && token) {
    _cached = new UpstashLimiter(url, token);
  } else {
    log.info("rate_limit_using_in_memory", {
      reason: "UPSTASH_REDIS_REST_URL or UPSTASH_REDIS_REST_TOKEN not set",
    });
    _cached = new InMemoryLimiter();
  }
  return _cached;
}

/** TEST-ONLY: drop the cached singleton so a test can swap limiters. */
export function _resetLimiterForTests(): void {
  _cached = null;
}

// Backwards-compatible stub interfaces from Phase 1A — kept so existing
// code that imported these types still compiles.
export interface FreeTierLimiter {
  attempt(userId: string): Promise<boolean>;
}
