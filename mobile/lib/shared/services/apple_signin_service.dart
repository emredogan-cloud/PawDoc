/// Apple Sign-In integration.
///
/// Discipline:
/// - We generate a cryptographically random nonce, SHA-256 hash it, and
///   send the *hash* to Apple. The *raw* nonce is forwarded to Supabase
///   which verifies that sha256(raw) matches Apple's signed hash.
/// - The button is hidden in code when `appleSignInEnabled = false` so
///   dev builds without the OAuth provider configured don't show a
///   non-functional button.
/// - Errors are translated to friendly copy in `AuthController`; this
///   service surfaces typed exceptions only.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../app/config.dart';
import 'logger.dart';
import 'supabase_client.dart';

/// Outcome of one Apple sign-in attempt.
@immutable
class AppleSignInOutcome {
  const AppleSignInOutcome({required this.success, this.error});
  final bool success;
  final AppleSignInError? error;
}

enum AppleSignInError {
  unsupportedPlatform,
  userCancelled,
  notConfigured,
  network,
  invalidResponse,
  unknown;

  String get userMessage => switch (this) {
    AppleSignInError.unsupportedPlatform =>
      'Apple Sign-In is only available on iOS.',
    AppleSignInError.userCancelled => '',
    AppleSignInError.notConfigured =>
      'Apple Sign-In is not configured for this build.',
    AppleSignInError.network =>
      'Could not reach Apple. Check your connection and try again.',
    AppleSignInError.invalidResponse =>
      'Apple returned an unexpected response. Try again.',
    AppleSignInError.unknown => 'Something went wrong with Apple Sign-In.',
  };
}

abstract class AppleSignInService {
  bool get isSupported;
  Future<AppleSignInOutcome> signIn();
}

class AppleSignInServiceImpl implements AppleSignInService {
  AppleSignInServiceImpl({
    required SupabaseClient client,
    required bool enabled,
    bool? platformIsIos,
  }) : _client = client,
       _enabled = enabled,
       _platformIsIos = platformIsIos ?? Platform.isIOS;

  final SupabaseClient _client;
  final bool _enabled;
  final bool _platformIsIos;
  static final _log = AppLogger.of('auth.apple');

  @override
  bool get isSupported => _enabled && _platformIsIos;

  @override
  Future<AppleSignInOutcome> signIn() async {
    if (!isSupported) {
      return const AppleSignInOutcome(
        success: false,
        error: AppleSignInError.unsupportedPlatform,
      );
    }
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256Hex(rawNonce);

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      _log.warning('apple_auth_exception', e.code.name);
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AppleSignInOutcome(
          success: false,
          error: AppleSignInError.userCancelled,
        );
      }
      if (e.code == AuthorizationErrorCode.notHandled ||
          e.code == AuthorizationErrorCode.notInteractive) {
        return const AppleSignInOutcome(
          success: false,
          error: AppleSignInError.notConfigured,
        );
      }
      return const AppleSignInOutcome(
        success: false,
        error: AppleSignInError.unknown,
      );
    } on Object catch (e, s) {
      _log.severe('apple_sign_in_unexpected', e, s);
      return const AppleSignInOutcome(
        success: false,
        error: AppleSignInError.unknown,
      );
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      _log.warning('apple_missing_id_token');
      return const AppleSignInOutcome(
        success: false,
        error: AppleSignInError.invalidResponse,
      );
    }

    try {
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      _log.info('apple_sign_in_success');
      return const AppleSignInOutcome(success: true);
    } on AuthException catch (e) {
      _log.warning('apple_supabase_failed', '${e.statusCode} ${e.message}');
      return AppleSignInOutcome(success: false, error: _mapAuthException(e));
    } on Object catch (e, s) {
      _log.severe('apple_sign_in_supabase_unexpected', e, s);
      return const AppleSignInOutcome(
        success: false,
        error: AppleSignInError.network,
      );
    }
  }

  /// Supabase's `signInWithIdToken` returns 400 with a "provider is not
  /// enabled" / "Unsupported provider" message when the Apple OAuth
  /// provider has not been turned on for the project. That's an
  /// operator misconfiguration, not a user error — surface it as
  /// `notConfigured` so the UI suggests the email path instead of
  /// asking the user to retry.
  static AppleSignInError _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    final looksLikeProviderDisabled =
        msg.contains('provider') &&
        (msg.contains('not enabled') ||
            msg.contains('disabled') ||
            msg.contains('unsupported'));
    if (e.statusCode == '400' && looksLikeProviderDisabled) {
      return AppleSignInError.notConfigured;
    }
    if (e.statusCode == '422' || e.statusCode == '400') {
      return AppleSignInError.invalidResponse;
    }
    return AppleSignInError.network;
  }

  // ---- Test seams -------------------------------------------------------

  @visibleForTesting
  static String generateNonce({int byteLength = 32, Random? random}) =>
      _generateNonce(byteLength: byteLength, random: random);

  @visibleForTesting
  static String sha256Hex(String raw) => _sha256Hex(raw);

  // ---- Internals --------------------------------------------------------

  static String _generateNonce({int byteLength = 32, Random? random}) {
    final r = random ?? Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => r.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _sha256Hex(String raw) {
    return crypto.sha256.convert(utf8.encode(raw)).toString();
  }
}

/// Provider — returns a stub on non-iOS/disabled so consumers can call
/// `.isSupported` without platform checks. Routes the enabled flag
/// through `AppConfig` so tests can override the value via the
/// `appConfigProvider`.
final appleSignInServiceProvider = Provider<AppleSignInService>((ref) {
  final config = ref.watch(appConfigProvider);
  return AppleSignInServiceImpl(
    client: ref.watch(supabaseClientProvider),
    enabled: config.appleSignInEnabled,
  );
});

/// Internal helper exposed for tests of [AppleSignInServiceImpl]'s
/// Supabase-error mapping logic. Keeps the gnarly statusCode + message
/// heuristics testable without a real `SupabaseClient`.
@visibleForTesting
AppleSignInError debugMapAuthException(AuthException e) =>
    AppleSignInServiceImpl._mapAuthException(e);
