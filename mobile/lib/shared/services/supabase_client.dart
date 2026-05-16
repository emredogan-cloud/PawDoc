/// Supabase client provider.
///
/// Phase 1C: returns the singleton from `Supabase.initialize(...)` set up in
/// `main.dart`. That singleton owns session persistence, secure storage of
/// the JWT, and the auth event stream — none of which we want to
/// duplicate.
///
/// Tests override this provider with a mock client so they don't need to
/// initialise the real SDK.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read via `ref.watch(supabaseClientProvider)`. The mobile is built around
/// this seam — every Supabase call goes through it.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  // `Supabase.initialize` MUST have been called in main.dart before the
  // first read. If it hasn't, the SDK throws a clear "not initialized"
  // error which propagates here.
  return Supabase.instance.client;
});
