import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import 'assistant_models.dart';

/// History reads + conversation management for the assistant. All access is
/// RLS-scoped to the signed-in user; message WRITES happen only through the
/// assistant-chat Edge Function (this repository never inserts messages).
class AssistantRepository {
  AssistantRepository(this._client);

  final SupabaseClient _client;

  Future<List<AssistantConversation>> conversations({int limit = 50}) async {
    final rows = await _client
        .from('assistant_conversations')
        .select()
        .order('updated_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => AssistantConversation.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// The conversation list plus what `conversation_history` draws beside each
  /// row — a preview, a photo count and a topic.
  ///
  /// One extra round trip for the whole page rather than one per row: at 200
  /// threads that would be 200 requests, and the screen opens from a header
  /// button people press often.
  Future<List<ConversationSummary>> summaries({int limit = 200}) async {
    final list = await conversations(limit: limit);
    if (list.isEmpty) return const [];
    final ids = list.map((c) => c.id).toList(growable: false);
    final rows = await _client
        .from('assistant_messages')
        .select('conversation_id, role, content, image_storage_key, created_at')
        .inFilter('conversation_id', ids)
        .order('created_at', ascending: true)
        .limit(2000);

    final firstUser = <String, String>{};
    final firstReply = <String, String>{};
    final photos = <String, int>{};
    final counts = <String, int>{};
    for (final raw in rows as List) {
      final r = raw as Map<String, dynamic>;
      final id = r['conversation_id'] as String;
      final content = (r['content'] as String?)?.trim() ?? '';
      counts[id] = (counts[id] ?? 0) + 1;
      if (r['image_storage_key'] != null) {
        photos[id] = (photos[id] ?? 0) + 1;
      }
      if (r['role'] == 'user') {
        firstUser[id] ??= content;
      } else {
        firstReply[id] ??= content;
      }
    }

    return [
      for (final c in list)
        ConversationSummary(
          conversation: c,
          preview: _preview(firstReply[c.id] ?? firstUser[c.id] ?? ''),
          photoCount: photos[c.id] ?? 0,
          messageCount: counts[c.id] ?? 0,
          topic: conversationTopic(c.title, firstUser[c.id]),
        ),
    ];
  }

  /// Flatten a reply to one line: markdown headings, bullets and emphasis all
  /// render as literal `#`/`*` in a single-line preview otherwise.
  static String _preview(String body) {
    final flat = body
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'[*_`>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return flat.length <= 140 ? flat : '${flat.substring(0, 140)}…';
  }

  Future<List<AssistantMessage>> messages(String conversationId) async {
    final rows = await _client
        .from('assistant_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(200);
    return (rows as List)
        .map((r) => AssistantMessage.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> rename(String conversationId, String title) async {
    await _client
        .from('assistant_conversations')
        .update({'title': title, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', conversationId);
  }

  /// Deletes the conversation; messages cascade at the database.
  Future<void> delete(String conversationId) async {
    await _client
        .from('assistant_conversations')
        .delete()
        .eq('id', conversationId);
  }

  /// Deletes every conversation this user can see. RLS is what scopes it — the
  /// filter is `user_id = auth.uid()` in the policy, not in this statement, so
  /// there is no way for a client bug here to reach another account's rows.
  /// A `delete()` with no filter is rejected by PostgREST, hence the tautology.
  Future<void> deleteAll() async {
    await _client
        .from('assistant_conversations')
        .delete()
        .not('id', 'is', null);
  }
}

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  return AssistantRepository(ref.watch(supabaseClientProvider));
});

final assistantConversationsProvider =
    FutureProvider.autoDispose<List<AssistantConversation>>((ref) {
  // Scoped to the signed-in user: watching the id makes an identity change
  // on this device recompute instead of serving the previous account's cache.
  ref.watch(currentUserIdProvider);
  return ref.watch(assistantRepositoryProvider).conversations();
});

/// The history screen's list. Separate from [assistantConversationsProvider]
/// because the hub's "Continue a conversation" card needs three titles and this
/// needs every thread with its preview, photo count and topic.
final conversationSummariesProvider =
    FutureProvider.autoDispose<List<ConversationSummary>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(assistantRepositoryProvider).summaries();
});
