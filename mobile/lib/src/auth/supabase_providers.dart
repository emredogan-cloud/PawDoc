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
///
/// Derived from [currentSessionProvider] rather than reading
/// `auth.currentUser` directly. That is load-bearing, not stylistic: reading
/// the client straight created a provider with no reactive dependency at all —
/// [supabaseClientProvider] is a singleton that never changes, so this value
/// was computed once per process and never again.
///
/// Every user-scoped provider (pets, memories, assistant, community, profile)
/// watches this to recompute when identity changes on a shared device. With a
/// frozen dependency they never recomputed, and the previous account's data
/// survived a sign-out — the exact bleed-through this was meant to prevent.
/// Device-reproduced 2026-07-27: after deleting an account and signing in
/// again, Home still showed the deleted account's pet.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentSessionProvider)?.user.id;
});
