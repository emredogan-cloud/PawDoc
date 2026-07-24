import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_views.dart';
import '../core/motion.dart';
import '../pets/pet.dart' show speciesEmoji;
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'breed.dart';
import 'breed_detail_screen.dart';
import 'breeds_repository.dart';

/// The Breed Encyclopedia (Next Evolution Phase 3): a premium field guide —
/// species tabs, search-as-you-type, photo cards. Launch catalog: 10 dogs +
/// 10 cats; the data layer scales to hundreds without UI changes.
class EncyclopediaScreen extends ConsumerStatefulWidget {
  const EncyclopediaScreen({super.key, this.initialSpecies});

  /// 'dog' | 'cat' — preselects the tab (e.g. entered from a cat profile).
  final String? initialSpecies;

  @override
  ConsumerState<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends ConsumerState<EncyclopediaScreen> {
  late String _species =
      widget.initialSpecies == 'cat' ? 'cat' : 'dog';
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(breedCatalogProvider);
    return PawScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Breed Encyclopedia'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s8),
            child: SegmentedButton<String>(
              key: const Key('encyclopedia_species_toggle'),
              segments: [
                ButtonSegment(
                    value: 'dog',
                    label: Text('${speciesEmoji('dog')} Dogs')),
                ButtonSegment(
                    value: 'cat',
                    label: Text('${speciesEmoji('cat')} Cats')),
              ],
              selected: {_species},
              onSelectionChanged: (s) => setState(() => _species = s.first),
              showSelectedIcon: false,
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            child: TextField(
              key: const Key('encyclopedia_search_field'),
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name, origin, or temperament…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          Expanded(
            child: catalogAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpace.s16),
                children: const [
                  SkeletonCard(height: 220),
                  SkeletonCard(height: 220),
                  SkeletonCard(height: 220),
                ],
              ),
              error: (e, _) => AppErrorView(
                message: 'Could not load the encyclopedia.',
                onRetry: () => ref.invalidate(breedCatalogProvider),
              ),
              data: (catalog) {
                final visible =
                    searchBreeds(catalog.bySpecies(_species), _query);
                if (visible.isEmpty) {
                  return const AppEmptyView(
                    message: 'No breeds match your search.',
                    icon: Icons.search_off_rounded,
                  );
                }
                return ListView.separated(
                  key: const Key('encyclopedia_list'),
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.s16, AppSpace.s4, AppSpace.s16, AppSpace.s24),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpace.s12),
                  itemBuilder: (context, i) => _BreedCard(
                    breed: visible[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BreedDetailScreen(
                          breed: visible[i],
                          credit: catalog.creditFor(visible[i].id),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BreedCard extends StatelessWidget {
  const _BreedCard({required this.breed, required this.onTap});

  final Breed breed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PawCard(
      key: Key('breed_card_${breed.id}'),
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'breed_${breed.id}',
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.asset(
                breed.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: PawPalette.leaf.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: Text(speciesEmoji(breed.species),
                      style: const TextStyle(fontSize: 48)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        breed.name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: AppColors.ink50),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: PawPalette.mint),
                  ],
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  '${breed.origin} · ${breed.lifeExpectancyLabel} · ${breed.sizeLabel}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.ink300),
                ),
                const SizedBox(height: AppSpace.s8),
                Wrap(
                  spacing: AppSpace.s4,
                  runSpacing: AppSpace.s4,
                  children: [
                    for (final t in breed.temperament.take(3))
                      _Chip(label: t),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8, vertical: AppSpace.s4),
      decoration: BoxDecoration(
        color: PawPalette.teal.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: PawPalette.mint),
      ),
    );
  }
}
