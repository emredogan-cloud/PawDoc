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

/// Lottie motion assets (M1 "First breath", PAWDOC_MOTION_ROADMAP.md §4).
/// Always rendered through `AppMotionAsset` with the matching [AppAssets] PNG
/// as the reduce-motion / degrade fallback. Budget: each file ≤250KB
/// (enforced by test/motion_assets_test.dart).
class AppMotionAssets {
  const AppMotionAssets._();

  static const _m = 'assets/motion';

  static const String onbHeroLoop = '$_m/onboarding_hero_loop_v1.json'; // A1
  static const String emptyHomeLoop = '$_m/empty_home_welcome_loop_v1.json'; // A2
  static const String signinHeartbeat = '$_m/signin_heartbeat_v1.json'; // A3, one-shot
  static const String paywallPeaceLoop = '$_m/paywall_peace_loop_v1.json'; // A4
  static const String familyCircleLoop = '$_m/family_circle_loop_v1.json'; // A5
  static const String referralGiftIdle = '$_m/referral_gift_idle_v1.json'; // A6, settle→loop
  static const String historyEmptyLoop = '$_m/history_empty_loop_v1.json'; // matrix #8

  /// Every shipped motion asset with its required PNG fallback (drives the
  /// budget/parse test and the reduce-motion audit).
  static const Map<String, String> allWithFallbacks = {
    onbHeroLoop: AppAssets.onbHero,
    emptyHomeLoop: AppAssets.emptyHome,
    signinHeartbeat: AppAssets.logoMark,
    paywallPeaceLoop: AppAssets.paywallPeace,
    familyCircleLoop: AppAssets.familyCircle,
    referralGiftIdle: AppAssets.referralGift,
    historyEmptyLoop: AppAssets.emptyHistory,
  };
}
