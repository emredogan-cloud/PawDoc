/// A manually-logged pet health event, mirroring the `health_events` table
/// (Phase 1.1 schema). Ownership is derived from the parent pet via RLS — the
/// table has no `user_id` column (owner-approved CR #2 design), so inserts carry
/// only `pet_id` and the user's JWT scopes them.
const List<String> kHealthEventTypes = [
  'vaccination',
  'vet_visit',
  'medication',
  'weight',
  'custom',
];

/// Human label for an event_type (also used by the timeline).
String healthEventLabel(String type) => switch (type) {
      'vaccination' => 'Vaccination',
      'vet_visit' => 'Vet visit',
      'medication' => 'Medication',
      'weight' => 'Weight',
      _ => 'Note',
    };

class HealthEvent {
  const HealthEvent({
    this.id,
    required this.petId,
    required this.eventType,
    required this.eventDate,
    this.notes,
    this.metadata,
    this.createdAt,
  });

  final String? id;
  final String petId;
  final String eventType;
  final DateTime eventDate;
  final String? notes;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  factory HealthEvent.fromJson(Map<String, dynamic> json) {
    final date = json['event_date'] as String?;
    final created = json['created_at'] as String?;
    return HealthEvent(
      id: json['id'] as String?,
      petId: json['pet_id'] as String,
      eventType: json['event_type'] as String,
      eventDate: DateTime.parse(date!),
      notes: json['notes'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
      createdAt: created == null ? null : DateTime.tryParse(created),
    );
  }

  /// Columns for insert. No `user_id` (the table has none — see CR #2 note); the
  /// RLS WITH CHECK validates ownership through `pet_id` → `pets.user_id`.
  Map<String, dynamic> toColumns() => {
        'pet_id': petId,
        'event_type': eventType,
        'event_date': eventDate.toIso8601String().split('T').first,
        'notes': notes,
        'metadata': metadata,
      };
}
