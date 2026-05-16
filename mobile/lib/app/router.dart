/// `go_router` configuration with auth + onboarding redirect logic.
///
/// Routing contract (also documented in Phase 1C plan §2.2):
///   - `initializing` auth → stay on splash
///   - `unauthenticated` → /auth (no protected screen ever flashes)
///   - `authenticated` + 0 pets → /onboarding
///   - `authenticated` + ≥1 pets → /home and friends
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/analysis/analysis_capture_screen.dart';
import '../features/analysis/analysis_loading_screen.dart';
import '../features/analysis/analysis_result_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/verify_otp_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_pet_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/pets/pets_controller.dart';
import '../features/settings/settings_screen.dart';
import '../shared/models/analysis_result.dart';
import '../shared/models/pet.dart';
import '../shared/providers/auth_provider.dart';

class AppRoutes {
  AppRoutes._();
  static const String splash = '/';
  static const String auth = '/auth';
  static const String authVerify = '/auth/verify';
  static const String onboardingWelcome = '/onboarding/welcome';
  static const String onboardingPet = '/onboarding/pet';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String analysisNew = '/analysis/new';
  static const String analysisLoading = '/analysis/loading';
  static const String analysisResult = '/analysis/result';
}

final routerProvider = Provider<GoRouter>((ref) {
  // The router rebuilds on auth/pets changes, but the GoRouter instance
  // is cached: GoRouter listens to its `refreshListenable` for redirects.
  // We use a small Listenable that fires when either provider changes.
  final refreshListenable = _RouterRefreshListenable(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final authStatus = ref.read(authStateProvider);
      final petsState = ref.read(petsControllerProvider);
      final loc = state.matchedLocation;

      // Don't redirect away from splash while auth is initializing.
      if (authStatus is AuthInitializing) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // Unauthenticated → only /auth and /auth/verify allowed.
      if (authStatus is Unauthenticated) {
        if (loc == AppRoutes.auth || loc == AppRoutes.authVerify) return null;
        return AppRoutes.auth;
      }

      // Authenticated:
      // - if pets are still loading, hold them on splash so we don't
      //   flash the wrong screen.
      if (petsState is PetsLoading) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }
      // - if no pets, push them to onboarding (unless they are on it).
      final hasPet = petsState is PetsReady && petsState.pets.isNotEmpty;
      if (!hasPet) {
        if (loc.startsWith('/onboarding')) return null;
        return AppRoutes.onboardingWelcome;
      }
      // - authenticated + has pet: forbid /auth and /onboarding.
      if (loc == AppRoutes.splash ||
          loc.startsWith('/auth') ||
          loc.startsWith('/onboarding')) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const _SplashScreen()),
      GoRoute(path: AppRoutes.auth, builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: AppRoutes.authVerify,
        builder: (_, state) {
          final email = state.extra as String? ?? '';
          return VerifyOtpScreen(email: email);
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingWelcome,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPet,
        builder: (_, _) => const OnboardingPetScreen(),
      ),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.analysisNew,
        builder: (context, state) {
          final pet = state.extra as Pet?;
          if (pet == null) {
            return const _MissingExtra(label: 'pet for analysis');
          }
          return AnalysisCaptureScreen(pet: pet);
        },
      ),
      GoRoute(
        path: AppRoutes.analysisLoading,
        builder: (_, _) => const AnalysisLoadingScreen(),
      ),
      GoRoute(
        path: AppRoutes.analysisResult,
        builder: (context, state) {
          final result = state.extra as AnalysisResult?;
          if (result == null) {
            return const _MissingExtra(label: 'analysis result');
          }
          return AnalysisResultScreen(result: result);
        },
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pets_rounded,
                size: 96,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingExtra extends StatelessWidget {
  const _MissingExtra({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    // Should be unreachable in normal flow; if a deep link lands here
    // without an extra, route the user home rather than crash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) GoRouter.of(context).go(AppRoutes.home);
    });
    return Scaffold(body: Center(child: Text('Missing $label')));
  }
}

/// Bridge a couple of Riverpod providers into a Listenable that
/// `go_router` watches for redirect triggers.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(this._ref) {
    _sub1 = _ref.listen<AuthStatus>(authStateProvider, (_, _) {
      notifyListeners();
    });
    _sub2 = _ref.listen<PetsState>(petsControllerProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;
  late final ProviderSubscription<AuthStatus> _sub1;
  late final ProviderSubscription<PetsState> _sub2;

  @override
  void dispose() {
    _sub1.close();
    _sub2.close();
    super.dispose();
  }
}
