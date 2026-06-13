/// GAP-E9: extract a family-invite token from whatever a user pastes for the
/// manual-entry fallback — used when the invite deep link didn't open the app
/// (link copied out of a message, opened in a different browser, etc.).
///
/// Accepts a full invite link — `https://pawdoc.app/invite/<token>` or
/// `pawdoc://invite/<token>`, with an optional query/fragment — or a bare
/// token. Returns null for anything that doesn't contain a plausible token, so
/// the UI can reject junk before calling the accept endpoint.
String? parseInviteToken(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  const marker = '/invite/';
  final idx = s.indexOf(marker);
  if (idx >= 0) {
    final rest = s.substring(idx + marker.length);
    final token = rest.split(RegExp(r'[/?#]')).first.trim();
    return _isToken(token) ? token : null;
  }
  // No link marker: treat the whole input as a bare token if it looks like one.
  return _isToken(s) ? s : null;
}

bool _isToken(String s) =>
    s.isNotEmpty && RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(s);
