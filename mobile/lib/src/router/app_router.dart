import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/sign_in_screen.dart';
import '../auth/supabase_providers.dart';
import '../capture/camera_screen.dart';
import '../health/history_timeline_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_flow.dart';
import '../pets/pets_list_screen.dart';
import '../referral/referral_prefs.dart';
import '../text_input/symptom_text_screen.dart';

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
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final atSignIn = state.matchedLocation == '/sign-in';
      if (!loggedIn) return atSignIn ? null : '/sign-in';
      if (atSignIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingFlow()),
      GoRoute(path: '/pets', builder: (context, state) => const PetsListScreen()),
      GoRoute(path: '/history', builder: (context, state) => const HealthHistoryScreen()),
      GoRoute(path: '/capture', builder: (context, state) => const CameraScreen()),
      GoRoute(path: '/symptom-text', builder: (context, state) => const SymptomTextScreen()),
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
