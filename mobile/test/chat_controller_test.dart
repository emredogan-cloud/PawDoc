// Next Evolution Phase 4 — chat state machine driven by a fake transport.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/assistant/chat_controller.dart';
import 'package:pawdoc/src/assistant/sse_client.dart';

class _FakeTransport implements AssistantTransport {
  _FakeTransport(this._events,
      {this.conversationId = 'conv-1', this.error, this.manual = false});

  final List<SseEvent> _events;
  final String? conversationId;
  final Object? error;

  /// When true the test feeds [live] itself (nothing auto-emitted/closed).
  final bool manual;
  bool cancelled = false;
  String? lastMessage;
  StreamController<SseEvent>? live;

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
    live = controller;
    if (!manual) {
      Future.microtask(() async {
        for (final e in _events) {
          if (controller.isClosed) return;
          controller.add(e);
          await Future<void>.delayed(Duration.zero);
        }
        if (!controller.isClosed) await controller.close();
      });
    }
    return AssistantStream(
      conversationId: this.conversationId,
      events: controller.stream,
      cancel: () {
        cancelled = true;
        controller.close();
      },
    );
  }
}

ProviderContainer _container(AssistantTransport transport) {
  final container = ProviderContainer(overrides: [
    assistantTransportProvider.overrideWithValue(transport),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('streams deltas then finalizes the assistant reply on done', () async {
    final transport = _FakeTransport(const [
      SseEvent('delta', {'text': 'Hello'}),
      SseEvent('delta', {'text': ' owner'}),
      SseEvent('done', {'usage': {}}),
    ], conversationId: 'conv-1');
    final container = _container(transport);
    final chat = container.read(chatControllerProvider.notifier);

    await chat.send('How do I brush?');
    final state = container.read(chatControllerProvider);

    expect(state.status, ChatStatus.idle);
    expect(state.conversationId, 'conv-1');
    expect(state.messages, hasLength(2));
    expect(state.messages.first.isUser, isTrue);
    expect(state.messages.last.content, 'Hello owner');
    expect(state.streamingText, isEmpty);
  });

  test('client emergency router intercepts BEFORE any transport call',
      () async {
    final transport = _FakeTransport(const []);
    final container = _container(transport);
    final chat = container.read(chatControllerProvider.notifier);

    await chat.send('help, my dog just ate rat poison');
    final state = container.read(chatControllerProvider);

    expect(state.status, ChatStatus.emergency);
    expect(state.emergencyKeyword, isNotNull);
    expect(state.messages, isEmpty,
        reason: 'an emergency message never enters the thread');
    expect(transport.lastMessage, isNull,
        reason: 'the network must never be touched');
  });

  test('species-specific emergency applies (rabbit not eating)', () async {
    final transport = _FakeTransport(const []);
    final container = _container(transport);
    final chat = container.read(chatControllerProvider.notifier);

    await chat.send('she is not eating today', species: 'rabbit');
    expect(container.read(chatControllerProvider).status, ChatStatus.emergency);

    // The same text for a dog is NOT an instant emergency.
    final container2 = _container(_FakeTransport(const [
      SseEvent('done', {}),
    ]));
    await container2
        .read(chatControllerProvider.notifier)
        .send('she is not eating today', species: 'dog');
    expect(
        container2.read(chatControllerProvider).status, ChatStatus.idle);
  });

  test('server emergency event routes to emergency and drops the stream',
      () async {
    final transport = _FakeTransport(const [
      SseEvent('emergency', {'keyword': 'poison'}),
    ]);
    final container = _container(transport);
    final chat = container.read(chatControllerProvider.notifier);

    await chat.send('a message the client router missed');
    final state = container.read(chatControllerProvider);
    expect(state.status, ChatStatus.emergency);
    expect(state.emergencyKeyword, 'poison');
    expect(transport.cancelled, isTrue);
  });

  test('402 limit surfaces as limited with the server limit', () async {
    final transport =
        _FakeTransport(const [], error: const AssistantLimitException(20));
    final container = _container(transport);
    final chat = container.read(chatControllerProvider.notifier);

    await chat.send('one more question');
    final state = container.read(chatControllerProvider);
    expect(state.status, ChatStatus.limited);
    expect(state.limit, 20);
  });

  test('error event becomes a soft error state', () async {
    final transport = _FakeTransport(const [
      SseEvent('error', {'code': 'assistant_unavailable'}),
    ]);
    final container = _container(transport);
    await container.read(chatControllerProvider.notifier).send('hi there');
    final state = container.read(chatControllerProvider);
    expect(state.status, ChatStatus.error);
    expect(state.errorMessage, isNotEmpty);
  });

  test('stream ending without done is a soft error, not a silent success',
      () async {
    final transport = _FakeTransport(const [
      SseEvent('delta', {'text': 'partial'}),
    ]);
    final container = _container(transport);
    await container.read(chatControllerProvider.notifier).send('hi there');
    expect(
        container.read(chatControllerProvider).status, ChatStatus.error);
  });

  test('stop mid-stream keeps the partial reply', () async {
    final transport = _FakeTransport(const [], manual: true);
    final container = _container(transport);
    final chat = container.read(chatControllerProvider.notifier);

    final sending = chat.send('long question');
    // Let the transport hand back its stream, then feed one delta.
    await Future<void>.delayed(Duration.zero);
    transport.live!.add(const SseEvent('delta', {'text': 'First half'}));
    await Future<void>.delayed(Duration.zero);
    chat.stopStreaming();
    await sending;

    final state = container.read(chatControllerProvider);
    expect(state.status, ChatStatus.idle);
    expect(state.messages.last.content, 'First half');
  });

  test('acknowledgeStatus clears a transient status', () async {
    final transport =
        _FakeTransport(const [], error: const AssistantLimitException(20));
    final container = _container(transport);
    final chat = container.read(chatControllerProvider.notifier);
    await chat.send('q');
    chat.acknowledgeStatus();
    expect(container.read(chatControllerProvider).status, ChatStatus.idle);
  });

  test('startNew clears the thread but a second send reuses nothing', () async {
    final transport = _FakeTransport(const [
      SseEvent('done', {}),
    ]);
    final container = _container(transport);
    final chat = container.read(chatControllerProvider.notifier);
    await chat.send('first');
    expect(container.read(chatControllerProvider).conversationId, 'conv-1');
    chat.startNew();
    final state = container.read(chatControllerProvider);
    expect(state.messages, isEmpty);
    expect(state.conversationId, isNull);
  });
}
