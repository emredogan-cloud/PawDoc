import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/friendly_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Regression for the RC on-device finding: the sign-in screen showed users a
// raw `ClientException with SocketException: Failed host lookup …` and a raw
// `{"code":"unexpected_failure","message":"Database error querying schema"}`.
// Neither may ever reach a first-time owner.
void main() {
  group('friendlyAuthError', () {
    test('host-lookup / socket failure → calm offline copy, no raw detail', () {
      final msg = friendlyAuthError(const AuthException(
          "ClientException with SocketException: Failed host lookup: "
          "'example-ref.supabase.co'"));
      expect(msg, "Couldn't reach PawDoc. Check your internet connection and try again.");
      expect(msg.toLowerCase(), isNot(contains('socket')));
      expect(msg, isNot(contains('supabase')));
    });

    test('server JSON error body → generic copy, never the raw JSON', () {
      final msg = friendlyAuthError(const AuthException(
          '{"code":"unexpected_failure","message":"Database error querying schema"}'));
      expect(msg, 'Something went wrong. Please try again in a moment.');
      expect(msg, isNot(contains('{')));
      expect(msg.toLowerCase(), isNot(contains('schema')));
    });

    test('clean, already-human auth message passes through', () {
      expect(friendlyAuthError(const AuthException('Invalid login credentials')),
          'Invalid login credentials');
    });

    test('a non-auth error never leaks toString()', () {
      final msg = friendlyAuthError(StateError('boom internal detail'));
      expect(msg, isNot(contains('boom')));
    });
  });

  group('friendlyLoadError', () {
    test('offline → connection copy with the noun', () {
      expect(friendlyLoadError(Exception('SocketException: failed'), noun: 'history'),
          "Couldn't load your history — check your connection and try again.");
    });

    test('other error → generic copy, no raw detail', () {
      final msg = friendlyLoadError(StateError('null check operator'), noun: 'reminders');
      expect(msg, "Couldn't load your reminders. Please try again.");
      expect(msg, isNot(contains('null check')));
    });
  });
}
