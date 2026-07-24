import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../emergency/emergency_keywords.dart';
import 'assistant_models.dart';
import 'assistant_repository.dart';
import 'sse_client.dart';

enum ChatStatus { idle, streaming, limited, error, emergency }

/// One rendered chat bubble.
class ChatUiMessage {
  const ChatUiMessage({
    required this.role,
    required this.content,
    this.imageStorageKey,
  });

  final String role; // 'user' | 'assistant'
  final String content;
  final String? imageStorageKey;

  bool get isUser => role == 'user';
}

class ChatState {
  const ChatState({
    this.conversationId,
    this.messages = const [],
    this.streamingText = '',
    this.status = ChatStatus.idle,
    this.errorMessage,
    this.limit,
    this.emergencyKeyword,
  });

  final String? conversationId;
  final List<ChatUiMessage> messages;

  /// The assistant reply as it streams in (moved into [messages] on done).
  final String streamingText;
  final ChatStatus status;
  final String? errorMessage;

  /// Free daily allowance, present when [status] is [ChatStatus.limited].
  final int? limit;

  /// Matched keyword, present when [status] is [ChatStatus.emergency].
  final String? emergencyKeyword;

  bool get isStreaming => status == ChatStatus.streaming;
  bool get isEmpty => messages.isEmpty && streamingText.isEmpty;

  ChatState copyWith({
    String? conversationId,
    List<ChatUiMessage>? messages,
    String? streamingText,
    ChatStatus? status,
    String? errorMessage,
    int? limit,
    String? emergencyKeyword,
  }) =>
      ChatState(
        conversationId: conversationId ?? this.conversationId,
        messages: messages ?? this.messages,
        streamingText: streamingText ?? this.streamingText,
        status: status ?? this.status,
        errorMessage: errorMessage,
        limit: limit ?? this.limit,
        emergencyKeyword: emergencyKeyword ?? this.emergencyKeyword,
      );
}

/// The active chat's state machine. The transport is injected (Riverpod), so
/// tests drive the full streaming lifecycle with a fake.
///
/// Safety: the OFFLINE emergency router runs before any network call — a
/// matching message never reaches the thread, the backend, or the quota; the
/// UI routes straight to the red help screen (the server layers re-check).
class ChatController extends Notifier<ChatState> {
  void Function()? _cancelStream;
  bool _cancelRequested = false;

  @override
  ChatState build() => const ChatState();

  /// Load an existing conversation into the active chat.
  Future<void> openConversation(AssistantConversation conversation) async {
    final messages =
        await ref.read(assistantRepositoryProvider).messages(conversation.id);
    state = ChatState(
      conversationId: conversation.id,
      messages: [
        for (final m in messages)
          ChatUiMessage(
            role: m.role,
            content: m.content,
            imageStorageKey: m.imageStorageKey,
          ),
      ],
    );
  }

  /// Start a fresh conversation (history stays in the conversations list).
  void startNew() => state = const ChatState();

  /// Clear a transient limited/error/emergency status back to idle.
  void acknowledgeStatus() =>
      state = state.copyWith(status: ChatStatus.idle);

  Future<void> send(
    String text, {
    String? petId,
    String? species,
    String? locale,
    String? imageStorageKey,
  }) async {
    final message = text.trim();
    if (message.isEmpty || state.isStreaming) return;

    // Layer 1 of 3: the client-side emergency router (same triplicated
    // keyword list as the Edge Function and the AI service).
    final matched =
        matchEmergencyKeyword(message, species: species, locale: locale);
    if (matched != null) {
      state = state.copyWith(
        status: ChatStatus.emergency,
        emergencyKeyword: matched,
      );
      return;
    }

    _cancelRequested = false;
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatUiMessage(
            role: 'user', content: message, imageStorageKey: imageStorageKey),
      ],
      streamingText: '',
      status: ChatStatus.streaming,
      errorMessage: null,
    );

    try {
      final stream = await ref.read(assistantTransportProvider).send(
            message: message,
            conversationId: state.conversationId,
            petId: petId,
            imageStorageKey: imageStorageKey,
          );
      _cancelStream = stream.cancel;
      var buffer = '';
      var sawDone = false;
      await for (final event in stream.events) {
        switch (event.event) {
          case 'delta':
            final text = event.data['text'];
            if (text is String) {
              buffer += text;
              state = state.copyWith(streamingText: buffer);
            }
          case 'emergency':
            // Server-side router match (layer 2/3) — mirror the client path.
            stream.cancel();
            state = state.copyWith(
              status: ChatStatus.emergency,
              emergencyKeyword: (event.data['keyword'] as String?) ?? '',
              streamingText: '',
            );
            return;
          case 'error':
            throw const AssistantUnavailableException();
          case 'done':
            sawDone = true;
        }
      }
      if (sawDone || (_cancelRequested && buffer.isNotEmpty)) {
        state = state.copyWith(
          conversationId: stream.conversationId ?? state.conversationId,
          messages: buffer.isEmpty
              ? state.messages
              : [
                  ...state.messages,
                  ChatUiMessage(role: 'assistant', content: buffer),
                ],
          streamingText: '',
          status: ChatStatus.idle,
        );
        ref.invalidate(assistantConversationsProvider);
      } else if (!_cancelRequested) {
        // Stream ended without a done event — surface as a soft failure.
        throw const AssistantUnavailableException();
      } else {
        // Cancelled before any text arrived: drop back to idle.
        state = state.copyWith(streamingText: '', status: ChatStatus.idle);
      }
    } on AssistantLimitException catch (e) {
      state = state.copyWith(status: ChatStatus.limited, limit: e.limit);
    } on AssistantUnavailableException catch (e) {
      state = state.copyWith(
        status: ChatStatus.error,
        errorMessage: e.message,
        streamingText: '',
      );
    } catch (_) {
      if (_cancelRequested) {
        // Connection torn down mid-stream by cancel(): keep any partial text.
        final buffer = state.streamingText;
        state = state.copyWith(
          messages: buffer.isEmpty
              ? state.messages
              : [
                  ...state.messages,
                  ChatUiMessage(role: 'assistant', content: buffer),
                ],
          streamingText: '',
          status: ChatStatus.idle,
        );
      } else {
        state = state.copyWith(
          status: ChatStatus.error,
          errorMessage:
              'The assistant is unavailable right now. Please try again.',
          streamingText: '',
        );
      }
    } finally {
      _cancelStream = null;
    }
  }

  /// Stop the live stream; any text already received stays as the reply.
  void stopStreaming() {
    if (!state.isStreaming) return;
    _cancelRequested = true;
    _cancelStream?.call();
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
