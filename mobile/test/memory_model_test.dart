// Next Evolution Phase 2 — Memory model + pure journal logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/memories/memory.dart';

Memory mem({
  String? id,
  String title = 'Beach day',
  String? note,
  DateTime? takenOn,
}) =>
    Memory(
      id: id ?? 'm1',
      userId: 'u1',
      petId: 'p1',
      title: title,
      note: note,
      storageKey: 'memories/u1/$id.jpg',
      takenOn: takenOn ?? DateTime(2026, 7, 20),
    );

void main() {
  test('fromJson/toColumns roundtrip preserves journal fields', () {
    final m = Memory.fromJson({
      'id': 'abc',
      'user_id': 'u1',
      'pet_id': 'p1',
      'title': 'First snow',
      'note': 'He loved it',
      'storage_key': 'memories/u1/abc.jpg',
      'taken_on': '2026-01-05',
      'created_at': '2026-01-05T12:00:00Z',
    });
    expect(m.title, 'First snow');
    expect(m.takenOn, DateTime(2026, 1, 5));
    final cols = m.toColumns();
    expect(cols['taken_on'], '2026-01-05');
    expect(cols['storage_key'], 'memories/u1/abc.jpg');
    expect(cols.containsKey('user_id'), isFalse,
        reason: 'user_id is injected by the repository (RLS WITH CHECK)');
  });

  test('copyWith replaces only what changed', () {
    final m = mem(note: 'old');
    final edited = m.copyWith(title: 'New title', takenOn: DateTime(2026, 2, 1));
    expect(edited.title, 'New title');
    expect(edited.note, 'old');
    expect(edited.takenOn, DateTime(2026, 2, 1));
    expect(edited.storageKey, m.storageKey);
  });

  group('filterMemories', () {
    final list = [
      mem(id: 'a', title: 'Beach day', note: 'sunny afternoon'),
      mem(id: 'b', title: 'Vet visit'),
      mem(id: 'c', title: 'Nap', note: 'On the BEACH towel'),
    ];

    test('empty query returns everything', () {
      expect(filterMemories(list, '  '), hasLength(3));
    });

    test('matches title and note, case-insensitive', () {
      final hits = filterMemories(list, 'beach');
      expect(hits.map((m) => m.id), ['a', 'c']);
    });

    test('no matches yields empty list', () {
      expect(filterMemories(list, 'zebra'), isEmpty);
    });
  });

  group('groupMemoriesByMonth', () {
    test('buckets newest month first, preserving in-month order', () {
      final groups = groupMemoriesByMonth([
        mem(id: 'a', takenOn: DateTime(2026, 7, 21)),
        mem(id: 'b', takenOn: DateTime(2026, 7, 3)),
        mem(id: 'c', takenOn: DateTime(2026, 5, 30)),
      ]);
      expect(groups, hasLength(2));
      expect(groups.first.month, DateTime(2026, 7));
      expect(groups.first.memories.map((m) => m.id), ['a', 'b']);
      expect(groups.last.month, DateTime(2026, 5));
    });

    test('month label omits the current year, keeps others', () {
      final now = DateTime(2026, 7, 24);
      expect(memoryMonthLabel(DateTime(2026, 7), now: now), 'July');
      expect(memoryMonthLabel(DateTime(2025, 12), now: now), 'December 2025');
    });
  });

  group('free-tier allowance', () {
    test('premium is always allowed', () {
      expect(canAddMemory(currentCount: 999, isPremium: true), isTrue);
    });
    test('free is allowed under the cap and blocked at it', () {
      expect(
          canAddMemory(currentCount: kFreeMemoryLimit - 1, isPremium: false),
          isTrue);
      expect(canAddMemory(currentCount: kFreeMemoryLimit, isPremium: false),
          isFalse);
    });
  });
}
