// Mockups `breed_encyclopedia` and `breed_detail`.
//
// The references print **"Common Health Conditions · Hip Dysplasia · Risk:
// Moderate"** with a filled dot meter, five conditions deep, on a page whose
// most likely reader is the owner of that exact breed. A graded risk beside a
// named condition is a claim about an animal.
//
// What the catalogue holds instead is `health_notes` — authored hedged, "can
// be prone to…", "reputable breeders screen their stock" — and that is what
// ships, with no risk level, no meter and no percentage, under the standing
// line that this is general breed information and not a statement about your
// pet.
//
// The references also ask for Height, Coat Length, Colors, Breed Group, AKC
// Recognition, FCI Group, a "Popularity #3" ranking, star ratings for
// trainability and watchdog ability, and a breed-match quiz. None of those is
// in `breeds_v1.json`, and a fact strip that invents six of ten values is not
// a fact strip.
//
// The fixture below drives both screens; no asset and no network.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/encyclopedia/breed.dart';
import 'package:pawdoc/src/encyclopedia/breed_detail_screen.dart';
import 'package:pawdoc/src/encyclopedia/breed_sections.dart';
import 'package:pawdoc/src/encyclopedia/breeds_repository.dart';
import 'package:pawdoc/src/encyclopedia/encyclopedia_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Breed _breed(
  String id,
  String species,
  String name, {
  String origin = 'Testland',
  List<String>? temperament,
  String size = 'medium',
  int exercise = 3,
  List<int> life = const [10, 12],
}) =>
    Breed.fromJson({
      'id': id,
      'species': species,
      'name': name,
      'image': 'assets/breeds/$id.webp',
      'origin': origin,
      'countries': ['Testland'],
      'life_expectancy_years': life,
      'size_class': size,
      'weight_kg': [10, 20],
      'coat': 'Short coat',
      'temperament': temperament ?? ['Gentle', 'Curious', 'Loyal'],
      'personality': 'A friendly companion for tests.',
      'exercise_level': exercise,
      'exercise_note': 'Daily walks keep it happy.',
      'grooming_level': 2,
      'grooming_note': 'Weekly brushing.',
      'health_notes': ['Can be prone to test findings.'],
      'fun_facts': ['Exists only in tests.', 'Never sheds bytes.'],
    });

class _FixtureSource implements BreedsSource {
  _FixtureSource(this.catalog);
  final BreedCatalog catalog;
  @override
  Future<BreedCatalog> load() async => catalog;
}

BreedCatalog _catalog() => BreedCatalog(
      breeds: [
        _breed('rexhound', 'dog', 'Rexhound', origin: 'Norway'),
        _breed('milocat', 'cat', 'Milocat',
            temperament: ['Calm', 'Quiet', 'Soft']),
      ],
      credits: {
        'rexhound': const BreedCredit(
          slug: 'rexhound',
          author: 'Test Author',
          license: 'CC BY 4.0',
          sourceUrl: 'https://commons.wikimedia.org/wiki/File:Rexhound.jpg',
        ),
      },
    );

void _surface(WidgetTester tester, {double height = 3200}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app({String? initialSpecies, Map<String, Object> prefs = const {}}) {
  SharedPreferences.setMockInitialValues(prefs);
  return ProviderScope(
    overrides: [
      breedsSourceProvider.overrideWithValue(_FixtureSource(_catalog())),
    ],
    child: MaterialApp(
        home: EncyclopediaScreen(initialSpecies: initialSpecies)),
  );
}

/// Taps a section chip, dragging the rail first — six chips are ~540dp wide
/// on a 393dp screen, so the last two are off-stage until it scrolls.
Future<void> _section(WidgetTester tester, String name) async {
  final chip = find.byKey(Key('breed_section_$name'));
  if (chip.evaluate().isEmpty) {
    await tester.drag(
        find.byKey(const Key('breed_section_rail')), const Offset(-260, 0));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(Key('breed_section_$name')));
  await tester.pumpAndSettle();
}

Widget _detail(Breed breed, {BreedCredit? credit}) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      breedsSourceProvider.overrideWithValue(_FixtureSource(_catalog())),
    ],
    child: MaterialApp(home: BreedDetailScreen(breed: breed, credit: credit)),
  );
}

void main() {
  group('ordering and matching are pure', () {
    test('the four orders each do what they say', () {
      final breeds = [
        _breed('a', 'dog', 'Zeta', size: 'toy', exercise: 1, life: [8, 9]),
        _breed('b', 'dog', 'Alpha', size: 'large', exercise: 5, life: [14, 16]),
      ];
      expect(sortBreeds(breeds, BreedOrder.name).first.name, 'Alpha');
      expect(sortBreeds(breeds, BreedOrder.size).first.sizeClass, 'large');
      expect(sortBreeds(breeds, BreedOrder.energy).first.exerciseLevel, 5);
      expect(sortBreeds(breeds, BreedOrder.lifespan).first.name, 'Alpha');
    });

    test('similar breeds stay within a species and score on real fields', () {
      final all = [
        _breed('base', 'dog', 'Base', size: 'large'),
        _breed('same', 'dog', 'Same Size', size: 'large'),
        _breed('other', 'dog', 'Other Size', size: 'toy'),
        _breed('cat', 'cat', 'A Cat'),
      ];
      final similar = similarBreeds(all, all.first);
      expect(similar.map((b) => b.id), isNot(contains('cat')));
      expect(similar.first.id, 'same');
      expect(similar.map((b) => b.id), isNot(contains('base')));
    });

    test('the binomial follows the species, not the breed', () {
      expect(breedBinomial('dog'), 'Canis lupus familiaris');
      expect(breedBinomial('cat'), 'Felis catus');
    });

    test('only dogs and cats are offered; the rest say so', () {
      for (final s in BreedSpecies.values) {
        final available = s == BreedSpecies.all ||
            s == BreedSpecies.dogs ||
            s == BreedSpecies.cats;
        expect(s.available, available, reason: s.label);
      }
    });
  });

  group('the index, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Breed Encyclopedia'), findsOneWidget);
      expect(find.byKey(const Key('encyclopedia_search_field')), findsOneWidget);
      expect(find.byKey(const Key('encyclopedia_filters')), findsOneWidget);
      expect(
          find.byKey(const Key('encyclopedia_species_rail')), findsOneWidget);
      expect(find.byKey(const Key('encyclopedia_saved')), findsOneWidget);
      expect(find.byKey(const Key('encyclopedia_share')), findsOneWidget);
      expect(find.byKey(const Key('breed_featured_name')), findsOneWidget);
      expect(find.byKey(const Key('encyclopedia_footer')), findsOneWidget);
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the rail filters, and All shows both species',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Defaults to every breed in the guide.
      expect(find.text('Milocat'), findsOneWidget);
      expect(find.text('Rexhound'), findsOneWidget);

      await tester.tap(find.byKey(const Key('encyclopedia_species_cats')));
      await tester.pumpAndSettle();
      expect(find.text('Milocat'), findsOneWidget);
      expect(find.text('Rexhound'), findsNothing);
    });

    testWidgets('initialSpecies preselects the cat rail', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(initialSpecies: 'cat'));
      await tester.pumpAndSettle();
      expect(find.text('Milocat'), findsOneWidget);
      expect(find.text('Rexhound'), findsNothing);
    });

    testWidgets('an unsupported species explains rather than emptying the list',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Soon'), findsWidgets);
      await tester.tap(find.byKey(const Key('encyclopedia_species_birds')));
      await tester.pump();
      expect(find.textContaining('covers dogs and cats today'), findsOneWidget);
      // The list did not change.
      expect(find.text('Rexhound'), findsOneWidget);
    });

    testWidgets('search filters by origin and shows the empty state',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('encyclopedia_search_field')), 'norway');
      await tester.pumpAndSettle();
      expect(find.text('Rexhound'), findsOneWidget);
      expect(find.text('Milocat'), findsNothing);

      await tester.enterText(
          find.byKey(const Key('encyclopedia_search_field')), 'zebra');
      await tester.pumpAndSettle();
      expect(find.text('No breeds match your search.'), findsOneWidget);
    });

    testWidgets('a saved breed survives into the saved-only view',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(prefs: const {
        SavedBreeds.key: <String>['milocat'],
      }));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('encyclopedia_saved')));
      await tester.pumpAndSettle();
      expect(find.text('Milocat'), findsOneWidget);
      expect(find.text('Rexhound'), findsNothing);
    });

    testWidgets('tapping a card opens the detail', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Rexhound is featured (A–Z puts Milocat first, so tap the row).
      await tester.tap(find.byKey(const Key('breed_card_rexhound')));
      await tester.pumpAndSettle();
      expect(find.byType(BreedDetailScreen), findsOneWidget);
      expect(find.byKey(const Key('breed_detail_name')), findsOneWidget);
    });
  });

  group('the detail, drawn', () {
    testWidgets('the hero and every section of the rail are reachable',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_detail(_catalog().breeds.first,
          credit: _catalog().creditFor('rexhound')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('breed_detail_name')), findsOneWidget);
      expect(find.text('Canis lupus familiaris'), findsOneWidget);
      expect(find.byKey(const Key('breed_section_rail')), findsOneWidget);
      expect(find.byKey(const Key('breed_glance_card')), findsOneWidget);
      expect(find.byKey(const Key('breed_size_card')), findsOneWidget);
      expect(find.byKey(const Key('breed_life_card')), findsOneWidget);
      expect(find.byKey(const Key('breed_match_card')), findsOneWidget);

      for (final section in const [
        ('care', 'breed_care_card'),
        ('health', 'breed_health_card'),
        ('traits', 'breed_traits_card'),
        ('gallery', 'breed_gallery_card'),
        ('similar', 'breed_similar_card'),
      ]) {
        await _section(tester, section.$1);
        expect(find.byKey(Key(section.$2)), findsOneWidget,
            reason: section.$1);
      }
    });

    testWidgets('the health section carries the notes and the standing line',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_detail(_catalog().breeds.first));
      await tester.pumpAndSettle();

      await _section(tester, 'health');
      expect(find.text('Can be prone to test findings.'), findsOneWidget);
      expect(find.byKey(const Key('breed_health_disclaimer')), findsOneWidget);
      expect(find.textContaining('not a statement about your pet'),
          findsOneWidget);
    });

    testWidgets('the gallery names the photographer and the licence',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_detail(_catalog().breeds.first,
          credit: _catalog().creditFor('rexhound')));
      await tester.pumpAndSettle();

      await _section(tester, 'gallery');
      expect(find.byKey(const Key('breed_photo_credit')), findsOneWidget);
      expect(find.textContaining('Test Author'), findsOneWidget);
    });

    testWidgets('detail without a credit renders no attribution row',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_detail(_breed('solo', 'cat', 'Solo')));
      await tester.pumpAndSettle();

      await _section(tester, 'gallery');
      expect(find.byKey(const Key('breed_photo_credit')), findsNothing);
    });
  });

  group('safety', () {
    testWidgets('no risk grade, no meter, no invented registry field',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_detail(_catalog().breeds.first));
      await tester.pumpAndSettle();

      for (final section in BreedSection.values) {
        await _section(tester, section.name);
        for (final banned in const [
          'Risk:',
          'Risk: Moderate',
          'Common Health Conditions',
          'Popularity',
          'AKC',
          'FCI',
          'Breed Group',
          'Watchdog',
          'Good With Kids',
          'High quality dog food',
        ]) {
          expect(find.textContaining(banned), findsNothing,
              reason: '"$banned" on ${section.label}');
        }
      }
    });

    testWidgets('life expectancy states a range and promises nothing',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_detail(_catalog().breeds.first));
      await tester.pumpAndSettle();

      expect(find.text('10–12'), findsOneWidget);
      expect(find.textContaining('It is not a prediction'), findsOneWidget);
      expect(find.textContaining('long, healthy and happy life'), findsNothing);
    });

    testWidgets('the match quiz keeps its card and says Soon', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_detail(_catalog().breeds.first));
      await tester.pumpAndSettle();

      expect(find.text('Is this the right breed for you?'), findsOneWidget);
      expect(find.text('Soon'), findsOneWidget);

      await tester.tap(find.byKey(const Key('breed_match_card')));
      await tester.pumpAndSettle();
      expect(find.textContaining('a made-up score would be a poor way'),
          findsOneWidget);
    });

    test('the standing line names what a breed page is not', () {
      expect(kBreedHealthDisclaimer, contains('not a statement about your pet'));
      expect(kBreedHealthDisclaimer, contains('never a diagnosis'));
    });
  });
}
