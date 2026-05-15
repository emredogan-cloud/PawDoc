/// Supabase client provider.
///
/// Phase 0 defines the seam; Phase 1 wires real auth + storage + DB usage.
/// The provider intentionally throws if the app starts without
/// `SUPABASE_ANON_KEY` configured — fail loud, not silently.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config.dart';

/// Eagerly-initialized Supabase client.
///
/// Use via:
///   final supabase = ref.read(supabaseClientProvider);
///
/// During tests, override this provider with a mock.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasSupabase) {
    throw StateError(
      'Supabase anon key missing. Run with --dart-define-from-file=env/dev.json '
      'and populate SUPABASE_ANON_KEY.',
    );
  }
  return SupabaseClient(config.supabaseUrl, config.supabaseAnonKey);
});
