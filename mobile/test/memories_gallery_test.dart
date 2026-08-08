// Mockup `memories_gallery`.
//
// The reference draws videos — a play badge and a duration on half its tiles.
// A memory is one still photo (`memory_photo.dart`, one `storage_key`); there
// is no video pipeline, no duration, no thumbnail. The type filter keeps its
// Videos entry and says *Soon* rather than putting a play badge over a
// photograph.
//
// It also draws a "Highlights" row that nothing in the schema could populate —
// except that the same mockup puts a heart on every tile. Highlights *is* the
// hearted set, kept on the device like the medication tracker's dose ticks,
// and the row says so.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/memories/media_url_cache.dart';
import 'package:pawdoc/src/memories/memories_repository.dart';
import 'package:pawdoc/src/memories/memories_screen.dart';
import 'package:pawdoc/src/memories/memory.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _buddy =
    Pet(id: 'p1', userId: 'u1', name: 'Buddy', species: 'dog');
const _milo = Pet(id: 'p2', userId: 'u1', name: 'Milo', species: 'cat');

Memory _memory(String id, String title, DateTime on, {String pet = 'p1'}) =>
    Memory(
      id: id,
      userId: 'u1',
      petId: pet,
      title: title,
      storageKey: 'memories/u1/$id.jpg',
      takenOn: on,
    );

List<Memory> _buddys() => [
      _memory('m1', 'Beach day', DateTime(2025, 12, 4)),
      _memory('m2', 'First snow', DateTime(2025, 12, 20)),
      _memory('m3', 'Adoption day', DateTime(2024, 3, 2)),
    ];

void _surface(WidgetTester tester, {double height = 3200}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({
  Map<String, List<Memory>>? byPet,
  List<Pet>? pets,
  Map<String, Object> prefs = const {},
}) {
  SharedPreferences.setMockInitialValues(prefs);
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => pets ?? const [_buddy]),
      memoriesListProvider.overrideWith(
          (ref, petId) async => (byPet ?? {'p1': _buddys()})[petId] ?? const []),
      memoriesCountProvider.overrideWith((ref) async => 3),
      userProfileProvider.overrideWith((ref) async => const UserProfile(
          subscriptionStatus: 'premium', photoLogsUsedThisMonth: 0)),
      mediaUrlServiceProvider.overrideWithValue(
        MediaUrlService(signer: (keys) async => (const <String, String>{}, 0)),
      ),
    ],
    child: const MaterialApp(home: MemoriesScreen(pet: _buddy)),
  );
}

void main() {
  group('ordering is pure', () {
    test('newest first', () {
      final out = sortMemories(_buddys(), MemoryOrder.newest);
      expect(out.map((m) => m.id), ['m2', 'm1', 'm3']);
    });

    test('oldest first', () {
      final out = sortMemories(_buddys(), MemoryOrder.oldest);
      expect(out.map((m) => m.id), ['m3', 'm1', 'm2']);
    });

    test('by title, case-insensitively', () {
      final out = sortMemories(_buddys(), MemoryOrder.title);
      expect(out.map((m) => m.title), ['Adoption day', 'Beach day', 'First snow']);
    });

    test('never drops or duplicates', () {
      for (final o in MemoryOrder.values) {
        expect(sortMemories(_buddys(), o).map((m) => m.id).toSet(),
            {'m1', 'm2', 'm3'});
      }
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Memories Gallery'), findsOneWidget);
      expect(find.byKey(const Key('memories_new_button')), findsOneWidget);
      expect(find.byKey(const Key('memories_filters')), findsOneWidget);
      expect(find.byKey(const Key('memories_pet_rail')), findsOneWidget);
      expect(find.byKey(const Key('memories_pet_all')), findsOneWidget);
      expect(find.byKey(const Key('memories_search_field')), findsOneWidget);
      expect(find.byKey(const Key('memories_type_button')), findsOneWidget);
      expect(find.byKey(const Key('memories_order_button')), findsOneWidget);
      expect(find.byKey(const Key('memories_view_toggle')), findsOneWidget);
      expect(find.byKey(const Key('memories_grid')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('memories are grouped by month, with a count', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('December 2025'), findsOneWidget);
      expect(find.text('March 2024'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
    });

    testWidgets('the pet rail switches scope, and All Pets merges',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(
        pets: const [_buddy, _milo],
        byPet: {
          'p1': [_memory('m1', 'Beach day', DateTime(2025, 12, 4))],
          'p2': [_memory('m9', 'Windowsill', DateTime(2025, 12, 8), pet: 'p2')],
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Beach day'), findsOneWidget);
      expect(find.text('Windowsill'), findsNothing);

      // The rail scrolls; reach the last chip the way a user would.
      await tester.scrollUntilVisible(
        find.byKey(const Key('memories_pet_all')),
        140,
        scrollable: find.descendant(
          of: find.byKey(const Key('memories_pet_rail')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memories_pet_all')));
      await tester.pumpAndSettle();
      expect(find.text('Beach day'), findsOneWidget);
      expect(find.text('Windowsill'), findsOneWidget);
    });
  });

  group('highlights are the hearted set', () {
    testWidgets('no hearts, no row', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Highlights'), findsNothing);
    });

    testWidgets('hearting one raises the row and says where it is kept',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('memory_fav_m1')));
      await tester.pumpAndSettle();

      expect(find.text('Added to highlights. Kept on this device.'),
          findsOneWidget);
      expect(find.text('Highlights'), findsOneWidget);
      expect(find.textContaining('Kept on this device'), findsWidgets);
      expect(find.text('1 hearted'), findsOneWidget);
    });

    testWidgets('a heart already on the device is read back', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(prefs: {
        MemoriesScreen.favKey('m1'): DateTime.now().toIso8601String(),
      }));
      await tester.pumpAndSettle();
      expect(find.text('Highlights'), findsOneWidget);
      expect(find.text('1 hearted'), findsOneWidget);
    });

    test('the heart namespace cannot collide with a dose or a reminder', () {
      final key = MemoriesScreen.favKey('m1');
      expect(key.startsWith('pawdoc.memory.fav.'), isTrue);
      expect(key.startsWith('pawdoc.dose.'), isFalse);
      expect(key.startsWith('pawdoc.reminder.done.'), isFalse);
    });
  });

  group('the filter sheet', () {
    testWidgets('offers every order and marks videos Soon', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('memories_filters')));
      await tester.pumpAndSettle();

      for (final o in MemoryOrder.values) {
        expect(find.byKey(Key('memory_order_${o.name}')), findsOneWidget);
      }
      expect(find.byKey(const Key('memory_type_videos')), findsOneWidget);
      expect(find.textContaining('Soon — a memory is a photo for now'),
          findsOneWidget);
    });

    testWidgets('choosing an order re-labels the control', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('memories_filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory_order_oldest')));
      await tester.pumpAndSettle();
      expect(find.text('Oldest'), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('the journal says nothing about an animal\'s health',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final banned in [
        'Health Score',
        'Excellent',
        'Great',
        'Healthy',
        'AI',
        'diagnos',
      ]) {
        expect(find.textContaining(banned), findsNothing,
            reason: 'the journal is human content only — no AI, no claims');
      }
    });

    testWidgets('no play badge is drawn over a photograph', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('0:'), findsNothing,
          reason: 'a duration implies a video the journal cannot hold');
    });
  });
}
