/// A health reminder, mirroring the `reminders` table (Phase 1.1 schema).
/// Owned by user_id (RLS); the cron-driven /process-reminders push uses
/// `reminder_type` as the message label and flips `is_sent` once delivered.
const List<String> kReminderPresets = [
  'Vaccine',
  'Flea & tick medication',
  'Medication',
  'Vet appointment',
  'Deworming',
];

class Reminder {
  const Reminder({
    this.id,
    required this.petId,
    this.userId,
    required this.reminderType,
    required this.dueDate,
    this.isSent = false,
  });

  final String? id;
  final String petId;
  final String? userId;
  final String reminderType;
  final DateTime dueDate;
  final bool isSent;

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String?,
        petId: json['pet_id'] as String,
        userId: json['user_id'] as String?,
        reminderType: json['reminder_type'] as String,
        dueDate: DateTime.parse(json['due_date'] as String),
        isSent: json['is_sent'] as bool? ?? false,
      );

  /// Columns for insert. `user_id` is added by the repository (must equal
  /// auth.uid() to satisfy the reminders RLS WITH CHECK). `due_date` is sent as
  /// a date-only string — a timezone-agnostic calendar date.
  Map<String, dynamic> toColumns() => {
        'pet_id': petId,
        'reminder_type': reminderType,
        'due_date': dueDate.toIso8601String().split('T').first,
      };
}
