/// Pet Memory model mirroring the `pet_memories` table (Next Evolution
/// Phase 2). A memory is human content only — photo + title + note + date.
/// Photos live in R2 under `memories/<uid>/…`, addressed by [storageKey] and
/// displayed via short-lived signed GET URLs (never a public bucket).
class Memory {
  const Memory({
    this.id,
    required this.userId,
    required this.petId,
    required this.title,
    this.note,
    required this.storageKey,
    required this.takenOn,
    this.createdAt,
  });

  final String? id;
  final String userId;
  final String petId;
  final String title;
  final String? note;
  final String storageKey;

  /// The day the memory happened (user-editable, date-only).
  final DateTime takenOn;
  final DateTime? createdAt;

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        petId: json['pet_id'] as String,
        title: json['title'] as String,
        note: json['note'] as String?,
        storageKey: json['storage_key'] as String,
        takenOn: DateTime.parse(json['taken_on'] as String),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String),
      );

  /// Columns for insert/update. `user_id` is added by the repository (it must
  /// equal auth.uid() to satisfy the RLS WITH CHECK).
  Map<String, dynamic> toColumns() => {
        'pet_id': petId,
        'title': title,
        'note': note,
        'storage_key': storageKey,
        'taken_on': takenOn.toIso8601String().split('T').first,
      };

  Memory copyWith({
    String? title,
    String? note,
    String? storageKey,
    DateTime? takenOn,
  }) =>
      Memory(
        id: id,
        userId: userId,
        petId: petId,
        title: title ?? this.title,
        note: note ?? this.note,
        storageKey: storageKey ?? this.storageKey,
        takenOn: takenOn ?? this.takenOn,
        createdAt: createdAt,
      );
}

/// Free-tier memory allowance ("paid = memory": the journal is the premium
/// pillar, but everyone gets a real taste). Premium is unlimited.
const int kFreeMemoryLimit = 20;

/// Pure gate for the create flow — server cost surface is storage-only, so a
/// client-side gate is proportionate here (unlike AI quotas, which are
/// server-enforced).
bool canAddMemory({required int currentCount, required bool isPremium}) =>
    isPremium || currentCount < kFreeMemoryLimit;

/// Case-insensitive search across title + note. Pure so it is unit-testable
/// and works offline on the already-loaded list.
List<Memory> filterMemories(List<Memory> memories, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return memories;
  return memories
      .where((m) =>
          m.title.toLowerCase().contains(q) ||
          (m.note?.toLowerCase().contains(q) ?? false))
      .toList(growable: false);
}

/// Month bucket ("July 2026") for the timeline view, newest month first.
/// Input is assumed sorted newest-first (the repository orders it); grouping
/// preserves that order within and across buckets.
List<({DateTime month, List<Memory> memories})> groupMemoriesByMonth(
    List<Memory> memories) {
  final buckets = <DateTime, List<Memory>>{};
  for (final m in memories) {
    final key = DateTime(m.takenOn.year, m.takenOn.month);
    buckets.putIfAbsent(key, () => []).add(m);
  }
  final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final k in keys) (month: k, memories: buckets[k]!)];
}

const List<String> _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "July 2026" — current year omitted ("July") to keep timeline headers light.
String memoryMonthLabel(DateTime month, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final name = _kMonthNames[month.month - 1];
  return month.year == ref.year ? name : '$name ${month.year}';
}
