import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'supabase_providers.dart';

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(supabaseClientProvider));
});

/// Whether the Google button should exist at all: requires the OAuth client
/// id at build time (graceful degrade — no dead controls). A provider seam so
/// widget tests can exercise both states.
final googleSignInAvailableProvider =
    Provider<bool>((ref) => Env.hasGoogleSignIn);

/// Thin wrapper over Supabase auth for the email, Apple, and Google flows.
class AuthController {
  AuthController(this._client, {Future<String?> Function()? googleIdToken})
      : _googleIdToken = googleIdToken ?? _nativeGoogleIdToken;

  final SupabaseClient _client;

  /// Fetches a Google id token via the native sheet, or null on cancel.
  /// Injectable so unit tests never touch the platform plugin.
  final Future<String?> Function() _googleIdToken;

  static bool _googleInitialized = false;

  static Future<String?> _nativeGoogleIdToken() async {
    final signIn = GoogleSignIn.instance;
    if (!_googleInitialized) {
      // The WEB client id is the `serverClientId`: Google mints the id token
      // for that audience and Supabase validates it (dashboard: the same id
      // listed under Auth → Google → authorized client IDs).
      await signIn.initialize(serverClientId: Env.googleWebClientId);
      _googleInitialized = true;
    }
    try {
      final account = await signIn.authenticate(scopeHint: const ['email']);
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<void> signInWithEmail(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String email, String password) {
    return _client.auth.signUp(email: email, password: password);
  }

  /// Native Sign in with Apple. Uses a nonce: the SHA-256 hash is sent to
  /// Apple, and the raw nonce is sent to Supabase to validate the id token.
  Future<void> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple did not return an identity token.');
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  /// Marker for a user-cancelled Google sheet — the UI stays quiet on it
  /// (cancelling is not an error).
  static const googleCancelled = AuthException('google_sign_in_cancelled');

  /// Next Evolution Phase 7 — native Google Sign-In. A first Google sign-in
  /// also CREATES the account (Supabase provisions it; the DB trigger adds
  /// the profile row), so the caller gates it behind the same terms assent
  /// as email sign-up. Throws [googleCancelled] when the user backs out.
  Future<void> signInWithGoogle() async {
    final idToken = await _googleIdToken();
    if (idToken == null) throw googleCancelled;
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// GAP-E1: send a password-reset email. The link returns to the app via the
  /// `pawdoc://` scheme (router-handled); the PASSWORD_RECOVERY auth event then
  /// drives the set-new-password screen. Requires SMTP (founder, F-13) + the
  /// redirect URL allow-listed in the Supabase dashboard.
  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'pawdoc://login-callback',
    );
  }

  /// GAP-E1: set a new password during a recovery session.
  Future<void> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() => _client.auth.signOut();

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
}
