// Mockup `first_aid_guide`.
//
// The reference puts an **AI Triager** in the hero slot of the first-aid
// screen — review item V-17, CRITICAL against the emergency rule in CLAUDE.md,
// because an owner arriving here has an animal in front of them and the screen
// must open with no signal. It also badges four of seven rows "High Priority",
// sorts the list "Most relevant", prints an invented read time on every row,
// and offers a "Call Emergency · Available 24/7" button for a line PawDoc does
// not run.
//
// None of that ships. What ships is the same composition over the five
// bundled cards, in a fixed order, with the two contacts that are real.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/emergency/emergency_sections.dart';
import 'package:pawdoc/src/emergency/first_aid.dart';
import 'package:pawdoc/src/emergency/first_aid_guide_screen.dart';

void _surface(WidgetTester tester, {double height = 3000}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

/// Deliberately **not** wrapped in a ProviderScope, exactly as
/// `emergency_hub_test` does it. This screen is pushed from the red button and
/// must not acquire a dependency on app state either.
Widget _app() => const MaterialApp(home: FirstAidGuideScreen());

/// Every word the screen renders, so a safety assertion can scan the page
/// rather than guess which widget holds the offending string.
String _pageText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' ')
    .toLowerCase();

void main() {
  group('ordering', () {
    test('is fixed, and every bundled card appears exactly once', () {
      final ordered = orderedFirstAidTopics();
      expect(ordered.length, kFirstAidTopics.length);
      expect(ordered.map((t) => t.id).toSet(),
          kFirstAidTopics.map((t) => t.id).toSet());
      // The most time-critical cards lead (V-27).
      expect(ordered.first.id, 'bleeding');
      expect(ordered[1].id, 'choking');
    });

    test('a card missing from the order list is still listed, never dropped',
        () {
      // Every id in the order list must exist, or the guide would silently
      // shorten itself.
      final ids = kFirstAidTopics.map((t) => t.id).toSet();
      for (final id in kFirstAidOrder) {
        expect(ids.contains(id), isTrue, reason: '$id is not a bundled card');
      }
    });
  });

  group('search', () {
    test('an empty query returns everything', () {
      expect(searchFirstAid(kFirstAidTopics, '   ').length,
          kFirstAidTopics.length);
    });

    test('matches a title', () {
      final hits = searchFirstAid(kFirstAidTopics, 'choking');
      expect(hits.single.id, 'choking');
    });

    test('matches what the owner can see, not just the title', () {
      // "gums" appears in the heatstroke card's subtitle, nowhere in a title.
      expect(searchFirstAid(kFirstAidTopics, 'gums').single.id, 'heatstroke');
      // "tourniquet" appears only in the bleeding card's body.
      expect(
          searchFirstAid(kFirstAidTopics, 'tourniquet').single.id, 'bleeding');
    });

    test('no match returns empty rather than a guess', () {
      expect(searchFirstAid(kFirstAidTopics, 'zebra'), isEmpty);
    });
  });

  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('First Aid Guide'), findsOneWidget);
      expect(find.byKey(const Key('module_back')), findsOneWidget);
      expect(find.byKey(const Key('first_aid_disclaimer')), findsOneWidget);
      expect(find.byKey(const Key('first_aid_search')), findsOneWidget);
      expect(find.byKey(const Key('first_aid_rail')), findsOneWidget);
      expect(find.byKey(const Key('first_aid_cat_all')), findsOneWidget);
      expect(find.byKey(const Key('first_aid_browse')), findsOneWidget);

      // Every bundled card has a row.
      for (final t in kFirstAidTopics) {
        expect(find.byKey(Key('first_aid_${t.id}')), findsOneWidget);
      }

      expect(find.byKey(const Key('emergency_honesty_note')), findsOneWidget);
      expect(find.byKey(const Key('emergency_call_band')), findsOneWidget);
      expect(find.byKey(const Key('help_find_vet')), findsOneWidget);
      expect(find.byKey(const Key('help_poison_control')), findsOneWidget);
    });

    testWidgets('renders with no ProviderScope — the red path reads no state',
        (tester) async {
      // The reference draws the app's bottom navigation here. `PawNavBar` is a
      // ConsumerWidget, so adopting it would re-introduce a ProviderScope
      // dependency one push below `EmergencyHelpScreen`, which is provider-free
      // precisely so the red path is provably independent of app state.
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('root_nav_emergency')), findsNothing);
    });

    testWidgets('the category rail narrows the list to one card',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('first_aid_cat_choking')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('first_aid_choking')), findsOneWidget);
      expect(find.byKey(const Key('first_aid_bleeding')), findsNothing);

      await tester.tap(find.byKey(const Key('first_aid_cat_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('first_aid_bleeding')), findsOneWidget);
    });

    testWidgets('search filters, and a miss says so instead of showing nothing',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('first_aid_search')), 'bleeding');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('first_aid_bleeding')), findsOneWidget);
      expect(find.byKey(const Key('first_aid_choking')), findsNothing);

      await tester.enterText(find.byKey(const Key('first_aid_search')), 'zebra');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('first_aid_no_match')), findsOneWidget);
      // Even with nothing to read, the way out is still on the screen.
      expect(find.byKey(const Key('help_find_vet')), findsOneWidget);
    });

    testWidgets('a row opens the card with its steps and its nevers',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('first_aid_choking')));
      await tester.pumpAndSettle();

      expect(find.text('Do this now'), findsOneWidget);
      expect(find.text('Never'), findsOneWidget);
      expect(find.textContaining('First aid buys time'), findsOneWidget);
      // The card offers the same two real contacts.
      expect(find.byKey(const Key('help_find_vet')), findsOneWidget);
    });

    testWidgets('Browse by symptom puts the cursor in the search field',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final field = find.descendant(
          of: find.byKey(const Key('first_aid_search')),
          matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isFalse);

      await tester.tap(find.byKey(const Key('first_aid_browse')));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
    });
  });

  group('safety', () {
    testWidgets('the red path advertises no AI and no network', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      // V-17: no AI entry point, no AI branding, in any casing.
      expect(text.contains('ai triage'), isFalse);
      expect(text.contains('ai triager'), isFalse);
      expect(text.contains('ai powered'), isFalse);
      expect(text.contains('start ai'), isFalse);
      // The promise that makes the screen trustworthy.
      expect(find.textContaining('works offline and involves no AI'),
          findsOneWidget);
      expect(find.textContaining('Works offline'), findsOneWidget);
    });

    testWidgets('no row is graded, ranked, or timed', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      // No severity badge — an unbadged row must never read as "less urgent".
      expect(text.contains('high priority'), isFalse);
      expect(text.contains('low priority'), isFalse);
      expect(text.contains('risk'), isFalse);
      // V-27: no relevance sort on an offline safety surface.
      expect(text.contains('most relevant'), isFalse);
      // No invented read time. ("5 steps" is a fact about the card.)
      expect(RegExp(r'\d+\s*min').hasMatch(text), isFalse);
      expect(find.textContaining('steps'), findsWidgets);
    });

    testWidgets('no service PawDoc does not run is advertised', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      // PawDoc runs no emergency line and cannot promise a clinic's hours.
      expect(text.contains('24/7'), isFalse);
      expect(text.contains('call emergency'), isFalse);
      // The poison-control line is somebody else's, and it costs money.
      expect(text.contains('consultation fee may apply'), isTrue);
      expect(text.contains('aspca'), isTrue);
    });

    testWidgets('the guide never claims to know what is wrong', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final text = _pageText(tester);
      expect(text.contains('diagnos'), isFalse);
      expect(text.contains('likely normal'), isFalse);
      // No monetization on the emergency path.
      expect(text.contains('premium'), isFalse);
      expect(text.contains('upgrade'), isFalse);
      expect(text.contains('free trial'), isFalse);
    });
  });
}
