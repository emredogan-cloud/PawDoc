/// A health reminder, mirroring the `reminders` table (Phase 1.1 schema).
/// Owned by user_id (RLS); the cron-driven /process-reminders push uses
/// `reminder_type` as the message label and flips `is_sent` once delivered.
library;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    this.createdAt,
    this.notificationSentAt,
  });

  final String? id;
  final String petId;
  final String? userId;
  final String reminderType;
  final DateTime dueDate;
  final bool isSent;

  /// When the owner set this reminder. A real column since the initial schema,
  /// simply never read until `reminder_detail` needed a "Set on" fact and a
  /// history entry that was not invented.
  final DateTime? createdAt;

  /// When the notification actually went out. Also a real column, and the only
  /// delivery evidence the app has.
  final DateTime? notificationSentAt;

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String?,
        petId: json['pet_id'] as String,
        userId: json['user_id'] as String?,
        reminderType: json['reminder_type'] as String,
        dueDate: DateTime.parse(json['due_date'] as String),
        isSent: json['is_sent'] as bool? ?? false,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'].toString()),
        notificationSentAt: json['notification_sent_at'] == null
            ? null
            : DateTime.tryParse(json['notification_sent_at'].toString()),
      );

  /// Columns for insert. `user_id` is added by the repository (must equal
  /// auth.uid() to satisfy the reminders RLS WITH CHECK). `due_date` is sent as
  /// a date-only string — a timezone-agnostic calendar date.
  Map<String, dynamic> toColumns() => {
        'pet_id': petId,
        'reminder_type': reminderType,
        'due_date': dueDate.toIso8601String().split('T').first,
      };

  Reminder copyWith({String? reminderType, DateTime? dueDate}) => Reminder(
        id: id,
        petId: petId,
        userId: userId,
        reminderType: reminderType ?? this.reminderType,
        dueDate: dueDate ?? this.dueDate,
        isSent: isSent,
        createdAt: createdAt,
        notificationSentAt: notificationSentAt,
      );

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Whole days from today until it is due; negative once the date has passed.
  int get daysUntilDue => dueDate.difference(_today()).inDays;

  bool get isPastDue => daysUntilDue < 0;
}

// ---------------------------------------------------------------------------
// Filing labels
// ---------------------------------------------------------------------------

/// What kind of thing a reminder is about.
///
/// **A filing label on the owner's own words, never a claim about the animal.**
/// The reminders table stores one free-text field; this reads it the way the
/// reminders list has always chosen its glyph, and the same way
/// `conversation_history` derives a topic from a thread. It changes a colour
/// and an icon and nothing else.
enum ReminderCategory {
  medication('Medication', LucideIcons.pill),
  vaccine('Vaccine', LucideIcons.syringe),
  vetVisit('Vet visit', LucideIcons.stethoscope),
  grooming('Grooming', LucideIcons.scissors),
  parasite('Parasite control', LucideIcons.bug),
  general('Reminder', LucideIcons.bell);

  const ReminderCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Reads the owner's text. Order matters — "flea & tick medication" is
  /// parasite control before it is medication.
  static ReminderCategory of(String reminderType) {
    final t = reminderType.toLowerCase();
    bool has(List<String> needles) => needles.any(t.contains);

    if (has(['flea', 'tick', 'worm', 'parasite', 'heartworm', 'mite'])) {
      return ReminderCategory.parasite;
    }
    if (has(['vaccin', 'vacc', 'booster', 'dhpp', 'rabies', 'shot'])) {
      return ReminderCategory.vaccine;
    }
    if (has(['groom', 'nail', 'claw', 'bath', 'brush', 'clip'])) {
      return ReminderCategory.grooming;
    }
    if (has(['vet', 'appointment', 'check-up', 'checkup', 'clinic', 'visit'])) {
      return ReminderCategory.vetVisit;
    }
    if (has(['med', 'tablet', 'pill', 'dose', 'drops', 'capsule', 'syrup'])) {
      return ReminderCategory.medication;
    }
    return ReminderCategory.general;
  }
}
