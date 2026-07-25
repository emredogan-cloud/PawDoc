// Internal-test hardening: one device, two accounts — no bleed-through.
//
// Device-found (Redmi Note 8): after deleting an account and signing up a fresh
// one in the same app session, Home and My Pets still listed the *deleted*
// user's pet ("Rex · Labrador Retriever") even though the new account owned no
// pets in the database. The read was correct; the cached provider value simply
// outlived the identity that produced it. User-scoped providers now watch the
// signed-in user id, so a change of identity recomputes them.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/auth/supabase_providers.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';

class _PerUserRepo implements PetsRepository {
  _PerUserRepo(this._petsByUser, this._currentUser);
  final Map<String, List<Pet>> _petsByUser;
  String Function() _currentUser;
  int listCalls = 0;

  @override
  Future<List<Pet>> list() async {
    listCalls++;
    return _petsByUser[_currentUser()] ?? const <Pet>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('signing in as a different user does not inherit the previous pets',
      () async {
    var uid = 'user-a';
    final repo = _PerUserRepo(
      {
        'user-a': [const Pet(userId: 'user-a', name: 'Rex', species: 'dog', breed: 'Labrador')],
        'user-b': const <Pet>[],
      },
      () => uid,
    );

    final container = ProviderContainer(overrides: [
      petsRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWith((ref) => uid),
    ]);
    addTearDown(container.dispose);

    // User A sees their pet.
    expect((await container.read(petsListProvider.future)).single.name, 'Rex');

    // A different identity signs in on the same device.
    uid = 'user-b';
    container.invalidate(currentUserIdProvider);

    final forUserB = await container.read(petsListProvider.future);
    expect(forUserB, isEmpty,
        reason: "user B must not see user A's pet");
    expect(repo.listCalls, greaterThan(1),
        reason: 'the identity change forces a re-read, not a cache hit');
  });
}
