// Structured JSON logger used by every edge function.
//
// Supabase captures stdout from edge functions into the dashboard's log
// viewer. JSON output makes queries cheap; freeform text makes them
// expensive. So everything goes through this module.
//
// Discipline:
//   - Never log raw secret values (PawDoc API keys, JWTs).
//   - In production, never log raw user emails. They are PII under GDPR.
//   - Always include `fn` (which edge function) and `request_id` (when
//     available from the inbound request).

import { isLocal } from "./env.ts";

type LogLevel = "debug" | "info" | "warn" | "error";

interface LogContext {
  [key: string]: unknown;
}

function emit(level: LogLevel, msg: string, ctx?: LogContext): void {
  const record = {
    ts: new Date().toISOString(),
    level,
    msg,
    ...(ctx ?? {}),
  };
  // Stdout is captured by Supabase; one JSON object per line.
  const line = JSON.stringify(record);
  if (level === "error" || level === "warn") {
    console.error(line);
  } else {
    console.log(line);
  }
}

export const log = {
  debug(msg: string, ctx?: LogContext): void {
    if (isLocal()) emit("debug", msg, ctx);
  },
  info(msg: string, ctx?: LogContext): void {
    emit("info", msg, ctx);
  },
  warn(msg: string, ctx?: LogContext): void {
    emit("warn", msg, ctx);
  },
  error(msg: string, ctx?: LogContext): void {
    emit("error", msg, ctx);
  },
} as const;

/** Sanitise a user email for logs — preserves domain, masks the local-part. */
export function maskEmail(email: string): string {
  const at = email.indexOf("@");
  if (at < 1) return "***";
  return `${email.slice(0, 1)}***${email.slice(at)}`;
}
