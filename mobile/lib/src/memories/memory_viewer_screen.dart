import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../core/dates.dart';
import '../core/living_pet_avatar.dart';
import '../core/local_tick_log.dart';
import '../core/paw_nav_bar.dart';
import '../core/pet_display.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../pets/pet.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'memories_repository.dart';
import 'memories_screen.dart';
import 'memory.dart';
import 'memory_editor_sheet.dart';
import 'memory_photo.dart';

/// One memory, rebuilt against mockup `memory_detail`.
///
/// Media viewer with the position counter and the favourite heart, the pet
/// strip, the note, the provenance card, the privacy card, the action row, the
/// memory facts and "More from this day" — over the app's bottom navigation.
///
/// ## What the mockup asks for, and what ships
///
/// | Mockup | Shipped | Why |
/// |---|---|---|
/// | **"AI Highlight · A moment full of joy and energy! Captured Buddy's playful spirit perfectly."** | **gone** — the slot holds how old the pet was that day | the journal is human content only, by design. This card is a model reading an animal's emotional state off a photograph, on the one surface in the app that has never carried AI output. It is also a claim about a pet that nothing supports |
/// | "Location · Kent Park, Eskişehir" with a map | the privacy card: PawDoc **strips GPS from every photo before upload** | there is no location, and there must never be one. The block becomes the true statement instead of a false one |
/// | a video scrubber, "0:04 / 0:18", Duration, Size, Resolution | Type, taken-on, added-on and where it is stored | a memory is one still photo. There is no video, and neither byte size nor pixel dimensions are recorded |
/// | tags "Playtime · Park · Happy" | one *Soon* chip, in the chips' place | no column for a tag |
/// | "Add to Album" | *Soon* | there are no albums |
/// | "1 / 8" and the arrows | **real** — the position among this pet's memories, and the arrows move between them |
/// | "More from this day" | **real** — the other memories sharing this date |
///
/// Pops `true` when the memory changed so the gallery refreshes.
class MemoryViewerScreen extends ConsumerStatefulWidget {
  const MemoryViewerScreen({
    super.key,
    required this.memory,
    required this.pet,
  });

  final Memory memory;
  final Pet pet;

  @override
  ConsumerState<MemoryViewerScreen> createState() => _MemoryViewerScreenState();
}

class _MemoryViewerScreenState extends ConsumerState<MemoryViewerScreen> {
  late Memory _memory = widget.memory;
  bool _changed = false;
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

  bool get _isFavourite =>
      _memory.id != null &&
      (_favourites?.containsKey(MemoriesScreen.favKey(_memory.id!)) ?? false);

  Future<void> _toggleFavourite() async {
    if (_memory.id == null) return;
    final key = MemoriesScreen.favKey(_memory.id!);
    final current = Map<String, DateTime>.from(_favourites ?? const {});
    final wasSet = current.containsKey(key);
    if (wasSet) {
      current.remove(key);
      await LocalTickLog.clear(key);
    } else {
      current[key] = DateTime.now();
      await LocalTickLog.set(key, current[key]!);
    }
    if (!mounted) return;
    setState(() => _favourites = current);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(wasSet
          ? 'Removed from highlights.'
          : 'Added to highlights. Kept on this device.'),
    ));
  }

  List<Memory> get _siblings {
    final all = ref.watch(memoriesListProvider(widget.pet.id!)).value ??
        <Memory>[_memory];
    return sortMemories(all, MemoryOrder.newest);
  }

  Future<void> _edit() async {
    final saved = await showMemoryEditorSheet(
      context,
      pet: widget.pet,
      existing: _memory,
    );
    if (saved == true && mounted) {
      _changed = true;
      // Re-read the fresh row so the viewer reflects the edit immediately.
      final list =
          await ref.read(memoriesRepositoryProvider).listForPet(widget.pet.id!);
      final updated = list.where((m) => m.id == _memory.id).toList();
      if (mounted && updated.isNotEmpty) setState(() => _memory = updated.first);
      ref.invalidate(memoriesListProvider(widget.pet.id!));
    }
  }

  Future<void> _share() async {
    final text = '${_memory.title} — a memory with ${widget.pet.name} 🐾';
    try {
      // Share the already-downloaded bytes when they are in the image cache
      // (keyed by storage key); fall back to text-only.
      final cached =
          await DefaultCacheManager().getFileFromCache(_memory.storageKey);
      if (cached != null) {
        await SharePlus.instance.share(ShareParams(
          text: text,
          files: [XFile(cached.file.path, mimeType: 'image/jpeg')],
        ));
        return;
      }
    } catch (_) {
      // Fall through to text-only.
    }
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this memory?'),
        content: const Text(
            'The photo and note will be removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('memory_delete_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete',
                style:
                    TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(memoriesRepositoryProvider).delete(_memory);
      if (_memory.id != null) {
        await LocalTickLog.clear(MemoriesScreen.favKey(_memory.id!));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not delete the memory. Please try again.')));
      }
    }
  }

  void _step(int delta) {
    final list = _siblings;
    final index = list.indexWhere((m) => m.id == _memory.id);
    if (index < 0) return;
    final next = index + delta;
    if (next < 0 || next >= list.length) return;
    setState(() => _memory = list[next]);
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  void _openFullscreen() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _FullscreenPhoto(memory: _memory),
    ));
  }

  void _openMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: _memory.title,
        children: [
          HealthRecordRow(
            key: const Key('memory_more_edit'),
            leading: HealthGlyphDisc(
                icon: LucideIcons.pencil,
                tint: PawTone.of(context).accent,
                size: 36),
            title: 'Edit memory',
            subtitle: 'Title, note, date or photo',
            onTap: () {
              Navigator.pop(sheetContext);
              _edit();
            },
          ),
          HealthRecordRow(
            key: const Key('memory_more_fullscreen'),
            leading: const HealthGlyphDisc(
                icon: LucideIcons.expand, tint: HealthTone.info, size: 36),
            title: 'View full screen',
            subtitle: 'Pinch to zoom',
            onTap: () {
              Navigator.pop(sheetContext);
              _openFullscreen();
            },
          ),
          HealthRecordRow(
            key: const Key('memory_more_delete'),
            leading: const HealthGlyphDisc(
                icon: LucideIcons.trash2, tint: HealthTone.gold, size: 36),
            title: 'Delete memory',
            subtitle: 'The photo and note go with it',
            onTap: () {
              Navigator.pop(sheetContext);
              _delete();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final siblings = _siblings;
    final index = siblings.indexWhere((m) => m.id == _memory.id);
    final sameDay = siblings
        .where((m) =>
            m.id != _memory.id &&
            m.takenOn.year == _memory.takenOn.year &&
            m.takenOn.month == _memory.takenOn.month &&
            m.takenOn.day == _memory.takenOn.day)
        .toList(growable: false);
    final age = petAgeLabelOn(widget.pet.birthDate, _memory.takenOn);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: PawBackground(
        variant: PawSurface.dark,
        child: HealthRecordScaffold(
          appBar: PetModuleAppBar(
            icon: LucideIcons.pawPrint,
            title: 'Memory Detail',
            subtitle: 'Cherish every moment',
            onBack: () => Navigator.of(context).pop(_changed),
            actions: [
              HealthCircleButton(
                key: const Key('memory_share_button'),
                icon: LucideIcons.share2,
                tooltip: 'Share',
                color: PawTone.of(context).accent,
                onTap: _share,
              ),
              HealthCircleButton(
                key: const Key('memory_more_button'),
                icon: LucideIcons.ellipsis,
                tooltip: 'More',
                onTap: _openMore,
              ),
            ],
          ),
          bottomNav: const PawNavBar(detached: true),
          children: [
            gap(2),
            _Viewer(
              memory: _memory,
              position: index < 0 ? 1 : index + 1,
              total: siblings.length,
              favourite: _isFavourite,
              canPrev: index > 0,
              canNext: index >= 0 && index < siblings.length - 1,
              onPrev: () => _step(-1),
              onNext: () => _step(1),
              onFavourite: _toggleFavourite,
              onFullscreen: _openFullscreen,
            ),
            gap(9),
            _PetStrip(pet: widget.pet, memory: _memory),
            gap(9),
            _StoryCard(
              memory: _memory,
              petName: widget.pet.name,
              ageOnTheDay: age,
              onEdit: _edit,
              onTags: () => _soon('Tagging a memory'),
            ),
            gap(9),
            const _PrivacyCard(),
            gap(9),
            _ActionRow(
              onEdit: _edit,
              onAlbum: () => _soon('Albums'),
              onDownload: _share,
              onShare: _share,
              onDelete: _delete,
            ),
            gap(9),
            _FactsCard(memory: _memory),
            if (sameDay.isNotEmpty) ...[
              gap(9),
              _MoreFromThisDay(
                memories: sameDay,
                onOpen: (m) => setState(() => _memory = m),
              ),
            ],
            gap(8),
          ],
        ),
      ),
    );
  }
}

/// `2y 4m`, as the pet was on a given day. Null when the birthday is unknown.
String? petAgeLabelOn(DateTime? birth, DateTime on) {
  if (birth == null) return null;
  var months = (on.year - birth.year) * 12 + on.month - birth.month;
  if (on.day < birth.day) months -= 1;
  if (months < 0) return null;
  return months < 12 ? '${months}m' : '${months ~/ 12}y ${months % 12}m';
}

// ---------------------------------------------------------------------------
// Viewer
// ---------------------------------------------------------------------------

class _Viewer extends StatelessWidget {
  const _Viewer({
    required this.memory,
    required this.position,
    required this.total,
    required this.favourite,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.onFavourite,
    required this.onFullscreen,
  });

  final Memory memory;
  final int position;
  final int total;
  final bool favourite;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onFavourite;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'memory_${memory.id}',
              child: MemoryPhoto(storageKey: memory.storageKey),
            ),
            Positioned(
              left: 9,
              top: 9,
              child: _Glass(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.image, size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                  Text('$position / $total',
                      key: const Key('memory_position'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            Positioned(
              right: 9,
              top: 9,
              child: Semantics(
                button: true,
                label: favourite ? 'Remove from highlights' : 'Add to highlights',
                child: ExcludeSemantics(
                  child: InkWell(
                    key: const Key('memory_favourite'),
                    onTap: onFavourite,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: favourite
                                ? t.accent
                                : Colors.white.withValues(alpha: 0.45)),
                      ),
                      child: Icon(LucideIcons.heart,
                          size: 17,
                          color: favourite ? t.accent : Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            if (canPrev)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: _RoundArrow(
                    fieldKey: const Key('memory_prev'),
                    icon: LucideIcons.chevronLeft,
                    tooltip: 'Previous memory',
                    onTap: onPrev,
                  ),
                ),
              ),
            if (canNext)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: _RoundArrow(
                    fieldKey: const Key('memory_next'),
                    icon: LucideIcons.chevronRight,
                    tooltip: 'Next memory',
                    onTap: onNext,
                  ),
                ),
              ),
            // The reference puts a video scrubber along this edge. A memory is
            // one still photo, so the bar carries what there is: the date, and
            // the way into the full-screen zoom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(11, 22, 9, 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.70),
                    ],
                  ),
                ),
                child: Row(children: [
                  Expanded(
                    child: Text(shortDate(memory.takenOn),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  _RoundArrow(
                    fieldKey: const Key('memory_fullscreen'),
                    icon: LucideIcons.expand,
                    tooltip: 'Full screen',
                    onTap: onFullscreen,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: Colors.black.withValues(alpha: 0.50),
        ),
        child: child,
      );
}

class _RoundArrow extends StatelessWidget {
  const _RoundArrow({
    required this.fieldKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Key fieldKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: ExcludeSemantics(
          child: InkWell(
            key: fieldKey,
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.50),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenPhoto extends StatelessWidget {
  const _FullscreenPhoto({required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: InteractiveViewer(
        maxScale: 4,
        child: Center(
          child: MemoryPhoto(
              storageKey: memory.storageKey, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pet strip
// ---------------------------------------------------------------------------

class _PetStrip extends StatelessWidget {
  const _PetStrip({required this.pet, required this.memory});

  final Pet pet;
  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(10, 10, 11, 10),
      child: Row(children: [
        HealthRingPortrait(
          size: 40,
          portrait: PetPortrait(
            pet: pet,
            size: 40,
            livingAvatar: pet.photoKey == null
                ? null
                : LivingPetAvatar(
                    species: pet.species,
                    size: 40,
                    seed: pet.id,
                    photoKey: pet.photoKey,
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(petDisplayName(pet.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w700)),
              Text(
                pet.breed?.trim().isNotEmpty == true
                    ? pet.breed!.trim()
                    : speciesName(pet.species),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: HealthTone.muted, fontSize: 11.5, height: 1.25),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 4,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.calendarDays, size: 15, color: t.accent),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(shortDate(memory.takenOn),
                    maxLines: 1,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// The story
// ---------------------------------------------------------------------------

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.memory,
    required this.petName,
    required this.ageOnTheDay,
    required this.onEdit,
    required this.onTags,
  });

  final Memory memory;
  final String petName;
  final String? ageOnTheDay;
  final VoidCallback onEdit;
  final VoidCallback onTags;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final note = memory.note?.trim();
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(memory.title,
                    key: const Key('memory_viewer_title'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        height: 1.2,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              HealthCircleButton(
                key: const Key('memory_edit_button'),
                icon: LucideIcons.pencil,
                tooltip: 'Edit',
                size: 30,
                color: t.accent,
                onTap: onEdit,
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note,
                style: const TextStyle(
                    color: HealthTone.dim, fontSize: 12.5, height: 1.45)),
          ] else ...[
            const SizedBox(height: 4),
            const Text('No note on this one yet.',
                style: TextStyle(
                    color: HealthTone.faint, fontSize: 12, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            // The mockup tags the moment "Playtime · Park · Happy". No column
            // for a tag, so the row keeps its place as an invitation.
            child: HealthActionPill(
              key: const Key('memory_tags'),
              label: 'Add tags · Soon',
              icon: LucideIcons.tag,
              color: HealthTone.muted,
              onTap: onTags,
            ),
          ),
          const SizedBox(height: 11),
          // Where the reference puts its "AI Highlight". The journal is human
          // content only, and a model reading an animal's mood off a photo is
          // both a claim the product cannot make and AI on the one surface
          // that has never carried any. What goes here instead is a fact:
          // how old they were that day.
          Container(
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: t.accent.withValues(alpha: 0.06),
              border: Border.all(color: t.accent.withValues(alpha: 0.22)),
            ),
            child: Row(children: [
              Icon(LucideIcons.pawPrint, size: 19, color: t.accent),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('On this day',
                        key: const Key('memory_on_this_day'),
                        style: TextStyle(
                            color: t.accent,
                            fontSize: 12.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      ageOnTheDay == null
                          ? 'Add ${petDisplayPossessive(petName)} birthday and '
                              'this will say how old they were.'
                          : '${petDisplayName(petName)} was $ageOnTheDay old.',
                      style: const TextStyle(
                          color: HealthTone.dim, fontSize: 11.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.heart,
                  size: 22, color: t.accent.withValues(alpha: 0.30)),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Where the reference puts a location and a map.
///
/// PawDoc strips EXIF and GPS from every photo **on the device, before
/// upload** — a standing rule, not a setting. There is no location to show and
/// there must never be one, so the block states the rule rather than a place.
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    // An education card, not a privacy card with a chevron: this is a
    // statement, and a chevron that opens nothing is a dead end.
    return const HealthEduCard(
      key: Key('memory_privacy'),
      icon: LucideIcons.mapPinOff,
      title: 'No location on this photo',
      body: 'PawDoc removes GPS and camera data on your device before anything '
          'is uploaded — so a photo of your home never carries its address.',
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.onEdit,
    required this.onAlbum,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onAlbum;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    Widget cell(Key key, IconData icon, String label, Color tint,
            VoidCallback onTap) =>
        Expanded(
          child: Semantics(
            button: true,
            label: label,
            child: ExcludeSemantics(
              child: InkWell(
                key: key,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 17, color: tint),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label,
                            maxLines: 1,
                            style:
                                const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    Widget divider() => Container(
        width: 1, height: 30, color: Colors.white.withValues(alpha: 0.06));

    return HomeCard(
      radius: 16,
      padding: EdgeInsets.zero,
      child: Row(children: [
        cell(const Key('memory_action_edit'), LucideIcons.pencil, 'Edit',
            t.accent, onEdit),
        divider(),
        cell(const Key('memory_action_album'), LucideIcons.folderPlus,
            'Album · Soon', HealthTone.faint, onAlbum),
        divider(),
        cell(const Key('memory_action_download'), LucideIcons.download, 'Save',
            HealthTone.info, onDownload),
        divider(),
        cell(const Key('memory_action_share'), LucideIcons.share2, 'Share',
            HealthTone.teal, onShare),
        divider(),
        // The mockup paints Delete in the EMERGENCY red — the colour that means
        // GET_HELP_NOW everywhere else, including the nav bar on this screen.
        // The ladder's hues are locked against reuse; the confirmation carries
        // the weight instead.
        cell(const Key('memory_delete_button'), LucideIcons.trash2, 'Delete',
            HealthTone.gold, onDelete),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Facts
// ---------------------------------------------------------------------------

/// The mockup's "Memory Stats: Type · Duration · Size · Resolution". A memory
/// is one still photo; neither its byte size nor its pixel dimensions are
/// recorded, and there is no duration because there is no video. These four
/// are what the row actually holds.
class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthSectionHead(
            leading:
                Icon(LucideIcons.chartColumn, size: 17, color: t.accent),
            title: 'Memory Details',
          ),
          const SizedBox(height: 9),
          HealthInfoGrid(
            key: const Key('memory_facts'),
            cells: [
              const HealthInfoCell(
                icon: LucideIcons.image,
                label: 'Type',
                value: 'Photo',
              ),
              HealthInfoCell(
                icon: LucideIcons.calendarDays,
                label: 'Taken on',
                value: shortDate(memory.takenOn),
              ),
              HealthInfoCell(
                icon: LucideIcons.clock,
                label: 'Added',
                value: memory.createdAt == null
                    ? '—'
                    : shortDate(memory.createdAt!.toLocal()),
              ),
              const HealthInfoCell(
                icon: LucideIcons.lock,
                label: 'Stored',
                value: 'Private',
                caption: 'Signed links only',
                captionColor: HealthTone.faint,
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// More from this day
// ---------------------------------------------------------------------------

class _MoreFromThisDay extends StatelessWidget {
  const _MoreFromThisDay({required this.memories, required this.onOpen});

  final List<Memory> memories;
  final ValueChanged<Memory> onOpen;

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
              leading:
                  Icon(LucideIcons.images, size: 17, color: t.accent),
              title: 'More from this day',
              actionLabel: '${memories.length}',
              chevron: false,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              key: const Key('memory_same_day'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 11),
              itemCount: memories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => InkWell(
                key: Key('memory_day_${memories[i].id}'),
                onTap: () => onOpen(memories[i]),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 84,
                    height: 92,
                    child: MemoryPhoto(storageKey: memories[i].storageKey),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
