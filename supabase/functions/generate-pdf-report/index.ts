// Phase 6.3 — /generate-pdf-report Edge Function (premium-included).
//
// PRIVACY LIFECYCLE — see the report (§3 of SUBPR_PHASE_6.3.md):
//   * NO SERVER STORAGE. The PDF is rendered in memory and streamed to the
//     client as the response body. We never write to R2, Supabase Storage,
//     or local disk. Once the client receives the bytes, GC reclaims them.
//   * NO LOGGING OF THE PDF CONTENT. Only metadata (pet_id, byte size) is
//     ever logged.
//   * The data fetched to build the PDF is read under the USER'S JWT
//     (RLS-scoped); the service-role admin client is used ONLY to look up
//     the subscription status.
//
// ENTITLEMENT — server-side enforced: PDF reports are premium-included
// (no consumable credits, no add-on products).
//
// verify_jwt = true (Edge Functions default) — the user's JWT identifies them.

import { createClient } from "jsr:@supabase/supabase-js@2";
// deno-lint-ignore no-import-assertions
import { buildReportSections, reportFilename } from "../_shared/pdf_report.mjs";
import { PDFDocument, StandardFonts, rgb } from "https://esm.sh/pdf-lib@1.17.1";

const PREMIUM_STATUSES = new Set(["premium", "trial"]);

Deno.serve(async (req: Request) => {
  const requestId = req.headers.get("x-request-id") ?? crypto.randomUUID();
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "x-request-id": requestId },
    });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: auth } = await userClient.auth.getUser();
  const user = auth?.user;
  if (!user) return json({ error: "unauthorized" }, 401);

  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }
  const petId = body?.pet_id;
  if (!petId || typeof petId !== "string") {
    return json({ error: "pet_id required" }, 400);
  }

  // RLS-scoped reads: only succeed for the caller's own pet.
  const { data: pet, error: petErr } = await userClient
    .from("pets")
    .select("id, name, species, breed, sex, weight_kg, birth_date")
    .eq("id", petId)
    .single();
  if (petErr || !pet) return json({ error: "pet not found" }, 404);

  // Entitlement check: PDF reports are a premium feature.
  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const { data: profile, error: profileErr } = await admin
    .from("users")
    .select("subscription_status")
    .eq("id", user.id)
    .single();
  if (profileErr) {
    console.error("generate-pdf-report: profile read failed", requestId, profileErr.message);
    return json({ error: "profile lookup failed" }, 500);
  }
  const isPremium = PREMIUM_STATUSES.has(profile?.subscription_status ?? "free");
  if (!isPremium) {
    return json({
      error: "premium_required",
      message: "PDF Health Reports are part of PawDoc Premium.",
    }, 402);
  }

  // Personalization context (same window as Phase 6.1 / 30 days), RLS-scoped.
  const since = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString();
  // deno-lint-ignore no-explicit-any
  let analyses: any[] = [];
  // deno-lint-ignore no-explicit-any
  let events: any[] = [];
  try {
    const a = await userClient
      .from("analyses")
      .select("action, observation, created_at")
      .eq("pet_id", petId)
      .gte("created_at", since)
      .order("created_at", { ascending: false })
      .limit(10);
    if (Array.isArray(a.data)) analyses = a.data;
  } catch (_err) {
    // best-effort
  }
  try {
    const e = await userClient
      .from("health_events")
      .select("event_type, event_date, notes")
      .eq("pet_id", petId)
      .gte("event_date", since.slice(0, 10))
      .order("event_date", { ascending: false })
      .limit(10);
    if (Array.isArray(e.data)) events = e.data;
  } catch (_err) {
    // best-effort
  }

  // Render the PDF entirely in memory. We never persist to storage.
  const sections = buildReportSections({
    pet,
    analyses,
    events,
    generatedAtIso: new Date().toISOString(),
  });

  const pdfBytes = await renderPdf(sections);

  const filename = reportFilename(pet, new Date().toISOString());
  // SECURITY HEADERS for an ephemeral PDF response:
  //   * Cache-Control: no-store         — no proxy / browser caching.
  //   * Content-Disposition: attachment — force download (no inline render).
  //   * X-Request-Id                    — trace, no PII.
  return new Response(pdfBytes, {
    status: 200,
    headers: {
      "content-type": "application/pdf",
      "content-disposition": `attachment; filename="${filename}"`,
      "cache-control": "no-store, max-age=0",
      "x-request-id": requestId,
    },
  });
});

// --- Renderer: dumb pdf-lib glue. Walks the sections built by the shared
// content shaper; no policy logic lives here.
// deno-lint-ignore no-explicit-any
async function renderPdf(sections: any[]): Promise<Uint8Array> {
  const pdf = await PDFDocument.create();
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const bold = await pdf.embedFont(StandardFonts.HelveticaBold);

  let page = pdf.addPage([612, 792]); // US Letter portrait
  const margin = 48;
  let y = 792 - margin;
  const lineHeight = 16;

  const writeLine = (text: string, opts: { font?: typeof font; size?: number; color?: ReturnType<typeof rgb> } = {}) => {
    if (y < margin + lineHeight) {
      page = pdf.addPage([612, 792]);
      y = 792 - margin;
    }
    page.drawText(text, {
      x: margin,
      y,
      size: opts.size ?? 11,
      font: opts.font ?? font,
      color: opts.color ?? rgb(0, 0, 0),
    });
    y -= opts.size ? opts.size + 4 : lineHeight;
  };

  for (const s of sections) {
    if (s.kind === "title") {
      writeLine(s.text, { font: bold, size: 20 });
      y -= 4;
    } else if (s.kind === "subtitle") {
      writeLine(s.text, { size: 11, color: rgb(0.35, 0.35, 0.35) });
      y -= 8;
    } else if (s.kind === "section") {
      writeLine(s.heading, { font: bold, size: 13 });
      for (const line of s.lines) writeLine(line);
      y -= 6;
    } else if (s.kind === "footer") {
      y = Math.min(y, margin + lineHeight + 12); // push to bottom margin
      writeLine(s.text, { size: 9, color: rgb(0.45, 0.45, 0.45) });
    }
  }
  return await pdf.save();
}
