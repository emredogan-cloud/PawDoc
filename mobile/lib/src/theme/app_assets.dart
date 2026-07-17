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
  static const String sysError = '$_ill/system/system_error_calm_v1.png';
  static const String sysOffline = '$_ill/system/system_offline_v1.png';

  // ---- NEW UI translation illustrations (OLD→NEW migration, 2026-06-12) ----
  // Cartoon puppy+kitten duo in the new teal-green design language. Every one is
  // rendered through [AppImage] with a code fallback, so a missing file degrades
  // gracefully (§7.4). Filenames are authoritative — provided by asset gen.
  static const String onbWelcomeDuoMoon = '$_ill/onboarding/welcome_duo_moon_v1.png'; // 002 home empty
  static const String onbDuoContent = '$_ill/onboarding/onboarding_duo_content_v1.png'; // 003 value
  static const String onbDuoHug = '$_ill/onboarding/onboarding_duo_hug_v1.png'; // 004 add pet
  static const String onbSafetyDuo = '$_ill/onboarding/onboarding_safety_duo_v1.png'; // 005 safety
  static const String onbBellDuo = '$_ill/onboarding/onboarding_bell_duo_v1.png'; // 006 notifications
  static const String onbFirstCheckDuo = '$_ill/onboarding/onboarding_firstcheck_duo_v1.png'; // 007 first check
  static const String cameraGuidance = '$_ill/camera/camera_guidance_v1.png'; // 015/016 capture
  static const String petsNone = '$_ill/pets/no_pets_v1.png'; // pets empty
  static const String premiumGiftOpen = '$_ill/premium/gift_box_open_v1.png'; // 013 referral / 007 free checks
  static const String premiumSleepingDog = '$_ill/premium/premium_sleeping_dog_v1.png'; // 011 hero
  static const String premiumValueIcons = '$_ill/premium/premium_value_icons_v1.png'; // 011 value strip
  static const String premiumEnvelopePaw = '$_ill/premium/referral_envelope_paw_v1.png'; // 011 notify-me / coming soon
  static const String trustSleepingDuo = '$_ill/premium/trust_sleeping_cat_v1.png'; // 001 footer / 010 danger / 011
  static const String resultCompanion = '$_ill/results/analysis_companion_v1.png'; // 019 result body
  static const String resultEmergencySupport = '$_ill/results/emergency_support_v1.png'; // emergency result
  static const String resultFirstCheckComplete = '$_ill/results/first_check_complete_v1.png'; // result success
  static const String resultHistoryEmpty = '$_ill/results/history_empty_v1.png'; // 018 history hero
  static const String resultMonitor = '$_ill/results/monitor_result_v1.png'; // 019 monitor banner
  static const String offlineCompanion = '$_ill/system/offline_companion_v1.png'; // offline

  // ---- Species + avatars (keyed by the Species enum value) ----
  // 'other' ships as the paw mascot file (species_other_paw.png) — without
  // this mapping the Other chip silently fell back to the emoji (M2 find).
  static String species(String key) =>
      '$_ic/species/species_${key == 'other' ? 'other_paw' : key}.png';
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
  static const String historyEmptyLoop = '$_m/history_empty_loop_v1.json'; // matrix #8
  static const String premiumWelcome = '$_m/premium_welcome_v1.json'; // A8, one-shot (M3)
  static const String errorNapLoop = '$_m/error_nap_loop_v1.json'; // A9 (M4)

  /// M2 flagship — the Paw Pals species rig (7 artboards, state machine
  /// `pal`). Budget ≤300KB, gate-tested in test/paw_pals_riv_test.dart.
  static const String pawPals = '$_m/paw_pals_v1.riv'; // A10

  /// Every shipped motion asset with its required PNG fallback (drives the
  /// budget/parse test and the reduce-motion audit).
  static const Map<String, String> allWithFallbacks = {
    onbHeroLoop: AppAssets.onbHero,
    emptyHomeLoop: AppAssets.emptyHome,
    signinHeartbeat: AppAssets.logoMark,
    paywallPeaceLoop: AppAssets.paywallPeace,
    familyCircleLoop: AppAssets.familyCircle,
    historyEmptyLoop: AppAssets.emptyHistory,
    premiumWelcome: AppAssets.paywallPeace,
    errorNapLoop: AppAssets.sysError,
  };
}
