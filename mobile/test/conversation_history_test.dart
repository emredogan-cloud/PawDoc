// Mockup `conversation_history` — the assistant's full history surface.
//
// Two things this file exists to hold:
//
//  1. The screen draws everything the reference draws — pet header, search,
//     topic rail, privacy card, day-grouped rows, statistics, clear-history —
//     and every figure on it is counted rather than invented.
//  2. The mockup's third statistic, "2h 14m · Total time saved", never ships.
//     The app does not know what a conversation saved anyone; a flattering
//     number over no measurement is the same class of claim as a fabricated
//     health score.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/assistant/assistant_models.dart';
import 'package:pawdoc/src/assistant/assistant_repository.dart';
import 'package:pawdoc/src/assistant/conversation_history_screen.dart';
import 'package:pawdoc/src/auth/supabase_providers.dart';
import 'package:pawdoc/src/health/health_sections.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepo implements AssistantRepository {
  _FakeRepo(this.rows);
  final List<ConversationSummary> rows;
  bool clearedAll = false;
  final deleted = <String>[];

  @override
  Future<List<AssistantConversation>> conversations({int limit = 50}) async =>
      [for (final r in rows) r.conversation];
  @override
  Future<List<ConversationSummary>> summaries({int limit = 200}) async => rows;
  @override
  Future<List<AssistantMessage>> messages(String id) async => const [];
  @override
  Future<void> rename(String id, String title) async {}
  @override
  Future<void> delete(String id) async => deleted.add(id);
  @override
  Future<void> deleteAll() async => clearedAll = true;
}

const _pet = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Buddy',
  species: 'dog',
  breed: 'Golden Retriever',
  weightKg: 28,
);

ConversationSummary _row(
  String id,
  String title, {
  required DateTime at,
  String preview = 'A short reply.',
  int photos = 0,
  int messages = 2,
}) =>
    ConversationSummary(
      conversation:
          AssistantConversation(id: id, title: title, updatedAt: at),
      preview: preview,
      photoCount: photos,
      messageCount: messages,
      topic: conversationTopic(title),
    );

/// A handset surface. The default 800x600 test window is much shorter than any
/// phone, so on a tall scrolling screen everything below the fold is never
/// built and the assertions pass vacuously.
void _surface(WidgetTester tester, {double height = 1600}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

Widget _app(_FakeRepo repo) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      assistantRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u1'),
      petsListProvider.overrideWith((ref) async => const [_pet]),
    ],
    child: const MaterialApp(home: ConversationHistoryScreen()),
  );
}

/// A moment that is always *earlier today*, whatever the hour the suite runs
/// at. `now - 2h` is yesterday for anyone running before 02:00 — which is how
/// this fixture broke in CI, whose runners are UTC.
DateTime _earlierToday() {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  return now.difference(midnight) >= const Duration(hours: 2)
      ? now.subtract(const Duration(hours: 2))
      : midnight;
}

/// Noon, [days] days back. Day arithmetic rather than `subtract(days:)` so a
/// DST shift cannot slide the row into the neighbouring day.
DateTime _noonDaysAgo(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - days, 12);
}

List<ConversationSummary> _sample() {
  return [
    _row('c1', 'Paw redness that will not settle',
        at: _earlierToday(),
        preview: 'There are several everyday reasons a paw can look red.',
        photos: 1,
        messages: 6),
    _row('c2', 'Is seasonal shedding normal?',
        at: _noonDaysAgo(1), messages: 4),
    _row('c3', 'Dry food or wet food?', at: _noonDaysAgo(1), messages: 3),
    _row('c4', 'Could this be separation anxiety?',
        at: _noonDaysAgo(9), messages: 5),
  ];
}

void main() {
  group('the mockup, drawn', () {
    testWidgets('every block the reference draws is present', (tester) async {
      _surface(tester);
      final repo = _FakeRepo(_sample());
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      // Header + pet card.
      expect(find.text('Conversation History'), findsOneWidget);
      expect(find.byKey(const Key('module_back')), findsOneWidget);
      expect(find.byKey(const Key('history_search_button')), findsOneWidget);
      expect(find.byKey(const Key('module_pet_name')), findsOneWidget);
      expect(find.text('All Pets'), findsOneWidget);

      // Topic rail.
      expect(find.byKey(const Key('health_filter_all')), findsOneWidget);
      expect(find.byKey(const Key('health_filter_health')), findsOneWidget);

      // Privacy card, rows, day grouping.
      expect(find.text('Your conversations are private'), findsOneWidget);
      expect(find.byKey(const Key('conversation_tile_c1')), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      // One group label, plus the stamp on each of the two threads in it —
      // exactly what the reference draws.
      expect(find.text('Yesterday'), findsNWidgets(3));

      // Statistics + clear card.
      expect(find.text('Your conversation stats'), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.byKey(const Key('history_clear_all')), findsOneWidget);

      // The bottom navigation the mockup draws, with Emergency intact.
      expect(find.byKey(const Key('root_nav_emergency')), findsOneWidget);
    });

    testWidgets('the statistics are counted, not invented', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_FakeRepo(_sample())));
      await tester.pumpAndSettle();

      expect(find.text('4'), findsWidgets); // four conversations
      expect(find.text('18'), findsOneWidget); // 6+4+3+5 messages
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('a photo count only appears when a thread carries one',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_FakeRepo(_sample())));
      await tester.pumpAndSettle();
      expect(find.text('1 Photo'), findsOneWidget);
      expect(find.textContaining('Photos'), findsNothing);
    });

    testWidgets('an empty history says so instead of drawing a blank page',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_FakeRepo(const [])));
      await tester.pumpAndSettle();
      expect(find.text('No conversations yet'), findsOneWidget);
      // The rest of the surface still stands.
      expect(find.text('Your conversation stats'), findsOneWidget);
    });
  });

  group('safety', () {
    testWidgets('no fabricated "time saved" statistic', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_FakeRepo(_sample())));
      await tester.pumpAndSettle();
      for (final banned in ['Total time saved', 'time saved', '2h 14m']) {
        expect(find.textContaining(banned), findsNothing,
            reason: 'the app cannot measure this');
      }
    });

    testWidgets('the standing assistant disclaimer is on the surface',
        (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_FakeRepo(_sample())));
      await tester.pumpAndSettle();
      expect(find.textContaining('not veterinary advice'), findsOneWidget);
    });
  });

  group('search and topic filtering', () {
    testWidgets('search narrows the list and can be closed', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_FakeRepo(_sample())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history_search_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('history_search_field')), 'shedding');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('conversation_tile_c2')), findsOneWidget);
      expect(find.byKey(const Key('conversation_tile_c1')), findsNothing);

      await tester.tap(find.byKey(const Key('history_search_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conversation_tile_c1')), findsOneWidget);
    });

    testWidgets('a search with no hits explains itself', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_FakeRepo(_sample())));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history_search_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('history_search_field')), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches'), findsOneWidget);
    });

    testWidgets('the topic rail filters by topic', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_app(_FakeRepo(_sample())));
      await tester.pumpAndSettle();

      final rail = find.descendant(
        of: find.byType(HealthFilterChips),
        matching: find.byType(Scrollable),
      );

      // Nutrition is the fourth chip — the rail scrolls, so reach it the way a
      // user would rather than tapping a widget that is off-screen.
      await tester.scrollUntilVisible(
          find.byKey(const Key('health_filter_nutrition')), 120,
          scrollable: rail);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('health_filter_nutrition')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conversation_tile_c3')), findsOneWidget);
      expect(find.byKey(const Key('conversation_tile_c2')), findsNothing);

      await tester.scrollUntilVisible(
          find.byKey(const Key('health_filter_all')), -120,
          scrollable: rail);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('health_filter_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conversation_tile_c2')), findsOneWidget);
    });
  });

  group('clearing', () {
    testWidgets('clear all confirms first, then really deletes',
        (tester) async {
      _surface(tester);
      final repo = _FakeRepo(_sample());
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history_clear_all')));
      await tester.pumpAndSettle();
      expect(find.text('Clear all history?'), findsOneWidget);

      // Backing out changes nothing.
      await tester.tap(find.text('Keep them'));
      await tester.pumpAndSettle();
      expect(repo.clearedAll, isFalse);

      await tester.tap(find.byKey(const Key('history_clear_all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conversation_clear_all_confirm')));
      await tester.pumpAndSettle();
      expect(repo.clearedAll, isTrue);
    });

    testWidgets('with nothing to clear it says so rather than deleting',
        (tester) async {
      _surface(tester);
      final repo = _FakeRepo(const []);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history_clear_all')));
      await tester.pumpAndSettle();
      expect(find.text('There is nothing to clear.'), findsOneWidget);
      expect(repo.clearedAll, isFalse);
    });
  });

  group('topic filing', () {
    test('files a thread by its own words, and defaults to General', () {
      expect(conversationTopic('Dry food or wet food?'),
          ConversationTopic.nutrition);
      expect(conversationTopic('Is seasonal shedding normal?'),
          ConversationTopic.grooming);
      expect(conversationTopic('Could this be separation anxiety?'),
          ConversationTopic.behavior);
      expect(conversationTopic('Which vaccines are due?'),
          ConversationTopic.health);
      expect(conversationTopic('Hello there'), ConversationTopic.general);
    });

    test('the opening message files a thread the title cannot', () {
      expect(conversationTopic('A question', 'how much should I feed him?'),
          ConversationTopic.nutrition);
    });

    test('every topic has keywords, so the rail can never be all-General', () {
      for (final topic in ConversationTopic.values) {
        if (topic == ConversationTopic.general) continue;
        expect(kConversationTopicKeywords[topic], isNotEmpty,
            reason: '${topic.label} lost its keywords');
      }
    });
  });

  group('decorative tints never borrow a safety-locked hue', () {
    test('no HealthTone colour equals an action-ladder colour', () {
      const ladder = [
        AppColors.emergencyDark,
        AppColors.emergencyLight,
        AppColors.monitorDark,
        AppColors.monitorLight,
        AppColors.actionBookVisit,
        AppColors.actionWatch,
      ];
      for (final tint in HealthTone.all) {
        expect(ladder.contains(tint), isFalse,
            reason: 'a ladder hue used as decoration reads as a severity '
                'signal; $tint must not be reused');
      }
    });
  });
}
