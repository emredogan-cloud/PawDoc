/// Single source of truth for asset paths (PAWDOC_UI_UX_MASTER_ROADMAP.md §7.2).
///
/// No raw asset strings in widgets — always reference `AppAssets.*`. Every
/// illustration is rendered through `AppImage` (core/app_image.dart) so a
/// not-yet-generated asset degrades to a themed fallback instead of a broken
/// box. This lets the design-token / theme work merge before the art exists.
class AppAssets {
  const AppAssets._();

  static const _brand = 'assets/brand';
  static const _ill = 'assets/illustrations';
  static const _ic = 'assets/icons';

  // ---- Brand ----
  static const String logoMark = '$_brand/logo_mark_v1.png';
  static const String splashLogo = '$_brand/splash_logo.png';

  // ---- Illustrations: onboarding / analysis / empties / monetization / growth ----
  static const String onbHero = '$_ill/onboarding/onboarding_hero_value_v1.png';
  static const String shieldCare = '$_ill/analysis/shield_care_v1.png';
  static const String scanAccent = '$_ill/analysis/analysis_scan_accent_v1.png';
  static const String emptyHome = '$_ill/empty_states/empty_home_welcome_v1.png';
  static const String emptyHistory = '$_ill/empty_states/empty_history_story_v1.png';
  static const String paywallPeace =
      '$_ill/monetization/paywall_peace_of_mind_v1.png';
  static const String familyCircle = '$_ill/growth/family_care_circle_v1.png';
  static const String referralGift = '$_ill/growth/referral_gift_v1.png';
  static const String referralGiftOpen = '$_ill/growth/referral_gift_open_v1.png';
  static const String sysError = '$_ill/system/system_error_calm_v1.png';
  static const String sysOffline = '$_ill/system/system_offline_v1.png';

  // ---- Species + avatars (keyed by the Species enum value) ----
  static String species(String key) => '$_ic/species/species_$key.png';
  static String avatar(String key) => '$_ic/avatars/avatar_$key.png';

  // ---- Status glyphs (always paired with text label + shape — never alone) ----
  static const String statusEmergency = '$_ic/status/status_emergency.png';
  static const String statusMonitor = '$_ic/status/status_monitor.png';
  static const String statusNormal = '$_ic/status/status_normal.png';
}
