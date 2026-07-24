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

  Future<List<AssistantConversation>> conversations() async {
    final rows = await _client
        .from('assistant_conversations')
        .select()
        .order('updated_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((r) => AssistantConversation.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
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
}

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  return AssistantRepository(ref.watch(supabaseClientProvider));
});

final assistantConversationsProvider =
    FutureProvider.autoDispose<List<AssistantConversation>>((ref) {
  return ref.watch(assistantRepositoryProvider).conversations();
});
