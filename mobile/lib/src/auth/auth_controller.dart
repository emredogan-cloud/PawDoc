import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_providers.dart';

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(supabaseClientProvider));
});

/// Thin wrapper over Supabase auth for the email and Apple flows.
class AuthController {
  AuthController(this._client);

  final SupabaseClient _client;

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
