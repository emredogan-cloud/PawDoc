// Phase 6.3 — PDF Health Report content shaping.
//
// The actual rendering uses pdf-lib (Deno-importable via esm.sh) in the
// /generate-pdf-report Edge Function, but the *content* — what goes on each
// line, where to wrap, the disclaimer — is shaped here as a pure data
// structure so it can be unit-tested without pulling in the PDF runtime.
//
// The output is intentionally an array of "section" objects with line lists,
// which a thin renderer turns into pdf-lib text() calls. Keeping the renderer
// dumb lets us swap PDF libraries later without touching the content logic.

const DISCLAIMER = (
  "PawDoc provides information, not a veterinary diagnosis. " +
  "In an emergency, contact a veterinarian immediately."
);

const MAX_RECENT_ANALYSES = 10;
const MAX_RECENT_EVENTS = 10;

function fmtDate(iso) {
  if (!iso) return "";
  // ISO "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM:SSZ" — keep the date portion.
  return String(iso).slice(0, 10);
}

function age(birthDateIso, asOfIso) {
  if (!birthDateIso) return null;
  try {
    const b = new Date(birthDateIso.slice(0, 10) + "T00:00:00Z");
    const a = new Date((asOfIso ?? new Date().toISOString()).slice(0, 10) + "T00:00:00Z");
    const days = Math.max(0, Math.floor((a - b) / 86_400_000));
    return Math.round((days / 365.25) * 10) / 10; // 1 dp
  } catch {
    return null;
  }
}

function profileLines(pet) {
  const lines = [`Species: ${pet?.species ?? "—"}`];
  if (pet?.breed) lines.push(`Breed: ${pet.breed}`);
  const yrs = age(pet?.birth_date);
  if (yrs !== null) lines.push(`Age: ${yrs} years`);
  if (pet?.sex) lines.push(`Sex: ${pet.sex}`);
  if (pet?.weight_kg) lines.push(`Weight: ${pet.weight_kg} kg`);
  if (pet?.client_name) lines.push(`Client: ${pet.client_name}`);
  return lines;
}

function analysesLines(analyses) {
  if (!Array.isArray(analyses) || analyses.length === 0) {
    return ["(no recent analyses)"];
  }
  return analyses.slice(0, MAX_RECENT_ANALYSES).map((a) => {
    const date = fmtDate(a?.created_at);
    const triage = (a?.triage_level ?? "").toUpperCase() || "—";
    const concern = a?.primary_concern || "(no concern recorded)";
    return `[${date || "earlier"}] ${triage} — ${concern}`;
  });
}

function eventsLines(events) {
  if (!Array.isArray(events) || events.length === 0) {
    return ["(no recent health events)"];
  }
  return events.slice(0, MAX_RECENT_EVENTS).map((e) => {
    const date = fmtDate(e?.event_date);
    const kind = e?.event_type || "event";
    const notes = e?.notes ? ` — ${e.notes}` : "";
    return `[${date || "earlier"}] ${kind}${notes}`;
  });
}

// Pure builder. Pass the joined data from the Edge Function; get back an
// array of sections the renderer can walk verbatim.
export function buildReportSections({ pet, analyses, events, generatedAtIso }) {
  const generated = fmtDate(generatedAtIso) || fmtDate(new Date().toISOString());
  return [
    { kind: "title", text: "PawDoc Health Report" },
    { kind: "subtitle", text: `${pet?.name ?? "Pet"} • generated ${generated}` },
    { kind: "section", heading: "Pet profile", lines: profileLines(pet) },
    {
      kind: "section",
      heading: "Recent analyses (last 30 days)",
      lines: analysesLines(analyses),
    },
    {
      kind: "section",
      heading: "Recent health events (last 30 days)",
      lines: eventsLines(events),
    },
    { kind: "footer", text: DISCLAIMER },
  ];
}

// Convenience for tests and for telemetry log lines.
export function reportFilename(pet, generatedAtIso) {
  const safe = (pet?.name ?? "pet").toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "");
  const date = fmtDate(generatedAtIso) || fmtDate(new Date().toISOString());
  return `pawdoc-${safe || "pet"}-${date}.pdf`;
}

export const PDF_REPORT_DISCLAIMER = DISCLAIMER;
