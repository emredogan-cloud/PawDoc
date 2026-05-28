/// A weekly AI health journal entry (Phase 5.3). Generated server-side by the
/// cron, RLS-readable only by the owning user. The schema has no user_id leak
/// beyond what RLS allows: only the row's own user sees it.
class Journal {
  const Journal({
    this.id,
    required this.petId,
    required this.userId,
    required this.narrativeText,
    required this.weekStartDate,
    this.modelUsed,
    this.createdAt,
  });

  final String? id;
  final String petId;
  final String userId;
  final String narrativeText;
  final DateTime weekStartDate;
  final String? modelUsed;
  final DateTime? createdAt;

  factory Journal.fromJson(Map<String, dynamic> json) => Journal(
        id: json['id'] as String?,
        petId: json['pet_id'] as String,
        userId: json['user_id'] as String,
        narrativeText: json['narrative_text'] as String,
        weekStartDate: DateTime.parse(json['week_start_date'] as String),
        modelUsed: json['model_used'] as String?,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
      );
}
