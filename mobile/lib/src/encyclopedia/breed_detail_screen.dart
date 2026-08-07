import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/paw_nav_bar.dart';
import '../health/health_sections.dart';
import '../home/home_sections.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';
import 'breed.dart';
import 'breed_sections.dart';
import 'breeds_repository.dart';

/// One breed, rebuilt against mockup `breed_detail`.
///
/// Hero with the photograph, name, binomial, temperament chips and the fact
/// grid; a section rail; then the glance card, the highlights, size, life
/// expectancy, care essentials, the health notes, quick facts, the gallery
/// with its attribution, and the similar breeds.
///
/// **Everything on it comes from `breeds_v1.json`.** Where the reference asks
/// for a field the catalogue does not carry, the row holds a field it does —
/// the full table is in `breed_sections.dart`. The three that matter:
///
/// * **"Common Health Conditions · Hip Dysplasia · Risk: Moderate"** with a
///   dot meter becomes the catalogue's own hedged notes with no grade at all.
///   A risk level printed beside a named condition is a claim, and the reader
///   most likely to see this page is the owner of that exact breed.
/// * **"Popularity #3 · AKC Rankings"** is not in the catalogue and citing a
///   registry's ranking would be fabrication. The badge became the save
///   control, which is real and device-local.
/// * **"With proper care… can live a long, healthy and happy life"** is a
///   promise. The life-expectancy card states the range and stops.
class BreedDetailScreen extends ConsumerStatefulWidget {
  const BreedDetailScreen({super.key, required this.breed, this.credit});

  final Breed breed;
  final BreedCredit? credit;

  @override
  ConsumerState<BreedDetailScreen> createState() => _BreedDetailScreenState();
}

/// The reference's section rail.
enum BreedSection {
  overview('Overview', LucideIcons.eye),
  care('Care', LucideIcons.heart),
  health('Health', LucideIcons.stethoscope),
  traits('Traits', LucideIcons.star),
  gallery('Gallery', LucideIcons.image),
  similar('Similar', LucideIcons.copy);

  const BreedSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _BreedDetailScreenState extends ConsumerState<BreedDetailScreen> {
  BreedSection _section = BreedSection.overview;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await SavedBreeds.load();
    if (mounted) setState(() => _saved = saved.contains(widget.breed.id));
  }

  Future<void> _toggleSaved() async {
    final next = await SavedBreeds.toggle(widget.breed.id);
    if (!mounted) return;
    setState(() => _saved = next.contains(widget.breed.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_saved
          ? '${widget.breed.name} saved. Kept on this device.'
          : '${widget.breed.name} removed from saved.'),
    ));
  }

  void _share() {
    final b = widget.breed;
    SharePlus.instance.share(ShareParams(
      text: '${b.name} — ${b.sizeLabel}, ${b.weightLabel}, '
          '${b.lifeExpectancyLabel}. From PawDoc’s breed guide. General breed '
          'information, not advice about any particular animal.',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final breed = widget.breed;
    final catalog = ref.watch(breedCatalogProvider).value;

    return PawBackground(
      variant: PawSurface.dark,
      child: HealthRecordScaffold(
        appBar: PetModuleAppBar(
          icon: LucideIcons.pawPrint,
          title: 'Breed Detail',
          subtitle: 'Everything in the guide about this ',
          subtitleTrail: 'breed',
          actions: [
            HealthCircleButton(
              key: const Key('breed_save'),
              icon: LucideIcons.bookmark,
              tooltip: _saved ? 'Remove from saved' : 'Save this breed',
              color: _saved ? PawTone.of(context).accent : null,
              onTap: _toggleSaved,
            ),
            HealthCircleButton(
              key: const Key('breed_share'),
              icon: LucideIcons.share2,
              tooltip: 'Share',
              onTap: _share,
            ),
          ],
        ),
        bottomNav: const PawNavBar(detached: true),
        children: [
          gap(2),
          _Hero(breed: breed, saved: _saved, onSave: _toggleSaved),
          gap(11),
          HealthBleed(
            child: _SectionRail(
              selected: _section,
              onSelect: (s) => setState(() => _section = s),
            ),
          ),
          gap(11),
          ...switch (_section) {
            BreedSection.overview => _overview(breed),
            BreedSection.care => _care(breed),
            BreedSection.health => _health(breed),
            BreedSection.traits => _traits(breed),
            BreedSection.gallery => _gallery(breed),
            BreedSection.similar => _similar(breed, catalog),
          },
          gap(11),
          _MatchCard(onTap: _explainQuiz),
          gap(8),
        ],
      ),
    );
  }

  void _explainQuiz() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const HealthSheet(
        title: 'Breed match',
        scrollable: true,
        children: [
          Text(
            'A questionnaire that weighs your home, your hours and your '
            'experience against what a breed needs is coming. It is not here '
            'yet, and a made-up score would be a poor way to choose an animal '
            'you will live with for a decade.',
            style:
                TextStyle(color: HealthTone.dim, fontSize: 12.5, height: 1.45),
          ),
          HealthEduCard(
            icon: LucideIcons.stethoscope,
            title: 'In the meantime',
            body: 'A rescue or a breed club will tell you more in ten minutes '
                'than any quiz, and a vet will tell you what a breed needs '
                'where you live.',
          ),
        ],
      ),
    );
  }

  // --- overview ------------------------------------------------------------

  List<Widget> _overview(Breed breed) => [
        HomeCard(
          key: const Key('breed_glance_card'),
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthSectionHead(
                title: 'Breed at a Glance',
                leading:
                    Icon(LucideIcons.eye, size: 15, color: HealthTone.muted),
              ),
              const SizedBox(height: 8),
              // Only the two levels the catalogue authors get a meter. The
              // reference draws six, four of which nobody rated.
              BreedMeterRow(
                label: 'Exercise',
                level: breed.exerciseLevel,
                caption: BreedMeterRow.words[breed.exerciseLevel - 1],
              ),
              BreedMeterRow(
                label: 'Grooming',
                level: breed.groomingLevel,
                caption: BreedMeterRow.words[breed.groomingLevel - 1],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0x14FFFFFF)),
              const SizedBox(height: 8),
              HealthDetailRow(
                  icon: LucideIcons.mapPin,
                  label: 'Origin',
                  value: breed.origin),
              HealthDetailRow(
                  icon: LucideIcons.globe,
                  label: 'Kept in',
                  value: breed.countries.join(', ')),
              HealthDetailRow(
                  icon: LucideIcons.scissors, label: 'Coat', value: breed.coat),
            ],
          ),
        ),
        gap(11),
        HomeCard(
          key: const Key('breed_about_card'),
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthSectionHead(
                title: 'About the Breed',
                leading: Icon(LucideIcons.bookOpen,
                    size: 15, color: HealthTone.muted),
              ),
              const SizedBox(height: 8),
              Text(breed.personality,
                  style: const TextStyle(
                      color: HealthTone.dim, fontSize: 12, height: 1.5)),
            ],
          ),
        ),
        gap(11),
        _SizeCard(breed: breed),
        gap(11),
        _LifeCard(breed: breed),
      ];

  // --- care ----------------------------------------------------------------

  List<Widget> _care(Breed breed) => [
        HomeCard(
          key: const Key('breed_care_card'),
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthSectionHead(
                title: 'Care Essentials',
                leading:
                    Icon(LucideIcons.heart, size: 15, color: HealthTone.muted),
              ),
              const SizedBox(height: 10),
              _CareRow(
                icon: LucideIcons.footprints,
                title: 'Exercise',
                level: breed.exerciseLevel,
                body: breed.exerciseNote,
              ),
              const SizedBox(height: 11),
              _CareRow(
                icon: LucideIcons.scissors,
                title: 'Grooming',
                level: breed.groomingLevel,
                body: breed.groomingNote,
              ),
              const SizedBox(height: 11),
              // The reference's third row is "Nutrition · High quality dog
              // food" — dietary advice with no source. This is the coat, which
              // is in the catalogue and is what the grooming note is about.
              _CareRow(
                icon: LucideIcons.sparkles,
                title: 'Coat',
                level: null,
                body: breed.coat,
              ),
            ],
          ),
        ),
        gap(11),
        const HealthEduCard(
          key: Key('breed_care_footer'),
          icon: LucideIcons.stethoscope,
          title: 'What a breed cannot tell you',
          body: 'How much exercise, which food and how often to groom depend '
              'on the animal in front of you — their age, their weight and '
              'their health. That is a conversation with your vet.',
        ),
      ];

  // --- health --------------------------------------------------------------

  List<Widget> _health(Breed breed) => [
        BreedHealthCard(breed: breed),
        gap(11),
        HealthEduCard(
          key: const Key('breed_health_footer'),
          icon: LucideIcons.searchCheck,
          title: 'If you are choosing a puppy or kitten',
          body: 'Ask the breeder or rescue which screening tests the parents '
              'had, and for the paperwork. A ${breed.name} from tested lines '
              'is the question worth asking.',
        ),
      ];

  // --- traits --------------------------------------------------------------

  List<Widget> _traits(Breed breed) => [
        HomeCard(
          key: const Key('breed_traits_card'),
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthSectionHead(
                title: 'Temperament',
                leading:
                    Icon(LucideIcons.star, size: 15, color: HealthTone.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final trait in breed.temperament)
                    BreedTraitChip(label: trait),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Words that describe the breed as a whole. Individual animals '
                'vary far more than any list of adjectives suggests.',
                style: TextStyle(
                    color: HealthTone.faint, fontSize: 10.5, height: 1.4),
              ),
            ],
          ),
        ),
        gap(11),
        if (breed.funFacts.isNotEmpty)
          HomeCard(
            key: const Key('breed_facts_card'),
            radius: 18,
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HealthSectionHead(
                  title: 'Worth Knowing',
                  leading: Icon(LucideIcons.lightbulb,
                      size: 15, color: HealthTone.muted),
                ),
                const SizedBox(height: 9),
                for (final fact in breed.funFacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: PawTone.of(context)
                                  .accent
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(fact,
                              style: const TextStyle(
                                  color: HealthTone.dim,
                                  fontSize: 11.5,
                                  height: 1.45)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ];

  // --- gallery -------------------------------------------------------------

  List<Widget> _gallery(Breed breed) => [
        HomeCard(
          key: const Key('breed_gallery_card'),
          radius: 18,
          padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthSectionHead(
                title: 'Gallery',
                leading:
                    Icon(LucideIcons.image, size: 15, color: HealthTone.muted),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: BreedPhoto(breed: breed),
                ),
              ),
              const SizedBox(height: 9),
              // The reference counts "1 / 24". The guide bundles one
              // photograph per breed, and says so rather than promising 24.
              const Text('One photograph per breed in this guide.',
                  style: TextStyle(
                      color: HealthTone.faint, fontSize: 10.5, height: 1.35)),
              if (widget.credit != null) ...[
                const SizedBox(height: 10),
                _Credit(credit: widget.credit!),
              ],
            ],
          ),
        ),
      ];

  // --- similar -------------------------------------------------------------

  List<Widget> _similar(Breed breed, BreedCatalog? catalog) {
    final others =
        catalog == null ? const <Breed>[] : similarBreeds(catalog.breeds, breed);
    return [
      HomeCard(
        key: const Key('breed_similar_card'),
        radius: 18,
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HealthSectionHead(
              title: 'Similar Breeds',
              leading:
                  Icon(LucideIcons.copy, size: 15, color: HealthTone.muted),
            ),
            const SizedBox(height: 3),
            // The reference lists four with no stated basis.
            const Text(
                'Matched on size, temperament and activity, within this guide.',
                style: TextStyle(
                    color: HealthTone.faint, fontSize: 10.5, height: 1.35)),
            const SizedBox(height: 11),
            if (others.isEmpty)
              const Text('Nothing else of this species in the guide yet.',
                  style: TextStyle(
                      color: HealthTone.faint, fontSize: 11.5, height: 1.4))
            else
              SizedBox(
                height: 132,
                child: ListView.separated(
                  key: const Key('breed_similar_rail'),
                  scrollDirection: Axis.horizontal,
                  itemCount: others.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 9),
                  itemBuilder: (context, i) {
                    final other = others[i];
                    return SizedBox(
                      width: 104,
                      child: InkWell(
                        key: Key('breed_similar_${other.id}'),
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => BreedDetailScreen(
                              breed: other,
                              credit: catalog?.creditFor(other.id),
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: SizedBox(
                                height: 84,
                                width: 104,
                                child:
                                    BreedPhoto(breed: other),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(other.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.breed, required this.saved, required this.onSave});

  final Breed breed;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      radius: 18,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 186,
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
                      key: const Key('breed_detail_name'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 1),
                  Text(breedBinomial(breed.species),
                      style: const TextStyle(
                          color: HealthTone.muted,
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final trait in breed.temperament.take(4))
                        BreedTraitChip(label: trait),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BreedFactStrip(facts: breedFacts(breed)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({required this.selected, required this.onSelect});

  final BreedSection selected;
  final ValueChanged<BreedSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SizedBox(
      height: 40,
      child: ListView(
        key: const Key('breed_section_rail'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kRecordGutter),
        children: [
          for (final s in BreedSection.values) ...[
            Material(
              color: s == selected
                  ? t.accent.withValues(alpha: 0.10)
                  : HealthTone.card,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                key: Key('breed_section_${s.name}'),
                onTap: () => onSelect(s),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: s == selected
                          ? t.accent
                          : Colors.white.withValues(alpha: 0.08),
                      width: s == selected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.icon,
                        size: 14,
                        color: s == selected ? t.accent : HealthTone.muted),
                    const SizedBox(width: 7),
                    Text(s.label,
                        style: TextStyle(
                            color: s == selected ? t.accent : Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

class _CareRow extends StatelessWidget {
  const _CareRow({
    required this.icon,
    required this.title,
    required this.level,
    required this.body,
  });

  final IconData icon;
  final String title;
  final int? level;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.accent.withValues(alpha: 0.09),
          ),
          child: Icon(icon, size: 16, color: t.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.2,
                          fontWeight: FontWeight.w700)),
                ),
                if (level != null)
                  HealthPill(
                    label: BreedMeterRow.words[level! - 1],
                    tint: HealthTone.info,
                  ),
              ]),
              const SizedBox(height: 3),
              Text(body,
                  style: const TextStyle(
                      color: HealthTone.dim, fontSize: 11.5, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The reference's "Size Reference" card, with its invented centimetres
/// replaced by the weight range the catalogue actually carries.
class _SizeCard extends StatelessWidget {
  const _SizeCard({required this.breed});

  final Breed breed;

  static const _order = ['toy', 'small', 'medium', 'large'];

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final index = _order.indexOf(breed.sizeClass);
    return HomeCard(
      key: const Key('breed_size_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HealthSectionHead(
            title: 'Size',
            leading:
                Icon(LucideIcons.ruler, size: 15, color: HealthTone.muted),
          ),
          const SizedBox(height: 11),
          Row(children: [
            for (var i = 0; i < _order.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i <= index && index >= 0
                            ? t.accent
                            : Colors.white.withValues(alpha: 0.09),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _order[i][0].toUpperCase() + _order[i].substring(1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: i == index ? t.accent : HealthTone.faint,
                          fontSize: 10.5,
                          fontWeight:
                              i == index ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ]),
          const SizedBox(height: 11),
          Text('${breed.sizeLabel} · typically ${breed.weightLabel}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          const Text(
              'A range across the breed. Where an individual falls in it is a '
              'body-condition question for a vet, not a target.',
              style: TextStyle(
                  color: HealthTone.faint, fontSize: 10.5, height: 1.35)),
        ],
      ),
    );
  }
}

class _LifeCard extends StatelessWidget {
  const _LifeCard({required this.breed});

  final Breed breed;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return HomeCard(
      key: const Key('breed_life_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HealthSectionHead(
            title: 'Life Expectancy',
            leading:
                Icon(LucideIcons.heart, size: 15, color: HealthTone.muted),
          ),
          const SizedBox(height: 10),
          // Flexible, not bare: at the em-square test font "10–12 years,
          // typically" overflowed the card by 1.3px.
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(
              child: Text(breed.lifeExpectancyLabel.replaceAll(' yrs', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.accent,
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 7),
            const Flexible(
              child: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text('years, typically',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: HealthTone.muted, fontSize: 12)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          // The reference closes this card with "With proper care… can live a
          // long, healthy and happy life." That is a promise about an animal.
          const Text(
              'A published range for the breed. It is not a prediction, and '
              'nothing an app does changes it.',
              style: TextStyle(
                  color: HealthTone.faint, fontSize: 10.5, height: 1.35)),
        ],
      ),
    );
  }
}

/// The reference's "Take Breed Match Quiz". There is no quiz.
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      key: const Key('breed_match_card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
            child: const Icon(LucideIcons.shieldQuestionMark,
                size: 17, color: HealthTone.muted),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Is this the right breed for you?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text(
                    'A match questionnaire is coming. Until it is here, this '
                    'guide will not score the decision for you.',
                    style: TextStyle(
                        color: HealthTone.dim, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const HealthPill(label: 'Soon', tint: HealthTone.faint),
        ],
      ),
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit({required this.credit});

  final BreedCredit credit;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return InkWell(
      key: const Key('breed_photo_credit'),
      onTap: () => launchUrl(Uri.parse(credit.sourceUrl),
          mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.028),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(children: [
          const Icon(LucideIcons.camera, size: 14, color: HealthTone.muted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
                'Photo by ${credit.author} · ${credit.license}',
                maxLines: 2,
                style: const TextStyle(
                    color: HealthTone.dim, fontSize: 10.5, height: 1.35)),
          ),
          Icon(LucideIcons.externalLink, size: 13, color: t.accent),
        ]),
      ),
    );
  }
}
