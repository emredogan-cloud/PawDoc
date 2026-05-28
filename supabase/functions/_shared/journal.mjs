// Pure helpers for the AI Health Journal cron (Phase 5.3).
// Plain ESM so it runs in Deno (the Edge Function) and Node (the unit test).

/** Monday of the week containing `date`, in UTC, as `YYYY-MM-DD`. The cron
 *  fires Sunday 00:00 UTC -> this returns the just-completed week's Monday. */
export function mondayOfWeekUtc(date) {
  const d = new Date(date);
  // JS getUTCDay: 0 = Sun ... 6 = Sat. Map so Monday = 0.
  const offset = (d.getUTCDay() + 6) % 7;
  const monday = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - offset));
  const yyyy = monday.getUTCFullYear();
  const mm = String(monday.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(monday.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

/** Compact analysis rows for the prompt — only the fields the journal needs. */
export function summarizeAnalyses(rows) {
  if (!Array.isArray(rows)) return [];
  return rows.map((r) => ({
    created_at: r?.created_at ?? "",
    triage_level: r?.triage_level ?? "",
    primary_concern: r?.primary_concern ?? "",
  }));
}

/** Compact event rows for the prompt. */
export function summarizeEvents(rows) {
  if (!Array.isArray(rows)) return [];
  return rows.map((r) => ({
    event_date: r?.event_date ?? "",
    event_type: r?.event_type ?? "",
    notes: r?.notes ?? null,
  }));
}
