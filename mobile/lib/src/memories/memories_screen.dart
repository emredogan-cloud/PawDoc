import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../account/user_profile.dart';
import '../core/dates.dart';
import '../core/friendly_error.dart';
import '../core/living_pet_avatar.dart';
import '../core/local_tick_log.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../monetization/paywall_screen.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'memories_repository.dart';
import 'memory.dart';
import 'memory_editor_sheet.dart';
import 'memory_photo.dart';
import 'memory_viewer_screen.dart';

/// The pet journal, rebuilt against mockup `memories_gallery`.
///
/// Pet switcher rail, search with type and order controls, the Highlights row,
/// and the month sections — over the app's bottom navigation. Human content
/// only: no AI, no safety logic, no claim about an animal anywhere on it.
///
/// ## What the mockup draws that the journal does not hold
///
/// * **Videos.** Every other tile carries a play badge and a duration. A
///   memory is a still photo (`memory_photo.dart`, one `storage_key`); there
///   is no video pipeline, no duration and no thumbnail. The type filter keeps
///   its Videos entry and says *Soon* rather than showing a play badge over a
///   photograph.
/// * **A "Highlights" set.** Nothing marks a memory as special — but the
///   mockup already draws the affordance that would: a heart on every tile.
///   So Highlights *is* the favourites, the owner's own picks, and the heart
///   toggles one. Kept on the device, and the row says so, exactly as the
///   medication tracker's dose ticks are.
/// * **The crown on the first highlight.** That one is computable and true:
///   it marks the earliest memory on record.
///
/// ## Layout departure
///
/// The reference sets four tiles across a month grid (87 logical each). A
/// title needs ~90 at readable type, and a gallery of untitled squares cannot
/// be scanned — nor matched against the search that reads those titles. The
/// month grid is three across, which is the narrowest that still carries a
/// caption. Everything else keeps the reference's composition.
class MemoriesScreen extends ConsumerStatefulWidget {
  const MemoriesScreen({super.key, required this.pet});

  final Pet pet;

  /// Which memories the owner has hearted.
  ///
  /// **On the device, and the Highlights row says so.** `pet_memories` has no
  /// favourite column; adding one is a migration plus an RLS review plus a
  /// deploy, all founder-gated. A heart whose answer is silently forgotten
  /// would be worse than no heart.
  static const favPrefix = 'pawdoc.memory.fav.';
  static const favLog = LocalTickLog(favPrefix);

  static String favKey(String memoryId) => '$favPrefix$memoryId';

  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

/// What the type filter offers.
enum MemoryType {
  all('All Types', LucideIcons.layoutGrid),
  photos('Photos', LucideIcons.image),
  videos('Videos', LucideIcons.video);

  const MemoryType(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Videos have no pipeline behind them; the entry is drawn, not offered.
  bool get available => this != MemoryType.videos;
}

/// How the gallery is ordered.
enum MemoryOrder {
  newest('Newest', LucideIcons.arrowDown),
  oldest('Oldest', LucideIcons.arrowUp),
  title('Title (A–Z)', LucideIcons.arrowDownAZ);

  const MemoryOrder(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Ordering. Pure, so it is unit-tested without a widget.
List<Memory> sortMemories(List<Memory> memories, MemoryOrder order) {
  final out = [...memories];
  switch (order) {
    case MemoryOrder.newest:
      out.sort((a, b) => b.takenOn.compareTo(a.takenOn));
    case MemoryOrder.oldest:
      out.sort((a, b) => a.takenOn.compareTo(b.takenOn));
    case MemoryOrder.title:
      out.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
  return out;
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _timeline = false;
  MemoryOrder _order = MemoryOrder.newest;
  MemoryType _type = MemoryType.all;

  /// `null` means every pet — the mockup's "All Pets" tile.
  late String? _petId = widget.pet.id;

  Map<String, DateTime>? _favourites;

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    final favs = await MemoriesScreen.favLog.loadAll();
    if (mounted) setState(() => _favourites = favs);
  }

  Future<void> _toggleFavourite(Memory memory) async {
    if (memory.id == null) return;
    final key = MemoriesScreen.favKey(memory.id!);
    final current = Map<String, DateTime>.from(_favourites ?? const {});
    final wasSet = current.containsKey(key);
    if (wasSet) {
      current.remove(key);
      await LocalTickLog.clear(key);
    } else {
      final now = DateTime.now();
      current[key] = now;
      await LocalTickLog.set(key, now);
    }
    if (!mounted) return;
    setState(() => _favourites = current);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(wasSet
          ? 'Removed from highlights.'
          : 'Added to highlights. Kept on this device.'),
    ));
  }

  bool _isFavourite(Memory m) =>
      m.id != null &&
      (_favourites?.containsKey(MemoriesScreen.favKey(m.id!)) ?? false);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final isPremium = ref.read(userProfileProvider).maybeWhen(
          data: (p) => p.isPremium,
          orElse: () => false,
        );
    final count = ref.read(memoriesCountProvider).maybeWhen(
          data: (c) => c,
          orElse: () => 0,
        );
    if (!canAddMemory(currentCount: count, isPremium: isPremium)) {
      _showLimitSheet();
      return;
    }
    final target = _petFor(_petId) ?? widget.pet;
    final saved = await showMemoryEditorSheet(context, pet: target);
    if (saved == true) _refresh();
  }

  Pet? _petFor(String? id) {
    if (id == null) return null;
    for (final pet in ref.read(petsListProvider).value ?? const <Pet>[]) {
      if (pet.id == id) return pet;
    }
    return null;
  }

  void _refresh() {
    for (final pet in ref.read(petsListProvider).value ?? const <Pet>[]) {
      if (pet.id != null) ref.invalidate(memoriesListProvider(pet.id!));
    }
    ref.invalidate(memoriesListProvider(widget.pet.id!));
    ref.invalidate(memoriesCountProvider);
  }

  void _showLimitSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Your memory book is full',
        children: [
          Text(
            'The free plan holds $kFreeMemoryLimit memories. Premium keeps the '
            'whole story — unlimited memories, across all your pets.',
            style: const TextStyle(
                color: HealthTone.dim, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 4),
          HealthPrimaryCta(
            key: const Key('memories_upgrade_button'),
            icon: LucideIcons.crown,
            label: 'See Premium',
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _open(Memory memory) async {
    final pet = _petFor(memory.petId) ?? widget.pet;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MemoryViewerScreen(memory: memory, pet: pet),
      ),
    );
    if (changed == true) _refresh();
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Filter and sort',
        scrollable: true,
        children: [
          const HealthGroupLabel(label: 'Type'),
          for (final t in MemoryType.values)
            HealthRecordRow(
              key: Key('memory_type_${t.name}'),
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
          const HealthGroupLabel(label: 'Order'),
          for (final o in MemoryOrder.values)
            HealthRecordRow(
              key: Key('memory_order_${o.name}'),
              leading: HealthGlyphDisc(
                icon: o.icon,
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
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petsListProvider).value ?? <Pet>[widget.pet];
    final (all, loading, error) = _collect(pets);
    final visible = sortMemories(filterMemories(all, _query), _order);
    final favourites =
        sortMemories(all.where(_isFavourite).toList(), MemoryOrder.oldest);
    final earliest = all.isEmpty
        ? null
        : sortMemories(all, MemoryOrder.oldest).first.id;

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.image,
          title: 'Memories Gallery',
          subtitle: 'All the beautiful moments with ',
          subtitleTrail: 'your pets',
          actions: [
            HealthCircleButton(
              key: const Key('memories_new_button'),
              icon: LucideIcons.cloudUpload,
              tooltip: 'New memory',
              color: PawTone.of(context).accent,
              onTap: _add,
            ),
            HealthCircleButton(
              key: const Key('memories_filters'),
              icon: LucideIcons.slidersHorizontal,
              tooltip: 'Filter and sort',
              onTap: _openFilters,
            ),
          ],
        ),
        onRefresh: () async {
          _refresh();
          await _loadFavourites();
        },
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(2),
          HealthBleed(
            child: _PetRail(
              pets: pets,
              selectedId: _petId,
              onSelect: (id) => setState(() => _petId = id),
            ),
          ),
          gap(11),
          _Toolbar(
            controller: _searchController,
            onQuery: (v) => setState(() => _query = v),
            typeLabel: _type.label,
            orderLabel: _order.label,
            onFilters: _openFilters,
            timeline: _timeline,
            onToggle: () => setState(() => _timeline = !_timeline),
          ),
          const _AllowanceStrip(),
          gap(9),
          ...switch ((error, loading, all.isEmpty)) {
            (final Object e, _, _) => [
                _Notice(
                  icon: LucideIcons.cloudOff,
                  title: 'Could not load memories',
                  body: friendlyLoadError(e, noun: 'memories'),
                ),
              ],
            (_, true, true) => [
                const Center(child: CircularProgressIndicator()),
              ],
            (_, _, true) => [
                _EmptyMemories(
                  petName: _petId == null
                      ? 'your pets'
                      : (_petFor(_petId)?.name ?? widget.pet.name),
                  onAdd: _add,
                ),
              ],
            _ when visible.isEmpty => [
                const _EmptyLine(
                  key: Key('memories_no_match'),
                  icon: LucideIcons.search,
                  text: 'No memories match your search.',
                ),
              ],
            _ => [
                if (favourites.isNotEmpty) ...[
                  _HighlightsCard(
                    memories: favourites,
                    earliestId: earliest,
                    onOpen: _open,
                    onFavourite: _toggleFavourite,
                  ),
                  gap(11),
                ],
                if (_timeline)
                  _Timeline(
                    memories: visible,
                    isFavourite: _isFavourite,
                    onOpen: _open,
                    onFavourite: _toggleFavourite,
                  )
                else
                  _MonthSections(
                    memories: visible,
                    isFavourite: _isFavourite,
                    onOpen: _open,
                    onFavourite: _toggleFavourite,
                  ),
              ],
          },
          gap(8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pet rail
// ---------------------------------------------------------------------------

class _PetRail extends StatelessWidget {
  const _PetRail({
    required this.pets,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Pet> pets;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      height: 62,
      child: ListView(
        key: const Key('memories_pet_rail'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kRecordGutter),
        children: [
          for (final pet in pets) ...[
            _PetChip(
              fieldKey: Key('memories_pet_${pet.id}'),
              selected: pet.id == selectedId,
              label: petDisplayName(pet.name),
              detail: speciesName(pet.species),
              onTap: () => onSelect(pet.id),
              leading: ClipOval(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: PetPortrait(
                    pet: pet,
                    size: 38,
                    livingAvatar: pet.photoKey == null
                        ? null
                        : LivingPetAvatar(
                            species: pet.species,
                            size: 38,
                            seed: pet.id,
                            photoKey: pet.photoKey,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _PetChip(
            fieldKey: const Key('memories_pet_all'),
            selected: selectedId == null,
            label: 'All Pets',
            detail: '${pets.length} in the book',
            dashed: true,
            onTap: () => onSelect(null),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.accent.withValues(alpha: 0.10),
              ),
              child: Icon(LucideIcons.pawPrint, size: 18, color: t.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetChip extends StatelessWidget {
  const _PetChip({
    required this.fieldKey,
    required this.selected,
    required this.label,
    required this.detail,
    required this.leading,
    required this.onTap,
    this.dashed = false,
  });

  final Key fieldKey;
  final bool selected;
  final String label;
  final String detail;
  final Widget leading;
  final VoidCallback onTap;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return InkWell(
      key: fieldKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? t.accent.withValues(alpha: 0.10) : HealthTone.card,
          border: Border.all(
            color: selected
                ? t.accent
                : Colors.white.withValues(alpha: dashed ? 0.16 : 0.08),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          leading,
          const SizedBox(width: 9),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: selected ? t.accent : Colors.white,
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w700)),
              Text(detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: HealthTone.muted, fontSize: 10.5, height: 1.25)),
            ],
          ),
          if (selected) ...[
            const SizedBox(width: 7),
            Icon(LucideIcons.circleCheck, size: 15, color: t.accent),
          ],
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toolbar
// ---------------------------------------------------------------------------

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.onQuery,
    required this.typeLabel,
    required this.orderLabel,
    required this.onFilters,
    required this.timeline,
    required this.onToggle,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQuery;
  final String typeLabel;
  final String orderLabel;
  final VoidCallback onFilters;
  final bool timeline;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Column(
      children: [
        HealthSearchField(
          fieldKey: const Key('memories_search_field'),
          controller: controller,
          onChanged: onQuery,
          hint: 'Search memories…',
          autofocus: false,
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _DropButton(
              fieldKey: const Key('memories_type_button'),
              label: typeLabel,
              onTap: onFilters,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DropButton(
              fieldKey: const Key('memories_order_button'),
              label: orderLabel,
              onTap: onFilters,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: timeline ? 'Gallery view' : 'Timeline view',
            child: Semantics(
              button: true,
              label: timeline ? 'Gallery view' : 'Timeline view',
              child: InkWell(
                key: const Key('memories_view_toggle'),
                onTap: onToggle,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: t.accent.withValues(alpha: 0.14),
                    border: Border.all(color: t.accent.withValues(alpha: 0.65)),
                  ),
                  child: Icon(
                      timeline ? LucideIcons.layoutGrid : LucideIcons.list,
                      size: 18,
                      color: t.accent),
                ),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

class _DropButton extends StatelessWidget {
  const _DropButton({
    required this.fieldKey,
    required this.label,
    required this.onTap,
  });

  final Key fieldKey;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HealthTone.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: fieldKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
            const Icon(LucideIcons.chevronDown,
                size: 15, color: Colors.white54),
          ]),
        ),
      ),
    );
  }
}

/// Free-plan allowance line (hidden for premium). Quiet by design — a caption,
/// not a meter dominating a joyful surface.
class _AllowanceStrip extends ConsumerWidget {
  const _AllowanceStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final count = ref.watch(memoriesCountProvider);
    final isPremium =
        profile.maybeWhen(data: (p) => p.isPremium, orElse: () => true);
    if (isPremium) return const SizedBox.shrink();
    final used = count.maybeWhen(data: (c) => c, orElse: () => null);
    if (used == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 3),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$used of $kFreeMemoryLimit free memories used',
          key: const Key('memories_allowance'),
          style: const TextStyle(color: HealthTone.muted, fontSize: 11),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Highlights
// ---------------------------------------------------------------------------

/// The mockup's Highlights row. Nothing marks a memory as special, but the
/// mockup already draws the affordance that would — a heart on every tile — so
/// Highlights *is* the owner's hearted set.
class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({
    required this.memories,
    required this.earliestId,
    required this.onOpen,
    required this.onFavourite,
  });

  final List<Memory> memories;
  final String? earliestId;
  final ValueChanged<Memory> onOpen;
  final ValueChanged<Memory> onFavourite;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 0, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 11),
            child: HealthSectionHead(
              leading: Icon(LucideIcons.star, size: 17, color: t.accent),
              title: 'Highlights',
              actionLabel: '${memories.length} hearted',
              chevron: false,
            ),
          ),
          const SizedBox(height: 3),
          const Padding(
            padding: EdgeInsets.only(right: 11),
            child: Text('The ones you hearted. Kept on this device.',
                style: TextStyle(
                    color: HealthTone.dim, fontSize: 11, height: 1.3)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 148,
            child: ListView.separated(
              key: const Key('memories_highlights'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 11),
              itemCount: memories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => SizedBox(
                width: 118,
                child: _MemoryTile(
                  memory: memories[i],
                  favourite: true,
                  crown: memories[i].id == earliestId,
                  caption: true,
                  onTap: () => onOpen(memories[i]),
                  onFavourite: () => onFavourite(memories[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month sections
// ---------------------------------------------------------------------------

class _MonthSections extends StatelessWidget {
  const _MonthSections({
    required this.memories,
    required this.isFavourite,
    required this.onOpen,
    required this.onFavourite,
  });

  final List<Memory> memories;
  final bool Function(Memory) isFavourite;
  final ValueChanged<Memory> onOpen;
  final ValueChanged<Memory> onFavourite;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final groups = groupMemoriesByMonth(memories);
    return Column(
      key: const Key('memories_grid'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          HomeCard(
            radius: 16,
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HealthSectionHead(
                  leading: Icon(LucideIcons.calendarDays,
                      size: 17, color: t.accent),
                  title: memoryMonthLabel(group.month),
                  actionLabel: '${group.memories.length} '
                      '${group.memories.length == 1 ? 'item' : 'items'}',
                  chevron: false,
                ),
                const SizedBox(height: 10),
                // Three across, not the reference's four: a title needs ~90dp
                // at readable type, and a gallery of untitled squares cannot be
                // scanned — nor matched against the search that reads those
                // titles.
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                  childAspectRatio: 0.86,
                  children: [
                    for (final memory in group.memories)
                      _MemoryTile(
                        memory: memory,
                        favourite: isFavourite(memory),
                        crown: false,
                        caption: true,
                        onTap: () => onOpen(memory),
                        onFavourite: () => onFavourite(memory),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({
    required this.memory,
    required this.favourite,
    required this.crown,
    required this.caption,
    required this.onTap,
    required this.onFavourite,
  });

  final Memory memory;
  final bool favourite;
  final bool crown;
  final bool caption;
  final VoidCallback onTap;
  final VoidCallback onFavourite;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return InkWell(
      key: Key('memory_tile_${memory.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'memory_${memory.id}',
              child: MemoryPhoto(storageKey: memory.storageKey),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),
            if (crown)
              Positioned(
                left: 6,
                top: 6,
                child: Tooltip(
                  message: 'The first memory on record',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                    child:
                        Icon(LucideIcons.crown, size: 13, color: t.accent),
                  ),
                ),
              ),
            Positioned(
              right: 2,
              top: 2,
              child: Semantics(
                button: true,
                label: favourite ? 'Remove from highlights' : 'Add to highlights',
                child: ExcludeSemantics(
                  child: InkWell(
                    key: Key('memory_fav_${memory.id}'),
                    onTap: onFavourite,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        favourite ? LucideIcons.heart : LucideIcons.heart,
                        size: 15,
                        color: favourite ? t.accent : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (caption)
              Positioned(
                left: 7,
                right: 7,
                bottom: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(memory.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w700)),
                    Text(shortDate(memory.takenOn),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            height: 1.25)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline (list) view
// ---------------------------------------------------------------------------

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.memories,
    required this.isFavourite,
    required this.onOpen,
    required this.onFavourite,
  });

  final List<Memory> memories;
  final bool Function(Memory) isFavourite;
  final ValueChanged<Memory> onOpen;
  final ValueChanged<Memory> onFavourite;

  @override
  Widget build(BuildContext context) {
    final groups = groupMemoriesByMonth(memories);
    return Column(
      key: const Key('memories_timeline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          HealthGroupLabel(label: memoryMonthLabel(group.month), accent: true),
          for (final memory in group.memories)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: HealthRecordRow(
                key: Key('memory_row_${memory.id}'),
                background: HealthTone.card,
                padding: const EdgeInsets.all(9),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: MemoryPhoto(storageKey: memory.storageKey),
                  ),
                ),
                title: memory.title,
                subtitle: (memory.note ?? '').isEmpty
                    ? shortDate(memory.takenOn)
                    : memory.note,
                footer: (memory.note ?? '').isEmpty
                    ? null
                    : Text(shortDate(memory.takenOn),
                        style: const TextStyle(
                            color: HealthTone.faint, fontSize: 10.5)),
                trailing: InkWell(
                  key: Key('memory_row_fav_${memory.id}'),
                  onTap: () => onFavourite(memory),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(LucideIcons.heart,
                        size: 16,
                        color: isFavourite(memory)
                            ? PawTone.of(context).accent
                            : Colors.white38),
                  ),
                ),
                onTap: () => onOpen(memory),
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty + notices
// ---------------------------------------------------------------------------

class _EmptyMemories extends StatelessWidget {
  const _EmptyMemories({required this.petName, required this.onAdd});

  final String petName;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('memories_empty'),
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.12),
            ),
            child: Icon(LucideIcons.sparkles, size: 34, color: t.accent),
          ),
          const SizedBox(height: 14),
          Text('Start ${petDisplayPossessive(petName)} story',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Keep the little moments — first walks, silly naps, birthday '
            'treats. Your memories stay private to you.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: HealthTone.dim, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          HealthPrimaryCta(
            icon: LucideIcons.camera,
            label: 'Add the first memory',
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
      decoration: BoxDecoration(
        color: HealthTone.raised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: HealthTone.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: HealthTone.dim, fontSize: 11.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 26, color: HealthTone.muted),
          const SizedBox(height: 11),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: HealthTone.dim, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }
}
