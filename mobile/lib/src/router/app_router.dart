import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/recovery_screen.dart';
import '../auth/sign_in_screen.dart';
import '../auth/supabase_providers.dart';
import '../capture/camera_screen.dart';
import '../core/root_shell.dart';
import '../health/history_timeline_screen.dart';
import '../onboarding/auth_gateway_screen.dart';
import '../onboarding/first_run_screen.dart';
import '../onboarding/onboarding_flow.dart';
import '../pets/pets_list_screen.dart';
import '../text_input/symptom_text_screen.dart';
import 'app_page_transitions.dart';

/// Bridges a Stream to a [Listenable] so go_router re-runs `redirect` whenever
/// auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// The auth-redirect decision, extracted PURE so it is unit-testable without
/// a Supabase client (ENG-02/QA-02: the most brittle navigation logic in the
/// app used to be exercised only through mocks or not at all).
/// Returns the location to redirect to, or null to stay.
/// Routes that a signed-out user is allowed to sit on.
///
/// The first-run journey runs BEFORE authentication: app-open (`0001`) →
/// onboarding (`002`–`009`) → the auth gateway (`000`). Sending an
/// unauthenticated user straight to `/sign-in` would skip all of it, so these
/// four are exempt from the auth redirect.
/// Whether the app-open + onboarding journey has been seen.
///
/// Cached in memory and loaded once at startup: go_router's redirect runs on
/// every navigation, and hitting disk there would add latency to each one.
class FirstRun {
  const FirstRun._();

  static const _key = 'first_run_done';
  static bool _done = false;

  static bool get done => _done;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _done = prefs.getBool(_key) ?? false;
  }

  /// Called when the user reaches the auth gateway — the journey is over
  /// whether they signed up, skipped, or backed out to sign in.
  static Future<void> markDone() async {
    if (_done) return;
    _done = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

const _preAuthRoutes = {
  '/welcome',
  '/onboarding',
  '/auth-gateway',
  '/sign-in',
};

String? computeRedirect({
  required bool inRecovery,
  required bool loggedIn,
  required String location,
  bool firstRunDone = true,
}) {
  // GAP-E1: a recovery session IS a session — handle it before normal routing.
  if (inRecovery) return location == '/recovery' ? null : '/recovery';
  if (location == '/recovery') return '/';

  if (!loggedIn) {
    if (_preAuthRoutes.contains(location)) return null;
    // A fresh install starts the journey; a returning signed-out user goes
    // straight to the gateway rather than replaying onboarding.
    return firstRunDone ? '/auth-gateway' : '/welcome';
  }

  // Signed in: the pre-auth journey is finished, so never sit on it.
  if (location == '/sign-in' ||
      location == '/welcome' ||
      location == '/auth-gateway') {
    return '/';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final refresh = GoRouterRefreshStream(client.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  // GAP-E1: a PASSWORD_RECOVERY deep link opens a short-lived recovery session;
  // route to set-new-password until the user finishes (userUpdated) or signs out.
  var inRecovery = false;
  final recoverySub = client.auth.onAuthStateChange.listen((s) {
    if (s.event == AuthChangeEvent.passwordRecovery) {
      inRecovery = true;
    } else if (s.event == AuthChangeEvent.userUpdated ||
        s.event == AuthChangeEvent.signedOut) {
      inRecovery = false;
    }
  });
  ref.onDispose(recoverySub.cancel);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) async => computeRedirect(
      inRecovery: inRecovery,
      loggedIn: client.auth.currentSession != null,
      location: state.matchedLocation,
      firstRunDone: FirstRun.done,
    ),
    routes: [
      // Page transitions standardized via AppPageTransitions (§4.1). Sections
      // use fade-through; pushed modal/detail screens use shared-axis. Reduce-
      // motion collapses every transition to instant. The result/EMERGENCY
      // screens are pushed via Navigator (not here), so they keep the default
      // clear platform transition — no playful motion on the safety path.
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(context, const RootShell()),
      ),
      GoRoute(
        path: '/sign-in',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(context, const SignInScreen()),
      ),
      GoRoute(
        path: '/recovery',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(context, const RecoveryScreen()),
      ),
      // App-open screen (mockup 0001) — the first thing a fresh install shows.
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          context,
          FirstRunScreen(
            onStart: () => context.go('/onboarding'),
            onSignIn: () => context.go('/sign-in'),
          ),
        ),
      ),
      // Authentication gateway (mockup 000) — shown AFTER onboarding.
      GoRoute(
        path: '/auth-gateway',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(context, const AuthGatewayScreen2()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(context, const OnboardingFlow()),
      ),
      GoRoute(
        path: '/pets',
        pageBuilder: (context, state) =>
            AppPageTransitions.sharedAxisVertical(context, const PetsListScreen()),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(context, const HealthHistoryScreen()),
      ),
      GoRoute(
        path: '/capture',
        pageBuilder: (context, state) =>
            AppPageTransitions.sharedAxisVertical(context, const CameraScreen()),
      ),
      GoRoute(
        path: '/symptom-text',
        pageBuilder: (context, state) =>
            AppPageTransitions.sharedAxisVertical(context, const SymptomTextScreen()),
      ),
    ],
  );
});
