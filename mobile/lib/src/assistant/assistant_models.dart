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

/// The topic rail `conversation_history` filters by.
///
/// The `assistant_conversations` table carries a title and nothing else, so a
/// topic is derived from the thread's own words rather than stored. It is a
/// **filing label on the owner's own question**, never a statement about the
/// animal — mis-filing "Coat & skin" as "General" costs a filter hit and
/// nothing more.
enum ConversationTopic {
  health('Health', 'health'),
  behavior('Behavior', 'behavior'),
  nutrition('Nutrition', 'nutrition'),
  grooming('Grooming', 'grooming'),
  general('General', 'general');

  const ConversationTopic(this.label, this.id);

  final String label;
  final String id;
}

/// Keywords per topic, most specific first. Deliberately small and legible —
/// this is a filing heuristic, not a classifier, and it is unit-tested so a
/// later edit cannot silently make every thread "General".
const Map<ConversationTopic, List<String>> kConversationTopicKeywords = {
  ConversationTopic.nutrition: [
    'food', 'feed', 'diet', 'nutrition', 'treat', 'kibble', 'meal', 'appetite',
    'water', 'mama', 'beslen',
  ],
  ConversationTopic.grooming: [
    'groom', 'coat', 'fur', 'shed', 'brush', 'bath', 'nail', 'claw', 'dental',
    'teeth', 'tüy', 'tırnak',
  ],
  ConversationTopic.behavior: [
    'behavio', 'train', 'anxiet', 'bark', 'chew', 'scratch', 'socialis',
    'socializ', 'walk', 'play', 'sleep', 'davran', 'kaygı',
  ],
  ConversationTopic.health: [
    'health', 'vet', 'vaccin', 'medicat', 'medicine', 'dose', 'weight',
    'checkup', 'check-up', 'record', 'sağlık', 'aşı',
  ],
};

/// Files a conversation by its title and opening question.
ConversationTopic conversationTopic(String title, [String? firstMessage]) {
  final hay = '$title ${firstMessage ?? ''}'.toLowerCase();
  for (final entry in kConversationTopicKeywords.entries) {
    for (final word in entry.value) {
      if (hay.contains(word)) return entry.key;
    }
  }
  return ConversationTopic.general;
}

/// A conversation with the extras `conversation_history` draws beside it: the
/// opening exchange as a preview, how many photos it carries, and its topic.
class ConversationSummary {
  const ConversationSummary({
    required this.conversation,
    required this.preview,
    required this.photoCount,
    required this.messageCount,
    required this.topic,
  });

  final AssistantConversation conversation;
  final String preview;
  final int photoCount;
  final int messageCount;
  final ConversationTopic topic;

  String get id => conversation.id;
  String get title => conversation.title;
  DateTime get updatedAt => conversation.updatedAt;
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
