// The Assistant, against mockups `ai_assistant_home`, `ai_assistant_chat` and
// `ai_message_actions` (fake transport; no network).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';
import 'package:pawdoc/src/analysis/analysis_service.dart';
import 'package:pawdoc/src/assistant/assistant_repository.dart';
import 'package:pawdoc/src/assistant/assistant_models.dart';
import 'package:pawdoc/src/assistant/assistant_screen.dart';
import 'package:pawdoc/src/assistant/assistant_sections.dart';
import 'package:pawdoc/src/assistant/sse_client.dart';
import 'package:pawdoc/src/auth/supabase_providers.dart';
import 'package:pawdoc/src/emergency/emergency_help_screen.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:pawdoc/src/reminders/reminder.dart';
import 'package:pawdoc/src/reminders/reminders_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScriptedTransport implements AssistantTransport {
  _ScriptedTransport(this.events, {this.error});
  final List<SseEvent> events;
  final Object? error;
  String? lastMessage;
  int sends = 0;

  @override
  Future<AssistantStream> send({
    required String message,
    String? conversationId,
    String? petId,
    String? imageStorageKey,
  }) async {
    lastMessage = message;
    sends++;
    if (error != null) throw error!;
    final controller = StreamController<SseEvent>();
    Future.microtask(() async {
      for (final e in events) {
        controller.add(e);
        await Future<void>.delayed(Duration.zero);
      }
      await controller.close();
    });
    return AssistantStream(
      conversationId: 'conv-1',
      events: controller.stream,
      cancel: controller.close,
    );
  }
}

class _FakeRepo implements AssistantRepository {
  _FakeRepo([this.list = const []]);
  final List<AssistantConversation> list;
  bool clearedAll = false;
  final deleted = <String>[];

  @override
  Future<List<AssistantConversation>> conversations({int limit = 50}) async =>
      list;
  @override
  Future<List<ConversationSummary>> summaries({int limit = 200}) async => [
        for (final c in list)
          ConversationSummary(
            conversation: c,
            preview: 'A short reply about ${c.title}.',
            photoCount: 0,
            messageCount: 2,
            topic: conversationTopic(c.title),
          ),
      ];
  @override
  Future<List<AssistantMessage>> messages(String conversationId) async =>
      const [];
  @override
  Future<void> rename(String conversationId, String title) async {}
  @override
  Future<void> delete(String conversationId) async => deleted.add(conversationId);
  @override
  Future<void> deleteAll() async => clearedAll = true;
}

const _pet = Pet(
  id: 'p1',
  userId: 'u1',
  name: 'Rex',
  species: 'dog',
  breed: 'Golden Retriever',
  weightKg: 28,
);

Widget _app(
  AssistantTransport transport, {
  List<AssistantConversation> conversations = const [],
  bool premium = false,
}) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      assistantTransportProvider.overrideWithValue(transport),
      assistantRepositoryProvider.overrideWithValue(_FakeRepo(conversations)),
      // The conversations provider watches the signed-in id so a account switch
      // recomputes; without a Supabase client that read throws and the list
      // would silently arrive empty.
      currentUserIdProvider.overrideWithValue('u1'),
      petsListProvider.overrideWith((ref) async => const [_pet]),
      userProfileProvider.overrideWith(
        (ref) async => UserProfile(
          subscriptionStatus: premium ? 'premium' : 'free',
          photoLogsUsedThisMonth: 1,
        ),
      ),
      latestTriageProvider.overrideWith((ref, petId) => null),
      remindersForPetProvider.overrideWith(
        (ref, petId) async => const <Reminder>[],
      ),
    ],
    child: const MaterialApp(home: AssistantScreen()),
  );
}

/// A handset-sized surface. The default 800x600 test window is wider and much
/// shorter than any phone, so a screen whose whole point is a tall scroll never
/// builds the blocks below the fold.
void _surface(WidgetTester tester, {double height = 851}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(393 * 3, height * 3);
  addTearDown(tester.view.reset);
}

/// Drives one exchange so the screen is on its conversation surface.
Future<_ScriptedTransport> _openChat(
  WidgetTester tester, {
  String reply = 'Brush **gently** every week.',
}) async {
  _surface(tester);
  final transport = _ScriptedTransport([
    SseEvent('delta', {'text': reply}),
    const SseEvent('done', {}),
  ]);
  await tester.pumpWidget(_app(transport));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('assistant_input')),
    'Grooming tips?',
  );
  await tester.tap(find.byKey(const Key('assistant_send_button')));
  await tester.pumpAndSettle();
  return transport;
}

void main() {
  group('the hub (mockup ai_assistant_home)', () {
    testWidgets('renders every block the mockup draws', (tester) async {
      // Tall enough to lay the whole hub out in one pass.
      _surface(tester, height: 1500);
      await tester.pumpWidget(_app(_ScriptedTransport(const [])));
      await tester.pumpAndSettle();

      // Header + hero.
      expect(find.byKey(const Key('assistant_greeting')), findsOneWidget);
      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.text('Private & Secure'), findsOneWidget);
      expect(find.textContaining('Rex'), findsWidgets);

      // Openers, conversations, topics, at-a-glance, premium, composer.
      expect(find.byKey(const Key('assistant_suggestion_0')), findsOneWidget);
      expect(find.byKey(const Key('assistant_suggestion_3')), findsOneWidget);
      expect(find.text('Continue a conversation'), findsOneWidget);
      expect(find.text('Popular topics'), findsOneWidget);
      expect(find.textContaining('health at a glance'), findsOneWidget);
      expect(find.text('Care Score'), findsOneWidget);
      expect(find.byKey(const Key('assistant_premium_cta')), findsOneWidget);
      expect(find.byKey(const Key('assistant_input')), findsOneWidget);
      expect(find.byKey(const Key('assistant_disclaimer')), findsOneWidget);
      expect(find.textContaining('not a diagnosis'), findsOneWidget);
    });

    testWidgets('an opener sends its full question, not its chip label', (
      tester,
    ) async {
      _surface(tester, height: 1500);
      final transport = _ScriptedTransport(const [
        SseEvent('delta', {'text': 'Twice a day works well.'}),
        SseEvent('done', {}),
      ]);
      await tester.pumpWidget(_app(transport));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assistant_suggestion_0')));
      await tester.pumpAndSettle();

      expect(
        transport.lastMessage,
        'What does a good daily care routine look like for Rex?',
      );
      expect(
        find.textContaining('Twice a day', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('the Emergency topic opens the red screen without a model', (
      tester,
    ) async {
      _surface(tester, height: 1500);
      final transport = _ScriptedTransport(const []);
      await tester.pumpWidget(_app(transport));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Emergency\nHelp'));
      await tester.pumpAndSettle();

      expect(find.byType(EmergencyHelpScreen), findsOneWidget);
      expect(
        transport.lastMessage,
        isNull,
        reason: 'an emergency is never a question for a model',
      );
    });

    testWidgets('a resumable thread is offered, and opens', (tester) async {
      _surface(tester, height: 1500);
      await tester.pumpWidget(
        _app(
          _ScriptedTransport(const []),
          conversations: [
            AssistantConversation(
              id: 'c1',
              title: 'Rex’s grooming',
              updatedAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rex’s grooming'), findsOneWidget);
      expect(find.text('2 days ago'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('premium is hidden for a premium account', (tester) async {
      _surface(tester, height: 1500);
      await tester.pumpWidget(
        _app(_ScriptedTransport(const []), premium: true),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant_premium_cta')), findsNothing);
    });
  });

  group('the conversation (mockup ai_assistant_chat)', () {
    testWidgets('renders the pet bar, privacy strip, day chip and bubbles', (
      tester,
    ) async {
      await _openChat(tester);

      expect(find.byKey(const Key('assistant_messages')), findsOneWidget);
      expect(find.text('Rex'), findsWidgets); // pet bar
      expect(find.text('Golden Retriever • 28kg'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.textContaining('never stored with your'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Grooming tips?'), findsOneWidget); // owner bubble
      expect(
        find.textContaining('every week', findRichText: true),
        findsOneWidget,
      );
      // The rail the mockup puts above the composer.
      expect(find.byKey(const Key('assistant_rail_0')), findsOneWidget);
    });

    testWidgets(
      'a reply carries the mockup action row and the helpful prompt',
      (tester) async {
        await _openChat(tester);

        expect(find.byKey(const Key('assistant_msg_copy')), findsOneWidget);
        expect(find.byKey(const Key('assistant_msg_helpful')), findsOneWidget);
        expect(
          find.byKey(const Key('assistant_msg_not_helpful')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('assistant_msg_more')), findsOneWidget);
        expect(find.text('Was this helpful?'), findsOneWidget);

        await tester.tap(find.byKey(const Key('assistant_prompt_helpful')));
        await tester.pumpAndSettle();
        // Answered once, retired.
        expect(find.text('Was this helpful?'), findsNothing);
      },
    );

    testWidgets('copy puts the reply on the clipboard', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _openChat(tester, reply: 'Weekly brushing is plenty.');
      await tester.tap(find.byKey(const Key('assistant_msg_copy')));
      await tester.pumpAndSettle();

      expect(copied, ['Weekly brushing is plenty.']);
    });
  });

  group('per-message actions (mockup ai_message_actions)', () {
    testWidgets('the sheet carries all eight tiles and the follow-ups', (
      tester,
    ) async {
      await _openChat(tester);
      await tester.tap(find.byKey(const Key('assistant_msg_more')));
      await tester.pumpAndSettle();

      expect(find.text('AI Message Actions'), findsOneWidget);
      for (final k in [
        'assistant_action_copy',
        'assistant_action_diary',
        'assistant_action_share',
        'assistant_action_reminder',
        'assistant_action_helpful',
        'assistant_action_not_helpful',
        'assistant_action_regenerate',
        'assistant_action_report',
      ]) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(find.text('You might also ask'), findsOneWidget);
      expect(find.byKey(const Key('assistant_followup_0')), findsOneWidget);
      expect(find.byKey(const Key('assistant_followup_2')), findsOneWidget);
    });

    testWidgets('shuffle swaps the follow-ups', (tester) async {
      await _openChat(tester);
      await tester.tap(find.byKey(const Key('assistant_msg_more')));
      await tester.pumpAndSettle();

      final before = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('assistant_followup_0')),
              matching: find.byType(Text),
            ),
          )
          .data;
      await tester.tap(find.byKey(const Key('assistant_followup_shuffle')));
      await tester.pumpAndSettle();
      final after = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('assistant_followup_0')),
              matching: find.byType(Text),
            ),
          )
          .data;

      expect(after, isNot(before));
    });

    testWidgets('a follow-up sends, and closes the sheet', (tester) async {
      final transport = await _openChat(tester);
      await tester.tap(find.byKey(const Key('assistant_msg_more')));
      await tester.pumpAndSettle();

      final prompt = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('assistant_followup_1')),
              matching: find.byType(Text),
            ),
          )
          .data;
      await tester.tap(find.byKey(const Key('assistant_followup_1')));
      await tester.pumpAndSettle();

      expect(find.text('AI Message Actions'), findsNothing);
      expect(transport.lastMessage, prompt);
    });

    testWidgets('regenerate re-asks the question in place', (tester) async {
      final transport = await _openChat(tester);
      expect(transport.sends, 1);

      await tester.tap(find.byKey(const Key('assistant_msg_more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assistant_action_regenerate')));
      await tester.pumpAndSettle();

      expect(transport.sends, 2);
      expect(transport.lastMessage, 'Grooming tips?');
      // Re-asked, not stacked: one owner bubble, one reply.
      expect(find.text('Grooming tips?'), findsOneWidget);
      expect(
        find.textContaining('every week', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('safety', () {
    testWidgets('the assistant never claims a veterinary role (V-23)', (
      tester,
    ) async {
      _surface(tester, height: 1500);
      await tester.pumpWidget(_app(_ScriptedTransport(const [])));
      await tester.pumpAndSettle();

      expect(find.textContaining('Vet Assistant'), findsNothing);
      expect(find.text('Your everyday pet-care companion'), findsOneWidget);
    });

    testWidgets('no opener presupposes a symptom (V-12)', (tester) async {
      _surface(tester, height: 1500);
      await tester.pumpWidget(_app(_ScriptedTransport(const [])));
      await tester.pumpAndSettle();

      for (final banned in ['itching', 'Why is', 'wrong with', 'sick']) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
    });

    testWidgets(
      'emergency text routes to the red help screen, thread stays clean',
      (tester) async {
        _surface(tester);
        final transport = _ScriptedTransport(const []);
        await tester.pumpWidget(_app(transport));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('assistant_input')),
          'I think my dog got into rat poison',
        );
        await tester.tap(find.byKey(const Key('assistant_send_button')));
        await tester.pumpAndSettle();

        expect(find.byType(EmergencyHelpScreen), findsOneWidget);
        expect(
          transport.lastMessage,
          isNull,
          reason: 'the network must never see an emergency message',
        );
      },
    );

    testWidgets('daily limit opens the premium sheet', (tester) async {
      _surface(tester);
      final transport = _ScriptedTransport(
        const [],
        error: const AssistantLimitException(20),
      );
      await tester.pumpWidget(_app(transport));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('assistant_input')),
        'one more question',
      );
      await tester.tap(find.byKey(const Key('assistant_send_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining("today's free conversation"), findsOneWidget);
      expect(find.byKey(const Key('assistant_upgrade_button')), findsOneWidget);
      // The honesty line: safety is never the thing being limited.
      expect(find.textContaining('safety checks stay'), findsOneWidget);
    });

    testWidgets('transport failure surfaces a calm inline error', (
      tester,
    ) async {
      _surface(tester);
      final transport = _ScriptedTransport(
        const [],
        error: const AssistantUnavailableException(),
      );
      await tester.pumpWidget(_app(transport));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('assistant_input')),
        'hello there',
      );
      await tester.tap(find.byKey(const Key('assistant_send_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assistant_error')), findsOneWidget);
    });

    test('the action grid never borrows a safety-locked ladder hue', () {
      // `design_tokens.dart`: the action ladder's colours are safety-locked and
      // must never be repurposed as decoration. The mockup paints "Create
      // Reminder" in the MONITOR amber and "Report" in the EMERGENCY red; those
      // two substitutions are the reason this list exists.
      const ladder = [
        AppColorsLadder.emergencyDark,
        AppColorsLadder.monitorDark,
        AppColorsLadder.actionBookVisit,
        AppColorsLadder.actionWatch,
      ];
      for (final tone in AssistantTone.all) {
        expect(
          ladder.contains(tone),
          isFalse,
          reason: '$tone is one of the action ladder hues',
        );
      }
    });
  });
}

/// The four safety-locked values, spelled out so the guard above breaks if
/// `design_tokens.dart` ever moves one.
class AppColorsLadder {
  const AppColorsLadder._();
  static const emergencyDark = Color(0xFFFF5A52);
  static const monitorDark = Color(0xFFFFC233);
  static const actionBookVisit = Color(0xFF1565C0);
  static const actionWatch = Color(0xFF455A64);
}
