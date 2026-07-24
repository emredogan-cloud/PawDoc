import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The initialized Supabase client. `Supabase.initialize(...)` runs in main()
/// before the app is built; reading this provider before that throws, which is
/// intentional (fail fast on misconfiguration).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Emits on every auth change (sign-in, sign-out, token refresh). The router
/// listens to this to re-evaluate its redirect.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// The current session, or null when signed out. Recomputed on every auth change.
final currentSessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession;
});

/// The signed-in user's id, or null. A seam of its own so widget tests can
/// override identity without faking a whole Supabase client.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});
