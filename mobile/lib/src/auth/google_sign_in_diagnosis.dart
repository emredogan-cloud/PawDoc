import 'package:flutter/foundation.dart';

/// What to tell the user — and the developer — when Google sign-in fails.
///
/// Written after the 2026-07-28 incident: Google Sign-In worked on every
/// sideloaded build and failed on every Play-installed one. Google Play
/// Services was reporting the exact cause the whole time —
///
///     Auth.Api.Credentials: [GoogleSignIn_flowRunner] Flow failed.
///     cipe: [8] Unknown error [status=UNREGISTERED_ON_API_CONSOLE].
///
/// — but the app caught the exception, threw the code and description away,
/// and showed "Google sign-in failed. Please try again." That message was
/// wrong twice over: it hid the only diagnostic that mattered, and it told
/// users to retry a misconfiguration that could never fix itself by retrying.
///
/// Two rules encoded here:
///   1. The raw cause is always logged (see [logGoogleSignInFailure]).
///   2. A configuration failure never says "try again".
@immutable
class GoogleSignInDiagnosis {
  const GoogleSignInDiagnosis({
    required this.userMessage,
    required this.retryable,
  });

  /// One sentence for the sign-in screen's inline banner.
  final String userMessage;

  /// Whether retrying could plausibly succeed. False for configuration faults,
  /// where the honest thing is to point at the alternative (email sign-in)
  /// rather than invite a pointless second tap.
  final bool retryable;
}

/// True when the failure means "this app+signature isn't registered with
/// Google" — i.e. package name or signing certificate matches no Android OAuth
/// client in the Cloud project.
///
/// Google reports this several ways depending on Play Services version, so we
/// match on the stable substrings rather than a single code:
///   * `UNREGISTERED_ON_API_CONSOLE` — the newer Credential Manager wording
///   * `Developer console is not set up correctly` / `[28444]` — older wording
///   * `DEVELOPER_ERROR` / `10` — the classic GoogleSignInStatusCode
bool isDeveloperConfigurationFailure(String? description) {
  if (description == null) return false;
  final d = description.toUpperCase();
  return d.contains('UNREGISTERED_ON_API_CONSOLE') ||
      d.contains('DEVELOPER CONSOLE IS NOT SET UP CORRECTLY') ||
      d.contains('DEVELOPER_ERROR') ||
      d.contains('28444');
}

/// Map a Google sign-in failure to what the user should see.
///
/// Takes primitives rather than the plugin's exception type so the decision is
/// unit-testable without the platform channel.
GoogleSignInDiagnosis diagnoseGoogleSignIn({
  required String code,
  String? description,
}) {
  if (isDeveloperConfigurationFailure(description)) {
    // Nothing the user can do. Do not offer a retry.
    return const GoogleSignInDiagnosis(
      userMessage:
          'Google sign-in is not available in this version of PawDoc. '
          'Please sign in with your email address instead — you can use the '
          'same email as your Google account.',
      retryable: false,
    );
  }

  final c = code.toLowerCase();
  final d = (description ?? '').toLowerCase();

  if (c.contains('network') || d.contains('network') || d.contains('timeout')) {
    return const GoogleSignInDiagnosis(
      userMessage:
          'Could not reach Google. Check your connection and try again.',
      retryable: true,
    );
  }

  if (c.contains('providerconfiguration') || d.contains('play services')) {
    return const GoogleSignInDiagnosis(
      userMessage:
          'Google Play services is unavailable or out of date on this device. '
          'Update it, or sign in with your email address instead.',
      retryable: false,
    );
  }

  return const GoogleSignInDiagnosis(
    userMessage: 'Google sign-in did not complete. Please try again.',
    retryable: true,
  );
}

/// Put the raw cause where a release build can actually be debugged from.
///
/// `dart:developer`'s `log()` does NOT reach logcat in a release build — that
/// is precisely why the 2026-07-28 investigation needed temporary
/// device-specific instrumentation to see what Google was saying. `debugPrint`
/// goes through `print`, which does reach logcat, so `adb logcat | grep
/// '\[auth/google\]'` is enough next time.
void logGoogleSignInFailure(String code, String? description) {
  debugPrint('[auth/google] sign-in failed: code=$code description=$description');
}
