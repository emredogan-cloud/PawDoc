// Mockup `memory_detail`.
//
// The reference puts an **AI Highlight** on the journal — "A moment full of
// joy and energy! Captured Buddy's playful spirit perfectly." That is a model
// reading an animal's emotional state off a photograph, on the one surface in
// the app that has never carried AI output and is documented as human content
// only. It is gone; the slot holds a fact instead — how old the pet was that
// day.
//
// It also shows a **location and a map**. PawDoc strips EXIF and GPS from
// every photo on the device before upload, as a standing rule. There is no
// location and there must never be one, so the block states the rule.
//
// And it shows a video scrubber, a duration, a byte size and a resolution. A
// memory is one still photo, and none of those three is recorded.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/memories/media_url_cache.dart';
import 'package:pawdoc/src/memories/memories_repository.dart';
import 'package:pawdoc/src/memories/memories_screen.dart';
import 'package:pawdoc/src/memories/memory.dart';
import 'package:pawdoc/src/memories/memory_viewer_screen.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _buddy = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
  birthDate: DateTime(2022, 5, 19),
);

Memory _memory(String id, String title, DateTime on, {String? note}) => Memory(
      id: id,
      userId: 'u1',
      petId: 'p1',
      title: title,
      note: note,
      storageKey: 'memories/u1/$id.jpg',
      takenOn: on,
      createdAt: DateTime(2026, 8, 7),
    );

final _hero = _memory('m1', 'Evening playtime', DateTime(2025, 5, 19),
    note: 'He would not give the ball back.');

List<Memory> _book() => [
      _hero,
      _memory('m2', 'Same day, second shot', DateTime(2025, 5, 19)),
      _memory('m3', 'Another month', DateTime(2025, 3, 2)),
    ];

void _surface(WidgetTester tester, {double height = 3000}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({
  Memory? memory,
  List<Memory>? book,
  Pet? pet,
  Map<String, Object> prefs = const {},
}) {
  SharedPreferences.setMockInitialValues(prefs);
  return ProviderScope(
    overrides: [
      memoriesListProvider
          .overrideWith((ref, petId) async => book ?? _book()),
      mediaUrlServiceProvider.overrideWithValue(
        MediaUrlService(signer: (keys) async => (const <String, String>{}, 0)),
      ),
    ],
    child: MaterialApp(
      home: MemoryViewerScreen(memory: memory ?? _hero, pet: pet ?? _buddy),
    ),
  );
}

void main() {
  group('age on the day', () {
    test('counts from the birthday to the photo, not to today', () {
      expect(petAgeLabelOn(DateTime(2022, 5, 19), DateTime(2025, 5, 19)),
          '3y 0m');
      expect(petAgeLabelOn(DateTime(2022, 5, 19), DateTime(2025, 8, 1)),
          '3y 2m');
    });

    test('under a year reads in months', () {
      expect(petAgeLabelOn(DateTime(2025, 1, 10), DateTime(2025, 6, 10)), '5m');
    });

    test('no birthday, no claim', () {
      expect(petAgeLabelOn(null, DateTime(2025, 5, 19)), isNull);
    });

    test('a photo from before the birthday claims nothing', () {
      expect(petAgeLabelOn(DateTime(2025, 5, 19), DateTime(2024, 1, 1)), isNull);
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Memory Detail'), findsOneWidget);
      expect(find.byKey(const Key('memory_share_button')), findsOneWidget);
      expect(find.byKey(const Key('memory_more_button')), findsOneWidget);
      expect(find.byKey(const Key('memory_position')), findsOneWidget);
      expect(find.byKey(const Key('memory_favourite')), findsOneWidget);
      expect(find.byKey(const Key('memory_fullscreen')), findsOneWidget);
      expect(find.byKey(const Key('memory_viewer_title')), findsOneWidget);
      expect(find.byKey(const Key('memory_tags')), findsOneWidget);
      expect(find.byKey(const Key('memory_on_this_day')), findsOneWidget);
      expect(find.byKey(const Key('memory_privacy')), findsOneWidget);
      expect(find.byKey(const Key('memory_action_edit')), findsOneWidget);
      expect(find.byKey(const Key('memory_delete_button')), findsOneWidget);
      expect(find.byKey(const Key('memory_facts')), findsOneWidget);
      expect(find.byKey(const Key('memory_same_day')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the counter is the real position in the book',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('the arrows step through the book', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // First memory: no previous.
      expect(find.byKey(const Key('memory_prev')), findsNothing);
      await tester.tap(find.byKey(const Key('memory_next')));
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Same day, second shot'), findsOneWidget);
      expect(find.byKey(const Key('memory_prev')), findsOneWidget);
    });

    testWidgets('"More from this day" lists only the same date',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory_day_m2')), findsOneWidget);
      expect(find.byKey(const Key('memory_day_m3')), findsNothing);
    });

    testWidgets('a lone memory has no same-day rail and no arrows',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(book: [_hero]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory_same_day')), findsNothing);
      expect(find.byKey(const Key('memory_next')), findsNothing);
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('the facts are what the row holds', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Taken on'), findsOneWidget);
      expect(find.text('Stored'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
    });
  });

  group('the heart', () {
    testWidgets('toggles and says where it is kept', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('memory_favourite')));
      await tester.pumpAndSettle();
      expect(find.text('Added to highlights. Kept on this device.'),
          findsOneWidget);
    });

    testWidgets('a heart already on the device is read back', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(prefs: {
        MemoriesScreen.favKey('m1'): DateTime.now().toIso8601String(),
      }));
      await tester.pumpAndSettle();
      // Tapping it now removes rather than adds.
      await tester.tap(find.byKey(const Key('memory_favourite')));
      await tester.pumpAndSettle();
      expect(find.text('Removed from highlights.'), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('there is no AI anywhere on the journal', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final banned in [
        'AI Highlight',
        'AI ',
        'playful spirit',
        'joy and energy',
        'Captured',
      ]) {
        expect(find.textContaining(banned), findsNothing,
            reason: '"$banned" is a model reading a mood off a photograph, on '
                'the one surface that is human content only');
      }
    });

    testWidgets('the location block states the privacy rule, not a place',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('No location on this photo'), findsOneWidget);
      expect(find.textContaining('removes GPS'), findsOneWidget);
      expect(find.textContaining('Kent Park'), findsNothing);
    });

    testWidgets('nothing claims a duration, a size or a resolution',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      for (final banned in ['Duration', 'Resolution', 'MB', '0:18', '1080 x']) {
        expect(find.textContaining(banned), findsNothing,
            reason: '"$banned" is not recorded anywhere');
      }
    });

    testWidgets('"On this day" states a fact, or asks for the birthday',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('Buddy was 3y 0m old'), findsOneWidget);

      await tester.pumpWidget(_app(
        pet: const Pet(id: 'p1', userId: 'u1', name: 'Rex', species: 'cat'),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Add Rex’s birthday'), findsOneWidget);
    });

    testWidgets('Delete is not painted in a ladder hue', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      const ladder = [
        Color(0xFFFF5A52),
        Color(0xFFC62828),
        Color(0xFFFFC233),
        Color(0xFFFFB300),
        Color(0xFF1565C0),
        Color(0xFF455A64),
      ];
      final icons = tester.widgetList<Icon>(find.descendant(
        of: find.byKey(const Key('memory_delete_button')),
        matching: find.byType(Icon),
      ));
      expect(icons, isNotEmpty);
      for (final icon in icons) {
        expect(ladder.contains(icon.color), isFalse);
      }
    });
  });
}
