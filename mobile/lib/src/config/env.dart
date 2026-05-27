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

  /// True only when both Supabase values are present, so the app can degrade
  /// gracefully (and tests can run) without a live backend configured.
  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
