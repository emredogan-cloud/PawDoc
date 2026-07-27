// Regression cover for the account bleed-through root cause found on-device
// 2026-07-27 (Redmi Note 8, release build 1.0.0+5).
//
// account_switch_isolation_test.dart already proved that petsListProvider
// re-reads when currentUserIdProvider changes. What nothing covered was
// whether currentUserIdProvider *ever* changes in production. It didn't:
//
//   final currentUserIdProvider = Provider<String?>((ref) {
//     return ref.watch(supabaseClientProvider).auth.currentUser?.id;
//   });
//
// supabaseClientProvider is a singleton that never changes, so this provider
// had no reactive dependency — computed once per process, never recomputed.
// Every user-scoped provider that watched it for account isolation (pets,
// memories, assistant, community, user profile) therefore kept serving the
// previous account's cache after a sign-out. The isolation test passed only
// because it called container.invalidate(currentUserIdProvider) by hand.
//
// These tests pin the reactivity itself, so the dependency cannot be dropped
// again without a failure.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/auth/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Session _sessionFor(String uid) => Session(
      accessToken: 'token-$uid',
      tokenType: 'bearer',
      user: User(
        id: uid,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.utc(2026).toIso8601String(),
      ),
    );

void main() {
  test('tracks the signed-in identity as the session changes', () {
    Session? session = _sessionFor('user-a');

    final container = ProviderContainer(overrides: [
      currentSessionProvider.overrideWith((ref) => session),
    ]);
    addTearDown(container.dispose);

    expect(container.read(currentUserIdProvider), 'user-a');

    // A different account signs in on the same device.
    session = _sessionFor('user-b');
    container.invalidate(currentSessionProvider);

    expect(container.read(currentUserIdProvider), 'user-b',
        reason: 'a new session must produce the new identity, not a stale one');
  });

  test('reports null once the session is gone', () {
    Session? session = _sessionFor('user-a');

    final container = ProviderContainer(overrides: [
      currentSessionProvider.overrideWith((ref) => session),
    ]);
    addTearDown(container.dispose);

    expect(container.read(currentUserIdProvider), 'user-a');

    session = null; // sign-out / account deletion
    container.invalidate(currentSessionProvider);

    expect(container.read(currentUserIdProvider), isNull,
        reason: 'signing out must clear the identity, not retain it');
  });

  test('is wired to the session provider, not to a frozen singleton', () {
    // The defect: currentUserIdProvider read the Supabase client directly, so
    // overriding the session had no effect on it whatsoever. If someone
    // reintroduces that, this expectation fails.
    final container = ProviderContainer(overrides: [
      currentSessionProvider.overrideWith((ref) => _sessionFor('scoped-user')),
    ]);
    addTearDown(container.dispose);

    expect(container.read(currentUserIdProvider), 'scoped-user',
        reason: 'currentUserIdProvider must derive from currentSessionProvider');
  });
}
