import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/user_profile.dart';
import '../core/app_views.dart';
import '../core/motion.dart';
import '../monetization/paywall_screen.dart';
import '../pets/pet.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'memories_repository.dart';
import 'memory.dart';
import 'memory_editor_sheet.dart';
import 'memory_photo.dart';
import 'memory_viewer_screen.dart';

/// The pet journal (Next Evolution Phase 2): a premium gallery + timeline of
/// photo memories for one pet, with search, create/edit/delete. Human content
/// only — no AI, no safety logic.
class MemoriesScreen extends ConsumerStatefulWidget {
  const MemoriesScreen({super.key, required this.pet});

  final Pet pet;

  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _timeline = false;

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
    final saved = await showMemoryEditorSheet(context, pet: widget.pet);
    if (saved == true) _refresh();
  }

  void _refresh() {
    ref.invalidate(memoriesListProvider(widget.pet.id!));
    ref.invalidate(memoriesCountProvider);
  }

  void _showLimitSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.ink900,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your memory book is full',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.ink50)),
              const SizedBox(height: AppSpace.s8),
              Text(
                'The free plan holds $kFreeMemoryLimit memories. Premium keeps '
                'the whole story — unlimited memories, across all your pets.',
                style: Theme.of(sheetContext)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.ink300),
              ),
              const SizedBox(height: AppSpace.s16),
              PawPrimaryButton(
                key: const Key('memories_upgrade_button'),
                icon: Icons.workspace_premium_rounded,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const PaywallScreen()),
                  );
                },
                child: const Text('See Premium'),
              ),
              const SizedBox(height: AppSpace.s8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(Memory memory) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MemoryViewerScreen(memory: memory, pet: widget.pet),
      ),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memoriesAsync = ref.watch(memoriesListProvider(widget.pet.id!));
    return PawScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Memories'),
            Text(
              'with ${widget.pet.name}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: PawPalette.mint),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('memories_view_toggle'),
            tooltip: _timeline ? 'Gallery view' : 'Timeline view',
            icon: Icon(_timeline
                ? Icons.grid_view_rounded
                : Icons.view_timeline_outlined),
            onPressed: () => setState(() => _timeline = !_timeline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('memories_new_button'),
        onPressed: _add,
        backgroundColor: PawPalette.teal,
        foregroundColor: PawPalette.bgBottom,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('New memory'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s8),
            child: TextField(
              key: const Key('memories_search_field'),
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search memories…',
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
          _AllowanceStrip(),
          Expanded(
            child: memoriesAsync.when(
              loading: () => const _MemoriesSkeleton(),
              error: (e, _) => AppErrorView(
                message: 'Could not load memories.',
                onRetry: _refresh,
              ),
              data: (memories) {
                final filtered = filterMemories(memories, _query);
                if (memories.isEmpty) {
                  return _EmptyMemories(
                      petName: widget.pet.name, onAdd: _add);
                }
                if (filtered.isEmpty) {
                  return const AppEmptyView(
                    message: 'No memories match your search.',
                    icon: Icons.search_off_rounded,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: _timeline
                      ? _MemoriesTimeline(memories: filtered, onOpen: _open)
                      : _MemoriesGrid(memories: filtered, onOpen: _open),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Free-plan allowance line (hidden for premium). Quiet by design — a caption,
/// not a meter dominating a joyful surface.
class _AllowanceStrip extends ConsumerWidget {
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
      padding: const EdgeInsets.only(bottom: AppSpace.s4),
      child: Text(
        '$used of $kFreeMemoryLimit free memories used',
        key: const Key('memories_allowance'),
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.ink300),
      ),
    );
  }
}

class _MemoriesGrid extends StatelessWidget {
  const _MemoriesGrid({required this.memories, required this.onOpen});

  final List<Memory> memories;
  final ValueChanged<Memory> onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const Key('memories_grid'),
      padding: const EdgeInsets.fromLTRB(
          AppSpace.s16, AppSpace.s4, AppSpace.s16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpace.s12,
        crossAxisSpacing: AppSpace.s12,
      ),
      itemCount: memories.length,
      itemBuilder: (context, i) => _MemoryCell(
        memory: memories[i],
        onTap: () => onOpen(memories[i]),
      ),
    );
  }
}

class _MemoryCell extends StatelessWidget {
  const _MemoryCell({required this.memory, required this.onTap});

  final Memory memory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brMd,
      child: ClipRRect(
        borderRadius: AppRadius.brMd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'memory_${memory.id}',
              child: MemoryPhoto(storageKey: memory.storageKey),
            ),
            // Legibility gradient behind the caption.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpace.s12,
              right: AppSpace.s12,
              bottom: AppSpace.s12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: Colors.white),
                  ),
                  Text(
                    _shortDate(memory.takenOn),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoriesTimeline extends StatelessWidget {
  const _MemoriesTimeline({required this.memories, required this.onOpen});

  final List<Memory> memories;
  final ValueChanged<Memory> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = groupMemoriesByMonth(memories);
    return ListView(
      key: const Key('memories_timeline'),
      padding: const EdgeInsets.fromLTRB(
          AppSpace.s16, AppSpace.s4, AppSpace.s16, 96),
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.only(
                top: AppSpace.s12, bottom: AppSpace.s8),
            child: Text(
              memoryMonthLabel(group.month),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: PawPalette.mint),
            ),
          ),
          for (final memory in group.memories)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8),
              child: PawCard(
                onTap: () => onOpen(memory),
                padding: const EdgeInsets.all(AppSpace.s8),
                radius: AppRadius.md,
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: MemoryPhoto(
                        storageKey: memory.storageKey,
                        borderRadius: AppRadius.brSm,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memory.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: AppColors.ink50),
                          ),
                          if ((memory.note ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              memory.note!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.ink300),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            _shortDate(memory.takenOn),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.ink300),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.ink300),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _EmptyMemories extends StatelessWidget {
  const _EmptyMemories({required this.petName, required this.onAdd});

  final String petName;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      key: const Key('memories_empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PawPalette.teal.withValues(alpha: 0.18),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 40, color: PawPalette.mint),
            ),
            const SizedBox(height: AppSpace.s16),
            Text(
              'Start $petName’s story',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.titleLarge?.copyWith(color: AppColors.ink50),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              'Keep the little moments — first walks, silly naps, birthday '
              'treats. Your memories stay private to you.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: AppColors.ink300),
            ),
            const SizedBox(height: AppSpace.s24),
            PawPrimaryButton(
              icon: Icons.add_a_photo_rounded,
              expand: false,
              onPressed: onAdd,
              child: const Text('Add the first memory'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoriesSkeleton extends StatelessWidget {
  const _MemoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpace.s16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpace.s12,
        crossAxisSpacing: AppSpace.s12,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const Skeleton(
        height: double.infinity,
        width: double.infinity,
      ),
    );
  }
}

String _shortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
