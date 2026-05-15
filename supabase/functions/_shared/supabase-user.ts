// User-context Supabase client.
//
// Forwards the caller's JWT to Supabase so every query runs under their
// identity — RLS policies apply. This is the default for any read that
// represents the user accessing their own data.
//
// The Authorization header MUST be a `Bearer <jwt>` from Supabase Auth;
// `requireUser()` in `./auth.ts` validates this before any handler uses
// this client.

import { createClient, SupabaseClient } from "@supabase/supabase-js";

import { requireEnv } from "./env.ts";
import type { Database } from "./types/db.ts";

export function supabaseUser(req: Request): SupabaseClient<Database> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    // Defensive: the caller is supposed to have run `requireUser` first.
    throw new Error("supabaseUser called without Authorization header");
  }
  return createClient<Database>(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_ANON_KEY"),
    {
      global: { headers: { Authorization: authHeader } },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}
