/// Auth-screen controller — email OTP flow.
///
/// The controller exposes a tiny state machine:
///   Idle → Sending → CodeSent(email)
///   CodeSent → Verifying → Authenticated (handled by auth stream)
///   Any → Failed(message)
///
/// We hand the user a stable, friendly error message — never the raw
/// Supabase exception text.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/logger.dart';
import '../../shared/services/supabase_client.dart';

@immutable
sealed class AuthScreenState {
  const AuthScreenState();
}

class AuthIdle extends AuthScreenState {
  const AuthIdle();
}

class AuthSending extends AuthScreenState {
  const AuthSending();
}

class CodeSent extends AuthScreenState {
  const CodeSent(this.email);
  final String email;
}

class AuthVerifying extends AuthScreenState {
  const AuthVerifying(this.email);
  final String email;
}

class AuthFailed extends AuthScreenState {
  const AuthFailed(this.message, {this.email});
  final String message;
  final String? email;
}

class AuthController extends StateNotifier<AuthScreenState> {
  AuthController(this._client) : super(const AuthIdle());

  final SupabaseClient _client;
  static final _log = AppLogger.of('auth.controller');

  Future<void> sendOtp(String email) async {
    final trimmed = email.trim().toLowerCase();
    if (!_looksLikeEmail(trimmed)) {
      state = const AuthFailed('Enter a valid email address.');
      return;
    }
    state = const AuthSending();
    try {
      await _client.auth.signInWithOtp(email: trimmed, shouldCreateUser: true);
      _log.info('otp_sent');
      state = CodeSent(trimmed);
    } on AuthException catch (e) {
      _log.warning('otp_send_failed', e.message);
      state = AuthFailed(_friendlyAuthMessage(e), email: trimmed);
    } on Object catch (e, s) {
      _log.severe('otp_send_unexpected', e, s);
      state = const AuthFailed('Could not send the code. Try again.');
    }
  }

  Future<void> verifyOtp({required String email, required String code}) async {
    final cleaned = code.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length < 4) {
      state = AuthFailed(
        'Enter the 6-digit code from your email.',
        email: email,
      );
      return;
    }
    state = AuthVerifying(email);
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: cleaned,
        type: OtpType.email,
      );
      _log.info('otp_verified');
      // Successful verify triggers the auth stream → AuthStatus turns to
      // Authenticated → router redirects. We leave state at verifying so
      // the spinner stays up until the redirect actually happens.
    } on AuthException catch (e) {
      _log.warning('otp_verify_failed', e.message);
      state = AuthFailed(_friendlyAuthMessage(e), email: email);
    } on Object catch (e, s) {
      _log.severe('otp_verify_unexpected', e, s);
      state = AuthFailed(
        'Could not verify that code. Try again.',
        email: email,
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      state = const AuthIdle();
    } on AuthException catch (e) {
      _log.warning('sign_out_failed', e.message);
      // Even on error, push the user to the unauthenticated state — better
      // to be safely signed out than half-authenticated.
      state = const AuthIdle();
    }
  }

  void reset() => state = const AuthIdle();

  bool _looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  String _friendlyAuthMessage(AuthException e) {
    final raw = e.message.toLowerCase();
    if (raw.contains('rate') ||
        raw.contains('429') ||
        raw.contains('too many')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (raw.contains('invalid') && raw.contains('otp')) {
      return 'That code is incorrect or has expired. Request a new code.';
    }
    if (raw.contains('email')) {
      return 'Check your email address and try again.';
    }
    return 'Authentication failed. Please try again.';
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthScreenState>(
      (ref) => AuthController(ref.watch(supabaseClientProvider)),
    );
