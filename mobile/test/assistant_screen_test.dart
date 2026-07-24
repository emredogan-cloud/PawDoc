// Next Evolution Phase 4 — Assistant tab UI (fake transport; no network).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/assistant/assistant_repository.dart';
import 'package:pawdoc/src/assistant/assistant_models.dart';
import 'package:pawdoc/src/assistant/assistant_screen.dart';
import 'package:pawdoc/src/assistant/sse_client.dart';
import 'package:pawdoc/src/emergency/emergency_help_screen.dart';
import 'package:pawdoc/src/pets/pet.dart';
import 'package:pawdoc/src/pets/pets_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScriptedTransport implements AssistantTransport {
  _ScriptedTransport(this.events, {this.error});
  final List<SseEvent> events;
  final Object? error;
  String? lastMessage;

  @override
  Future<AssistantStream> send({
    required String message,
    String? conversationId,
    String? petId,
    String? imageStorageKey,
  }) async {
    lastMessage = message;
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
  @override
  Future<List<AssistantConversation>> conversations() async => const [];
  @override
  Future<List<AssistantMessage>> messages(String conversationId) async =>
      const [];
  @override
  Future<void> rename(String conversationId, String title) async {}
  @override
  Future<void> delete(String conversationId) async {}
}

Widget _app(AssistantTransport transport) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderScope(
    overrides: [
      assistantTransportProvider.overrideWithValue(transport),
      assistantRepositoryProvider.overrideWithValue(_FakeRepo()),
      petsListProvider.overrideWith((ref) async =>
          const [Pet(id: 'p1', userId: 'u1', name: 'Rex', species: 'dog')]),
    ],
    child: const MaterialApp(home: AssistantScreen()),
  );
}

void main() {
  testWidgets('greeting shows pet-aware hero, suggestions, and disclaimer',
      (tester) async {
    await tester.pumpWidget(_app(_ScriptedTransport(const [])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assistant_greeting')), findsOneWidget);
    expect(find.textContaining('Rex'), findsWidgets);
    expect(find.byKey(const Key('assistant_suggestion_0')), findsOneWidget);
    expect(find.byKey(const Key('assistant_disclaimer')), findsOneWidget);
    expect(find.textContaining('not a diagnosis'), findsOneWidget);
  });

  testWidgets('sending renders the user bubble and the streamed reply',
      (tester) async {
    final transport = _ScriptedTransport(const [
      SseEvent('delta', {'text': 'Brush **gently**'}),
      SseEvent('delta', {'text': ' every week.'}),
      SseEvent('done', {}),
    ]);
    await tester.pumpWidget(_app(transport));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('assistant_input')), 'Grooming tips?');
    await tester.tap(find.byKey(const Key('assistant_send_button')));
    await tester.pumpAndSettle();

    expect(transport.lastMessage, 'Grooming tips?');
    expect(find.text('Grooming tips?'), findsOneWidget); // user bubble
    // Markdown bold renders as rich text — match by fragment.
    expect(find.textContaining('every week', findRichText: true), findsOneWidget);
    expect(find.byKey(const Key('assistant_messages')), findsOneWidget);
  });

  testWidgets('suggestion chip sends without typing', (tester) async {
    final transport = _ScriptedTransport(const [
      SseEvent('delta', {'text': 'Here are some games.'}),
      SseEvent('done', {}),
    ]);
    await tester.pumpWidget(_app(transport));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assistant_suggestion_0')));
    await tester.pumpAndSettle();

    expect(transport.lastMessage, 'Indoor games for a rainy day');
    expect(find.textContaining('games', findRichText: true), findsWidgets);
  });

  testWidgets('emergency text routes to the red help screen, thread stays clean',
      (tester) async {
    final transport = _ScriptedTransport(const []);
    await tester.pumpWidget(_app(transport));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('assistant_input')),
        'I think my dog got into rat poison');
    await tester.tap(find.byKey(const Key('assistant_send_button')));
    await tester.pumpAndSettle();

    expect(find.byType(EmergencyHelpScreen), findsOneWidget);
    expect(transport.lastMessage, isNull,
        reason: 'the network must never see an emergency message');
  });

  testWidgets('daily limit opens the premium sheet', (tester) async {
    final transport =
        _ScriptedTransport(const [], error: const AssistantLimitException(20));
    await tester.pumpWidget(_app(transport));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('assistant_input')), 'one more question');
    await tester.tap(find.byKey(const Key('assistant_send_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining("today's free conversation"), findsOneWidget);
    expect(find.byKey(const Key('assistant_upgrade_button')), findsOneWidget);
    // The honesty line: safety is never the thing being limited.
    expect(find.textContaining('safety checks stay'), findsOneWidget);
  });

  testWidgets('transport failure surfaces a calm inline error', (tester) async {
    final transport = _ScriptedTransport(const [],
        error: const AssistantUnavailableException());
    await tester.pumpWidget(_app(transport));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('assistant_input')), 'hello there');
    await tester.tap(find.byKey(const Key('assistant_send_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assistant_error')), findsOneWidget);
  });
}
