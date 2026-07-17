import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/recovery_screen.dart';
import '../auth/sign_in_screen.dart';
import '../auth/supabase_providers.dart';
import '../capture/camera_screen.dart';
import '../core/root_shell.dart';
import '../health/history_timeline_screen.dart';
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
    redirect: (context, state) async {
      final loc = state.matchedLocation;
      // GAP-E1: a recovery session IS a session, so handle it before the normal
      // signed-in / sign-in routing. Manual hits to /recovery without one go home.
      if (inRecovery) return loc == '/recovery' ? null : '/recovery';
      if (loc == '/recovery') return '/';
      final loggedIn = client.auth.currentSession != null;
      final atSignIn = loc == '/sign-in';
      if (!loggedIn) return atSignIn ? null : '/sign-in';
      if (atSignIn) return '/';
      return null;
    },
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
