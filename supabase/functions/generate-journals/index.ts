// Phase 5.3 — /generate-journals
// Weekly cron (pg_cron, Sunday 00:00 UTC). For each opt-in, premium/family pet
// that DOESN'T already have a journal for the just-completed week, it calls the
// AI service /generate_journal and writes the narrative to health_journals.
//
// SECURITY: same secret-header gate as /process-reminders (x-cron-secret ==
// CRON_SECRET, constant-time, fail-closed). verify_jwt = false.
//
// RESILIENCE (CR #5): EVERY pet is processed in its own try/catch so one pet's
// OpenAI failure never blocks the others. On any failure for a pet, we log and
// MOVE ON without writing partial data. UNIQUE(pet_id, week_start_date) makes
// the row insert idempotent — a retry next week is safe.
//
// 60s EDGE TIMEOUT BUDGET: pets are processed in chunks of 5 concurrent calls
// with a soft deadline (~50s). Past the deadline, we stop early; remaining pets
// are picked up by the next weekly run (UNIQUE prevents dupes). For pet counts
// that exceed one weekly slot we recommend moving to a Fly background worker.
import { createClient } from "jsr:@supabase/supabase-js@2";
// deno-lint-ignore no-import-assertions
import { cronSecretValid } from "../_shared/reminders.mjs";
// deno-lint-ignore no-import-assertions
import { mondayOfWeekUtc, summarizeAnalyses, summarizeEvents } from "../_shared/journal.mjs";
// deno-lint-ignore no-import-assertions
import { aiServiceHeaders } from "../_shared/ai_service.mjs";

const AI_SERVICE_URL = Deno.env.get("AI_SERVICE_URL") ?? "https://pawdoc-ai.fly.dev";
// Phase A — trust-boundary credential presented to the internal AI service.
const AI_SERVICE_TOKEN = Deno.env.get("AI_SERVICE_TOKEN") ?? "";
const DEADLINE_MS = 50_000; // leave headroom inside the 60s Edge cap
const CONCURRENCY = 5;

Deno.serve(async (req: Request) => {
  const requestId = req.headers.get("x-request-id") ?? crypto.randomUUID();
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "x-request-id": requestId },
    });

  // Secret-header auth (fail closed if CRON_SECRET unset).
  if (!cronSecretValid(req.headers.get("x-cron-secret"), Deno.env.get("CRON_SECRET") ?? "")) {
    return json({ error: "forbidden" }, 401);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const now = new Date();
  const weekStart = mondayOfWeekUtc(now); // ISO date 'YYYY-MM-DD'
  const cutoff = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();

  // Eligible pets (premium/family/trial + opt-in + not already journaled).
  const { data: pets, error: petsErr } =
    await admin.rpc("pets_pending_journal", { week_start: weekStart });
  if (petsErr) {
    console.error("generate-journals: eligibility query failed", requestId, petsErr.message);
    return json({ error: "eligibility_failed" }, 500);
  }
  const eligible = Array.isArray(pets) ? pets : [];

  let processed = 0;
  let written = 0;
  let skipped = 0;
  const start = Date.now();

  // deno-lint-ignore no-explicit-any
  async function processOne(pet: any) {
    processed++;
    try {
      const [{ data: analyses }, { data: events }] = await Promise.all([
        admin
          .from("analyses")
          .select("triage_level, primary_concern, created_at")
          .eq("pet_id", pet.pet_id)
          .gte("created_at", cutoff)
          .order("created_at", { ascending: true }),
        admin
          .from("health_events")
          .select("event_type, event_date, notes")
          .eq("pet_id", pet.pet_id)
          .gte("event_date", weekStart)
          .order("event_date", { ascending: true }),
      ]);

      const resp = await fetch(`${AI_SERVICE_URL}/generate_journal`, {
        method: "POST",
        headers: aiServiceHeaders(requestId, AI_SERVICE_TOKEN),
        body: JSON.stringify({
          pet: { species: pet.species, breed: pet.breed ?? null, age_years: null, sex: null, weight_kg: null, prior_history: [] },
          week_start_date: weekStart,
          analyses: summarizeAnalyses(analyses),
          events: summarizeEvents(events),
        }),
      });
      if (!resp.ok) {
        skipped++;
        console.error("generate-journals: AI call failed", requestId, pet.pet_id, resp.status);
        return;
      }
      const body = await resp.json();
      if (!body?.narrative) {
        skipped++; // OpenAI down / no key / empty -> no row written (CR #5)
        return;
      }
      const ins = await admin.from("health_journals").insert({
        pet_id: pet.pet_id,
        user_id: pet.user_id,
        narrative_text: body.narrative,
        week_start_date: weekStart,
        model_used: body.model ?? null,
      });
      if (ins.error) {
        // Duplicate (UNIQUE) on a retry is fine; anything else = log + skip.
        if (ins.error.code !== "23505") {
          console.error("generate-journals: insert failed", requestId, pet.pet_id, ins.error.message);
        }
        skipped++;
      } else {
        written++;
      }
    } catch (err) {
      skipped++;
      console.error("generate-journals: pet failed", requestId, pet?.pet_id, String(err));
    }
  }

  // Chunked concurrency with a soft deadline (60s Edge cap).
  for (let i = 0; i < eligible.length; i += CONCURRENCY) {
    if (Date.now() - start > DEADLINE_MS) {
      console.warn("generate-journals: soft deadline hit; deferring", eligible.length - i, "pets");
      break;
    }
    await Promise.all(eligible.slice(i, i + CONCURRENCY).map(processOne));
  }

  return json({
    ok: true,
    week_start: weekStart,
    eligible: eligible.length,
    processed,
    written,
    skipped,
    request_id: requestId,
  });
});
