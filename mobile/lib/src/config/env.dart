/// Compile-time configuration, supplied via `--dart-define` (sourced from Doppler).
///
/// Never hardcode secrets. Run with, e.g.:
///   flutter run \
///     --dart-define=SUPABASE_URL=$SUPABASE_URL \
///     --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
///     --dart-define=SENTRY_DSN=$SENTRY_DSN
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String posthogApiKey = String.fromEnvironment('POSTHOG_API_KEY');
  static const String posthogHost =
      String.fromEnvironment('POSTHOG_HOST', defaultValue: 'https://us.i.posthog.com');
  static const String revenueCatPublicKey =
      String.fromEnvironment('REVENUECAT_PUBLIC_SDK_KEY');
  static const String oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');

  /// Phase 5.4 — Airvet-style telehealth affiliate URL. The deep-link is a
  /// partner referral (revenue share); empty in dev/test => the button hides.
  static const String airvetAffiliateUrl =
      String.fromEnvironment('AIRVET_AFFILIATE_URL');

  /// Phase 6.3 — Pet-insurance affiliate URL (e.g. Trupanion or Healthy Paws).
  /// Empty in dev/test => the CTA hides — no broken-link footgun.
  static const String petInsuranceAffiliateUrl =
      String.fromEnvironment('PET_INSURANCE_AFFILIATE_URL');

  /// True only when both Supabase values are present, so the app can degrade
  /// gracefully (and tests can run) without a live backend configured.
  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
