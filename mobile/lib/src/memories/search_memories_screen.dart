import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/dates.dart';
import '../core/friendly_error.dart';
import '../core/paw_nav_bar.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../pets/pet.dart';
import '../pets/pet_pick_rail.dart';
import '../pets/pets_repository.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'memories_repository.dart';
import 'memories_screen.dart';
import 'memory.dart';
import 'memory_photo.dart';
import 'memory_search.dart';
import 'memory_viewer_screen.dart';

/// Searching the whole journal, built to mockup `search_memories`.
///
/// The gallery filters the book you are looking at. This searches **every**
/// pet's book at once, ranks the hits, groups them by how recent they are, and
/// remembers what was searched for — which is why it is its own surface rather
/// than a wider version of the gallery's field.
///
/// ## Everything on it is counted, nothing is asserted
///
/// * "128 memories found" is the number of rows that matched.
/// * Each Quick Search chip carries the count of memories its terms actually
///   hit in the loaded book — the reference prints "Walks · 24 memories" over
///   no data at all.
/// * "Most Relevant" is a real ranking: an exact title, then a title prefix,
///   then a title match, then the note, then newest.
///
/// ## The location filter
///
/// The reference gives slot 3 to **"All Locations"** and puts a place under
/// every result. PawDoc strips EXIF and GPS from a photo on the device before
/// it is uploaded, as a standing rule — there is no location, and there must
/// never be one. The slot keeps its position, its shape and its neighbours;
/// it holds the owner's own hearts instead, which is something the app really
/// knows. The **More Filters** sheet says why, in as many words.
///
/// ## Layout departure
///
/// The reference sets its four filter pills in **one row** — four 87dp
/// lozenges. Each pill is a *value* display: it reads "All Types" now and
/// "Photos" later, "All Dates" now and "Past month" later. At readable type an
/// 87dp pill has ~50dp for its label once the glyph and the chevron are paid
/// for, and "Hearted only" does not fit in 50dp. A filter row whose current
/// values cannot be read is worse than one on two lines, so the four pills sit
/// two-up — every pill, its glyph, its order and its shape preserved.
class SearchMemoriesScreen extends ConsumerStatefulWidget {
  const SearchMemoriesScreen({super.key, required this.pet, this.petId});

  /// The pet whose journal opened the search.
  final Pet pet;

  /// Which pet to start scoped to. `null` searches every book.
  final String? petId;

  @override
  ConsumerState<SearchMemoriesScreen> createState() =>
      _SearchMemoriesScreenState();
}

class _SearchMemoriesScreenState extends ConsumerState<SearchMemoriesScreen> {
  final _controller = TextEditingController();

  String _query = '';
  late String? _petId = widget.petId;
  MemorySearchOrder _order = MemorySearchOrder.relevance;
  MemoryType _type = MemoryType.all;
  bool _heartedOnly = false;
  DateWindow _window = DateWindow.all;

  List<String> _recent = const [];
  Map<String, DateTime>? _favourites;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recent = await RecentSearches.load();
    final favs = await MemoriesScreen.favLog.loadAll();
    if (!mounted) return;
    setState(() {
      _recent = recent;
      _favourites = favs;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isFavourite(Memory m) =>
      m.id != null &&
      (_favourites?.containsKey(MemoriesScreen.favKey(m.id!)) ?? false);

  /// A query is only *remembered* once the owner acts on it — submitting the
  /// field, or opening a result. Storing every keystroke would fill the list
  /// with the prefixes of one word.
  Future<void> _remember(String query) async {
    final next = await RecentSearches.remember(query);
    if (mounted) setState(() => _recent = next);
  }

  void _run(String query) {
    _controller.text = query;
    _controller.selection =
        TextSelection.collapsed(offset: query.length);
    setState(() => _query = query);
    _remember(query);
  }

  // -------------------------------------------------------------------------
  // Data
  // -------------------------------------------------------------------------

  /// Every memory in scope: one pet, or all of them merged.
  (List<Memory>, bool, Object?) _collect(List<Pet> pets) {
    if (_petId != null) {
      final async = ref.watch(memoriesListProvider(_petId!));
      return (async.value ?? const <Memory>[], async.isLoading, async.error);
    }
    final all = <Memory>[];
    var loading = false;
    Object? error;
    for (final pet in pets) {
      if (pet.id == null) continue;
      final async = ref.watch(memoriesListProvider(pet.id!));
      all.addAll(async.value ?? const <Memory>[]);
      if (async.isLoading) loading = true;
      error ??= async.error;
    }
    return (all, loading, error);
  }

  Pet _petFor(String id) {
    for (final p in ref.read(petsListProvider).value ?? const <Pet>[]) {
      if (p.id == id) return p;
    }
    return widget.pet;
  }

  Future<void> _open(Memory memory) async {
    if (_query.trim().isNotEmpty) await _remember(_query);
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            MemoryViewerScreen(memory: memory, pet: _petFor(memory.petId)),
      ),
    );
    if (changed == true && mounted) {
      for (final pet in ref.read(petsListProvider).value ?? const <Pet>[]) {
        if (pet.id != null) ref.invalidate(memoriesListProvider(pet.id!));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Sheets
  // -------------------------------------------------------------------------

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Recent searches',
        scrollable: true,
        children: [
          if (_recent.isEmpty)
            const Text('Nothing searched yet on this phone.',
                style: TextStyle(
                    color: HealthTone.dim, fontSize: 12.5, height: 1.4))
          else ...[
            for (final q in _recent)
              HealthRecordRow(
                key: Key('search_recent_$q'),
                leading: const HealthGlyphDisc(
                    icon: LucideIcons.history, tint: HealthTone.info, size: 36),
                title: q,
                chevron: false,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _run(q);
                },
              ),
            HealthDangerCard(
              key: const Key('search_clear_history'),
              icon: LucideIcons.eraser,
              title: 'Clear recent searches',
              body: 'Kept on this phone only. Nothing is sent anywhere.',
              onTap: () async {
                Navigator.pop(sheetContext);
                await RecentSearches.clear();
                if (mounted) setState(() => _recent = const []);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'More filters',
        scrollable: true,
        children: [
          const HealthGroupLabel(label: 'Order'),
          for (final o in MemorySearchOrder.values)
            HealthRecordRow(
              key: Key('search_order_${o.name}'),
              leading: HealthGlyphDisc(
                icon: switch (o) {
                  MemorySearchOrder.relevance => LucideIcons.sparkles,
                  MemorySearchOrder.newest => LucideIcons.arrowDown,
                  MemorySearchOrder.oldest => LucideIcons.arrowUp,
                },
                tint: o == _order
                    ? PawTone.of(context).accent
                    : HealthTone.info,
                size: 36,
              ),
              title: o.label,
              subtitle: o == _order ? 'Current' : null,
              chevron: false,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _order = o);
              },
            ),
          const HealthGroupLabel(label: 'Type'),
          for (final t in MemoryType.values)
            HealthRecordRow(
              key: Key('search_type_${t.name}'),
              leading: HealthGlyphDisc(
                icon: t.icon,
                tint: t.available
                    ? (t == _type
                        ? PawTone.of(context).accent
                        : HealthTone.info)
                    : HealthTone.faint,
                size: 36,
              ),
              title: t.label,
              subtitle: t.available
                  ? (t == _type ? 'Current' : null)
                  : 'Soon — a memory is a photo for now',
              chevron: false,
              onTap: t.available
                  ? () {
                      Navigator.pop(sheetContext);
                      setState(() => _type = t);
                    }
                  : null,
            ),
          const HealthGroupLabel(label: 'Where a photo was taken'),
          const HealthEduCard(
            key: Key('search_location_rule'),
            icon: LucideIcons.mapPinOff,
            title: 'There is no location to filter by',
            body: 'PawDoc strips EXIF and GPS from every photo on this phone '
                'before it is uploaded. That is a rule, not a setting — so the '
                'journal never knows where a moment happened.',
          ),
        ],
      ),
    );
  }

  void _openDates() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Dates',
        scrollable: true,
        children: [
          for (final w in DateWindow.values)
            HealthRecordRow(
              key: Key('search_window_${w.name}'),
              leading: HealthGlyphDisc(
                icon: LucideIcons.calendarDays,
                tint: w == _window
                    ? PawTone.of(context).accent
                    : HealthTone.info,
                size: 36,
              ),
              title: w.label,
              subtitle: w == _window ? 'Current' : null,
              chevron: false,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _window = w);
              },
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final pets = ref.watch(petsListProvider).value ?? <Pet>[widget.pet];
    final (all, loading, error) = _collect(pets);

    final scoped = [
      for (final m in all)
        if (_window.contains(m.takenOn) && (!_heartedOnly || _isFavourite(m)))
          m,
    ];
    final results = searchMemories(scoped, _query, order: _order);
    final buckets = groupMemoriesByRecency(results);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.pawPrint,
          title: 'Search Memories',
          subtitle: 'Find the moments that ',
          subtitleTrail: 'matter',
          actionsWidth: 108,
          actions: [
            HealthActionPill(
              key: const Key('search_history'),
              label: 'History',
              icon: LucideIcons.history,
              onTap: _openHistory,
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        onRefresh: () async {
          for (final pet in pets) {
            if (pet.id != null) ref.invalidate(memoriesListProvider(pet.id!));
          }
          await _load();
        },
        children: [
          gap(4),
          Row(children: [
            Expanded(
              child: HealthSearchField(
                fieldKey: const Key('search_field'),
                controller: _controller,
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: _remember,
                hint: 'Search memories…',
                autofocus: false,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'More filters',
              child: Semantics(
                button: true,
                label: 'More filters',
                child: InkWell(
                  key: const Key('search_filters'),
                  onTap: _openFilters,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: t.accent.withValues(alpha: 0.10),
                      border:
                          Border.all(color: t.accent.withValues(alpha: 0.65)),
                    ),
                    child: Icon(LucideIcons.slidersHorizontal,
                        size: 19, color: t.accent),
                  ),
                ),
              ),
            ),
          ]),
          gap(11),
          HealthBleed(
            child: Padding(
              padding: kRecordPadding,
              child: PetPickRail(
                keyPrefix: 'search_pet',
                pets: pets,
                selectedId: _petId,
                allPets: true,
                onSelect: (id) => setState(() => _petId = id),
              ),
            ),
          ),
          gap(11),
          Row(children: [
            Expanded(
              child: HealthDropPill(
                fieldKey: const Key('search_type_pill'),
                icon: LucideIcons.image,
                label: _type.label,
                active: _type != MemoryType.all,
                onTap: _openFilters,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HealthDropPill(
                fieldKey: const Key('search_dates_pill'),
                icon: LucideIcons.calendarDays,
                label: _window.label,
                active: _window != DateWindow.all,
                onTap: _openDates,
              ),
            ),
          ]),
          gap(8),
          Row(children: [
            Expanded(
              child: HealthDropPill(
                fieldKey: const Key('search_hearted_pill'),
                icon: LucideIcons.heart,
                label: _heartedOnly ? 'Hearted only' : 'All memories',
                active: _heartedOnly,
                onTap: () => setState(() => _heartedOnly = !_heartedOnly),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HealthDropPill(
                fieldKey: const Key('search_more_pill'),
                icon: LucideIcons.filter,
                label: 'More Filters',
                onTap: _openFilters,
              ),
            ),
          ]),
          gap(11),
          if (_recent.isNotEmpty && _query.trim().isEmpty) ...[
            _RecentCard(
              queries: _recent,
              onRun: _run,
              onClearAll: () async {
                await RecentSearches.clear();
                if (mounted) setState(() => _recent = const []);
              },
            ),
            gap(11),
          ],
          _QuickSearchCard(book: all, onRun: _run),
          gap(11),
          _ResultsHead(
            count: results.length,
            order: _order,
            onOrder: _openFilters,
          ),
          gap(9),
          ...switch ((error, loading, all.isEmpty, results.isEmpty)) {
            (final Object e, _, _, _) => [
                _SearchNotice(
                  icon: LucideIcons.cloudOff,
                  title: 'Could not load memories',
                  body: friendlyLoadError(e, noun: 'memories'),
                ),
              ],
            (_, true, true, _) => [
                const Center(child: CircularProgressIndicator()),
              ],
            (_, _, true, _) => [
                const _SearchNotice(
                  key: Key('search_empty_book'),
                  icon: LucideIcons.bookOpen,
                  title: 'The book is empty',
                  body: 'Add a memory and it will be searchable the moment it '
                      'is saved.',
                ),
              ],
            (_, _, _, true) => [
                _SearchNotice(
                  key: const Key('search_no_results'),
                  icon: LucideIcons.searchX,
                  title: 'Nothing matched',
                  body: _query.trim().isEmpty
                      ? 'No memories fall inside these filters. Widen the '
                          'dates, or turn hearted-only off.'
                      : 'Search reads titles and notes. Try a shorter word, '
                          'or clear the filters above.',
                ),
              ],
            _ => [
                for (final bucket in buckets) ...[
                  _BucketCard(
                    bucket: bucket,
                    isFavourite: _isFavourite,
                    onOpen: _open,
                  ),
                  gap(11),
                ],
              ],
          },
          gap(8),
        ],
      ),
    );
  }
}

/// The date windows the "All Dates" pill offers.
enum DateWindow {
  all('All Dates', null),
  week('Past week', 7),
  month('Past month', 30),
  year('Past year', 365);

  const DateWindow(this.label, this.days);

  final String label;
  final int? days;

  bool contains(DateTime day, {DateTime? now}) {
    if (days == null) return true;
    final ref = now ?? DateTime.now();
    return !day.isBefore(ref.subtract(Duration(days: days!)));
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.queries,
    required this.onRun,
    required this.onClearAll,
  });

  final List<String> queries;
  final ValueChanged<String> onRun;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('search_recent_card'),
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            title: 'Recent Searches',
            leading: const Icon(LucideIcons.history,
                size: 15, color: HealthTone.muted),
            actionLabel: 'Clear',
            chevron: false,
            onAction: onClearAll,
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in queries)
                _Chip(
                  chipKey: Key('search_recent_chip_$q'),
                  icon: LucideIcons.cornerDownLeft,
                  label: q,
                  onTap: () => onRun(q),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Kept on this phone. Nothing is sent anywhere.',
              style: TextStyle(
                  color: HealthTone.faint, fontSize: 10.5, height: 1.3)),
        ],
      ),
    );
  }
}

/// The reference's "Quick Searches" strip — real saved queries, and the count
/// each one actually finds in the loaded book.
class _QuickSearchCard extends StatelessWidget {
  const _QuickSearchCard({required this.book, required this.onRun});

  final List<Memory> book;
  final ValueChanged<String> onRun;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('search_quick_card'),
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            title: 'Quick Searches',
            leading: Icon(LucideIcons.zap, size: 15, color: t.accent),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 52,
            child: ListView.separated(
              key: const Key('search_quick_rail'),
              scrollDirection: Axis.horizontal,
              itemCount: kQuickSearches.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final quick = kQuickSearches[i];
                final count = quick.countIn(book);
                return _QuickChip(
                  chipKey: Key('search_quick_${quick.label}'),
                  quick: quick,
                  count: count,
                  onTap: () => onRun(quick.query),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.chipKey,
    required this.quick,
    required this.count,
    required this.onTap,
  });

  final Key chipKey;
  final QuickSearch quick;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final empty = count == 0;
    return Material(
      color: HealthTone.raised,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        key: chipKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(quick.icon,
                size: 16, color: empty ? HealthTone.faint : t.accent),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(quick.label,
                    style: TextStyle(
                        color: empty ? HealthTone.muted : Colors.white,
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(
                    count == 1
                        ? '1 memory'
                        : (empty ? 'none yet' : '$count memories'),
                    style: const TextStyle(
                        color: HealthTone.faint, fontSize: 10.5, height: 1.2)),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _ResultsHead extends StatelessWidget {
  const _ResultsHead({
    required this.count,
    required this.order,
    required this.onOrder,
  });

  final int count;
  final MemorySearchOrder order;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(
      children: [
        Flexible(
          flex: 5,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '$count',
                style: TextStyle(
                    color: t.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
              TextSpan(text: count == 1 ? ' memory found' : ' memories found'),
            ]),
            key: const Key('search_result_count'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 4,
          child: Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              key: const Key('search_order_pill'),
              onTap: onOrder,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.settings2,
                      size: 14, color: HealthTone.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(order.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Icon(LucideIcons.chevronDown,
                      size: 14, color: HealthTone.muted),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One dated group of results — "Today · 3" over its grid.
class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.bucket,
    required this.isFavourite,
    required this.onOpen,
  });

  final MemoryBucket bucket;
  final bool Function(Memory) isFavourite;
  final ValueChanged<Memory> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: Key('search_bucket_${bucket.label}'),
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(bucket.label,
                style: TextStyle(
                    color: t.accent,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('${bucket.memories.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          // Three across, as the reference's own first group is set. Four —
          // which it switches to further down — leaves 82dp for a caption,
          // and an untitled grid cannot be scanned against the search that
          // just read those titles.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: bucket.memories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: 0.70,
            ),
            itemBuilder: (context, i) => _ResultTile(
              memory: bucket.memories[i],
              hearted: isFavourite(bucket.memories[i]),
              onTap: () => onOpen(bucket.memories[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.memory,
    required this.hearted,
    required this.onTap,
  });

  final Memory memory;
  final bool hearted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Semantics(
      button: true,
      label: '${memory.title}, ${shortDate(memory.takenOn)}',
      child: ExcludeSemantics(
        child: InkWell(
          key: Key('search_result_${memory.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: MemoryPhoto(
                        storageKey: memory.storageKey,
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x66000000),
                        ),
                        // Lucide ships one heart; the state is the colour.
                        child: Icon(LucideIcons.heart,
                            size: 13,
                            color: hearted ? t.accent : Colors.white70),
                      ),
                    ),
                    // The reference badges each tile as photo or video. There
                    // is only one kind, and it says which.
                    Positioned(
                      left: 5,
                      bottom: 5,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x66000000),
                        ),
                        child: const Icon(LucideIcons.image,
                            size: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(memory.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              // The reference prints a clock time and a place under every
              // result. `taken_on` is a date column, and there is no place —
              // GPS never leaves the phone.
              Text(shortDate(memory.takenOn),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: HealthTone.faint, fontSize: 10, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.chipKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key chipKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: HealthTone.raised,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          key: chipKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: HealthTone.muted),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class _SearchNotice extends StatelessWidget {
  const _SearchNotice({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => HomeCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
        child: Column(
          children: [
            Icon(icon, size: 26, color: HealthTone.muted),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: HealthTone.dim, fontSize: 11.5, height: 1.4)),
          ],
        ),
      );
}
