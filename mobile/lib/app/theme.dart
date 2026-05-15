/// Material 3 theming for PawDoc.
///
/// Brand colours from roadmap §10 (Phase 1 task list):
///   - Primary: teal #00897B
///   - Secondary: amber #FFB300
///
/// Triage-state colours surface in result screens (Phase 1).
library;

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color brandPrimary = Color(0xFF00897B);
  static const Color brandSecondary = Color(0xFFFFB300);

  static const Color triageEmergency = Color(0xFFD32F2F);
  static const Color triageMonitor = Color(0xFFF9A825);
  static const Color triageNormal = Color(0xFF2E7D32);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: Brightness.light,
    ).copyWith(secondary: brandSecondary);
    return _baseTheme(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: Brightness.dark,
    ).copyWith(secondary: brandSecondary);
    return _baseTheme(scheme);
  }

  static ThemeData _baseTheme(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
