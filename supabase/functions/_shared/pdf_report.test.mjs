// Phase 6.3 — pdf_report.mjs content shaping tests.
import assert from "node:assert/strict";
import { test } from "node:test";

import {
  PDF_REPORT_DISCLAIMER,
  buildReportSections,
  reportFilename,
} from "./pdf_report.mjs";

test("the report always carries the server-injected disclaimer in a footer", () => {
  const sections = buildReportSections({
    pet: { name: "Rex", species: "dog" },
    analyses: [],
    events: [],
    generatedAtIso: "2026-05-28T12:00:00Z",
  });
  const footer = sections.find((s) => s.kind === "footer");
  assert.ok(footer, "no footer in the report");
  assert.equal(footer.text, PDF_REPORT_DISCLAIMER);
  assert.match(footer.text, /not a veterinary diagnosis/i);
});

test("the report's title + subtitle carry the pet name and the generation date", () => {
  const sections = buildReportSections({
    pet: { name: "Rex", species: "dog", breed: "Lab", birth_date: "2020-05-28" },
    analyses: [],
    events: [],
    generatedAtIso: "2026-05-28T12:00:00Z",
  });
  assert.equal(sections[0].text, "PawDoc Health Report");
  assert.match(sections[1].text, /Rex/);
  assert.match(sections[1].text, /2026-05-28/);
});

test("the profile section reports age + breed + species when present", () => {
  const sections = buildReportSections({
    pet: { name: "Rex", species: "dog", breed: "Labrador", birth_date: "2020-05-28", sex: "M" },
    analyses: [],
    events: [],
    generatedAtIso: "2026-05-28T00:00:00Z",
  });
  const profile = sections.find((s) => s.heading === "Pet profile");
  assert.ok(profile);
  assert.deepEqual(profile.lines.includes("Species: dog"), true);
  assert.deepEqual(profile.lines.includes("Breed: Labrador"), true);
  assert.deepEqual(profile.lines.some((l) => l.startsWith("Age:")), true);
  assert.deepEqual(profile.lines.includes("Sex: M"), true);
});

test("the analyses section uses date + triage + concern per row", () => {
  const sections = buildReportSections({
    pet: { name: "Rex", species: "dog" },
    analyses: [
      { triage_level: "MONITOR", primary_concern: "vomiting", created_at: "2026-05-22T10:00:00Z" },
      { triage_level: "NORMAL",  primary_concern: "mild ear redness", created_at: "2026-05-15" },
    ],
    events: [],
    generatedAtIso: "2026-05-28T00:00:00Z",
  });
  const analyses = sections.find((s) => s.heading === "Recent analyses (last 30 days)");
  assert.ok(analyses);
  assert.equal(analyses.lines.length, 2);
  assert.match(analyses.lines[0], /\[2026-05-22\] MONITOR — vomiting/);
  assert.match(analyses.lines[1], /\[2026-05-15\] NORMAL — mild ear redness/);
});

test("empty history sections render a friendly placeholder instead of nothing", () => {
  const sections = buildReportSections({
    pet: { name: "Rex", species: "dog" },
    analyses: [],
    events: [],
    generatedAtIso: "2026-05-28T00:00:00Z",
  });
  const a = sections.find((s) => s.heading === "Recent analyses (last 30 days)");
  const e = sections.find((s) => s.heading === "Recent health events (last 30 days)");
  assert.deepEqual(a.lines, ["(no recent analyses)"]);
  assert.deepEqual(e.lines, ["(no recent health events)"]);
});

test("history caps prevent unbounded token / page growth for power users", () => {
  const big = Array.from({ length: 25 }, (_, i) => ({
    triage_level: "MONITOR",
    primary_concern: `item ${i}`,
    created_at: "2026-05-15T12:00:00Z",
  }));
  const sections = buildReportSections({
    pet: { name: "Rex", species: "dog" },
    analyses: big,
    events: big.map((_, i) => ({ event_type: "weight", event_date: "2026-05-15", notes: `e${i}` })),
    generatedAtIso: "2026-05-28T00:00:00Z",
  });
  const a = sections.find((s) => s.heading === "Recent analyses (last 30 days)");
  const e = sections.find((s) => s.heading === "Recent health events (last 30 days)");
  assert.equal(a.lines.length, 10);
  assert.equal(e.lines.length, 10);
});

test("reportFilename sanitizes the pet name and stamps the date", () => {
  assert.equal(
    reportFilename({ name: "Mister Whiskers" }, "2026-05-28T12:00:00Z"),
    "pawdoc-mister-whiskers-2026-05-28.pdf",
  );
  // No pet name / weird chars -> safe default.
  assert.equal(
    reportFilename({ name: "!!!" }, "2026-05-28T12:00:00Z"),
    "pawdoc-pet-2026-05-28.pdf",
  );
});
