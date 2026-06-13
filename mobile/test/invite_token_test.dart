import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/family/invite_token.dart';

void main() {
  // GAP-E9: the manual-entry fallback must accept a pasted link or a bare token
  // and reject junk before it reaches the accept endpoint.
  test('extracts the token from an https invite link', () {
    expect(parseInviteToken('https://pawdoc.app/invite/abc123'), 'abc123');
  });

  test('extracts the token from a pawdoc:// deep link', () {
    expect(parseInviteToken('pawdoc://invite/XyZ-9_8'), 'XyZ-9_8');
  });

  test('strips a trailing query and fragment', () {
    expect(parseInviteToken('https://pawdoc.app/invite/tok99?ref=sms#x'), 'tok99');
  });

  test('accepts a bare token and trims surrounding whitespace', () {
    expect(parseInviteToken('  tok_ABC-1.2  '), 'tok_ABC-1.2');
  });

  test('returns null for empty, spaced, or token-less input', () {
    expect(parseInviteToken(''), isNull);
    expect(parseInviteToken('   '), isNull);
    expect(parseInviteToken('join my family please'), isNull);
    expect(parseInviteToken('https://pawdoc.app/invite/'), isNull);
  });
}
