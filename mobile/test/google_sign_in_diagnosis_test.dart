import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/auth/google_sign_in_diagnosis.dart';

/// Regression cover for the 2026-07-28 Play sign-in incident.
///
/// Google Sign-In worked on every sideloaded build and failed on every
/// Play-installed one, because the Play App Signing certificate had no
/// matching Android OAuth client. Google Play Services said so plainly —
/// `[status=UNREGISTERED_ON_API_CONSOLE]` — but the app discarded the code and
/// description and rendered "Google sign-in failed. Please try again."
///
/// These tests pin the two rules that came out of it: recognise a
/// configuration fault, and never invite a retry that cannot work.
void main() {
  group('isDeveloperConfigurationFailure', () {
    test('recognises the exact string Play Services emitted on 2026-07-28', () {
      expect(
        isDeveloperConfigurationFailure(
            'cipe: [8] Unknown error [status=UNREGISTERED_ON_API_CONSOLE].'),
        isTrue,
      );
    });

    test('recognises the older Developer-console wording', () {
      expect(
        isDeveloperConfigurationFailure(
            '[28444] Developer console is not set up correctly.'),
        isTrue,
      );
    });

    test('recognises the classic DEVELOPER_ERROR status', () {
      expect(
        isDeveloperConfigurationFailure(
            'ConnectionResult{statusCode=DEVELOPER_ERROR}'),
        isTrue,
      );
    });

    test('does not fire on unrelated failures', () {
      expect(isDeveloperConfigurationFailure(null), isFalse);
      expect(isDeveloperConfigurationFailure(''), isFalse);
      expect(isDeveloperConfigurationFailure('Network error'), isFalse);
      expect(
        isDeveloperConfigurationFailure('The user cancelled the flow'),
        isFalse,
      );
    });
  });

  group('diagnoseGoogleSignIn', () {
    test('a configuration fault is NOT retryable and offers email instead', () {
      final d = diagnoseGoogleSignIn(
        code: 'unknownError',
        description: 'cipe: [8] Unknown error [status=UNREGISTERED_ON_API_CONSOLE].',
      );
      expect(d.retryable, isFalse,
          reason: 'retrying a misconfiguration can never succeed');
      expect(d.userMessage.toLowerCase(), contains('email'),
          reason: 'the user needs a route that actually works');
      expect(d.userMessage.toLowerCase(), isNot(contains('try again')),
          reason: 'this was the misleading message that shipped');
    });

    test('a network failure IS retryable', () {
      final d = diagnoseGoogleSignIn(
        code: 'unknownError',
        description: 'Network error while fetching token',
      );
      expect(d.retryable, isTrue);
      expect(d.userMessage.toLowerCase(), contains('connection'));
    });

    test('missing Play services points at the device, not a retry', () {
      final d = diagnoseGoogleSignIn(
        code: 'providerConfigurationError',
        description: 'Google Play services is missing',
      );
      expect(d.retryable, isFalse);
      expect(d.userMessage.toLowerCase(), contains('play services'));
    });

    test('an unrecognised failure degrades to a plain retryable message', () {
      final d = diagnoseGoogleSignIn(code: 'unknownError', description: 'weird');
      expect(d.retryable, isTrue);
      expect(d.userMessage, isNotEmpty);
    });

    test('no message ever leaks Google internals to the user', () {
      const leaks = [
        'UNREGISTERED_ON_API_CONSOLE',
        'DEVELOPER_ERROR',
        'cipe',
        '28444',
        'status=',
        'GoogleSignInException',
      ];
      final samples = <String?>[
        'cipe: [8] Unknown error [status=UNREGISTERED_ON_API_CONSOLE].',
        '[28444] Developer console is not set up correctly.',
        'ConnectionResult{statusCode=DEVELOPER_ERROR}',
        'Network error',
        null,
      ];
      for (final s in samples) {
        final msg = diagnoseGoogleSignIn(code: 'unknownError', description: s)
            .userMessage;
        for (final leak in leaks) {
          expect(msg, isNot(contains(leak)), reason: 'leaked "$leak" for "$s"');
        }
        expect(msg.endsWith('.'), isTrue, reason: 'not a sentence: "$msg"');
      }
    });
  });
}
