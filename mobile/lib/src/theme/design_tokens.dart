import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PawDoc design tokens — the single source of truth for color, type, spacing,
/// radius, elevation, motion and glass.
///
/// `app_theme.dart` builds both the light and dark [ThemeData] from these tokens
/// so every screen restyles by construction rather than by hand. Grounded in
/// PAWDOC_UI_UX_MASTER_ROADMAP.md §2 (Redesign Vision).
///
/// Tokens only — no safety logic, route, or contract lives here. The triage
/// status hues below are SAFETY-LOCKED: they are part of the emergency/monitor/
/// normal language and must never be repurposed for decoration, and must always
/// pair with an icon + text label (never color alone). See §2.2.

/// Brand, accent, semantic-status and warm-ink neutral colors (§2.2).
class AppColors {
  const AppColors._();

  // ---- Brand & primary (teal seed kept; safety-meaningful) ----
  static const Color teal700 = Color(0xFF00897B); // brand anchor / seed
  static const Color teal600Light = Color(0xFF009E8E); // primary action (light)
  static const Color teal600Dark = Color(0xFF1FB6A6);
  static const Color teal300Light = Color(0xFF5FD6C6);
  static const Color teal300Dark = Color(0xFF7FE6D6); // matches today's mint pills
  static const Color teal50Light = Color(0xFFE6F6F3);
  static const Color teal50Dark = Color(0xFF16201E);

  // ---- Accents ----
  static const Color amber500Light = Color(0xFFFFB300); // secondary + MONITOR
  static const Color amber500Dark = Color(0xFFFFC233);
  static const Color coral400Light = Color(0xFFFF8A65); // warmth only — never status
  static const Color coral400Dark = Color(0xFFFF9E80);

  // ---- Semantic status (SAFETY-LOCKED — do not repurpose for decoration) ----
  static const Color emergencyLight = Color(0xFFC62828); // EMERGENCY
  static const Color emergencyDark = Color(0xFFFF5A52);
  static const Color monitorLight = Color(0xFFFFB300); // MONITOR
  static const Color monitorDark = Color(0xFFFFC233);
  static const Color normalLight = Color(0xFF2E7D32); // LIKELY NORMAL / success
  static const Color normalDark = Color(0xFF66BB6A);
  static const Color infoLight = Color(0xFF0277BD); // informational
  static const Color infoDark = Color(0xFF4FC3F7);

  // ---- Warm-ink neutrals (dark = signature theme) ----
  static const Color ink900 = Color(0xFF0E1413); // app background
  static const Color ink850 = Color(0xFF141B19); // base surface
  static const Color ink800 = Color(0xFF1A2220); // cards (surfaceContainer)
  static const Color ink700 = Color(0xFF212B28); // raised cards / sheets
  static const Color ink600 = Color(0xFF33403C); // outline / dividers
  static const Color ink300 = Color(0xFFA7B6B1); // secondary text
  static const Color ink50 = Color(0xFFEAF3F0); // primary text (soft white)

  // ---- Light-mode warm off-whites ----
  static const Color lightBackground = Color(0xFFF7FAF9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFEFF4F2);
  static const Color lightText = Color(0xFF1A2220);
  static const Color lightTextSecondary = Color(0xFF4C5A56);
  static const Color lightOutline = Color(0xFFC9D6D1);

  // ---- Back-compat aliases (existing call-sites referenced these) ----
  static const Color teal = teal700;
  static const Color amber = amber500Light;

  /// Theme-aware accessor for the EMERGENCY status hue.
  static Color emergency(Brightness b) =>
      b == Brightness.dark ? emergencyDark : emergencyLight;

  /// Theme-aware accessor for the MONITOR status hue.
  static Color monitor(Brightness b) =>
      b == Brightness.dark ? monitorDark : monitorLight;

  /// Theme-aware accessor for the LIKELY-NORMAL / success status hue.
  static Color normal(Brightness b) =>
      b == Brightness.dark ? normalDark : normalLight;

  /// Theme-aware accessor for the informational hue.
  static Color info(Brightness b) => b == Brightness.dark ? infoDark : infoLight;
}

/// Typography (§2.3). Bricolage Grotesque @600 for display/headlines (warm,
/// modern-clinical); Inter for all body/labels/numerals. Loaded via google_fonts
/// (cached at runtime; runtime fetching is disabled in tests for determinism).
class AppType {
  const AppType._();

  static const String displayFamily = 'Bricolage Grotesque';
  static const String bodyFamily = 'Inter';

  /// Full Material 3 [TextTheme]. Colors are intentionally left null so the
  /// active [ColorScheme] supplies on-surface colors per brightness.
  static TextTheme textTheme() => TextTheme(
        displayLarge: GoogleFonts.bricolageGrotesque(
            fontSize: 36, height: 42 / 36, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        displayMedium: GoogleFonts.bricolageGrotesque(
            fontSize: 32, height: 38 / 32, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        displaySmall: GoogleFonts.bricolageGrotesque(
            fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w600, letterSpacing: -0.25),
        headlineLarge: GoogleFonts.bricolageGrotesque(
            fontSize: 30, height: 36 / 30, fontWeight: FontWeight.w600, letterSpacing: -0.25),
        headlineMedium: GoogleFonts.bricolageGrotesque(
            fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.bricolageGrotesque(
            fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(
            fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(
            fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.inter(
            fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(
            fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(
            fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.inter(
            fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.inter(
            fontSize: 14, height: 18 / 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        labelMedium: GoogleFonts.inter(
            fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, letterSpacing: 0.3),
        labelSmall: GoogleFonts.inter(
            fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500),
      );
}

/// Spacing — 8pt base grid with a 4pt half-step (§2.4). Named by their value so
/// the mechanical sweep reads clearly (`SizedBox(height: AppSpace.s16)`).
class AppSpace {
  const AppSpace._();
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;

  /// Max content width so forms don't sprawl on tablets/foldables (§2.4).
  static const double maxContentWidth = 480;
}

/// Corner radii (§2.5). Stadium buttons are kept (brand cue); cards warm 12→16.
class AppRadius {
  const AppRadius._();
  static const double sm = 10; // chips, small inputs
  static const double md = 16; // cards, fields
  static const double lg = 24; // sheets, hero cards, modals
  static const double xl = 28; // triage result hero
  static const double pill = 999; // stadium buttons

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
}

/// Elevation via tone, soft shadows reserved for the primary CTA + triage hero
/// (§2.6).
class AppElevation {
  const AppElevation._();
  static const double none = 0;
  static const double card = 1;
  static const double cta = 2;
  static const double raised = 3;
  static const double hero = 8;
}

/// Motion language (§2.7 / §4.0): calm confidence — slow-in, gentle-out.
class AppMotion {
  const AppMotion._();
  static const Duration micro = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 280);
  static const Duration hero = Duration(milliseconds: 420);

  /// Material 3 emphasized easing for entrances.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Standard easing for most transitions.
  static const Curve standardCurve = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Soft spring for the few earned delight beats (species pick, success check).
  static const SpringDescription spring =
      SpringDescription(mass: 1, stiffness: 380, damping: 26);
}

/// Frosted-glass presets — used sparingly (capture sheet, analyzing scrim, app
/// bar on scroll). Never on the emergency screen or behind body text (§2.6).
class AppGlass {
  const AppGlass._();
  static const double sheetBlur = 18;
  static const double scrimBlur = 16;
  static const double appBarBlur = 8;
  static const double sheetOpacity = 0.70;
}
