// Journal helper tests. Run: node --test supabase/functions/_shared/journal.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { mondayOfWeekUtc, summarizeAnalyses, summarizeEvents } from "./journal.mjs";

test("mondayOfWeekUtc returns the Monday of the week containing the date", () => {
  // 2026-05-27 is a Wednesday -> Monday 2026-05-25
  assert.equal(mondayOfWeekUtc("2026-05-27T12:00:00Z"), "2026-05-25");
  // 2026-05-25 is a Monday -> itself
  assert.equal(mondayOfWeekUtc("2026-05-25T00:00:00Z"), "2026-05-25");
  // 2026-05-31 is a Sunday (end of the week) -> 2026-05-25
  assert.equal(mondayOfWeekUtc("2026-05-31T23:59:59Z"), "2026-05-25");
  // 2026-06-01 is a Monday -> rolls forward
  assert.equal(mondayOfWeekUtc("2026-06-01T00:00:00Z"), "2026-06-01");
});

test("summarizers keep only the fields the prompt needs", () => {
  const a = summarizeAnalyses([
    { id: "x", created_at: "2026-05-26", triage_level: "MONITOR", primary_concern: "Mild limp", full_response: { secret: 1 } },
  ]);
  assert.deepEqual(a, [{ created_at: "2026-05-26", triage_level: "MONITOR", primary_concern: "Mild limp" }]);

  const e = summarizeEvents([
    { id: "y", event_date: "2026-05-27", event_type: "weight", notes: "+0.3kg", metadata: { weight_kg: 30.3 } },
  ]);
  assert.deepEqual(e, [{ event_date: "2026-05-27", event_type: "weight", notes: "+0.3kg" }]);
});

test("summarizers tolerate non-array / empty input", () => {
  assert.deepEqual(summarizeAnalyses(null), []);
  assert.deepEqual(summarizeEvents(undefined), []);
});
