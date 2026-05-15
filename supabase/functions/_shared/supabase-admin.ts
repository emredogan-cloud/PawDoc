// Service-role Supabase client.
//
// WARNING: This client BYPASSES Row Level Security. Use it only when:
//   - the edge function is operating on behalf of the system (webhooks)
//   - the edge function has already verified ownership manually
//   - the call requires writing to an append-only / billing table
//
// For ANY operation that should be filtered by the caller's identity,
// use `supabaseUser(req)` from `supabase-user.ts` instead.

import { createClient, SupabaseClient } from "@supabase/supabase-js";

import { requireEnv } from "./env.ts";
import type { Database } from "./types/db.ts";

let cached: SupabaseClient<Database> | null = null;

export function supabaseAdmin(): SupabaseClient<Database> {
  if (cached) return cached;
  cached = createClient<Database>(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
  return cached;
}
