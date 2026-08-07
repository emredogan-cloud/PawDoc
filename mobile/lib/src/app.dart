import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/design_tokens.dart';
import 'theme/paw_components.dart';

/// UX-03: clamp OS text scaling so accessibility sizes grow text without
/// shattering fixed-height cards. 1.6× keeps large-font (often older) pet
/// owners readable and layouts intact; the 1.0 floor stops a shrunk system
/// font making safety copy smaller than the design allows.
///
/// **Not `TextScaler.clamp`.** That returns a scaler carrying its own bounds,
/// and Material's date picker then clamps *that* to `min(currentScale, 1.6)`.
/// At the default system scale of 1.0 the result is a scaler whose min and max
/// are both 1.0, and `_ClampedTextScaler` asserts `maxScale > minScale` — so
/// **every date picker in the app crashed on every device at the default font
/// size** (found on a Redmi Note 8 opening the record form's date field; the
/// reminder form had the same hole). Returning the system scaler untouched
/// when it is already in range, and a plain linear one when it is not, keeps
/// the same clamping behaviour without ever handing the framework a scaler it
/// cannot re-clamp.
TextScaler pawTextScaler(TextScaler system) {
  // `scale(14) / 14` rather than `textScaleFactor`, which is deprecated and
  // meaningless for Android 14's non-linear curve.
  final factor = system.scale(14) / 14;
  if (factor < 1.0) return const TextScaler.linear(1.0);
  if (factor > 1.6) return const TextScaler.linear(1.6);
  // In range: hand back the system scaler itself, so a non-linear OS curve
  // survives instead of being flattened.
  return system;
}

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
          data: mq.copyWith(textScaler: pawTextScaler(mq.textScaler)),
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
