/// Assistant models mirroring `assistant_conversations` / `assistant_messages`
/// (Next Evolution Phase 4). History reads are RLS-scoped; writes go through
/// the assistant-chat Edge Function (user turns under the caller's JWT,
/// assistant turns server-side after the stream completes).
class AssistantConversation {
  const AssistantConversation({
    required this.id,
    this.petId,
    required this.title,
    required this.updatedAt,
  });

  final String id;
  final String? petId;
  final String title;
  final DateTime updatedAt;

  factory AssistantConversation.fromJson(Map<String, dynamic> json) =>
      AssistantConversation(
        id: json['id'] as String,
        petId: json['pet_id'] as String?,
        title: json['title'] as String,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class AssistantMessage {
  const AssistantMessage({
    this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.imageStorageKey,
    this.createdAt,
  });

  final String? id;
  final String conversationId;
  final String role; // 'user' | 'assistant'
  final String content;
  final String? imageStorageKey;
  final DateTime? createdAt;

  bool get isUser => role == 'user';

  factory AssistantMessage.fromJson(Map<String, dynamic> json) =>
      AssistantMessage(
        id: json['id'] as String?,
        conversationId: json['conversation_id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        imageStorageKey: json['image_storage_key'] as String?,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String),
      );
}
