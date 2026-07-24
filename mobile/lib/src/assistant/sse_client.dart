import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import '../config/env.dart';

/// One parsed Server-Sent Event from the assistant stream.
class SseEvent {
  const SseEvent(this.event, this.data);
  final String event;
  final Map<String, dynamic> data;
}

/// Transforms a raw byte stream into [SseEvent]s. Frames are `event:` +
/// `data:` line pairs separated by a blank line; chunk boundaries can fall
/// anywhere (mid-frame, mid-UTF-8), so parsing buffers across chunks. Pure —
/// unit-tested with adversarial chunk splits.
Stream<SseEvent> parseSseStream(Stream<List<int>> bytes) async* {
  var buffer = '';
  await for (final text in bytes.transform(utf8.decoder)) {
    buffer += text;
    while (true) {
      final idx = buffer.indexOf('\n\n');
      if (idx < 0) break;
      final frame = buffer.substring(0, idx);
      buffer = buffer.substring(idx + 2);
      final event = _parseFrame(frame);
      if (event != null) yield event;
    }
  }
}

SseEvent? _parseFrame(String frame) {
  String? name;
  String? data;
  for (final line in frame.split('\n')) {
    if (line.startsWith('event: ')) {
      name = line.substring(7).trim();
    } else if (line.startsWith('data: ')) {
      data = line.substring(6);
    }
  }
  if (name == null || data == null) return null;
  try {
    final decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) return SseEvent(name, decoded);
  } catch (_) {
    // Malformed frame — skip rather than kill the stream.
  }
  return null;
}

/// The free daily allowance was reached (HTTP 402 from the Edge Function).
class AssistantLimitException implements Exception {
  const AssistantLimitException(this.limit);
  final int? limit;
}

/// The assistant backend is unreachable/unhealthy. [message] is user-safe.
class AssistantUnavailableException implements Exception {
  const AssistantUnavailableException(
      [this.message = 'The assistant is unavailable right now. Please try again.']);
  final String message;
}

/// A live assistant reply stream plus its conversation id and a canceller.
class AssistantStream {
  const AssistantStream({
    required this.conversationId,
    required this.events,
    required this.cancel,
  });

  final String? conversationId;
  final Stream<SseEvent> events;
  final void Function() cancel;
}

/// How the chat controller reaches the backend — injectable for tests.
abstract class AssistantTransport {
  Future<AssistantStream> send({
    required String message,
    String? conversationId,
    String? petId,
    String? imageStorageKey,
  });
}

/// Production transport: POSTs to the assistant-chat Edge Function with the
/// caller's session JWT and parses the SSE body. Cancelling closes the
/// underlying connection (the server stops streaming; the exchange is simply
/// re-asked later).
class HttpAssistantTransport implements AssistantTransport {
  HttpAssistantTransport(this._supabase);

  final SupabaseClient _supabase;

  static const Duration _connectTimeout = Duration(seconds: 20);

  @override
  Future<AssistantStream> send({
    required String message,
    String? conversationId,
    String? petId,
    String? imageStorageKey,
  }) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw const AssistantUnavailableException('Please sign in again.');
    }
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('${Env.supabaseUrl}/functions/v1/assistant-chat'),
      )
        ..headers['content-type'] = 'application/json'
        ..headers['apikey'] = Env.supabaseAnonKey
        ..headers['authorization'] = 'Bearer ${session.accessToken}'
        ..body = jsonEncode({
          'message': message,
          'conversation_id': conversationId,
          'pet_id': petId,
          'image_storage_key': imageStorageKey,
        });
      final response = await client.send(request).timeout(_connectTimeout);

      if (response.statusCode == 402) {
        final body = await response.stream.bytesToString();
        client.close();
        int? limit;
        try {
          limit = (jsonDecode(body) as Map)['limit'] as int?;
        } catch (_) {}
        throw AssistantLimitException(limit);
      }
      if (response.statusCode != 200) {
        client.close();
        throw const AssistantUnavailableException();
      }
      return AssistantStream(
        conversationId: response.headers['x-conversation-id'],
        events: parseSseStream(response.stream),
        cancel: client.close,
      );
    } on AssistantLimitException {
      rethrow;
    } on AssistantUnavailableException {
      client.close();
      rethrow;
    } on TimeoutException {
      client.close();
      throw const AssistantUnavailableException();
    } catch (_) {
      client.close();
      throw const AssistantUnavailableException();
    }
  }
}

final assistantTransportProvider = Provider<AssistantTransport>((ref) {
  return HttpAssistantTransport(ref.watch(supabaseClientProvider));
});
