import 'package:supabase_flutter/supabase_flutter.dart';

/// GAP-A5: a typed view over Supabase's [FunctionException].
///
/// `functions.invoke` throws [FunctionException] on any non-2xx response, and a
/// blind `catch (_)` discards the server's message — so the free-tier **402**
/// (and the PDF 402 upsell, and family-invite error codes) were invisible,
/// dead-ending free users in a retry loop that can never succeed. This parses
/// the status + JSON `details` so the UI can route a quota-reached response to
/// the paywall (carrying the teaser triage chip from GAP-A3) instead of a
/// generic "couldn't analyze, try again" error.
class FunctionError {
  const FunctionError({
    required this.status,
    this.code,
    this.message,
    this.details,
  });

  final int status;

  /// `details['error']` — a stable machine code, e.g. `free_limit_reached`.
  final String? code;

  /// `details['message']` — the human-facing server message (safe to show).
  final String? message;

  /// The full parsed JSON error body (e.g. `quota_exceeded`, `triage_level`).
  final Map<String, dynamic>? details;

  /// The free-tier / quota wall (server returns 402 with an upgrade message).
  bool get isQuotaExceeded => status == 402;

  /// GAP-A3 teaser: the triage level the server computed for an out-of-quota
  /// VISUAL check (so the upgrade sheet can show the chip). Null otherwise.
  String? get triageLevel => details?['triage_level'] as String?;
}

/// Returns a [FunctionError] if [e] is a Supabase [FunctionException], else null
/// (so callers can fall through to their generic error handling for everything
/// that is not a structured function response).
FunctionError? asFunctionError(Object e) {
  if (e is! FunctionException) return null;
  Map<String, dynamic>? map;
  final d = e.details;
  if (d is Map) {
    map = d.map((k, v) => MapEntry(k.toString(), v));
  }
  return FunctionError(
    status: e.status,
    code: map?['error'] as String?,
    message: map?['message'] as String?,
    details: map,
  );
}
