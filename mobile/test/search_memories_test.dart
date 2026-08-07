// Mockup `search_memories`.
//
// Everything the reference counts, this screen counts for real: the result
// total, each Quick Search chip's tally, each dated bucket's badge. The
// reference prints "Walks · 24 memories" over no data at all.
//
// Two things it draws cannot exist:
//
//  * **"All Locations"**, and a place under every result. PawDoc strips EXIF
//    and GPS from a photo on the device before it is uploaded — a standing
//    rule, not a setting. The slot keeps its position and holds the owner's
//    own hearts; the More Filters sheet states the rule.
//  * **A clock time** under every result. `taken_on` is a date column.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/memories/media_url_cache.dart';
import 'package:pawdoc/src/memories/memories_repository.dart';
import 'package:pawdoc/src/memories/memory.dart';
import 'package:pawdoc/src/memories/memory_search.dart';
import 'package:pawdoc/src/memories/search_memories_screen.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _buddy = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
);
const _milo = Pet(id: 'p2', userId: 'u1', name: 'Milo', species: 'cat');

Memory _mem(
  String id,
  String title, {
  String? note,
  required DateTime on,
  String petId = 'p1',
}) =>
    Memory(
      id: id,
      userId: 'u1',
      petId: petId,
      title: title,
      note: note,
      storageKey: 'memories/u1/$id.jpg',
      takenOn: on,
    );

final _now = DateTime(2026, 8, 7);

List<Memory> _book() => [
      _mem('a', 'Evening walk', on: _now, note: 'round the park'),
      _mem('b', 'Lazy Sunday', on: _now.subtract(const Duration(days: 1))),
      _mem('c', 'Beach trip', on: _now.subtract(const Duration(days: 3)),
          note: 'a long walk on the sand'),
      _mem('d', 'Vet check', on: _now.subtract(const Duration(days: 20))),
      _mem('e', 'Puppy days', on: DateTime(2023, 4, 2)),
    ];

void _surface(WidgetTester tester, {double height = 3200}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({
  List<Memory>? book,
  String? petId = 'p1',
  Map<String, Object> prefs = const {},
}) {
  SharedPreferences.setMockInitialValues(prefs);
  return ProviderScope(
    overrides: [
      petsListProvider.overrideWith((ref) async => const [_buddy, _milo]),
      memoriesListProvider.overrideWith((ref, id) async =>
          id == 'p1' ? (book ?? _book()) : const <Memory>[]),
      mediaUrlServiceProvider.overrideWithValue(
        MediaUrlService(signer: (keys) async => (const <String, String>{}, 0)),
      ),
    ],
    child: MaterialApp(
      home: SearchMemoriesScreen(pet: _buddy, petId: petId),
    ),
  );
}

void main() {
  group('ranking', () {
    test('a title beats a note, and an exact title beats a prefix', () {
      final exact = _mem('1', 'walk', on: _now);
      final prefix = _mem('2', 'walking home', on: _now);
      final inside = _mem('3', 'a good walk', on: _now);
      final noted = _mem('4', 'Sunday', note: 'we went for a walk', on: _now);

      expect(memoryMatchScore(exact, 'walk'), 4);
      expect(memoryMatchScore(prefix, 'walk'), 3);
      expect(memoryMatchScore(inside, 'walk'), 2);
      expect(memoryMatchScore(noted, 'walk'), 1);

      final ranked = searchMemories([noted, inside, prefix, exact], 'walk');
      expect(ranked.map((m) => m.id).toList(), ['1', '2', '3', '4']);
    });

    test('with no query, relevance is simply newest — never an arbitrary order',
        () {
      final old = _mem('old', 'A', on: DateTime(2020));
      final recent = _mem('new', 'B', on: DateTime(2026));
      expect(
        searchMemories([old, recent], '').map((m) => m.id).toList(),
        ['new', 'old'],
      );
      expect(
        searchMemories([recent, old], '', order: MemorySearchOrder.oldest)
            .map((m) => m.id)
            .toList(),
        ['old', 'new'],
      );
    });

    test('a query that matches nothing returns nothing, not everything', () {
      expect(searchMemories(_book(), 'zebra'), isEmpty);
    });
  });

  group('grouping', () {
    test('buckets by recency and drops the empty ones', () {
      final groups = groupMemoriesByRecency(_book(), now: _now);
      expect(groups.map((g) => g.label).toList(),
          ['Today', 'Yesterday', 'This Week', 'This Month', 'Earlier']);
      expect(groups.first.memories.single.id, 'a');
      // Nothing sits in "This Year" for this book, so no empty card is drawn.
      expect(groups.map((g) => g.label), isNot(contains('This Year')));
    });

    test('an empty book produces no buckets at all', () {
      expect(groupMemoriesByRecency(const [], now: _now), isEmpty);
    });
  });

  group('quick searches count what is really there', () {
    test('a chip tallies every one of its terms', () {
      final walks = kQuickSearches.firstWhere((q) => q.label == 'Walks');
      // "Evening walk", "a long walk on the sand" — title and note both count.
      expect(walks.countIn(_book()), 2);
      final vet = kQuickSearches.firstWhere((q) => q.label == 'Vet Visits');
      expect(vet.countIn(_book()), 1);
    });

    test('a chip that finds nothing reports nothing, not a guess', () {
      final naps = kQuickSearches.firstWhere((q) => q.label == 'Naps');
      expect(naps.countIn(_book()), 0);
    });
  });

  group('recent searches', () {
    test('newest first, de-duplicated case-insensitively, capped', () {
      var list = RecentSearches.mergeRecent(const [], 'walk');
      expect(list, ['walk']);
      list = RecentSearches.mergeRecent(list, 'beach');
      expect(list, ['beach', 'walk']);
      // The same query again moves to the front rather than doubling up.
      list = RecentSearches.mergeRecent(list, 'WALK');
      expect(list, ['WALK', 'beach']);
      for (final q in ['a', 'b', 'c', 'd', 'e', 'f']) {
        list = RecentSearches.mergeRecent(list, q);
      }
      expect(list.length, RecentSearches.max);
      expect(list.first, 'f');
    });

    test('an empty query is never remembered', () {
      expect(RecentSearches.mergeRecent(const ['walk'], '   '), ['walk']);
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Search Memories'), findsOneWidget);
      expect(find.byKey(const Key('search_history')), findsOneWidget);
      expect(find.byKey(const Key('search_field')), findsOneWidget);
      expect(find.byKey(const Key('search_filters')), findsOneWidget);
      expect(find.byKey(const Key('search_pet_rail')), findsOneWidget);
      expect(find.byKey(const Key('search_pet_all')), findsOneWidget);
      expect(find.byKey(const Key('search_type_pill')), findsOneWidget);
      expect(find.byKey(const Key('search_dates_pill')), findsOneWidget);
      expect(find.byKey(const Key('search_hearted_pill')), findsOneWidget);
      expect(find.byKey(const Key('search_more_pill')), findsOneWidget);
      expect(find.byKey(const Key('search_quick_card')), findsOneWidget);
      expect(find.byKey(const Key('search_result_count')), findsOneWidget);
      expect(find.byKey(const Key('search_order_pill')), findsOneWidget);
      // The dated buckets, as the reference groups them.
      expect(find.byKey(const Key('search_bucket_Today')), findsOneWidget);
      expect(find.byKey(const Key('search_bucket_Yesterday')), findsOneWidget);
      // Over the app's bottom navigation, which the reference draws.
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the result count is the number of rows that matched',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // The count is a two-tone span (the number in the accent), so the
      // finder has to walk the rich text rather than a plain `data`.
      expect(find.textContaining('5 memories found', findRichText: true),
          findsOneWidget);

      await tester.enterText(find.byKey(const Key('search_field')), 'walk');
      await tester.pumpAndSettle();
      expect(find.textContaining('2 memories found', findRichText: true),
          findsOneWidget);
      expect(find.text('Evening walk'), findsOneWidget);
      expect(find.text('Vet check'), findsNothing);
    });

    testWidgets('a query with no hits says so instead of showing an empty grid',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_field')), 'zebra');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search_no_results')), findsOneWidget);
      expect(find.text('Nothing matched'), findsOneWidget);
    });

    testWidgets('an empty book says the book is empty, not that nothing matched',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(book: const []));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search_empty_book')), findsOneWidget);
    });

    testWidgets('a Quick Search chip drops its query into the field',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search_quick_Walks')));
      await tester.pumpAndSettle();
      expect(find.text('Evening walk'), findsOneWidget);
      expect(find.text('Vet check'), findsNothing);
      // And it is remembered, so the recent card appears once the field clears.
      expect(find.byKey(const Key('search_quick_card')), findsOneWidget);
    });

    testWidgets('a remembered search is offered back', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(prefs: {
        RecentSearches.key: <String>['beach', 'walk'],
      }));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_recent_card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('search_recent_chip_beach')));
      await tester.pumpAndSettle();
      expect(find.text('Beach trip'), findsOneWidget);
      expect(find.text('Lazy Sunday'), findsNothing);
    });

    testWidgets('the hearted pill narrows to the owner’s own picks',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(prefs: {
        'pawdoc.memory.fav.a': DateTime(2026, 8, 7).toIso8601String(),
      }));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search_hearted_pill')));
      await tester.pumpAndSettle();
      expect(find.text('Hearted only'), findsOneWidget);
      expect(find.text('Evening walk'), findsOneWidget);
      expect(find.text('Vet check'), findsNothing);
    });
  });

  group('safety', () {
    testWidgets('no location is offered, shown, or implied', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final banned in const [
        'All Locations',
        'Kent Park',
        'Location',
        'Near me',
      ]) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }

      // And the sheet says why, rather than leaving a hole where a filter was.
      await tester.tap(find.byKey(const Key('search_filters')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search_location_rule')), findsOneWidget);
      expect(find.textContaining('strips EXIF and GPS'), findsOneWidget);
    });

    testWidgets('the journal makes no claim about the animal', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final banned in const [
        'Health Score',
        'Excellent',
        'Low Risk',
        'AI ',
      ]) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
    });

    testWidgets('video keeps its entry and its Soon', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search_filters')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search_type_videos')), findsOneWidget);
      expect(find.textContaining('a memory is a photo for now'),
          findsOneWidget);
    });
  });
}
