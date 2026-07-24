// Next Evolution Phase 3 — Breed model + REAL catalog content validation.
//
// The second group loads the actual bundled assets, so a malformed or
// off-tone catalog fails CI, not a user session. Health notes are checked for
// the no-diagnosis contract: hedged, educational, no treatment/dosing talk.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/encyclopedia/breed.dart';
import 'package:pawdoc/src/encyclopedia/breeds_repository.dart';

Map<String, dynamic> fixture({String id = 'test-breed'}) => {
      'id': id,
      'species': 'dog',
      'name': 'Test Breed',
      'image': 'assets/breeds/$id.webp',
      'origin': 'Testland',
      'countries': ['Testland'],
      'life_expectancy_years': [10, 12],
      'size_class': 'medium',
      'weight_kg': [10, 20.5],
      'coat': 'Short coat',
      'temperament': ['Gentle', 'Curious'],
      'personality': 'A friendly test subject.',
      'exercise_level': 3,
      'exercise_note': 'Daily walks.',
      'grooming_level': 2,
      'grooming_note': 'Weekly brushing.',
      'health_notes': ['Can be prone to test findings.'],
      'fun_facts': ['Exists only in tests.'],
    };

void main() {
  group('Breed model', () {
    test('decodes a well-formed entry', () {
      final b = Breed.fromJson(fixture());
      expect(b.name, 'Test Breed');
      expect(b.lifeExpectancyLabel, '10–12 yrs');
      expect(b.weightLabel, '10–20.5 kg');
      expect(b.sizeLabel, 'Medium');
    });

    test('rejects malformed ranges, levels, and species', () {
      expect(() => Breed.fromJson({...fixture(), 'life_expectancy_years': [12, 10]}),
          throwsFormatException);
      expect(() => Breed.fromJson({...fixture(), 'exercise_level': 6}),
          throwsFormatException);
      expect(() => Breed.fromJson({...fixture(), 'species': 'dragon'}),
          throwsFormatException);
    });

    test('searchBreeds matches name, origin, and temperament', () {
      final breeds = [
        Breed.fromJson(fixture(id: 'a')),
        Breed.fromJson({
          ...fixture(id: 'b'),
          'name': 'Snowhound',
          'origin': 'Norway',
          'temperament': ['Bold'],
        }),
      ];
      expect(searchBreeds(breeds, 'snow').single.id, 'b');
      expect(searchBreeds(breeds, 'norway').single.id, 'b');
      expect(searchBreeds(breeds, 'bold').single.id, 'b');
      expect(searchBreeds(breeds, ''), hasLength(2));
    });
  });

  group('Bundled catalog content (the real assets)', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('loads, validates, and covers 10 dogs + 10 cats', () async {
      final catalog = await const AssetBreedsSource().load();
      expect(catalog.breeds, hasLength(20));
      expect(catalog.bySpecies('dog'), hasLength(10));
      expect(catalog.bySpecies('cat'), hasLength(10));

      for (final b in catalog.breeds) {
        // Every entry carries complete, sane content.
        expect(b.personality.length, greaterThan(60),
            reason: '${b.id}: personality should be real prose');
        expect(b.temperament.length, inInclusiveRange(3, 5),
            reason: '${b.id}: temperament chip count');
        expect(b.healthNotes.length, inInclusiveRange(2, 4),
            reason: '${b.id}: health notes count');
        expect(b.funFacts.length, inInclusiveRange(2, 3),
            reason: '${b.id}: fun facts count');
        expect(b.countries, isNotEmpty, reason: '${b.id}: countries');

        // Photo credit exists for every breed (license compliance).
        expect(catalog.creditFor(b.id), isNotNull,
            reason: '${b.id}: missing photo credit');

        // Bundled image actually exists.
        final bytes = await rootBundle.load(b.image);
        expect(bytes.lengthInBytes, greaterThan(10 * 1024),
            reason: '${b.id}: image asset missing or tiny');
      }
    });

    test('health notes keep the educational, no-diagnosis contract', () async {
      final catalog = await const AssetBreedsSource().load();
      // Banned: diagnostic/treatment/absolute language.
      final banned = RegExp(
          r'\b(diagnos\w*|medicat\w*|dosage|dose|prescri\w*|cure[sd]?\b|'
          r'will (get|develop|die)|guarantee\w*)\b',
          caseSensitive: false);
      // Required: at least one hedging pattern per breed's notes.
      final hedged = RegExp(
          r'(can be|may|prone to|predispos\w*|associated with|higher risk|'
          r'tendenc\w*|some\b|risk of|watch\w*|benefit\w*|consider\w*)',
          caseSensitive: false);
      for (final b in catalog.breeds) {
        final joined = b.healthNotes.join(' ');
        expect(banned.hasMatch(joined), isFalse,
            reason: '${b.id}: health notes contain banned phrasing '
                '(${banned.firstMatch(joined)?.group(0)})');
        expect(hedged.hasMatch(joined), isTrue,
            reason: '${b.id}: health notes lack hedged phrasing');
      }
    });

    test('credits manifest is complete and permissively licensed', () async {
      final raw = jsonDecode(
          await rootBundle.loadString(AssetBreedsSource.creditsPath)) as List;
      expect(raw, hasLength(20));
      for (final entry in raw.cast<Map<String, dynamic>>()) {
        final license = entry['license'] as String;
        expect(license, isNot(contains('NC')),
            reason: '${entry['slug']}: non-commercial license is not shippable');
        expect(license, isNot(contains('ND')),
            reason: '${entry['slug']}: no-derivatives license is not shippable');
        expect(entry['author'], isNotEmpty);
        expect(entry['source_url'], startsWith('https://commons.wikimedia.org/'));
      }
    });
  });
}
