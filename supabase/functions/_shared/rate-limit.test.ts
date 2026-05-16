// Tests for rate-limit.ts.
//
// Covers the in-memory limiter (the local-dev default). The Upstash REST
// path is exercised by mocking globalThis.fetch — we focus on the
// fail-open path because that's the safety-critical branch.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { _resetLimiterForTests, getDailyLimiter } from "./rate-limit.ts";

Deno.test("in-memory limiter allows under the limit", async () => {
  _resetLimiterForTests();
  // Ensure no Upstash env so we land on InMemoryLimiter.
  Deno.env.delete("UPSTASH_REDIS_REST_URL");
  Deno.env.delete("UPSTASH_REDIS_REST_TOKEN");
  Deno.env.set("DAILY_LIMIT", "3");

  const limiter = getDailyLimiter();
  const a = await limiter.check("user_a");
  const b = await limiter.check("user_a");
  const c = await limiter.check("user_a");
  const d = await limiter.check("user_a");

  assertEquals(a.allowed, true);
  assertEquals(b.allowed, true);
  assertEquals(c.allowed, true);
  // 4th call exceeds the limit of 3.
  assertEquals(d.allowed, false);
});

Deno.test("in-memory limiter is keyed per user", async () => {
  _resetLimiterForTests();
  Deno.env.delete("UPSTASH_REDIS_REST_URL");
  Deno.env.delete("UPSTASH_REDIS_REST_TOKEN");
  Deno.env.set("DAILY_LIMIT", "1");

  const limiter = getDailyLimiter();
  const a1 = await limiter.check("user_a");
  const a2 = await limiter.check("user_a");
  const b1 = await limiter.check("user_b");

  assertEquals(a1.allowed, true);
  // user_a's second call exceeds limit 1.
  assertEquals(a2.allowed, false);
  // user_b's first call is fine — independent bucket.
  assertEquals(b1.allowed, true);
});

Deno.test("in-memory limiter reports remaining quota correctly", async () => {
  _resetLimiterForTests();
  Deno.env.delete("UPSTASH_REDIS_REST_URL");
  Deno.env.delete("UPSTASH_REDIS_REST_TOKEN");
  Deno.env.set("DAILY_LIMIT", "3");

  const limiter = getDailyLimiter();
  const r1 = await limiter.check("user_x");
  assertEquals(r1.remaining, 2);
  const r2 = await limiter.check("user_x");
  assertEquals(r2.remaining, 1);
  const r3 = await limiter.check("user_x");
  assertEquals(r3.remaining, 0);
});

Deno.test("Upstash limiter fail-open on 5xx returns allowed=true", async () => {
  _resetLimiterForTests();
  Deno.env.set("UPSTASH_REDIS_REST_URL", "https://upstash.test");
  Deno.env.set("UPSTASH_REDIS_REST_TOKEN", "tok");

  const originalFetch = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response("upstream err", { status: 500 }),
    )) as typeof fetch;

  try {
    const limiter = getDailyLimiter();
    const r = await limiter.check("user_fail");
    assertEquals(r.allowed, true);
    assertEquals(r.remaining, -1); // sentinel for degraded mode
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete("UPSTASH_REDIS_REST_URL");
    Deno.env.delete("UPSTASH_REDIS_REST_TOKEN");
  }
});

Deno.test("Upstash limiter denies when count exceeds limit", async () => {
  _resetLimiterForTests();
  Deno.env.set("UPSTASH_REDIS_REST_URL", "https://upstash.test");
  Deno.env.set("UPSTASH_REDIS_REST_TOKEN", "tok");
  Deno.env.set("DAILY_LIMIT", "5");

  const originalFetch = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify([{ result: 6 }, { result: 1 }]),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    )) as typeof fetch;

  try {
    const limiter = getDailyLimiter();
    const r = await limiter.check("user_over");
    assertEquals(r.allowed, false);
    assertEquals(r.remaining, 0);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete("UPSTASH_REDIS_REST_URL");
    Deno.env.delete("UPSTASH_REDIS_REST_TOKEN");
  }
});
