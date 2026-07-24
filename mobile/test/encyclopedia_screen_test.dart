// Next Evolution Phase 3 — Encyclopedia UI (fixture catalog via provider
// override; no asset/network dependency).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/encyclopedia/breed.dart';
import 'package:pawdoc/src/encyclopedia/breed_detail_screen.dart';
import 'package:pawdoc/src/encyclopedia/breeds_repository.dart';
import 'package:pawdoc/src/encyclopedia/encyclopedia_screen.dart';

Breed _breed(String id, String species, String name,
        {String origin = 'Testland', List<String>? temperament}) =>
    Breed.fromJson({
      'id': id,
      'species': species,
      'name': name,
      'image': 'assets/breeds/$id.webp',
      'origin': origin,
      'countries': ['Testland'],
      'life_expectancy_years': [10, 12],
      'size_class': 'medium',
      'weight_kg': [10, 20],
      'coat': 'Short coat',
      'temperament': temperament ?? ['Gentle', 'Curious', 'Loyal'],
      'personality': 'A friendly companion for tests.',
      'exercise_level': 3,
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

Widget _app({String? initialSpecies}) {
  final catalog = BreedCatalog(
    breeds: [
      _breed('rexhound', 'dog', 'Rexhound', origin: 'Norway'),
      _breed('milocat', 'cat', 'Milocat', temperament: ['Calm', 'Quiet', 'Soft']),
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
  return ProviderScope(
    overrides: [
      breedsSourceProvider.overrideWithValue(_FixtureSource(catalog)),
    ],
    child: MaterialApp(
        home: EncyclopediaScreen(initialSpecies: initialSpecies)),
  );
}

void main() {
  testWidgets('lists the selected species and switches tabs', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Dogs tab default.
    expect(find.text('Rexhound'), findsOneWidget);
    expect(find.text('Milocat'), findsNothing);

    await tester.tap(find.textContaining('Cats'));
    await tester.pumpAndSettle();
    expect(find.text('Milocat'), findsOneWidget);
    expect(find.text('Rexhound'), findsNothing);
  });

  testWidgets('initialSpecies preselects the cat tab', (tester) async {
    await tester.pumpWidget(_app(initialSpecies: 'cat'));
    await tester.pumpAndSettle();
    expect(find.text('Milocat'), findsOneWidget);
  });

  testWidgets('search filters by origin and shows the empty state',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('encyclopedia_search_field')), 'norway');
    await tester.pumpAndSettle();
    expect(find.text('Rexhound'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('encyclopedia_search_field')), 'zebra');
    await tester.pumpAndSettle();
    expect(find.text('No breeds match your search.'), findsOneWidget);
  });

  testWidgets('tapping a card opens the detail with all sections',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('breed_card_rexhound')));
    await tester.pumpAndSettle();

    expect(find.byType(BreedDetailScreen), findsOneWidget);
    // The hero photo fills the first viewport; walk the page section by
    // section (the lazy list builds content as it scrolls into view).
    final sections = [
      find.byKey(const Key('breed_detail_name')),
      find.text('Personality & temperament'),
      find.text('Care at a glance'),
      find.text('Health, in general'),
      find.byKey(const Key('breed_health_disclaimer')),
      find.text('Worth knowing'),
      find.byKey(const Key('breed_photo_credit')),
    ];
    for (final target in sections) {
      await tester.scrollUntilVisible(target, 200);
      expect(target, findsOneWidget);
    }
    // Photo attribution names the author.
    expect(find.textContaining('Test Author'), findsOneWidget);
  });

  testWidgets('detail without a credit renders no attribution row',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BreedDetailScreen(breed: _breed('solo', 'cat', 'Solo')),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('breed_photo_credit')), findsNothing);
  });
}
