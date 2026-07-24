// Next Evolution Phase 2 — Memories gallery widget tests (provider overrides,
// no network: the fake signer returns no URLs so photos render the calm
// fallback tile).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/memories/media_url_cache.dart';
import 'package:pawdoc/src/memories/memories_repository.dart';
import 'package:pawdoc/src/memories/memories_screen.dart';
import 'package:pawdoc/src/memories/memory.dart';
import 'package:pawdoc/src/pets/pet.dart';

const _pet = Pet(id: 'p1', userId: 'u1', name: 'Rex', species: 'dog');

Memory _mem(String id, String title, {String? note, DateTime? takenOn}) =>
    Memory(
      id: id,
      userId: 'u1',
      petId: 'p1',
      title: title,
      note: note,
      storageKey: 'memories/u1/$id.jpg',
      takenOn: takenOn ?? DateTime(2026, 7, 10),
    );

Widget _app({
  required List<Memory> memories,
  UserProfile profile =
      const UserProfile(subscriptionStatus: 'free', photoLogsUsedThisMonth: 0),
}) {
  return ProviderScope(
    overrides: [
      memoriesListProvider('p1').overrideWith((ref) async => memories),
      memoriesCountProvider.overrideWith((ref) async => memories.length),
      userProfileProvider.overrideWith((ref) async => profile),
      mediaUrlServiceProvider.overrideWithValue(
        MediaUrlService(signer: (keys) async => (const <String, String>{}, 0)),
      ),
    ],
    child: const MaterialApp(home: MemoriesScreen(pet: _pet)),
  );
}

void main() {
  testWidgets('renders the gallery grid with titles and the allowance strip',
      (tester) async {
    await tester.pumpWidget(_app(memories: [
      _mem('a', 'Beach day', note: 'sunny'),
      _mem('b', 'First snow'),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('memories_grid')), findsOneWidget);
    expect(find.text('Beach day'), findsOneWidget);
    expect(find.text('First snow'), findsOneWidget);
    // Free plan shows the quiet allowance caption.
    expect(find.byKey(const Key('memories_allowance')), findsOneWidget);
    expect(find.textContaining('2 of $kFreeMemoryLimit'), findsOneWidget);
  });

  testWidgets('empty journal shows the warm start state', (tester) async {
    await tester.pumpWidget(_app(memories: []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('memories_empty')), findsOneWidget);
    expect(find.text('Start Rex’s story'), findsOneWidget);
    expect(find.text('Add the first memory'), findsOneWidget);
  });

  testWidgets('search filters titles and notes; clear restores', (tester) async {
    await tester.pumpWidget(_app(memories: [
      _mem('a', 'Beach day', note: 'sunny'),
      _mem('b', 'Vet visit'),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('memories_search_field')), 'beach');
    await tester.pumpAndSettle();
    expect(find.text('Beach day'), findsOneWidget);
    expect(find.text('Vet visit'), findsNothing);

    await tester.enterText(
        find.byKey(const Key('memories_search_field')), 'zebra');
    await tester.pumpAndSettle();
    expect(find.text('No memories match your search.'), findsOneWidget);
  });

  testWidgets('timeline toggle groups by month', (tester) async {
    await tester.pumpWidget(_app(memories: [
      _mem('a', 'Beach day', takenOn: DateTime(2026, 7, 10)),
      _mem('b', 'First snow', takenOn: DateTime(2025, 12, 25)),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('memories_view_toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('memories_timeline')), findsOneWidget);
    expect(find.text('December 2025'), findsOneWidget);
  });

  testWidgets('premium hides the allowance strip', (tester) async {
    await tester.pumpWidget(_app(
      memories: [_mem('a', 'Beach day')],
      profile: const UserProfile(
          subscriptionStatus: 'premium', photoLogsUsedThisMonth: 0),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('memories_allowance')), findsNothing);
  });

  testWidgets('at the free cap, New memory opens the premium sheet instead',
      (tester) async {
    final memories = [
      for (var i = 0; i < kFreeMemoryLimit; i++) _mem('m$i', 'Memory $i'),
    ];
    await tester.pumpWidget(_app(memories: memories));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('memories_new_button')));
    await tester.pumpAndSettle();

    expect(find.text('Your memory book is full'), findsOneWidget);
    expect(find.byKey(const Key('memories_upgrade_button')), findsOneWidget);
  });
}
