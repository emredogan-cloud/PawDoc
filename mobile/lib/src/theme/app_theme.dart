import 'package:flutter/material.dart';

/// PawDoc brand palette (per roadmap §UI): teal primary, amber secondary.
class AppColors {
  const AppColors._();
  static const Color teal = Color(0xFF00897B);
  static const Color amber = Color(0xFFFFB300);
}

/// Material 3 themes. Dark mode follows the system setting (handled by
/// MaterialApp.themeMode default of ThemeMode.system).
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
    ).copyWith(secondary: AppColors.amber);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}
