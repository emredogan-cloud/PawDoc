// Evolution Phase 3 — the client-side offline emergency router. These are the
// same lists the server runs (safety.py ≡ emergency_keywords.mjs); the client
// copy makes the red path instant and offline-capable.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/emergency/emergency_help_screen.dart';
import 'package:pawdoc/src/emergency/emergency_keywords.dart';
import 'package:pawdoc/src/emergency/first_aid.dart';

void main() {
  group('matchEmergencyKeyword (offline router)', () {
    test('matches EN global keywords case-insensitively', () {
      expect(matchEmergencyKeyword('My dog had a SEIZURE'), 'seizure');
      expect(matchEmergencyKeyword('he ate rat poison'), 'rat poison');
      expect(matchEmergencyKeyword('happy and eating well'), isNull);
    });

    test('matches DE global keywords under the de locale', () {
      expect(matchEmergencyKeyword('mein Hund hat einen Krampfanfall',
              locale: 'de'),
          'krampfanfall');
      expect(matchEmergencyKeyword('alles gut heute', locale: 'de'), isNull);
    });

    test('species-specific keywords fire only for the matching species', () {
      expect(
          matchEmergencyKeyword('she is not eating', species: 'rabbit'),
          'not eating');
      // The same phrase for a dog is a risk signal, not an instant emergency.
      expect(matchEmergencyKeyword('she is not eating', species: 'dog'),
          isNull);
    });

    test('unknown locale falls back to English (never an empty keyword set)', () {
      expect(matchEmergencyKeyword('my dog is not breathing', locale: 'fr'),
          'not breathing');
    });

    test('null/empty input never matches', () {
      expect(matchEmergencyKeyword(null), isNull);
      expect(matchEmergencyKeyword(''), isNull);
    });
  });

  group('EmergencyHelpScreen (the red button target)', () {
    testWidgets('renders help CTAs + all five first-aid topics with zero network',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(
          home: EmergencyHelpScreen(matchedKeyword: 'seizure')));
      expect(find.byKey(const Key('help_find_vet')), findsOneWidget);
      expect(find.byKey(const Key('help_poison_control')), findsOneWidget);
      expect(find.textContaining('"seizure"'), findsOneWidget);
      for (final t in kFirstAidTopics) {
        expect(find.byKey(Key('first_aid_${t.id}')), findsOneWidget);
      }
      // The honesty note: offline, no AI.
      expect(find.textContaining('works offline and involves no AI'),
          findsOneWidget);
    });

    testWidgets('a first-aid card opens with steps and nevers', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester
          .pumpWidget(const MaterialApp(home: EmergencyHelpScreen()));
      await tester.tap(find.byKey(const Key('first_aid_choking')));
      await tester.pumpAndSettle();
      expect(find.text('Do this now'), findsOneWidget);
      expect(find.text('Never'), findsOneWidget);
      expect(find.textContaining('first aid buys time',), findsNothing);
      expect(find.textContaining('First aid buys time'), findsOneWidget);
    });
  });

  group('first-aid content safety posture', () {
    test('no card names a medication, dose, or diagnosis', () {
      for (final t in kFirstAidTopics) {
        final all = '${t.title} ${t.subtitle} ${t.steps.join(' ')} ${t.never.join(' ')}'
            .toLowerCase();
        expect(all.contains('diagnos'), isFalse,
            reason: '${t.id} must not use diagnosis language');
        for (final drug in ['aspirin', 'ibuprofen', 'paracetamol', 'benadryl', ' mg ', 'dose of']) {
          expect(all.contains(drug), isFalse,
              reason: '${t.id} must not name medications/doses ($drug)');
        }
      }
    });

    test('every card routes to a veterinarian', () {
      for (final t in kFirstAidTopics) {
        final all = t.steps.join(' ').toLowerCase();
        expect(all.contains('vet'), isTrue,
            reason: '${t.id} must direct to a veterinarian');
      }
    });
  });
}
