import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/sign_in_screen.dart';
import '../auth/supabase_providers.dart';
import '../capture/camera_screen.dart';
import '../family/accept_family_invite_screen.dart';
import '../family/family_settings_screen.dart';
import '../family/pending_invite_prefs.dart';
import '../health/history_timeline_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_flow.dart';
import '../pets/pets_list_screen.dart';
import '../referral/referral_prefs.dart';
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

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) async {
      final loggedIn = client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final atSignIn = loc == '/sign-in';
      if (!loggedIn) {
        // Preserve a /invite/:token deep link across the sign-in detour
        // (same shape as the Phase 3.3 referral capture). Token is restored
        // post-sign-in on the next pass through this redirect.
        if (loc.startsWith('/invite/')) {
          await PendingInvitePrefs.capture(loc);
        }
        return atSignIn ? null : '/sign-in';
      }
      // Signed in: if a pending invite is parked, route there once.
      if (atSignIn || loc == '/') {
        final pending = await PendingInvitePrefs.pop();
        if (pending != null) return pending;
      }
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
            AppPageTransitions.fadeThrough(context, const HomeScreen()),
      ),
      GoRoute(
        path: '/sign-in',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(context, const SignInScreen()),
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
      // Phase 6.3.1 — Family Sharing settings + deep link.
      GoRoute(
        path: '/family',
        pageBuilder: (context, state) =>
            AppPageTransitions.sharedAxisVertical(context, const FamilySettingsScreen()),
      ),
      // Invite acceptance — handles both pawdoc://invite/:token (custom scheme)
      // and https://pawdoc.app/invite/:token (Universal / App Link). The auth
      // redirect above bounces unsigned-in users to /sign-in first; go_router
      // restores this route on return so the token isn't lost.
      GoRoute(
        path: '/invite/:token',
        builder: (_, state) => AcceptFamilyInviteScreen(
          token: state.pathParameters['token'] ?? '',
        ),
      ),
      // Referral deep link (https://pawdoc.app/r/CODE or pawdoc://r/CODE): capture
      // the code, then fall through to the normal auth-gated flow.
      GoRoute(
        path: '/r/:code',
        redirect: (context, state) async {
          final code = state.pathParameters['code'];
          if (code != null && code.isNotEmpty) await ReferralPrefs.capture(code);
          return '/';
        },
      ),
    ],
  );
});
