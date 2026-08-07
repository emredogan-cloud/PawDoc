import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'memory.dart';

/// The searching, ranking and grouping behind `search_memories`.
///
/// All of it is pure and unit-tested, for the reason `PetStats` is: the
/// arithmetic on a search screen is the part that quietly goes wrong, and
/// pumping a widget to check a count is a slow way to find out.
///
/// ## What the reference asks for that the journal cannot answer
///
/// * **"All Locations"**, and a place under every result. PawDoc strips EXIF
///   and GPS on the device before a photo is uploaded — as a standing rule, not
///   a setting. There is no location and there must never be one. The filter
///   slot keeps its position and its shape and holds something that *is* true:
///   the owner's own hearts.
/// * **A time of day** under each result. `taken_on` is a date column.
/// * **A video badge and a duration.** A memory is one still photograph.

// ---------------------------------------------------------------------------
// Ordering
// ---------------------------------------------------------------------------

/// How results are ordered.
enum MemorySearchOrder {
  relevance('Most Relevant'),
  newest('Newest First'),
  oldest('Oldest First');

  const MemorySearchOrder(this.label);

  final String label;
}

/// Where a query matched, highest first. Exposed so the ranking can be tested
/// directly rather than inferred from list order.
int memoryMatchScore(Memory memory, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0;
  final title = memory.title.toLowerCase();
  final note = (memory.note ?? '').toLowerCase();
  if (title == q) return 4;
  if (title.startsWith(q)) return 3;
  if (title.contains(q)) return 2;
  if (note.contains(q)) return 1;
  return 0;
}

/// Filter by [query], then order.
///
/// Relevance is title-before-note, then newest — with no query it *is* newest,
/// because there is nothing to be relevant to and a stable order beats an
/// arbitrary one.
List<Memory> searchMemories(
  List<Memory> memories,
  String query, {
  MemorySearchOrder order = MemorySearchOrder.relevance,
}) {
  final q = query.trim();
  final out = q.isEmpty ? [...memories] : filterMemories(memories, q).toList();
  switch (order) {
    case MemorySearchOrder.newest:
      out.sort((a, b) => b.takenOn.compareTo(a.takenOn));
    case MemorySearchOrder.oldest:
      out.sort((a, b) => a.takenOn.compareTo(b.takenOn));
    case MemorySearchOrder.relevance:
      out.sort((a, b) {
        final byScore =
            memoryMatchScore(b, q).compareTo(memoryMatchScore(a, q));
        if (byScore != 0) return byScore;
        return b.takenOn.compareTo(a.takenOn);
      });
  }
  return out;
}

// ---------------------------------------------------------------------------
// Grouping
// ---------------------------------------------------------------------------

/// A dated bucket of results — the reference's "Today · 3", "Yesterday · 4".
typedef MemoryBucket = ({String label, List<Memory> memories});

/// Buckets [memories] by how recent they are, preserving the order they arrive
/// in. Empty buckets are dropped, so a book with nothing from this week never
/// shows an empty "This Week" card.
///
/// [now] is injectable because a test that depends on the wall clock is a test
/// that fails at midnight.
List<MemoryBucket> groupMemoriesByRecency(
  List<Memory> memories, {
  DateTime? now,
}) {
  final today = _dayOf(now ?? DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 7));
  final monthAgo = today.subtract(const Duration(days: 30));
  final yearAgo = today.subtract(const Duration(days: 365));

  final buckets = <String, List<Memory>>{
    'Today': [],
    'Yesterday': [],
    'This Week': [],
    'This Month': [],
    'This Year': [],
    'Earlier': [],
  };
  for (final m in memories) {
    final day = _dayOf(m.takenOn);
    final label = switch (day) {
      _ when !day.isBefore(today) => 'Today',
      _ when !day.isBefore(yesterday) => 'Yesterday',
      _ when day.isAfter(weekAgo) => 'This Week',
      _ when day.isAfter(monthAgo) => 'This Month',
      _ when day.isAfter(yearAgo) => 'This Year',
      _ => 'Earlier',
    };
    buckets[label]!.add(m);
  }
  return [
    for (final entry in buckets.entries)
      if (entry.value.isNotEmpty)
        (label: entry.key, memories: entry.value),
  ];
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

// ---------------------------------------------------------------------------
// Quick searches
// ---------------------------------------------------------------------------

/// One of the reference's "Quick Searches" chips.
///
/// The reference labels each with a count — "Walks · 24 memories" — over
/// nothing. Here a quick search is a real saved query over the titles and
/// notes the owner wrote, and [countIn] is the answer for the book actually
/// loaded. Nothing is invented; a chip that matches nothing says so.
class QuickSearch {
  const QuickSearch(this.label, this.icon, this.terms);

  final String label;
  final IconData icon;

  /// Any one of these matching is a hit — the owner did not agree to a
  /// vocabulary, so "stroll" has to find the walk.
  final List<String> terms;

  bool matches(Memory memory) {
    final hay =
        '${memory.title} ${memory.note ?? ''}'.toLowerCase();
    for (final term in terms) {
      if (hay.contains(term)) return true;
    }
    return false;
  }

  int countIn(List<Memory> memories) =>
      memories.where(matches).length;

  /// The query this chip drops into the search field. The first term is the
  /// canonical one, so the field shows a word the owner will recognise.
  String get query => terms.first;
}

const List<QuickSearch> kQuickSearches = [
  QuickSearch('Walks', LucideIcons.footprints, ['walk', 'stroll', 'hike']),
  QuickSearch('Birthdays', LucideIcons.cake, ['birthday', 'gotcha day']),
  QuickSearch('Vet Visits', LucideIcons.stethoscope, ['vet', 'clinic']),
  QuickSearch('Travel', LucideIcons.luggage, ['trip', 'travel', 'holiday']),
  QuickSearch('Playtime', LucideIcons.volleyball, ['play', 'ball', 'toy']),
  QuickSearch('Naps', LucideIcons.moon, ['nap', 'sleep', 'snooze']),
];

// ---------------------------------------------------------------------------
// Recent searches
// ---------------------------------------------------------------------------

/// The last few things this owner searched for.
///
/// **On the device, and the screen says so.** There is no search-history table
/// and adding one would mean storing what a person typed about their animal on
/// a server, which is a worse trade than losing the list on a new phone.
class RecentSearches {
  const RecentSearches._();

  static const String key = 'pawdoc.memory.searches';
  static const int max = 6;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? const <String>[];
  }

  /// Puts [query] at the front, de-duplicated case-insensitively, capped at
  /// [max]. Returns the new list so the caller does not have to re-read.
  static Future<List<String>> remember(String query) async {
    final q = query.trim();
    if (q.isEmpty) return load();
    final prefs = await SharedPreferences.getInstance();
    final next = mergeRecent(prefs.getStringList(key) ?? const <String>[], q);
    await prefs.setStringList(key, next);
    return next;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// The list arithmetic, pure so it is tested without a plugin.
  static List<String> mergeRecent(List<String> current, String query) {
    final q = query.trim();
    if (q.isEmpty) return List<String>.from(current);
    final out = <String>[q];
    for (final item in current) {
      if (item.toLowerCase() == q.toLowerCase()) continue;
      out.add(item);
      if (out.length == max) break;
    }
    return out;
  }
}
