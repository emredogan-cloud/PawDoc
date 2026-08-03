import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/design_tokens.dart';
import 'theme/paw_components.dart';

class PawDocApp extends ConsumerWidget {
  const PawDocApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PawDoc',
      debugShowCheckedModeBanner: false,
      // UX-01: PawDoc is a single always-dark visual world (13 screens hard-
      // code PawSurface.dark). Pin themeMode so a light-mode OS can never pair
      // light onSurface text with the dark background — that combination made
      // safety guidance near-invisible for light-mode users.
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      // Phase 5.4 — i18n: English + German (CR #11). The same locale is also
      // sent to the Edge / AI service so the safety-critical emergency-keyword
      // override matches the UI language.
      // UX-03: clamp OS text scaling so accessibility sizes grow text without
      // shattering fixed-height cards; 1.6x keeps large-font (often older)
      // pet owners readable and layouts intact.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler
                .clamp(minScaleFactor: 1.0, maxScaleFactor: 1.6),
          ),
          // System B is declared at the app root, not in RootShell.
          //
          // A pushed route is inserted into the Navigator that *owns* the
          // shell, which sits above any scope the shell provides — so every
          // detail screen (analysis, memories, encyclopedia, account, …) was
          // still resolving to PawSystem.legacy and rendering teal primitives
          // on a black canvas. Declaring it here covers pushed routes too.
          //
          // Onboarding and sign-in override this to their own system; the
          // emergency screens are unaffected either way, since they carry the
          // safety-locked red rather than a brand accent.
          child: PawSystemScope(
            system: PawSystem.b,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Locale fallback: a device locale outside en/de must fall back to
      // ENGLISH — NOT Flutter's default of the first supported locale, which is
      // 'de' (alphabetical) and would surface German to, e.g., a Turkish user
      // on the safety-critical emergency screen.
      localeListResolutionCallback: resolveAppLocale,
      routerConfig: router,
    );
  }
}

/// Resolve the app locale from the device's preferred list against [supported]
/// (en/de). Matches by language code; any unsupported locale (or none) falls
/// back to ENGLISH — never Flutter's default first-supported ('de'). Pure +
/// unit-tested so the safety copy can never silently surface in a language the
/// user didn't pick.
Locale resolveAppLocale(List<Locale>? deviceLocales, Iterable<Locale> supported) {
  for (final device in deviceLocales ?? const <Locale>[]) {
    for (final s in supported) {
      if (s.languageCode == device.languageCode) return s;
    }
  }
  return const Locale('en');
}
