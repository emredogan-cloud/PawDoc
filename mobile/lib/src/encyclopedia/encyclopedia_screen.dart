import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../core/friendly_error.dart';
import '../core/paw_nav_bar.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'breed.dart';
import 'breed_detail_screen.dart';
import 'breed_sections.dart';
import 'breeds_repository.dart';

/// The Breed Encyclopedia index, rebuilt against mockup `breed_encyclopedia`.
///
/// Header with save and share, the search field beside its Filters button, the
/// six-tile species rail, the featured breed card, and the catalogue itself.
///
/// **Where the reference repeats itself.** Its lower half is `breed_detail`'s
/// content — Breed At a Glance, Ideal For, Common Health Conditions, Similar
/// Breeds — printed under an index's search bar. An index whose search and
/// filters have nothing to filter is not an index, so that half is the
/// catalogue: the featured card keeps its exact composition and every card
/// below it opens the detail page, which carries the rest.
///
/// Safety and content departures are tabled in `breed_sections.dart`; the two
/// that matter here are that the species rail's three unsupported tiles say
/// *Soon* rather than showing an empty list, and that no breed card carries a
/// risk grade.
class EncyclopediaScreen extends ConsumerStatefulWidget {
  const EncyclopediaScreen({super.key, this.initialSpecies});

  /// `dog` | `cat` — preselects the rail.
  final String? initialSpecies;

  @override
  ConsumerState<EncyclopediaScreen> createState() =>
      _EncyclopediaScreenState();
}

/// How the list is ordered.
enum BreedOrder {
  name('Name (A–Z)', LucideIcons.arrowDownAZ),
  size('Largest first', LucideIcons.ruler),
  energy('Most active first', LucideIcons.zap),
  lifespan('Longest lived first', LucideIcons.heart);

  const BreedOrder(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Ordering. Pure, so it is unit-tested without a widget.
List<Breed> sortBreeds(List<Breed> breeds, BreedOrder order) {
  const sizeRank = {'toy': 0, 'small': 1, 'medium': 2, 'large': 3};
  final out = [...breeds];
  switch (order) {
    case BreedOrder.name:
      out.sort((a, b) => a.name.compareTo(b.name));
    case BreedOrder.size:
      out.sort((a, b) {
        final byRank = (sizeRank[b.sizeClass] ?? 0)
            .compareTo(sizeRank[a.sizeClass] ?? 0);
        return byRank != 0 ? byRank : a.name.compareTo(b.name);
      });
    case BreedOrder.energy:
      out.sort((a, b) {
        final byLevel = b.exerciseLevel.compareTo(a.exerciseLevel);
        return byLevel != 0 ? byLevel : a.name.compareTo(b.name);
      });
    case BreedOrder.lifespan:
      out.sort((a, b) {
        final byLife =
            b.lifeExpectancyYears.$2.compareTo(a.lifeExpectancyYears.$2);
        return byLife != 0 ? byLife : a.name.compareTo(b.name);
      });
  }
  return out;
}

class _EncyclopediaScreenState extends ConsumerState<EncyclopediaScreen> {
  final _search = TextEditingController();

  String _query = '';
  late BreedSpecies _species = switch (widget.initialSpecies) {
    'cat' => BreedSpecies.cats,
    'dog' => BreedSpecies.dogs,
    _ => BreedSpecies.all,
  };
  BreedOrder _order = BreedOrder.name;
  bool _savedOnly = false;
  Set<String> _saved = const {};

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await SavedBreeds.load();
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _toggleSaved(Breed breed) async {
    final next = await SavedBreeds.toggle(breed.id);
    if (!mounted) return;
    setState(() => _saved = next);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(next.contains(breed.id)
          ? '${breed.name} saved. Kept on this device.'
          : '${breed.name} removed from saved.'),
    ));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Breed breed, BreedCatalog catalog) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => BreedDetailScreen(
            breed: breed,
            credit: catalog.creditFor(breed.id),
          ),
        ))
        .then((_) => _loadSaved());
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Filter and sort',
        scrollable: true,
        children: [
          const HealthGroupLabel(label: 'Order'),
          for (final o in BreedOrder.values)
            HealthRecordRow(
              key: Key('breed_order_${o.name}'),
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
          const HealthGroupLabel(label: 'Saved'),
          HealthRecordRow(
            key: const Key('breed_filter_saved'),
            leading: HealthGlyphDisc(
              icon: LucideIcons.bookmark,
              tint: _savedOnly
                  ? PawTone.of(context).accent
                  : HealthTone.info,
              size: 36,
            ),
            title: _savedOnly ? 'Showing saved only' : 'Show saved only',
            subtitle: '${_saved.length} saved on this device',
            chevron: false,
            onTap: () {
              Navigator.pop(sheetContext);
              setState(() => _savedOnly = !_savedOnly);
            },
          ),
        ],
      ),
    );
  }

  void _shareGuide() {
    SharePlus.instance.share(ShareParams(
      text: 'PawDoc’s breed guide — general breed information, written to be '
          'read alongside your vet, never instead of them.',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(breedCatalogProvider);

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.pawPrint,
          title: 'Breed Encyclopedia',
          subtitle: 'Learn about every ',
          subtitleTrail: 'breed',
          actions: [
            HealthCircleButton(
              key: const Key('encyclopedia_saved'),
              icon: LucideIcons.bookmark,
              tooltip: 'Saved breeds',
              color: _savedOnly ? PawTone.of(context).accent : null,
              onTap: () => setState(() => _savedOnly = !_savedOnly),
            ),
            HealthCircleButton(
              key: const Key('encyclopedia_share'),
              icon: LucideIcons.share2,
              tooltip: 'Share the guide',
              onTap: _shareGuide,
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(4),
          Row(children: [
            Expanded(
              child: HealthSearchField(
                fieldKey: const Key('encyclopedia_search_field'),
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                hint: 'Search breeds…',
                autofocus: false,
              ),
            ),
            const SizedBox(width: 8),
            _FiltersButton(
              active: _savedOnly || _order != BreedOrder.name,
              onTap: _openFilters,
            ),
          ]),
          gap(11),
          HealthBleed(
            child: _SpeciesRail(
              selected: _species,
              onSelect: (s) {
                if (s.available) {
                  setState(() => _species = s);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${s.label} are coming to the guide. It '
                        'covers dogs and cats today.'),
                  ));
                }
              },
            ),
          ),
          gap(11),
          ...catalogAsync.when(
            loading: () => [const Center(child: CircularProgressIndicator())],
            error: (e, _) => [
              _Notice(
                icon: LucideIcons.bookX,
                title: 'Could not open the guide',
                body: friendlyLoadError(e, noun: 'breeds'),
              ),
            ],
            data: (catalog) => _body(catalog),
          ),
          gap(8),
        ],
      ),
    );
  }

  List<Widget> _body(BreedCatalog catalog) {
    final scoped = _species.filter(catalog.breeds);
    final saved = _savedOnly
        ? [for (final b in scoped) if (_saved.contains(b.id)) b]
        : scoped;
    final results = sortBreeds(searchBreeds(saved, _query), _order);

    if (results.isEmpty) {
      return [
        _Notice(
          key: const Key('encyclopedia_empty'),
          icon: LucideIcons.searchX,
          title: _savedOnly && _query.trim().isEmpty
              ? 'Nothing saved yet'
              : 'No breeds match your search.',
          body: _savedOnly && _query.trim().isEmpty
              ? 'Tap the bookmark on a breed to keep it here.'
              : 'The guide covers ${catalog.breeds.length} breeds so far. Try '
                  'a shorter word, or a country of origin.',
        ),
      ];
    }

    // The reference features one breed above the fold, at full width.
    final featured = results.first;
    final rest = results.skip(1).toList();
    return [
      _FeaturedCard(
        breed: featured,
        saved: _saved.contains(featured.id),
        onSave: () => _toggleSaved(featured),
        onOpen: () => _open(featured, catalog),
      ),
      gap(13),
      HealthSectionHead(
        title: _species == BreedSpecies.all
            ? 'Every Breed'
            : 'All ${_species.label}',
        actionLabel: '${results.length} in the guide',
        chevron: false,
        onAction: null,
        leading: const Icon(LucideIcons.library,
            size: 15, color: HealthTone.muted),
      ),
      gap(9),
      for (final breed in rest) ...[
        _BreedRow(
          breed: breed,
          saved: _saved.contains(breed.id),
          onSave: () => _toggleSaved(breed),
          onOpen: () => _open(breed, catalog),
        ),
        gap(9),
      ],
      const HealthEduCard(
        key: Key('encyclopedia_footer'),
        icon: LucideIcons.info,
        title: 'How to read this guide',
        body: kBreedHealthDisclaimer,
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Tooltip(
      message: 'Filter and sort',
      child: Semantics(
        button: true,
        label: 'Filter and sort',
        child: InkWell(
          key: const Key('encyclopedia_filters'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: t.accent.withValues(alpha: active ? 0.14 : 0.08),
              border: Border.all(color: t.accent.withValues(alpha: 0.65)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.filter, size: 16, color: t.accent),
              const SizedBox(width: 7),
              Text('Filters',
                  style: TextStyle(
                      color: t.accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SpeciesRail extends StatelessWidget {
  const _SpeciesRail({required this.selected, required this.onSelect});

  final BreedSpecies selected;
  final ValueChanged<BreedSpecies> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      height: 92,
      child: ListView(
        key: const Key('encyclopedia_species_rail'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kRecordGutter),
        children: [
          for (final s in BreedSpecies.values) ...[
            SizedBox(
              width: 78,
              child: InkWell(
                key: Key('encyclopedia_species_${s.name}'),
                onTap: () => onSelect(s),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s == selected
                            ? t.accent.withValues(alpha: 0.14)
                            : HealthTone.card,
                        border: Border.all(
                          color: s == selected
                              ? t.accent
                              : Colors.white.withValues(alpha: 0.08),
                          width: s == selected ? 1.6 : 1,
                        ),
                      ),
                      child: Icon(s.icon,
                          size: 23,
                          color: s == selected
                              ? t.accent
                              : (s.available
                                  ? Colors.white70
                                  : HealthTone.faint)),
                    ),
                    const SizedBox(height: 7),
                    Text(s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: s == selected
                                ? t.accent
                                : (s.available
                                    ? Colors.white
                                    : HealthTone.faint),
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: s == selected
                                ? FontWeight.w700
                                : FontWeight.w500)),
                    if (!s.available)
                      const Text('Soon',
                          style: TextStyle(
                              color: HealthTone.faint,
                              fontSize: 9.5,
                              height: 1.2)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

/// The reference's featured breed: photograph on the left, name, binomial,
/// temperament chips, the fact strip and the opening of the description.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.breed,
    required this.saved,
    required this.onSave,
    required this.onOpen,
  });

  final Breed breed;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: Key('breed_featured_${breed.id}'),
      radius: 18,
      padding: EdgeInsets.zero,
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 168,
                  width: double.infinity,
                  child: BreedPhoto(breed: breed),
                ),
                Positioned(
                  right: 9,
                  top: 9,
                  child: BreedSaveButton(saved: saved, onTap: onSave),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(breed.name,
                      key: const Key('breed_featured_name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1.15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 1),
                  Text(breedBinomial(breed.species),
                      style: const TextStyle(
                          color: HealthTone.muted,
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final trait in breed.temperament.take(4))
                        BreedTraitChip(label: trait),
                    ],
                  ),
                  const SizedBox(height: 11),
                  BreedFactStrip(facts: breedFacts(breed)),
                  const SizedBox(height: 11),
                  Text(breed.personality,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: HealthTone.dim, fontSize: 11.5, height: 1.45)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('Read more',
                        style: TextStyle(
                            color: t.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Icon(LucideIcons.chevronRight, size: 14, color: t.accent),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreedRow extends StatelessWidget {
  const _BreedRow({
    required this.breed,
    required this.saved,
    required this.onSave,
    required this.onOpen,
  });

  final Breed breed;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: Key('breed_card_${breed.id}'),
      radius: 16,
      padding: const EdgeInsets.all(9),
      onTap: onOpen,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 66,
              height: 66,
              child: BreedPhoto(breed: breed),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(breed.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    '${breed.sizeLabel} · ${breed.weightLabel} · '
                    '${breed.lifeExpectancyLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.muted, fontSize: 11, height: 1.25)),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    for (final trait in breed.temperament.take(2))
                      BreedTraitChip(label: trait),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          BreedSaveButton(saved: saved, onTap: onSave, size: 32),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
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
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
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
