"use client";

import { useEffect, useRef, useState } from "react";

// Build-time public config (inlined by Next for the static export). Set these as
// Cloudflare Pages env vars (see web/.env.example + runbook 21).
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";
const TURNSTILE_SITE_KEY = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY ?? "";

const STORE = {
  appStore: "https://apps.apple.com/app/pawdoc",
  googlePlay: "https://play.google.com/store/apps/details?id=app.pawdoc",
};

const SPECIES = ["dog", "cat", "rabbit", "guinea_pig", "bird", "reptile", "other"];

type Result = { action: string; observation: string };

function actionColor(action: string): string {
  if (action === "GET_HELP_NOW") return "#C62828";
  if (action === "CALL_TODAY") return "#E65100";
  if (action === "BOOK_VISIT") return "#1565C0";
  return "#FFB300"; // WATCH_AND_RECHECK / default
}

function actionLabel(action: string): string {
  if (action === "GET_HELP_NOW") return "GET HELP NOW — contact a vet";
  if (action === "CALL_TODAY") return "CALL YOUR VET TODAY";
  if (action === "BOOK_VISIT") return "BOOK A ROUTINE VISIT";
  return "WATCH AND RE-CHECK"; // the floor — never "likely normal"
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function turnstile(): any {
  return typeof window !== "undefined" ? (window as unknown as { turnstile?: unknown }).turnstile : undefined;
}

export default function SymptomChecker() {
  const [text, setText] = useState("");
  const [species, setSpecies] = useState("dog");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<Result | null>(null);
  const [error, setError] = useState<string | null>(null);
  const widgetRef = useRef<HTMLDivElement>(null);

  // Load the Turnstile script once (only if a site key is configured).
  useEffect(() => {
    if (!TURNSTILE_SITE_KEY || document.getElementById("cf-turnstile-script")) return;
    const s = document.createElement("script");
    s.id = "cf-turnstile-script";
    s.src = "https://challenges.cloudflare.com/turnstile/v0/api.js";
    s.async = true;
    s.defer = true;
    document.head.appendChild(s);
  }, []);

  async function submit() {
    setError(null);
    setResult(null);
    if (text.trim().length < 5) {
      setError("Please describe the symptom in a little more detail.");
      return;
    }
    if (!SUPABASE_URL || !ANON_KEY) {
      setError("The checker isn't configured yet. Please try again later.");
      return;
    }
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const token = (turnstile() as any)?.getResponse?.() ?? "";
    setLoading(true);
    try {
      const resp = await fetch(`${SUPABASE_URL}/functions/v1/analyze-anonymous`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          apikey: ANON_KEY,
          Authorization: `Bearer ${ANON_KEY}`,
        },
        body: JSON.stringify({ text_description: text.trim(), species, token }),
      });
      if (resp.status === 429) {
        setError("You've reached the free limit (3/day). Download the app for unlimited checks.");
        return;
      }
      if (resp.status === 403) {
        setError("We couldn't verify you're human. Please refresh and try again.");
        return;
      }
      if (!resp.ok) {
        setError("The checker is temporarily unavailable. Please try again shortly.");
        return;
      }
      const data = await resp.json();
      setResult(data.result as Result);
    } catch {
      setError("Network error. Please check your connection and try again.");
    } finally {
      setLoading(false);
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (turnstile() as any)?.reset?.(); // force a fresh token for the next submit
    }
  }

  return (
    <div className="section">
      <textarea
        aria-label="Describe the symptom"
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="e.g. My rabbit hasn't eaten since yesterday and seems quiet."
        rows={5}
        style={{ width: "100%", padding: 12, borderRadius: 8, border: "1px solid #e2e8e6" }}
      />
      <div style={{ display: "flex", gap: 12, alignItems: "center", margin: "12px 0", flexWrap: "wrap" }}>
        <label>
          Species:{" "}
          <select value={species} onChange={(e) => setSpecies(e.target.value)}>
            {SPECIES.map((s) => (
              <option key={s} value={s}>
                {s.replace("_", " ")}
              </option>
            ))}
          </select>
        </label>
        {TURNSTILE_SITE_KEY ? (
          <div ref={widgetRef} className="cf-turnstile" data-sitekey={TURNSTILE_SITE_KEY} />
        ) : null}
      </div>
      <button className="badge" onClick={submit} disabled={loading} style={{ border: "none", cursor: "pointer" }}>
        {loading ? "Checking…" : "Check symptoms"}
      </button>

      {error ? (
        <div className="card" style={{ marginTop: 16 }}>
          <p>{error}</p>
          <div className="badges" style={{ justifyContent: "flex-start" }}>
            <a className="badge" href={STORE.appStore}>App Store</a>
            <a className="badge" href={STORE.googlePlay}>Google Play</a>
          </div>
        </div>
      ) : null}

      {result ? (
        <div style={{ marginTop: 24 }}>
          <div
            style={{
              padding: 16,
              borderRadius: 12,
              background: actionColor(result.action),
              color: "#fff",
              fontWeight: 700,
              textAlign: "center",
            }}
          >
            {actionLabel(result.action)}
          </div>
          <p style={{ marginTop: 16, fontWeight: 600 }}>{result.observation}</p>

          {result.action === "GET_HELP_NOW" ? (
            // SAFETY: never gate the emergency message behind the funnel.
            <p style={{ color: "#C62828" }}>
              This may be an emergency. Contact your veterinarian or an emergency animal hospital now.
            </p>
          ) : null}

          {/* Conversion funnel: the detailed "what to do" is app-only. */}
          <div style={{ position: "relative", marginTop: 16 }}>
            <div
              aria-hidden
              style={{ filter: "blur(6px)", userSelect: "none", pointerEvents: "none" }}
            >
              <h3>What to do next</h3>
              <p>1. ____________________________________</p>
              <p>2. ____________________________________</p>
              <p>3. ____________________________________</p>
            </div>
            <div
              style={{
                position: "absolute",
                inset: 0,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                textAlign: "center",
                gap: 8,
              }}
            >
              <strong>Get the full step-by-step guidance in the PawDoc app</strong>
              <span className="note">Save your pet&rsquo;s history, add photos, and track follow-ups.</span>
              <div className="badges">
                <a className="badge" href={STORE.appStore}>App Store</a>
                <a className="badge" href={STORE.googlePlay}>Google Play</a>
              </div>
            </div>
          </div>

          <p className="note" style={{ marginTop: 16 }}>
            PawDoc provides information, not a veterinary diagnosis. When in doubt, contact your vet.
          </p>
        </div>
      ) : null}
    </div>
  );
}
