// Typed access to environment variables.
//
// Edge Functions run as Deno isolates; secrets flow in via the Supabase
// secrets store (`supabase secrets set ...`) or, locally, via the project's
// `.env`-style files loaded by the CLI. Either way, `Deno.env.get` is the
// only sanctioned read path.
//
// The exports here centralise validation so a missing required value fails
// the very first request rather than at deepest call site.

export function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value || value.length === 0) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

export function optionalEnv(name: string, fallback = ""): string {
  const v = Deno.env.get(name);
  return v && v.length > 0 ? v : fallback;
}

export function isLocal(): boolean {
  return optionalEnv("SUPABASE_ENV", "local") === "local";
}
