/// Unit tests for AuthController.
///
/// We mock SupabaseClient + its auth surface via mocktail. The
/// controller's responsibility is the state machine + friendly-message
/// mapping — we test both.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pawdoc/features/auth/auth_controller.dart';
import 'package:pawdoc/shared/services/analytics_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockAuth extends Mock implements GoTrueClient {}

void main() {
  late _MockClient client;
  late _MockAuth auth;
  late AuthController controller;

  setUpAll(() {
    // Real enum value is fine — OtpType.email is the value we always pass.
    registerFallbackValue(OtpType.email);
  });

  setUp(() {
    client = _MockClient();
    auth = _MockAuth();
    when(() => client.auth).thenReturn(auth);
    controller = AuthController(client, RecordingAnalyticsService());
  });

  group('sendOtp', () {
    test('rejects invalid email without hitting Supabase', () async {
      await controller.sendOtp('not-an-email');
      expect(controller.state, isA<AuthFailed>());
      verifyNever(() => auth.signInWithOtp(email: any(named: 'email')));
    });

    test('transitions to CodeSent on success', () async {
      when(
        () => auth.signInWithOtp(
          email: any(named: 'email'),
          shouldCreateUser: any(named: 'shouldCreateUser'),
        ),
      ).thenAnswer((_) async {});

      await controller.sendOtp('user@example.test');
      final state = controller.state;
      expect(state, isA<CodeSent>());
      expect((state as CodeSent).email, 'user@example.test');
    });

    test('maps rate-limit AuthException to friendly copy', () async {
      when(
        () => auth.signInWithOtp(
          email: any(named: 'email'),
          shouldCreateUser: any(named: 'shouldCreateUser'),
        ),
      ).thenThrow(const AuthException('rate limit exceeded'));
      await controller.sendOtp('user@example.test');
      expect(controller.state, isA<AuthFailed>());
      final msg = (controller.state as AuthFailed).message;
      expect(msg, contains('Too many'));
    });

    test('maps unknown AuthException to generic friendly copy', () async {
      when(
        () => auth.signInWithOtp(
          email: any(named: 'email'),
          shouldCreateUser: any(named: 'shouldCreateUser'),
        ),
      ).thenThrow(const AuthException('something opaque from server'));
      await controller.sendOtp('user@example.test');
      final msg = (controller.state as AuthFailed).message;
      expect(msg, isNot(contains('opaque')));
      expect(msg, contains('Authentication failed'));
    });
  });

  group('verifyOtp', () {
    test('rejects empty/short code without hitting Supabase', () async {
      await controller.verifyOtp(email: 'u@e.t', code: '12');
      expect(controller.state, isA<AuthFailed>());
      verifyNever(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      );
    });

    test('transitions to verifying on successful call', () async {
      when(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => AuthResponse(session: null, user: null));

      await controller.verifyOtp(email: 'u@e.t', code: '123456');
      expect(controller.state, isA<AuthVerifying>());
    });

    test('maps invalid-OTP exception to user copy', () async {
      when(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      ).thenThrow(const AuthException('Invalid OTP'));
      await controller.verifyOtp(email: 'u@e.t', code: '123456');
      final msg = (controller.state as AuthFailed).message;
      expect(msg, contains('incorrect'));
    });
  });

  test('signOut sets Idle regardless of error', () async {
    when(() => auth.signOut()).thenThrow(const AuthException('boom'));
    await controller.signOut();
    expect(controller.state, isA<AuthIdle>());
  });
}
