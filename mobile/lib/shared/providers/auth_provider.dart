/// Authentication state — driven by the Supabase auth event stream.
///
/// We expose two providers:
///   - [authStreamProvider]: live stream of auth events from supabase_flutter.
///   - [authStateProvider]: a normalised [AuthState] derived from the stream.
///     Widgets and the router subscribe to this rather than to the raw stream.
///
/// State transitions:
///   Initializing → Authenticated   (cold start with a saved session)
///   Initializing → Unauthenticated (cold start with no session)
///   Authenticated ↔ Unauthenticated (signOut / signInWithOtp)
///
/// We never expose the raw JWT through this provider — the SupabaseClient
/// holds it and forwards it on every authenticated request.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_client.dart';

@immutable
sealed class AuthStatus {
  const AuthStatus();
}

class AuthInitializing extends AuthStatus {
  const AuthInitializing();
}

class Unauthenticated extends AuthStatus {
  const Unauthenticated();
}

class Authenticated extends AuthStatus {
  const Authenticated(this.user);
  final User user;
}

/// Raw stream from supabase_flutter. Cold start emits `initialSession`
/// then either a signed-in or signed-out event.
final authStreamProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Normalised auth state — the router + every UI subscribes to this.
final authStateProvider = Provider<AuthStatus>((ref) {
  final stream = ref.watch(authStreamProvider);
  return stream.when(
    loading: () {
      // Before the first event lands, fall back to whatever session the
      // SDK already has cached (cold start with persisted session).
      final session = ref.watch(supabaseClientProvider).auth.currentSession;
      if (session == null) return const AuthInitializing();
      return Authenticated(session.user);
    },
    error: (_, _) => const Unauthenticated(),
    data: (event) {
      final user = event.session?.user;
      return user == null ? const Unauthenticated() : Authenticated(user);
    },
  );
});
