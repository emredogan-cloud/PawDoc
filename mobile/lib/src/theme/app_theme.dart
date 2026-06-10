import 'package:flutter/material.dart';

import 'design_tokens.dart';

// `AppColors` now lives in design_tokens.dart (the single source of truth).
// Re-exported here so existing imports of `theme/app_theme.dart` keep compiling.
export 'design_tokens.dart' show AppColors, AppType, AppSpace, AppRadius, AppElevation, AppMotion, AppGlass;

/// Material 3 themes built from [design_tokens]. Dark mode is the signature
/// "warm-ink" theme (calm clinic at night); light mode is "warm clinical day".
/// `themeMode` defaults to [ThemeMode.system] (set in MaterialApp).
///
/// No safety logic here — colors, type, shape and spacing only. The triage
/// status hues are codified from `AppColors` and remain unchanged in value.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.teal700,
      brightness: brightness,
    );

    final scheme = isDark
        ? base.copyWith(
            primary: AppColors.teal300Dark, // mint primary (matches today's pills)
            onPrimary: AppColors.ink900,
            primaryContainer: AppColors.teal50Dark,
            onPrimaryContainer: AppColors.teal300Dark,
            secondary: AppColors.amber500Dark,
            tertiary: AppColors.coral400Dark,
            surface: AppColors.ink850,
            onSurface: AppColors.ink50,
            onSurfaceVariant: AppColors.ink300,
            surfaceContainerLowest: AppColors.ink900,
            surfaceContainerLow: AppColors.ink850,
            surfaceContainer: AppColors.ink800,
            surfaceContainerHigh: AppColors.ink700,
            surfaceContainerHighest: AppColors.ink700,
            outline: AppColors.ink600,
            outlineVariant: AppColors.ink600,
            error: AppColors.emergencyDark,
          )
        : base.copyWith(
            primary: AppColors.teal600Light,
            secondary: AppColors.amber500Light,
            tertiary: AppColors.coral400Light,
            surface: AppColors.lightSurface,
            onSurface: AppColors.lightText,
            onSurfaceVariant: AppColors.lightTextSecondary,
            surfaceContainer: AppColors.lightSurfaceContainer,
            outline: AppColors.lightOutline,
            error: AppColors.emergencyLight,
          );

    final textTheme = AppType.textTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.ink900 : AppColors.lightBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor:
            isDark ? AppColors.ink900 : AppColors.lightBackground,
        foregroundColor: isDark ? AppColors.ink50 : AppColors.lightText,
        titleTextStyle:
            textTheme.titleLarge?.copyWith(color: isDark ? AppColors.ink50 : AppColors.lightText),
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.card,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd), // 12 → 16
      ),
      // Stadium buttons are a brand cue — kept.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          elevation: AppElevation.cta,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s24, vertical: AppSpace.s12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s24, vertical: AppSpace.s12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        labelStyle: textTheme.labelLarge,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: AppRadius.brMd),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.brMd),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.brMd),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      ),
    );
  }
}
