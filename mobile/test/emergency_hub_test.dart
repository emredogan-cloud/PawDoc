// Mockup `emergency_hub` — the red-button target.
//
// The reference is the most constrained screen in the set. Six of its blocks
// cannot ship, five of them ruled out by the emergency-path rule in CLAUDE.md
// and one by a feature deleted in PR #80:
//
//   * "AI Triage · Check symptoms now"                          (V-16)
//   * "At Risk Pets 1 · Luna · Needs Attention · Based on
//      recent symptoms (Vomiting, Loss of appetite)"            (V-16)
//   * "Emergency Transport · Request help"          — no partner exists
//   * "Share Records"                               — premium-gated export
//   * "Nearest 24/7 Vet Clinics" + map + ratings    — Places finder deleted
//   * "Heat Alert in Your Area"                     — implies monitoring
//
// These tests are the tripwire for all six, plus the structural guarantee the
// screen rests on: it renders with no ProviderScope, so it cannot have
// acquired a dependency on app state without this file failing to compile.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/emergency/emergency_help_screen.dart';
import 'package:pawdoc/src/emergency/first_aid.dart';

void _surface(WidgetTester tester, {double height = 2600}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

/// Deliberately **not** wrapped in a ProviderScope. See the file header.
Widget _app({String? matchedKeyword}) => MaterialApp(
      home: EmergencyHelpScreen(matchedKeyword: matchedKeyword),
    );

String _pageText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' ')
    .toLowerCase();

void main() {
  group('the mockup, drawn', () {
    testWidgets('every block that survived the rule is present',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Emergency Hub'), findsOneWidget);
      expect(find.byKey(const Key('emergency_about')), findsOneWidget);

      // The red band, with the two contacts that are real.
      expect(find.byKey(const Key('emergency_call_band')), findsOneWidget);
      expect(find.byKey(const Key('help_find_vet')), findsOneWidget);
      expect(find.byKey(const Key('help_poison_control')), findsOneWidget);

      // Quick actions — three tiles, all offline or an OS hand-off.
      expect(find.byKey(const Key('emergency_tile_firstaid')), findsOneWidget);
      expect(find.byKey(const Key('emergency_tile_vet')), findsOneWidget);
      expect(find.byKey(const Key('emergency_tile_poison')), findsOneWidget);

      // Every bundled first-aid card, one tap away.
      for (final t in kFirstAidTopics) {
        expect(find.byKey(Key('first_aid_${t.id}')), findsOneWidget);
      }
      expect(find.byKey(const Key('emergency_honesty_note')), findsOneWidget);
    });

    testWidgets('the keyword the router matched is shown back', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(matchedKeyword: 'seizure'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('emergency_matched_banner')), findsOneWidget);
      expect(find.textContaining('"seizure"'), findsOneWidget);
    });

    testWidgets('with no keyword the banner is absent, not empty',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emergency_matched_banner')), findsNothing);
    });

    testWidgets('the first-aid tile opens the searchable guide',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('emergency_tile_firstaid')));
      await tester.pumpAndSettle();
      expect(find.text('First Aid Guide'), findsOneWidget);
    });

    testWidgets('a card row opens its steps', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('first_aid_bleeding')));
      await tester.pumpAndSettle();
      expect(find.text('Do this now'), findsOneWidget);
      expect(find.text('Never'), findsOneWidget);
    });
  });

  group('the emergency-path rule', () {
    testWidgets('renders with no ProviderScope — it reads no app state',
        (tester) async {
      // If this ever throws a ProviderScope lookup error, the red path has
      // grown a data dependency and no longer works on a cold offline start.
      _surface(tester);
      await tester.pumpWidget(_app(matchedKeyword: 'not breathing'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Emergency Hub'), findsOneWidget);
    });

    testWidgets('no AI anywhere, and it says so', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      expect(text.contains('ai triage'), isFalse);
      expect(text.contains('view triage'), isFalse);
      expect(text.contains('ai powered'), isFalse);
      expect(find.textContaining('works offline and involves no AI'),
          findsOneWidget);
    });

    testWidgets('no animal is assessed, graded, or flagged', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      expect(text.contains('at risk'), isFalse);
      expect(text.contains('needs attention'), isFalse);
      expect(text.contains('risk level'), isFalse);
      expect(text.contains('health score'), isFalse);
      expect(text.contains('based on recent symptoms'), isFalse);
    });

    testWidgets('no monetization, in any form', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      for (final word in [
        'premium',
        'upgrade',
        'subscribe',
        'free trial',
        'unlock',
        'share records',
      ]) {
        expect(text.contains(word), isFalse, reason: '"$word" is on the red path');
      }
    });

    testWidgets('no service or fact PawDoc cannot stand behind', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      // No staffed line, and no promise about a clinic's opening hours.
      expect(text.contains('24/7'), isFalse);
      expect(text.contains('call emergency'), isFalse);
      // No fabricated clinic directory: the Places finder was deleted in #80.
      expect(text.contains('directions'), isFalse);
      expect(text.contains('emergency transport'), isFalse);
      expect(RegExp(r'\d\.\d\s*\(\d+\)').hasMatch(text), isFalse,
          reason: 'a star rating with a review count is fabricated data');
      // No pushed environmental alert — the app is not watching.
      expect(text.contains('heat alert'), isFalse);
      expect(text.contains('in your area'), isFalse);
      // The one paid thing on the screen is somebody else's, and it is stated.
      expect(text.contains('consultation fee may apply'), isTrue);
    });
  });
}
