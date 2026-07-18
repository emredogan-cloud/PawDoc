import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a caught error into calm, user-safe copy.
///
/// Raw exception objects must NEVER reach a first-time pet owner: an RC
/// on-device test surfaced a raw `ClientException with SocketException: Failed
/// host lookup: PROJECT.supabase.co` and a raw `{"code":"unexpected_failure",
/// "message":"Database error querying schema"}` on the sign-in screen, because
/// supabase-dart wraps both the transport failure and the server error body in
/// `AuthException.message` and the UI showed `.message` verbatim. Log the real
/// error; show the human one.

bool _contains(String haystack, List<String> needles) {
  final s = haystack.toLowerCase();
  return needles.any(s.contains);
}

bool _looksOffline(String m) => _contains(m, const [
      'socketexception',
      'clientexception',
      'failed host lookup',
      'connection closed',
      'connection refused',
      'connection reset',
      'network is unreachable',
      'handshakeexception',
      'timeoutexception',
      'operation timed out',
    ]);

bool _looksTechnical(String m) =>
    _looksOffline(m) ||
    m.contains('{') || // a raw JSON error body leaked through
    _contains(m, const [
      'database error',
      'unexpected_failure',
      'internal server',
      'statuscode',
      'schema',
      'exception:',
    ]);

/// Friendly message for an authentication failure (sign-in / sign-up / reset).
/// Clean, already-human auth messages ("Invalid login credentials", "User
/// already registered") pass through; transport/server-internal detail does not.
String friendlyAuthError(Object error) {
  final message = error is AuthException ? error.message : error.toString();
  if (_looksOffline(message)) {
    return "Couldn't reach PawDoc. Check your internet connection and try again.";
  }
  if (_looksTechnical(message) || error is! AuthException) {
    return 'Something went wrong. Please try again in a moment.';
  }
  return message;
}

/// Friendly message for a failed data load (history, reminders, …). [noun] is
/// the thing being loaded, e.g. "history" → "Couldn't load your history".
String friendlyLoadError(Object error, {required String noun}) {
  if (_looksOffline(error.toString())) {
    return "Couldn't load your $noun — check your connection and try again.";
  }
  return "Couldn't load your $noun. Please try again.";
}
