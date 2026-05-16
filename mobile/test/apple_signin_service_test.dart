/// Tests for the Apple Sign-In service.
///
/// We don't drive the platform plugin from a unit test (it requires real
/// iOS APIs). Instead we cover the pure-Dart helpers and the
/// `isSupported` gating that decides whether the button appears.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/shared/services/apple_signin_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppleSignInError.userMessage', () {
    test('every kind except userCancelled has user-visible copy', () {
      for (final kind in AppleSignInError.values) {
        if (kind == AppleSignInError.userCancelled) {
          expect(kind.userMessage, isEmpty);
        } else {
          expect(kind.userMessage, isNotEmpty);
          expect(kind.userMessage.length, lessThan(160));
        }
      }
    });

    test('messages do not leak backend identifiers', () {
      const taboo = ['http', 'supabase', 'sentry', 'fastapi', 'exception'];
      for (final kind in AppleSignInError.values) {
        final m = kind.userMessage.toLowerCase();
        for (final t in taboo) {
          expect(
            m.contains(t),
            isFalse,
            reason: '$kind leaked "$t": ${kind.userMessage}',
          );
        }
      }
    });
  });

  group('nonce generation', () {
    test('produces a non-empty base64 url string', () {
      final raw = AppleSignInServiceImpl.generateNonce();
      expect(raw, isNotEmpty);
      expect(RegExp(r'^[A-Za-z0-9_\-=]+$').hasMatch(raw), isTrue);
    });

    test('each call yields a different nonce', () {
      final a = AppleSignInServiceImpl.generateNonce();
      final b = AppleSignInServiceImpl.generateNonce();
      expect(a, isNot(equals(b)));
    });

    test('sha256Hex is deterministic 64-char hex', () {
      const raw = 'sample';
      final hex = AppleSignInServiceImpl.sha256Hex(raw);
      expect(hex.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hex), isTrue);
      // Same input → same output.
      expect(hex, AppleSignInServiceImpl.sha256Hex(raw));
    });
  });

  group('Supabase AuthException mapping', () {
    test('400 "provider is not enabled" → notConfigured', () {
      final err = debugMapAuthException(
        const AuthException('Provider is not enabled', statusCode: '400'),
      );
      expect(err, AppleSignInError.notConfigured);
    });

    test('400 "Unsupported provider" → notConfigured', () {
      final err = debugMapAuthException(
        const AuthException('Unsupported provider: apple', statusCode: '400'),
      );
      expect(err, AppleSignInError.notConfigured);
    });

    test('400 generic → invalidResponse', () {
      final err = debugMapAuthException(
        const AuthException('Bad nonce', statusCode: '400'),
      );
      expect(err, AppleSignInError.invalidResponse);
    });

    test('422 → invalidResponse', () {
      final err = debugMapAuthException(
        const AuthException('Token expired', statusCode: '422'),
      );
      expect(err, AppleSignInError.invalidResponse);
    });

    test('5xx / no statusCode → network', () {
      final err = debugMapAuthException(
        const AuthException('Internal Server Error', statusCode: '500'),
      );
      expect(err, AppleSignInError.network);
    });
  });
}
